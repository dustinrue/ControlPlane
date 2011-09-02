#! /bin/sh

#NIBTOOL_FLAGS="-a"
NIBTOOL_FLAGS="-chx"

if [ $# -ne 2 ]; then echo "* Need two arguments!"; exit 1; fi
lang1="$1"
lang2="$2"
if [ ! -d "Resources/$lang1.lproj" ]; then echo "* Can't see 'Resources/$lang1.lproj'!"; exit 2; fi
if [ ! -d "Resources/$lang2.lproj" ]; then echo "* Can't see 'Resources/$lang2.lproj'!"; exit 2; fi

TMP1=`mktemp -t ${lang1}`
TMP2=`mktemp -t ${lang2}`


ibtool $NIBTOOL_FLAGS "Resources/$lang1.lproj/MainMenu.nib" > $TMP1 2> /dev/null
ibtool $NIBTOOL_FLAGS "Resources/$lang2.lproj/MainMenu.nib" > $TMP2 2> /dev/null

diff -ud $TMP1 $TMP2

rm $TMP1 $TMP2
