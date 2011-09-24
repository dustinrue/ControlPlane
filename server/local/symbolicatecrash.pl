#!/usr/bin/perl
#
# This script parses a crashdump file and attempts to resolve addresses into function names.
#
# It finds symbol-rich binaries by:
#   a) searching in Spotlight to find .dSYM files by UUID, then finding the executable from there.
#       That finds the symbols for binaries that a developer has built with "DWARF with dSYM File".
#   b) searching in various SDK directories.
#
# Copyright (c) 2008-2009 Apple Inc. All Rights Reserved.
#
#

use strict;
#use warnings;
use Getopt::Std;
use Cwd qw(realpath);
use Math::BigInt;

#############################

# Forward definitons
sub usage();

#############################

# read and parse command line
my %opt;
$Getopt::Std::STANDARD_HELP_VERSION = 1;

getopts('Ahvo:',\%opt);

usage() if $opt{'h'};

#############################

# have this thing to de-HTMLize Leopard-era plists
my %entity2char = (
    # Some normal chars that have special meaning in SGML context
    amp    => '&',  # ampersand 
    'gt'    => '>',  # greater than
    'lt'    => '<',  # less than
    quot   => '"',  # double quote;  this " character in the comment keeps Xcode syntax coloring happy 
    apos   => "'",  # single quote '
    );

# Array of all the supported architectures.
my %architectures = (
	ARM      =>  "armv6",
	X86      =>  "i386",
	"X86-64" =>  "x86_64",
	PPC      =>  "ppc",
	"PPC-64" =>  "ppc64",
	"ARMV4T" =>  "armv4t",
	"ARMV5"  =>  "armv5",
	"ARMV6"  =>  "armv6",
	"ARMV7"  =>  "armv7",
);
#############################


my $devToolsPath = `/usr/bin/xcode-select -print-path`;
chomp $devToolsPath;

# Find otool from the latest iphoneos
my $otool = `xcrun -sdk iphoneos -find otool`;
chomp($otool);
my $atos = `xcrun -sdk iphoneos -find atos`;
chomp($atos);

if ( ! -f $otool ) {
    # if that doesn't exist, then assume the PDK was installed
    $otool = "/usr/bin/otool";
    $atos = "/usr/bin/atos";
}
print STDERR "otool path is '$otool'\n" if $opt{v};
print STDERR "atos path is '$atos'\n" if $opt{v};

# quotemeta makes the paths such that -f can't be used
$devToolsPath = quotemeta($devToolsPath);
$otool = quotemeta($otool);
$atos = quotemeta($atos);


#############################
# run the script

symbolicate_log(@ARGV);


#############################

# begin subroutines

sub HELP_MESSAGE() {
    usage();
}

sub usage() {
print STDERR <<EOF;
usage: 
    $0 [-Ah] [-o <OUTPUT_FILE>] LOGFILE [SYMBOL_PATH ...]
    
    Symbolicates a crashdump LOGFILE which may be "-" to refer to stdin. By default,
    all heuristics will be employed in an attempt to symbolicate all addresses. 
    Additional symbol files can be found under specified directories.
    
Options:
    
    -A  Only symbolicate the application, not libraries
    -o  If specified, the symbolicated log will be written to OUTPUT_FILE (defaults to stdout)
    -h  Display this message
    -v  Verbose
EOF
exit 1;
}

##############

sub getSymbolDirPaths {
    my ($osVersion, $osBuild) = @_;
    
    my @devToolsPaths = ($devToolsPath);
    
    my @foundPaths = `mdfind -onlyin / "kMDItemCFBundleIdentifier == 'com.apple.Xcode'"`;
    
    foreach my $foundPath (@foundPaths) {
        chomp $foundPath;
        $foundPath =~ s/\/Applications\/Xcode.app$//;
        $foundPath = quotemeta($foundPath);
        if( $foundPath ne $devToolsPath ) {
            push(@devToolsPaths, $foundPath);
        }
    }
    
    my @result = ();
    
    foreach my $foundDevToolsPath (@devToolsPaths) {
        my $symbolDirs = $foundDevToolsPath . '\/Platforms\/*\.platform/DeviceSupport\/*\/Symbols*';
        my @pathResults = grep { -e && -d && !/Simulator/ } glob $symbolDirs;
        print STDERR "Symbol directory paths:  @pathResults\n" if $opt{v};
        push(@result, @pathResults);
    }
	
	## start with most specific "version build", then just build, last just version.
	my @pathsForOSbuild = grep { /$osVersion \($osBuild\)/ } @result;
	if ( @pathsForOSbuild <= 0 ) {
		@pathsForOSbuild = grep { /$osBuild/ } @result;
	}
	if ( @pathsForOSbuild <= 0 ) {
		@pathsForOSbuild = grep { /$osVersion/ } @result;
	}

	if ( @pathsForOSbuild <= 0 ) {
		print STDERR "Symbol directory path(s) not found for $osVersion ($osBuild):  @pathsForOSbuild\n" if $opt{v};
        # hmm, didn't find a path for the specific build, so return all the paths we got.
        return @result;
    }
	
	print STDERR "Symbol directory path(s) for $osVersion ($osBuild):  @pathsForOSbuild\n" if $opt{v};
	return @pathsForOSbuild;
}

