#!/bin/bash

curl http://standards.ieee.org/develop/regauth/oui/oui.txt | grep "..-..-.." | grep hex | sed "s/(hex)//" | awk -F '\t' '{print $1,$3}' | awk -F '       ' '{print $1"\t"$3}' | sed -e 's/^[ \t]*//' > ../Resources/oui.txt 
