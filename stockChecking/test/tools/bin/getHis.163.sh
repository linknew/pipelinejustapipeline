#! /bin/bash

TAC()
{
    command -v tac >&/dev/null && tac - || tail -r -;
}

#$1: code7
#$2: start_date_YYYYMMDD
#$3: end_date_YYYYMMDD

[[ ${#1} -ne 7 || ${#2} -ne 8 || ${#3} -ne 8 ]] && echo "*Error, getHis code7 startYYYYMMDD endYYYYMMDD" >&2 && exit

curl -f http://quotes.money.163.com/service/chddata.html?code=${1}\&start=${2}\&end=${3} 2>/dev/null |
   iconv -f GBK -t utf8 |
   sed -n '$d; 2,${ s/ //g; s/,,,/ 0 0 /g; s/,,/ 0 /g; s/,/ /g; s/None/0/g; p; }' | 
   awk '($4>0){print}' |
   TAC

