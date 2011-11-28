#!/bin/bash

# simple script to generate documentation fromt he
# header files

# should be run from the root of ControlPlane's project dir

DESTINATION=GeneratedDocumentation
SOURCE=Source

if [ -d "$DESTINATION" ]; then
  rm -rf $DESTINATION
fi

mkdir $DESTINATION
headerdoc2html -o $DESTINATION $SOURCE
gatherheaderdoc $DESTINATION index.html
