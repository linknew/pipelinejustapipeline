
#! /bin/bash

TAC()
{
    command -v tac >&/dev/null && tac - || tail -r -;
}

#$1: code7
#$2: start_date_YYYYMMDD
#$3: end_date_YYYYMMDD

[[ ${#1} -ne 7 || ${#2} -ne 8 || ${#3} -ne 8 ]] && echo "*Error, getHis code7 startYYYYMMDD endYYYYMMDD" >&2 && exit

code=$1
dateStart=$2
dateEnd=$3

[[ ${#code} -eq 7 ]] && code=${code:1}

rslt=$(
/bin/python3 <<- EOL
import akshare as ak
stock_df = ak.stock_zh_a_hist(symbol="$code", period="daily", start_date="$dateStart", end_date="$dateEnd")
print(stock_df.to_csv(index=False))
EOL
)

# covert format
#  from:  (1)日期  (2)开盘      (3)收盘  (4)最高    (5)最低    (6)成交量  (7)成交额  (8)振幅    (9)涨跌幅  (10)涨跌额  (11)换手率                                                      
#  to:    (1)日期  (2)股票代码  (3)名称  (4)收盘价  (5)最高价  (6)最低价  (7)开盘价  (8)前收盘  (9)涨跌额  (10)涨跌幅  (11)换手率  (12)成交量  (13)成交金额  (14)总市值  (15)流通市值  (16)成交笔数

echo "$rslt" | #cat - ; exit
    sed -n '2,${ s/ //g; s/,,,/ 0 0 /g; s/,,/ 0 /g; s/,/ /g; s/None/0/g; p; }' |
    awk -v code=${1:1} ' ($4>0){ print $1, "\047" code, "-", $3, $4, $5, $2, 0, $10, $9, $11, $6, $7, "0", "0", "0"; } '

