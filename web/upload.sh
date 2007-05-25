#! /bin/sh

BASE_DEST=dsymonds_symonds@ssh.phx.nearlyfreespeech.net:marcopolo/
FILES="$@"

if [ -z "$FILES" ]; then
	echo "  usage:  $0 <files>"
	exit 1
fi

for file in $FILES ; do
	dest=$BASE_DEST
	if echo $file | grep "\.dmg$" > /dev/null ; then
		dest=${BASE_DEST}dist/
	fi
	echo "$file -> $dest..."
	scp -C "$file" $dest
done