sub getSymbolPathFor_searchpaths {
    my ($bin,$path,$build,@extra_search_paths) = @_;
    my @result;
    for my $item (@extra_search_paths)
    {
        my $glob = "";
        
        $glob .=       quotemeta($item) . '\/' . quotemeta($bin) . "*";
        $glob .= " " . quotemeta($item) . '\/*\/' . quotemeta($bin) . "*";
        $glob .= " " . quotemeta($item) . quotemeta($path) . "*";
        
        #print STDERR "\nSearching [$glob]..." if $opt{v};
        push(@result, grep { -e && (! -d) } glob $glob);
    }
    
    print STDERR "\nSearching [@result]..." if $opt{v};
    return @result;
}

sub getSymbolPathFor_uuid{
    my ($uuid, $uuidsPath) = @_;
    $uuid or return undef;
    $uuid =~ /(.{4})(.{4})(.{4})(.{4})(.{4})(.{4})(.{8})/;
    return Cwd::realpath("$uuidsPath/$1/$2/$3/$4/$5/$6/$7");
}

# Look up a dsym file by UUID in Spotlight, then find the executable from the dsym.
sub getSymbolPathFor_dsymUuid{
    my ($uuid,$arch) = @_;
    $uuid or return undef;
    
    # Convert a uuid from the crash log, like "c42a118d722d2625f2357463535854fd",
    # to canonical format like "C42A118D-722D-2625-F235-7463535854FD".
    my $myuuid = uc($uuid);    # uuid's in Spotlight database are all uppercase
    $myuuid =~ /(.{8})(.{4})(.{4})(.{4})(.{12})/;
    $myuuid = "$1-$2-$3-$4-$5";
    
    # Do the search in Spotlight.
    my $cmd = "mdfind \"com_apple_xcode_dsym_uuids == $myuuid\"";
    print STDERR "Running $cmd\n" if $opt{v};
    my $dsymdir = `$cmd`;
    chomp $dsymdir;
    $dsymdir or return undef;
    # only take the first result if mdfind returned multiple
    my @paths = split /\n/, $dsymdir;
    for my $path (@paths) {
        $dsymdir = $path;
    }
    $dsymdir = quotemeta($dsymdir);	# quote the result to handle spaces in path and executable names
    print STDERR "dsym directory: $dsymdir\n" if $opt{v};
    
    my $pathToDsym;
    my $dsymBaseName;
    my $executable;
    
    # Find the executable from the dsym.
    if ($dsymdir =~ /(.*)\/(.*).dSYM/) {
        $pathToDsym = $1;
        $dsymBaseName = $2;
        $executable = $dsymBaseName;
    } else {
    	print STDERR "No match for dsymdir\n\n" if $opt{v};
    	my @files = glob("$dsymdir/*/*");
    	my $file;
        foreach $file (@files) {
            print STDERR "$file\n";
            if ($file =~ /(.*)\/(.*).dSYM$/) {
                print STDERR "using $file\n";
                $pathToDsym = quotemeta($1);
                $dsymBaseName = $2;
                $executable = $dsymBaseName;
                last;
            }
        }
    }
    $executable =~ s/\..*//g;	# strip off the suffix, if any
    
	print STDERR "Executable: $executable\n\n" if $opt{v};
	
	$executable =~ s/\\//g; # remove \ characters from the executable name.
    chomp($executable); # remove newline character if any from the executable path.
    my @paths = glob "$pathToDsym/$dsymBaseName/{,$executable,Contents/MacOS/$executable}";
    print STDERR "pathToDsym: $pathToDsym\n" if $opt{v};
    print STDERR "dsymBaseName: $dsymBaseName\n" if $opt{v};
    print STDERR "executable: $executable\n" if $opt{v};
    print STDERR "paths: @paths\n" if $opt{v};
    
    my @executablePath = grep { -x && ! -d } glob "$pathToDsym/$dsymBaseName/{,$executable,Contents/MacOS/$executable}";
	
	# Fix for <rdar://problem/6871493>, we shouldn't really need the executable name as we are using the uuid's, but as this has been working this way for some time now, we are continuing...
	my @spotLightSearchForExecutable = `mdfind $executable.app`; # To cover the case where the DSYM's and .app are no located in the same location.
	print STDERR "spotLightSearchForExecutable: @spotLightSearchForExecutable\n\n" if $opt{v};
	print STDERR "Executable: $executable\n\n" if $opt{v};
	foreach (@spotLightSearchForExecutable) {
        $_ =~ s/\/$//;
        chomp($_);
	    if ($_ =~ /.*.xcarchive/) {
	        my $path = quotemeta("$_");
	        $path = $path."/*/*/*/$executable";
            print STDERR "searching $path\n" if $opt{v};        	        
	        my @files = glob("$path");
	        my $file;
	        foreach $file (@files) {
            	print STDERR "Found $file\n" if $opt{v};        
	        }
	        if (@files) {
	            $_ = $files[0];
            	print STDERR "Found executable in .xcarchive: $_\n" if $opt{v};
	        }
	    } else {
            $_ = $_."/".$executable;
        }
	}
	@executablePath = (@executablePath,@spotLightSearchForExecutable); 
	print STDERR "executablePath = @executablePath\n\n" if $opt{v};
    my $executableCount = @executablePath;
	print STDERR "executableCount = $executableCount\n\n" if $opt{v};
    if ( $executableCount > 1 ) {
        print STDERR "Found more than one executable for a dsym: @executablePath\n" if $opt{v};
    }
    if ( $executableCount >= 1 ) {
		my $exec;
		while (defined($exec = shift @executablePath) ){
			if ( !matchesUUID($exec, $uuid, $arch) ) {
				print STDERR "UUID of executable is: $uuid\n" if $opt{v};
				print STDERR "Executable name: $exec\n" if $opt{v};
				print STDERR "UUID doesn't match dsym for executable $exec\n\n" if $opt{v};
				
			} else {
				print STDERR "Found executable $exec\n" if $opt{v};
				return $exec;
			}
		}
    }
	
    print STDERR "Did not find executable for dsym\n" if $opt{v};
    return undef;
}

