#!/bin/bash

for I in `ls -d Resources/*.lproj`
do
  echo $I
  genstrings -a -o $I Sources/*.m
done
