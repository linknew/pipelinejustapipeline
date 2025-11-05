#@ FIXME, no pre_close
exit -1

#! /bin/bash

[[ $1 == -login ]] && { exit 0; }
[[ $1 == -logout ]] && { exit 0; }
if [ -z "$1" ] || [ ${#1} -ne 7 ] || [ -z "$2" ] || [ -z "$3" ]; then
    echo "用法: $0 0|1<股票代码> <开始日期> <结束日期>, 0上证 1深证"
    echo "示例: $0 1600519 20240101 20241231"
    exit 131
fi

MARKET=${1:0:1}
CODE=${1:1}
START_DATE=$2
END_DATE=$3

#@ fix MARKET to fit east_money!!
[[ $MARKET -eq 0 ]] && MARKET=1 || MARKET=0

#@ f1:  股票代码
#@ f2:  市场类型
#@ f3:  股票名称
#@ f4:  价格小数位数
#@ f5:  总K线数量(历史数据总数,日K就是每日1条)
#@ f6:  前收盘价
#@ f51: 日期        (1)
#@ f52: 开盘价      (2)
#@ f53: 收盘价      (3)
#@ f54: 最高价      (4)
#@ f55: 最低价      (5)
#@ f56: 成交量(手)  (6)
#@ f57: 成交额(元)  (7)
#@ f58: 振幅(%)     (8)
#@ f59: 涨跌幅(%)   (9)
#@ f60: 涨跌额      (10)
#@ f61: 换手率(%)   (11)
#@ f62: ??总市值    (12)
#@ f63: ??流通市值  (13)

API_URL="\
http://push2his.eastmoney.com/api/qt/stock/kline/get?\
fields1=f1,f2,f3,f4,f5,f6,f7,f8,f9,f10&\
fields2=f51,f52,f53,f54,f55,f56,f57,f58,f59,f60,f61,f62,f63&\
secid=${MARKET}.${CODE}&\
beg=${START_DATE}&\
end=${END_DATE}&\
rtntype=6&\
klt=101&\
fqt=0\
"
response=$(curl -s "$API_URL") || exit 129
echo "$response" | jq


rc=$(echo "$response" | grep -o '"rc":[^,]*' | cut -d':' -f2)
if [ "$rc" != "0" ]; then
    echo "API请求失败，错误码: $rc"
    echo "原始响应: $response"
    exit 130
fi

name=$(echo "$response" | grep -o '"name":"[^"]*"' | cut -d'"' -f4)
klines=$(echo "$response" | grep -o '"klines":\[[^]]*\]' | cut -d':' -f2-)

#@  (1)日期    (2)股票代码  (3)名称     (4)收盘价   (5)最高价     (6)最低价   (7)开盘价     (8)前收盘
#@  (9)涨跌额  (10)涨跌幅   (11)换手率  (12)成交量  (13)成交金额  (14)总市值  (15)流通市值  (16)成交笔数
echo "$klines"  \
     | sed 's/","/\n/g; s/,/ /g; s/\[\|]\|"//g'     \
     | awk -v code=\'$CODE -v name=$name  '
        ($4>0) {
            #@    1     2    3    4   5   6   7    8    9   10   11  12  13  14   15   16
            print $1, code, name, $3, $4, $5, $2, "-", $10, $9, $11, $6, $7, $12, $13, "-";
        } '

exit 0

