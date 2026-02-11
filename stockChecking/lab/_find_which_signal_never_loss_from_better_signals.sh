#! /bin/bash

better_signals=${@:1}
pad_4k=$(printf " %.0s" {1..4096})

for i in  $better_signals ; do
    sed 's/$/'$i'/' $i |
    sed -E 's/ +/@/; s/@([^-])/@+\1/; s/@./&'"$pad_4k"'/'   #@ step1, diff positive and negtive profit
done    |
sort    | uniq -c -w 4096 |                                 #@ step2, counting
sort -n | column -t

