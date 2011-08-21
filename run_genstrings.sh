#!/bin/bash

for I in `ls -d *.lproj`
do
  echo $I
  genstrings -a -o $I src/*.m
done
