#! /bin/bash

better_signals=${@:1}

#pad_4k=$(printf " %.0s" {1..4096})
#for i in  $better_signals ; do
#    sed 's/$/'$i'/' $i |
#    sed -E 's/ +/@/; s/@([^-])/@+\1/; s/@./&'"$pad_4k"'/'   #@ step1, diff positive and negtive profit
#done            |
#sort            |
#uniq -c -w 4096 |
#sort -n         |
#column -t

awk '
    {
        year = substr(FILENAME, length(FILENAME)-3);
        tag =  substr(FILENAME, 1, length(FILENAME)-5);
        occ = $3;
        miss = $4;
        rate = $5;
        signal = $1;
        profit = $2+0;

        if(profit>0) {
            n_win[signal] ++;
            win[signal] = win[signal] "  " year "," occ "," miss "," rate ":" profit;
        }
        else {
            n_loss[signal] ++;
            loss[signal] = loss[signal] "  " year "," occ "," miss "," rate ":" profit;
        }
    }
    END {
        for (i in win) {
            print n_win[i], i "@+", tag, win[i];
        }
        for (i in loss) {
            print n_loss[i], i "@-", tag, loss[i];
        }
    }
    ' $better_signals   |   sort -n

