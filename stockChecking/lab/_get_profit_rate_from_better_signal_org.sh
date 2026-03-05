#! /bin/bash

signal=$1
better_signal_org=$2
simple=$3

trades=$(
grep -F "#$signal " $better_signal_org  | #cat -; exit
sed 's/.*@//; s/,.*//; s/\~/ /;'        | #cat -; exit
awk '
    /^$/ {
        next;
    }

    /^#/ {
        next;
    }

    {
        from = $1;
        to = $2;
        exist = 0;
        for (from_ in b) {
            to_ = b[from_];
            if (from == from_) {
                exist = 1;
            }
            if (from >= from_ && from <= to_) {
                a[from_,to_] ++;
            }
        }
        if (!exist) {
            a[from,to] ++;
            b[from] = to;
        }
    }

    END {
        for (i in a) {
            printf("%d trades during the period %s\n", a[i], i);
        }
    }
    '
)
#echo "$trades"; exit

profit=$(
grep -F "$signal " ${better_signal_org%.org}
)

n_profit=$(
echo "$profit" | awk '{print $2}'
)

n_max_trades=$(
echo "$trades" | sort -n | tail -n1 | awk '{print $1}'
)

n_max_investment=$((n_max_trades*20000))

n_profit_rate=$(
awk 'BEGIN{printf("%.2f", '$n_profit'/'$n_max_investment'*100);}'
)

if [[ -z $simple ]]; then
    echo $profit $n_max_trades*20000 $n_profit_rate%
else
    cat <<-EOF
	$trades
	-------
	signal: $(echo $profit | awk '{print $1}')
	the maximum trade is: $n_max_trades
	the maxinum investment is: $n_max_investment
	the profit rate is: $n_profit_rate%, ($n_profit/($n_max_trades*20000)*100)
	EOF
fi

