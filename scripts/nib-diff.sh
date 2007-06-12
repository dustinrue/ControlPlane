#! /bin/sh

#NIBTOOL_FLAGS="-8a"
NIBTOOL_FLAGS="-8chx"

if [ $# -ne 2 ]; then echo "* Need two arguments!"; exit 1; fi
lang1="$1"
lang2="$2"
if [ ! -d "$lang1.lproj" ]; then echo "* Can't see '$lang1.lproj'!"; exit 2; fi
if [ ! -d "$lang2.lproj" ]; then echo "* Can't see '$lang2.lproj'!"; exit 2; fi

TMP1=`mktemp`
TMP2=`mktemp`

nibtool $NIBTOOL_FLAGS "$lang1.lproj/MainMenu.nib" > $TMP1 2> /dev/null
nibtool $NIBTOOL_FLAGS "$lang2.lproj/MainMenu.nib" > $TMP2 2> /dev/null

diff -ud $TMP1 $TMP2

rm $TMP1 $TMP2
