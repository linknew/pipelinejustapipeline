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
dateStart=${2:0:4}-${2:4:2}-${2:6}
dateEnd=${3:0:4}-${3:4:2}-${3:6}

if   [[ ${#code} -eq 7 && ${code:0:1} == '0' ]]; then code=sh.${code:1}
elif [[ ${#code} -eq 7 && ${code:0:1} == '1' ]]; then code=sz.${code:1}
elif [[ ${#code} -eq 6 && ( ${code:0:1} == '6' || ${code:0:1} == '9' ) ]]; then code=sh.${code}
else code=sz.${code}
fi

rslt=$(
/bin/python3 <<- EOL

import baostock as bs
import pandas as pd

# 登录 Baostock
lg = bs.login()
if lg.error_code != '0':
    print(f"登录失败: {lg.error_msg}")
    exit()

# 获取股票历史行情数据
rs = bs.query_history_k_data_plus(
    code = "$code",  # 股票代码（浦发银行）
    fields = "date,code,open,high,low,close,preclose,volume,amount,adjustflag,turn,tradestatus,pctChg,peTTM,psTTM,pcfNcfTTM,pbMRQ,isST",
    start_date = "$dateStart",  # 开始日期
    end_date = "$dateEnd",    # 结束日期
    frequency = "d",            # 数据频率（d: 日线, w: 周线, m: 月线）
    adjustflag = "3"            # 复权类型（1: 后复权, 2: 前复权, 3: 不复权）
)

# 将数据转换为 DataFrame
data_list = []
while (rs.error_code == '0') & rs.next():
    data_list.append(rs.get_row_data())
df = pd.DataFrame(data_list, columns=rs.fields)

# 打印数据
print(df.to_csv(index=False))

# 保存到 CSV 文件
#df.to_csv('stock_history.csv', index=False)
#print("数据已保存到 stock_history.csv")

# 登出 Baostock
bs.logout()

EOL
)

# covert format
#  from:  (1)date  (2)code      (3)open  (4)high    (5)low     (6)close   (7)preclose  (8)volume  (9)amount  (10)adjustflag  (11)turn    (12)tradestatus  (13)pctChg    (14)peTTM   (15)psTTM     (16)pcfNcfTTM  (17)pbMRQ  (18)isST
#  to:    (1)日期  (2)股票代码  (3)名称  (4)收盘价  (5)最高价  (6)最低价  (7)开盘价    (8)前收盘  (9)涨跌额  (10)涨跌幅      (11)换手率  (12)成交量       (13)成交金额  (14)总市值  (15)流通市值  (16)成交笔数              

echo "$rslt"    \
     | iconv -f GBK -t utf8      \
     | sed -n '/^[0-9]/{ s/ //g; s/,,,/ 0 0 /g; s/,,/ 0 /g; s/,/ /g; s/None/0/g; p; }'     \
     | awk -v code=${1:1} '
        ($4>0){
            printf "%s %s %s %.2f %.2f %.2f %.2f %.2f %.2f %.2f %.2f %.2f %.2f %s %s %s\n", $1, "\047" code, "-", $6, $4, $5, $3, $7, $6-$7, $13, $11, $8/100.0,  $9/1000.0, "0", "0", "0";
            #       1  2  3  4    5    6    7    8    9    10   11 12   13   14 15 16     1          2     3    4   5   6   7   8   9      10   11   12         13         14   15   16
        } '

