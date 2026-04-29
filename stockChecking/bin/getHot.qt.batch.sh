
#!/bin/bash

#@ 格式: getHot.qt.batch.sh stocklist
#@ 从腾讯网获取所有stocklist中股票当前数据，保存至(覆盖) ~/StockData/*hot

#@ 批量获取数据时的bug,
#@ 0000001 和 1000001，获取的数据中股票代码都是 '000001, 导致数据被覆盖
#@ 解决方案, 使用 getHot.qt.sh 来获取单支股票数据
#@ getHot.qt.sh <<< 0000001
#@ getHot.qt.sh <<< 1000001

codes=$(
awk '
    {
        if(!$1) next;
        if(substr($1,1,1) == "#") next;
        len = length($1);
        if (len == 6) {
            dig1 = substr($1,1,1);
            market = (dig1==6 || dig1==9)? "sh" : "sz";
            code = $1;
        }
        else if (len == 7) {
            market = substr($1,1,1)==0? "sh" : "sz";
            code = substr($1,2);
        }
        else {
            print "unknown code :", $1 > "/dev/stderr";
            next;
        }
        print market code
    }
    ' ${1:--} | tr '\n' ',' | sed 's/,$//'
    )

DATE=$(date +%Y-%m-%d)
TIME=$(date +%H:%M:%S)

##@ (1)日期 (2)代码 (3)名称 (4)收盘价 (5)最高 (6)最低 (7)今开 (8)昨收 (9)涨跌额 (10)涨跌幅 (11)换手率 (12)成交量 (13)成交额 (14)总市值 (15)流通市值 (16)成交笔数 (17)时间
curl -s "http://qt.gtimg.cn/q=$codes"       |   #cat -; exit;
awk -F '[~/]' -v date=$DATE -v time=$TIME   \
    '
        BEGIN {
            CONVFMT="%.2f"; OFMT="%.2f";
        }
        {
            code = "\047"$3;            # (2)代码
            _68xx = (substr(code,2,2) == "68");
            name = "-";                 # (3)名称
            close_ = $4+0;              # (4)收盘价
            high = $34+0;               # (5)最高
            low = $35+0;                # (6)最低
            open = $6+0;                # (7)今开
            pre_close = $5+0;           # (8)昨收
            change_amt = $32+0;         # (9)涨跌额
            change_pct = $33+0;         # (10)涨跌幅
            turnover = $41+0;           # (11)换手率
            volume = _68xx? ($37/100) : ($37+0);               # (12)成交量
            amount = $38/1000;          # (13)成交额
            total_mv = $47*100000000;   # (14)总市值
            float_mv = $48*100000000;   # (15)流通市值
            deal_count = 0;             # (16)成交笔数
            print date, code, name, close_, high, low, open, pre_close, change_amt, change_pct, turnover, volume, amount, total_mv, float_mv, deal_count, time; 
#                  1      2      3    4      5     6     7       8           9          10         11       12      13     14           15        16        17
        }
    '               | #cat -; exit;
awk -v home=$HOME   \
    '
    {
        code = substr($2,2);
        dig1 = substr(code,1,1)+0;
        market = (dig1==6 || dig1==9)? 0 : 1;
        fn = home "/StockData/" market code ".html.org.hot";
        print  $0 > fn;
    }
    '

