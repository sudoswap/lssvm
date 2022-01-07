#!/bin/sh
usage="[-h] [-n] -- program to generate new tests 

args:
    -h  help
    -n ['noarb', 'robustrouter'] "

while getopts :hn: flag
do
    case "${flag}" in
        h) echo "$usage"
           exit;;
        n) name=${OPTARG};;    
    esac
done

if [ "$name" = "noarb" ]; then
    python3 scripts/generateAllNoArbTests.py 
elif [ "$name" == "robustrouter" ]; then
    python3 scripts/generateAllRobustRouterTests.py
else
    python3 scripts/generateAllNoArbTests.py && python3 scripts/generateAllRobustRouterTests.py    
fi