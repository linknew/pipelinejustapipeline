seg_data=${1:-gold/.t3.segData.lvl3.all.1991.to.2026}

awk '
    /#/{
        next;
    }

    {
        signal = $1;
        date = $9;
        counter [date, signal] ++;
    }

    END {
        for(i in counter) {
            print counter[i], i
        }
    }
    ' $seg_data |
    sort -n
