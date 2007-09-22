#! /bin/sh

SRC_DIR="$1"
DEST_FILE="$2"

if which git-rev-parse > /dev/null ; then
	git_ref=`cd "$SRC_DIR" && git-rev-parse HEAD`
else
	git_ref="** unknown **"
fi

cat > "$DEST_FILE" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple Computer//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>GitCommit</key>
	<string>$git_ref</string>
</dict>
</plist>
EOF