#########

sub matchesUUID
{  
    my ($path, $uuid, $arch) = @_;
    
    if ( ! -f $path ) {
        print STDERR "## $path doesn't exist \n" if $opt{v};
        return 0;
    }
    
    my $TEST_uuid = `$otool -arch $arch -l "$path"`;
    
    if ( $TEST_uuid =~ /uuid ((0x[0-9A-Fa-f]{2}\s+?){16})/ || $TEST_uuid =~ /uuid ([^\s]+)\s/ ) {
        my $test = $1;
        
        if ( $test =~ /^0x/ ) {
            # old style 0xnn 0xnn 0xnn ... on two lines
			$test =  join("", split /\s*0x/, $test);
			
			$test =~ s/0x//g;     ## remove 0x
			$test =~ s/\s//g;     ## remove spaces
		} else {
			# new style XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX
			$test =~ s/-//g;     ## remove -
			$test = lc($test);
		}
        
        if ( $test eq $uuid ) {
            ## See that it isn't stripped.  Even fully stripped apps have one symbol, so ensure that there is more than one.
            my ($nlocalsym) = $TEST_uuid =~ /nlocalsym\s+([0-9A-Fa-f]+)/;
            my ($nextdefsym) = $TEST_uuid =~ /nextdefsym\s+([0-9A-Fa-f]+)/;
            my $totalsym = $nextdefsym + $nlocalsym;
            print STDERR "\nNumber of symbols in $path: $nextdefsym + $nlocalsym = $totalsym\n" if $opt{v};
            return 1 if ( $totalsym > 1 );
                
            print STDERR "## $path appears to be stripped, skipping.\n" if $opt{v};
        } else {
			print STDERR "Given UUID $uuid for '$path' is really UUID $test\n" if $opt{v};
		}
    } else {
		print STDERR "Can't understand the output from otool ($TEST_uuid -> '$otool -arch $arch -l $path')\n" if $opt{v};
	}

    return 0;
}


