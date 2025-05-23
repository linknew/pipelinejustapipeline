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

if   [[ ${#code} -eq 7 && ${code:0:1} == '0' ]]; then code=${code:1}.sh
elif [[ ${#code} -eq 7 && ${code:0:1} == '1' ]]; then code=${code:1}.sz
elif [[ ${#code} -eq 6 && ( ${code:0:1} == '6' || ${code:0:1} == '9' ) ]]; then code=${code}.sh
else code=${code}.sz
fi

rslt=$(
/bin/python3 <<- EOL

import tushare as ts

# 初始化Pro API，替换'your_api_token'为你的实际API密钥
pro = ts.pro_api('658f0199ef35a5b6bd695888ec0de8bb0fd2e35fb1dfde84719fea58')

# 调用接口获取日线数据
#df = pro.daily(ts_code='000001.SZ', start_date='20240101', end_date=20241212')
df = pro.daily(ts_code='$code', start_date='$dateStart', end_date='$dateEnd')
print(df.to_csv(index=False))

# 保存到CSV文件
#df.to_csv('stock_history_data.csv', index=False)

EOL
)

# covert format
#  from:  (1)ts_code  (2)trade_date  (3)open  (4)high    (5)low     (6)close   (7)pre_close  (8)change  (9)pct_chg  (10)vol     (11)amount                                                      
#  to:    (1)日期     (2)股票代码    (3)名称  (4)收盘价  (5)最高价  (6)最低价  (7)开盘价     (8)前收盘  (9)涨跌额   (10)涨跌幅  (11)换手率  (12)成交量  (13)成交金额  (14)总市值  (15)流通市值  (16)成交笔数

echo "$rslt"    \
     | iconv -f GBK -t utf8      \
     | sed -n '2,${ s/ //g; s/,,,/ 0 0 /g; s/,,/ 0 /g; s/,/ /g; s/None/0/g; p; }'     \
     | awk -v code=${1:1} '
        ($4>0){
            date = substr($2,1,4) "-" substr($2,5,2) "-" substr($2,7);
            print date, "\047" code, "-", $6, $4, $5, $3, $7, $8, $9, "0", $10, $11, "0", "0", "0";
        } ' \
     | TAC

