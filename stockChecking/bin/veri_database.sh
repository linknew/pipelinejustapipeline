#! /bin/bash

Usage()
{
    echo -en "Usage:\n\t$(basename $0) [file]\n\n"
}

[[ $1 == -h ]] && { Usage; exit; }

list=${@:-$(find ~/StockData/ -name '*package.html.org')}

for i in $list; do
    echo "-- $i"
    dup=$(grep -o "^[0-9]\{4\}-[0-9][0-9]-[0-9][0-9] '[0-9]\{6\}" $i | sort | uniq -dw 20) || echo -en "\033[1;31m**\033[0m failed to check dup-line on $i\n"
    [[ -n $dup ]] && echo "found dup-line in $i"
    awk '{ if(lastNF==0) lastNF=NF; if(lastNF != NF && NF != 0) { print "\033[1;31m**\033[0m found missing column in", FILENAME, "at line:", NR; } }' $i
    cut -d' ' -f2 $i | uniq -dc
#   ((j++))
#   [[ $j -eq 30 ]] && exit
done