sub getSymbolPathFor {
    my ($path,$build,$uuid,$arch,@extra_search_paths) = @_;
    
    # derive a few more parameters...
    my $bin = ($path =~ /^.*?([^\/]+)$/)[0]; # basename
    
    # This setting can be tailored for a specific environment.  If it's not present, oh well...
    my $uuidsPath = "/Volumes/Build/UUIDToSymbolMap";
    if ( ! -d $uuidsPath ) {
        #print STDERR "No '$uuidsPath' path visible." if $opt{v};
    }
    
    # First try the simplest route, looking for a UUID match.
    my $out_path;
    $out_path = getSymbolPathFor_uuid($uuid, $uuidsPath);
    undef $out_path if ( defined($out_path) && !length($out_path) );
    
    print STDERR "--[$out_path] "  if defined($out_path) and $opt{v};
    print STDERR "--[undef] " if !defined($out_path) and $opt{v};
    
    if ( !defined($out_path) || !matchesUUID($out_path, $uuid, $arch)) {
        undef $out_path;
        
        for my $func (
            \&getSymbolPathFor_searchpaths,
            ) {
                my @out_path_arr = &$func($bin,$path,$build,@extra_search_paths);
                if(@out_path_arr) {
                    foreach my $temp_path (@out_path_arr) {
                        
                        print STDERR "--[$temp_path] "  if defined($temp_path) and $opt{v};
                        print STDERR "--[undef] " if !defined($temp_path) and $opt{v};
                        
                        if ( defined($temp_path) && matchesUUID($temp_path, $uuid, $arch) ) {
                            $out_path = $temp_path;
                            @out_path_arr = {};
                        } else {
                            undef $temp_path;
                            print STDERR "-- NO MATCH\n"  if $opt{v};
                        }
                    }
                } else {
                    print STDERR "-- NO MATCH\n"  if $opt{v};
                }              
                
                last if defined $out_path;
            }
    }
    # if $out_path is defined here, then we have already verified that the UUID matches
    if ( !defined($out_path) ) {
        undef $out_path;
        if ($path =~ m/^\/System\// || $path =~ m/^\/usr\//) {
            # Don't use Spotlight to try to find dsym by UUID for system dylibs, since they won't have dsyms.
            # We get here if the host system no longer has an SDK whose frameworks match the UUIDs in the crash logs. 
            print STDERR "NOT searching in Spotlight for dsym with UUID of $path\n" if $opt{v};
        } else {
            print STDERR "Searching in Spotlight for dsym with UUID of $path\n" if $opt{v};
            $out_path = getSymbolPathFor_dsymUuid($uuid, $arch);
            print STDERR " Found $out_path\n" if $opt{v};
            undef $out_path if ( defined($out_path) && !length($out_path) );
        }
    }
    
    if (defined($out_path)) {
        print STDERR "-- MATCH\n"  if $opt{v};
        return $out_path;
    }
    
    print STDERR "## Warning: Can't find any unstripped binary that matches version of $path\n" if $opt{v};
    print STDERR "\n" if $opt{v};
    
    return undef;
}

###########################
# crashlog parsing
###########################

# options:
#  - regex: don't escape regex metas in name
#  - continuous: don't reset pos when done.
#  - multiline: expect content to be on many lines following name
sub parse_section {
    my ($log_ref, $name, %arg ) = @_;
    my $content;
    
    $name = quotemeta($name) 
    unless $arg{regex};
    
    # content is thing from name to end of line...
    if( $$log_ref =~ m{ ^($name)\: [[:blank:]]* (.*?) $ }mgx ) {
        $content = $2;
        $name = $1;
        
        # or thing after that line.
        if($arg{multiline}) {
            $content = $1 if( $$log_ref =~ m{ 
                \G\n    # from end of last thing...
                (.*?) 
                (?:\n\s*\n|$) # until next blank line or the end
            }sgx ); 
        }
    } 
    
    pos($$log_ref) = 0 
    unless $arg{continuous}; 
    
    return ($name,$content) if wantarray;
    return $content;
}

# convenience method over above
sub parse_sections {
    my ($log_ref,$re,%arg) = @_;
    
    my ($name,$content);
    my %sections = ();
    
    while(1) {
        ($name,$content) = parse_section($log_ref,$re, regex=>1,continuous=>1,%arg);
        last unless defined $content;
        $sections{$name} = $content;
    } 
    
    pos($$log_ref) = 0;
    return \%sections;
}

