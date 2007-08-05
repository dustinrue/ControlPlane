#! /usr/bin/env ruby

STRINGS_FILE = "Localizable.strings"

require 'iconv'
$stdout.sync = true

print "Looking for translations... "
$languages = Dir["*.lproj/Localizable\.strings"]\
		.map { |x| x.sub(/\.lproj\/.*$/, "") }
puts "Found #{$languages.size} languages (#{$languages.join(", ")})"
if $languages.empty?
	puts "--> Nothing to do."
	puts "--> (are you running from the base source directory?)"
	exit
end

print "Picking base language... "
$base_language = $languages.grep(/^(English|en|eng)$/).first
puts "#{$base_language}"
if $base_language.nil?
	puts "--> Couldn't pick base language!"
	exit 1
end

print "Finding nibs... "
$nibs = Dir["#{$base_language}.lproj/*.nib"]\
		.map { |x| x.sub(/^.*\.lproj\/(.*)\.nib$/, '\1') }.sort
puts $nibs.join(", ")

print "Loading strings files... "
$strings = {}
$languages.each do |lang|
	print "[#{lang}:"
	raw = File.read("#{lang}.lproj/Localizable.strings")
	lines = Iconv.conv('UTF-8', 'UTF-16', raw).split(/\n/)

	# Remove comment lines and blank lines
	lines.delete_if { |l| l =~ /^\/\*/ or l.empty? }
	# Safety
	lines = lines.grep(/" = "/)
	# Build hash
	line_hash = {}
	lines.each { |l|
		if l =~ /^"(.*)" = "(.*)";$/
			line_hash[$1] = $2
		end
	}

	$strings[lang] = line_hash
	print "#{line_hash.size}] "
end
puts "ok"

# Look for missing strings or extra strings
$languages.each do |lang|
	next if lang == $base_language
	missing = $strings[$base_language].keys - $strings[lang].keys
	extra = $strings[lang].keys - $strings[$base_language].keys
	if missing.size > 0
		puts "** Missing in #{lang}:  (#{missing.size} strings)"
		puts missing.map { |l| "\t#{l}" }.join("\n")
	end
	if extra.size > 0
		puts "** Extra in #{lang}:  (#{extra.size} strings)"
		puts extra.map { |l| "\t#{l}" }.join("\n")
	end
end

# Look for idential strings that might not be translated
EXCEPTIONS = [
	"Bluetooth", "FireWire", "IP", "USB", "VPN", "WiFi",
	"OK"
]
$languages.each do |lang|
	next if lang == $base_language
	strings = $strings[lang]
	same = strings.keys.find_all { |k| k == strings[k] }.sort - EXCEPTIONS
	if same.size > 0
		puts "** Possibly-untranslated in #{lang}:  (#{same.size}) strings"
		puts same.map { |l| "\t#{l}" }.join("\n")
	end
end
