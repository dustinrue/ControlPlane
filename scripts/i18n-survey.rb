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
	# Strip each line back to the first string
	lines.map! { |l| l.scan(/^"(.*)" = "/)[0][0] }

	$strings[lang] = lines
	print "#{lines.size}] "
end
puts "ok"

# Look for missing strings or extra strings
$languages.each do |lang|
	next if lang == $base_language
	missing = $strings[$base_language] - $strings[lang]
	extra = $strings[lang] - $strings[$base_language]
	if missing.size > 0
		puts "** Missing in #{lang}:"
		puts missing.map { |l| "\t#{l}" }.join("\n")
	end
	if extra.size > 0
		puts "** Extra in #{lang}:"
		puts extra.map { |l| "\t#{l}" }.join("\n")
	end
end