sub parse_images {
    my ($log_ref, $report_version, $default_arch) = @_;
    
    my $section = parse_section($log_ref,'Binary Images Description',multiline=>1);
    if (!defined($section)) {
    	$section = parse_section($log_ref,'Binary Images',multiline=>1); # new format
    }
    if (!defined($section)) {
    	die "Error: Can't find \"Binary Images\" section in log file";
    }
    
    my @lines = split /\n/, $section;
    scalar @lines or die "Can't find binary images list: $$log_ref";
    
    my %images = ();
    my ($pat, $app, %captures);

    # FIXME: This should probably be passed in as an argument
#    my $default_arch = 'armv6';
    
    #To get all the architectures for string matching.
    my $arch_flattened = join('|', values(%architectures));
    
    # Once Perl 5.10 becomes the default in Mac OS X, named regexp 
    # capture buffers of the style (?<name>pattern) would make this 
    # code much more sane.
    if($report_version == 102 || $report_version == 103) { # Leopard GM                                                                                                                                            
        $pat = '                                                                                                                                                                                                      
            ^\s* (\w+) \s* \- \s* (\w+) \s*     (?# the range base and extent [1,2] )                                                                                                                                 
            (\+)?                               (?# the application may have a + in front of the name [3] )                                                                                                   
            (.+)                                (?# bundle name [4] )                                                                                                                                                 
            \s+ .+ \(.+\) \s*                   (?# the versions--generally "??? [???]" )                                                                                                                             
            \<?([[:xdigit:]]{32})?\>?           (?# possible UUID [5] )                                                                                                                                               
            \s* (\/.*)\s*$                      (?# first fwdslash to end we hope is path [6] )                                                                                                                       
            ';
        %captures = ( 'base' => \$1, 'extent' => \$2, 'plus' => \$3,
                      'bundlename' => \$4, 'uuid' => \$5, 'path' => \$6);
    }
    elsif($report_version == 104) { # Kirkwood                                                                                                                                                                    
        $pat = '                                                                                                                                                                                              
            ^\s* (\w+) \s* \- \s* (\w+) \s*     (?# the range base and extent [1,2] )                                                                                                                                 
            (\+)?                               (?# the application may have a + in front of the name [3] )                                                                                                   
            (.+)                                (?# bundle name [4] )                                                                                                                                                 
            \s+ ('.$arch_flattened.') \s+       (?# the image arch [5] )                                                                                                                                          
            \<?([[:xdigit:]]{32})?\>?           (?# possible UUID [6] )                                                                                                                                               
            \s* (\/.*)\s*$                      (?# first fwdslash to end we hope is path [7] )                                                                                                                       
            ';
        %captures = ( 'base' => \$1, 'extent' => \$2, 'plus' => \$3,
                      'bundlename' => \$4, 'arch' => \$5, 'uuid' => \$6,
                      'path' => \$7);
    }
    elsif($report_version == 6) { # TheRealKerni   
        $pat = '                                                                                                                                                                                              
            ^\s* (\w+) \s* \- \s* (\w+) \s*     (?# the range base and extent [1,2] )                                                                                                                                 
            (\+)?                               (?# the application may have a + in front of the name [3] )                                                                                                   
            (.+)                                (?# bundle name [4] )                                                                                                                                                 
            \s+ .+ \(.+\) \s*                   (?# the versions--generally "??? [???]" )                                                                                                                             
            \<?([^\s]{36})?\>?                  (?# possible UUID [5] )                                                                                                                                               
            \s* (\/.*)\s*$                      (?# first fwdslash to end we hope is path [6] )                                                                                                                       
            ';
        %captures = ( 'base' => \$1, 'extent' => \$2, 'plus' => \$3,
                      'bundlename' => \$4, 'uuid' => \$5, 'path' => \$6);
    }
    elsif($report_version == 9) { # TheRealKerni   
        $pat = '                                                                                                                                                                                              
            ^\s* (\w+) \s* \- \s* (\w+) \s*     (?# the range base and extent [1,2] )                                                                                                                                 
            (\+)?                               (?# the application may have a + in front of the name [3] )                                                                                                   
            (.+)                                (?# bundle name [4] )                                                                                                                                                 
            \s+ \(.+\) \s*                      (?# the versions--generally "??? [???]" )                                                                                                                             
            \<?([^\s]{36})?\>?                  (?# possible UUID [5] )                                                                                                                                               
            \s* (\/.*)\s*$                      (?# first fwdslash to end we hope is path [6] )                                                                                                                       
            ';
        %captures = ( 'base' => \$1, 'extent' => \$2, 'plus' => \$3,
                      'bundlename' => \$4, 'uuid' => \$5, 'path' => \$6);
    }
    
    for my $line (@lines) {
        next if $line =~ /PEF binary:/; # ignore these
        
	$line =~ s/(&(\w+);?)/$entity2char{$2} || $1/eg;
        
	if ($line =~ /$pat/ox) {

        # Dereference references 
        my %image;
        while((my $key, my $val) = each(%captures)) {
            $image{$key} = ${$captures{$key}} || '';
			#print "image{$key} = $image{$key}\n";
        }
		
		if ($report_version == 6 || $report_version == 9) { # TheRealKerni 
		    $image{uuid} =~ /(.{8})[-](.{4})[-](.{4})[-](.{4})[-](.{12})/;
            $image{uuid} = "$1$2$3$4$5";
		}
		
		$image{uuid} = lc $image{uuid};
		$image{arch} = $image{arch} || $default_arch;
		
		# Just take the first instance.  That tends to be the app.
        my $bundlename = $image{bundlename};
        $app = $bundlename if (!defined $app && defined $image{plus} && length $image{plus});
        
		# frameworks and apps (and whatever) may share the same name, so disambiguate
        if ( defined($images{$bundlename}) ) {
			# follow the chain of hash items until the end
            my $nextIDKey = $bundlename;
             while ( length($nextIDKey) ) {
                 last if ( !length($images{$nextIDKey}{nextID}) );
                 $nextIDKey = $images{$nextIDKey}{nextID};
             }
			
			 # add ourselves to that chain
            $images{$nextIDKey}{nextID} = $image{base};
			
			# and store under the key we just recorded
            $bundlename = $bundlename . $image{base};
        }
		
		# we are the end of the nextID chain
		$image{nextID} = "";
            
		$images{$bundlename} = \%image;
        }
    }
    
    return (\%images, $app);
}

# if this is actually a partial binary identifier we know about, then
# return the full name. else return undef.
my %_partial_cache = ();
sub resolve_partial_id {
    my ($bundle,$images) = @_;
    # is this partial? note: also stripping elipsis here
    return undef unless $bundle =~ s/^\.\.\.//;
    return $_partial_cache{$bundle} if exists $_partial_cache{$bundle};
    
    my $re = qr/\Q$bundle\E$/;
    for (keys %$images) { 
        if( /$re/ ) { 
            $_partial_cache{$bundle} = $_;
            return $_;
        }
    }
    return undef;
}

# returns an oddly-constructed hash:
#  'string-to-replace' => { bundle=>..., address=>... }
sub parse_backtrace {
    my ($backtrace,$images) = @_;
    my @lines = split /\n/,$backtrace;
    
    my %frames = ();
    for my $line (@lines) {
        if( $line =~ m{
            ^\d+ \s+     # stack frame number
            (\S.*?) \s+    # bundle id (1)
            ((0x\w+) \s+   # address (3)
            .*) \s* $    # current description, to be replaced (2)
        }x ) {
            my($bundle,$replace,$address) = ($1,$2,$3);
            #print STDERR "Parse_bt: $bundle,$replace,$address\n" if ($opt{v});
			
			# disambiguate within our hash of binaries
			$bundle = findImageByNameAndAddress($images, $bundle, $address);
            
            # skip unless we know about the image of this frame
            next unless 
            $$images{$bundle} or
            $bundle = resolve_partial_id($bundle,$images);
            
            $frames{$replace} = {
                'address' => $address,
                'bundle'  => $bundle,
            };
            
        }
        #        else { print "unable to parse backtrace line $line\n" }
    }
    
    return \%frames;
}

sub slurp_file {
    my ($file) = @_;
    my $data;
    my $fh;
    my $readingFromStdin = 0;
    
    local $/ = undef;
    
    # - or "" mean read from stdin, otherwise use the given filename
    if($file && $file ne '-') {
    	open $fh,"<",$file or die "while reading $file, $! : ";
    } else {
    	open $fh,"<&STDIN" or die "while readin STDIN, $! : ";
    	$readingFromStdin = 1;
    }
    
    $data = <$fh>;
    
    
    # Replace DOS-style line endings
    $data =~ s/\r\n/\n/g;
    
    # Replace Mac-style line endings
    $data =~ s/\r/\n/g;
    
    # Replace "NO-BREAK SPACE" (these often get inserted when copying from Safari)
    # \xC2\xA0 == U+00A0
    $data =~ s/\xc2\xa0/ /g;
    
    close $fh or die $!;
    return \$data;
}

sub parse_OSVersion {
    my ($log_ref) = @_;
    my $section = parse_section($log_ref,'OS Version');
	if ( $section =~ /\s([0-9\.]+)\s+\(Build (\w+)/ ) {
		return ($1, $2)
	}
	if ( $section =~ /\s([0-9\.]+)\s+\((\w+)/ ) {
		return ($1, $2)
	}
	if ( $section =~ /\s([0-9\.]+)/ ) {
		return ($1, "")
	}
    die "Error: can't parse OS Version string $section";
}

# Map from the "Code Type" field of the crash log, to a Mac OS X
# architecture name that can be understood by otool.
sub parse_arch {
    my ($log_ref) = @_;
    my $codeType = parse_section($log_ref,'Code Type');
    
    my $value = 0;
    
	if ( $codeType eq "X86-64 (Native)" ) {
	    $value = "X86-64";
	} elsif ( $codeType eq "PPC-64 (Native)" ) {
	    $value = "PPC-64";
	} else {
	    $codeType =~ /(\w+)/;
	    $value = $1;
	}

    my $arch = $architectures{$value};
    die "Error: Unknown architecture $1" unless defined $arch;
    return $arch;
}

sub parse_report_version {
    my ($log_ref) = @_;
    my $version = parse_section($log_ref,'Report Version');
    $version or return undef;
    $version =~ /(\d+)/;
    return $1;
}

sub findImageByNameAndAddress {
    my ($images,$bundle,$address) = @_;
    my $key = $bundle;
    
    #print STDERR "findImageByNameAndAddress($bundle,$address) ... \n";
    
    my $binary = $$images{$bundle};
    
    while( length($$binary{nextID}) ) {
        last if ( hex($address) >= hex($$binary{base}) && hex($address) <= hex($$binary{extent}) );
        
        $key = $key . $$binary{nextID};
        $binary = $$images{$key};
    }
    
    #print STDERR "$key\n";
    return $key;
}

sub prune_used_images {
    my ($images,$bt) = @_;
    
    # make a list of images actually used in backtrace
    my $images_used = {};
    for(values %$bt) {
        #print STDERR "Pruning: $images, $$_{bundle}, $$_{address}\n" if ($opt{v});
        my $imagename = findImageByNameAndAddress($images, $$_{bundle}, $$_{address});
        $$images_used{$imagename} = $$images{$imagename};
    }
    
    # overwrite the incoming image list with that;
    %$images = %$images_used; 
}

# fetch symbolled binaries
#   array of binary image ranges and names
#   the OS build
#   the name of the crashed program
#    undef
#   array of possible directories to locate symboled files in
sub fetch_symbolled_binaries {
    
    print STDERR "Finding Symbols:\n" if $opt{v};
    
    my $pre = "."; # used in formatting progress output
    my $post = sprintf "\033[K"; # vt100 code to clear from cursor to end of line
    
    my ($images,$build,$bundle,@extra_search_paths) = @_;
    
    # fetch paths to symbolled binaries. or ignore that lib if we can't
    # find it
    for my $b (keys %$images) {
        my $lib = $$images{$b};
        
        print STDERR "\r${pre}fetching symbol file for $b$post" if $opt{v};
        $pre .= ".";
        
        
        my $symbol = $$lib{symbol};
        unless($symbol) {
            ($symbol) = getSymbolPathFor($$lib{path},$build,$$lib{uuid},$$lib{arch},@extra_search_paths);
            if($symbol) { 
                $$lib{symbol} = $symbol;
            }
            else { 
                delete $$images{$b};
                next;
            }
        }
        
        # app can't slide
        next if $b eq $bundle;
        
	print STDERR "\r${pre}checking address range for $b$post" if $opt{v};
	$pre .= ".";
        
        # check for sliding. set slide offset if so
        if (-e '/usr/bin/size') {
            open my($ph),"-|",'size','-m','-l','-x',$symbol or die $!;
            my $real_base = ( 
            grep { $_ } 
            map { (/_TEXT.*vmaddr\s+(\w+)/)[0] } <$ph> 
            )[0];
            close $ph;
            if ($?) {
                # call to size failed.  Don't use this image in symbolication; don't die
                delete $$images{$b};
                print STDOUT "Error in symbol file for $symbol\n"; # tell the user
                print STDERR "Error in symbol file for $symbol\n"; # and log it
                next;
            }
            
            if($$lib{base} ne $real_base) {
                $$lib{slide} =  hex($real_base) - hex($$lib{base});
            }
        }
    }
    print STDERR "\rdone.$post\n" if $opt{v};
    print STDERR "\r$post" if $opt{v};
    print STDERR keys(%$images) . " binary images were found.\n" if $opt{v};
}

# run atos
sub symbolize_frames {
    my ($images,$bt) = @_;
    
    # create mapping of framework => address => bt frame (adjust for slid)
    # and for framework => arch
    my %frames_to_lookup = ();
    my %arch_map = ();
    
    for my $k (keys %$bt) {
        my $frame = $$bt{$k};
        my $lib = $$images{$$frame{bundle}};
        unless($lib) {
            # don't know about it, can't symbol
            # should have already been warned about this!
            # print "Skipping unknown $$frame{bundle}\n";
            delete $$bt{$k};
            next;
        }
        
        # adjust address for sliding
        my $address = $$frame{address};
        if($$lib{slide}) {
            $address = sprintf "0x%08x", hex($$frame{address}) + $$lib{slide};
            $$frame{address} = $address;
        }
        
        # list of address to lookup, mapped to the frame object, for
        # each library
        $frames_to_lookup{$$lib{symbol}}{$address} = $frame;
        $arch_map{$$lib{symbol}} = $$lib{arch};
    }
    
    # run atos for each library
    while(my($symbol,$frames) = each(%frames_to_lookup)) {
        # escape the symbol path if it contains single quotes
        my $escapedSymbol = $symbol;
        $escapedSymbol =~ s/\'/\'\\'\'/g;
        
        # run atos with the addresses and binary files we just gathered
        my $arch = $arch_map{$symbol};
        my $cmd = "$atos -arch $arch -o '$escapedSymbol' @{[ keys %$frames ]} | ";
        
        print STDERR "Running $cmd\n" if $opt{v};
        
        open my($ph),$cmd or die $!;
        my @symbolled_frames = map { chomp; $_ } <$ph>;
        close $ph or die $!;
        
        my $references = 0;
        
        foreach my $symbolled_frame (@symbolled_frames) {
            
            $symbolled_frame =~ s/\s*\(in .*?\)//; # clean up -- don't need to repeat the lib here
			
			# find the correct frame -- the order should match since we got the address list with keys
            my ($k,$frame) = each(%$frames);
			
			if ( $symbolled_frame !~ /^\d/ ) {
				# only symbolicate if we fetched something other than an address
				$$frame{symbolled} = $symbolled_frame;
                $references++;
            }
            
        }
        
        if ( $references == 0 ) {
            print STDERR "## Warning: Unable to symbolicate from required binary: $symbol\n";
        }
    }
    
    # just run through and remove elements for which we didn't find a
    # new mapping:
    while(my($k,$v) = each(%$bt)) {
        delete $$bt{$k} unless defined $$v{symbolled};
    }
}

# run the final regex to symbolize the log
sub replace_symbolized_frames {
    my ($log_ref,$bt)  = @_; 
    
    my $re = join "|" , map { quotemeta } keys %$bt;
    my $log = $$log_ref;
    
    if (length($re) > 0) {
        $log =~ s#$re#
        my $frame = $$bt{$&};
    
        if($$frame{address} && $$frame{symbolled}) {
            $$frame{address} ." ". $$frame{symbolled};
        }   
        #esg;
    
        $log =~ s/(&(\w+);?)/$entity2char{$2} || $1/eg;
    }
    return \$log;
}

#############

sub output_log($) {
  my ($log_ref)  = @_;
  
  if($opt{'o'}) {
    close STDOUT;
    open STDOUT, '>', $opt{'o'};
  }
  
  print $$log_ref;
}

#############

sub symbolicate_log {
    my ($file,@extra_search_paths) = @_;
    
    print STDERR "Symbolicating...\n" if ( $opt{v} );
    
    my $log_ref = slurp_file($file);
    
    print STDERR length($$log_ref)." characters read.\n" if ( $opt{v} );
    
    # get the version number
    my $report_version = parse_report_version($log_ref);
    $report_version or die "No crash report version in $file";
    
    # extract arch -- this doesn't really mean much now that we can mulitple archs in a backtrace.  Manage the arch in each stack frame.
    my $arch = parse_arch($log_ref);
    print STDERR "Arch of Logfile: $arch\n" if $opt{v};

    # read the binary images
    my ($images,$first_bundle) = parse_images($log_ref, $report_version, $arch);
    
    # -A option: just lookup app symbols
    $images = { $first_bundle => $$images{$first_bundle} } if $opt{A};
    
    if ( $opt{v} ) {
        print STDERR keys(%$images) . " binary images referenced:\n";
        foreach (keys(%$images)) {
            print STDERR $_;
            print STDERR "\t\t(";
            print STDERR $$images{$_}{path};
            print STDERR ")\n";
        }
        print "\n";
    }
    
    # just parse out crashing thread
    my $bt = {};
    if($opt{t}) {
        # just do crashing logs
        my $crashing = parse_section($log_ref,'Thread') 
        || parse_section($log_ref,'Crashed Thread'); # new format
        my $thread = parse_section($log_ref,"Thread $crashing Crashed",multiline=>1);
        
        die "Can't locate crashed thread in log file.  Try using -a option\n" unless defined $thread;
        
        $bt = parse_backtrace($thread,$images);
    } else {
        my $threads = parse_sections($log_ref,'Thread\s+\d+\s?(Highlighted|Crashed)?',multiline=>1);
        for my $thread (values %$threads) {
            # merge all of the frames from all backtraces into one
            # collection
            my $b = parse_backtrace($thread,$images);
            @$bt{keys %$b} = values %$b;
        }
    }
    
    # extract build
    my ($version, $build) = parse_OSVersion($log_ref);
    print STDERR "OS Version $version Build $build\n" if $opt{v};
    
    # sort out just the images needed for this backtrace
    prune_used_images($images,$bt);
    if ( $opt{v} ) {
        print STDERR keys(%$images) . " binary images remain after pruning:\n";
        foreach my $junk (keys(%$images)) {
            print STDERR $junk;
            print STDERR ", ";
        }
        print STDERR "\n";
    } 
    
    @extra_search_paths = (@extra_search_paths, getSymbolDirPaths($version, $build));

    fetch_symbolled_binaries($images,$build,$first_bundle,@extra_search_paths);
    
    # If we didn't get *any* symbolled binaries, just print out the original crash log.
    my $imageCount = keys(%$images);
    if ($imageCount == 0) {
        output_log($log_ref);
        return;
    }
        
    # run atos
    symbolize_frames($images,$bt);
    
    # run our fancy regex
    my $new_log = replace_symbolized_frames($log_ref,$bt);
    output_log($new_log);
}
