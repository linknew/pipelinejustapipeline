
#!/bin/bash

if [[ -z "$1" || ${#1} -ne 7 ]]; then
    echo "用法: $(basename $0) <7位股票代码>"
    exit 1
fi

CODE_ORG=$1
MARKET=${CODE_ORG:0:1}; [[ $MARKET -eq 0 ]] && MARKET=sh || MARKET=sz
CODE=${CODE_ORG:1}
DATE=$(date +%Y-%m-%d)
TIME=$(date +%H:%M:%S)

##@ (1)日期 (2)代码 (3)名称 (4)收盘价 (5)最高 (6)最低 (7)今开 (8)昨收 (9)涨跌额 (10)涨跌幅 (11)换手率 (12)成交量 (13)成交额 (14)总市值 (15)流通市值 (16)成交笔数 (17)时间
curl -s "http://qt.gtimg.cn/q=${MARKET}${CODE}" |
awk -F '[~/]' -v date=$DATE -v time=$TIME       \
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
      '     |
awk -v home=$HOME -v code=$CODE_ORG  \
    '
    {
        fn = home "/StockData/" code ".html.org.hot";
        print  $0 > fn;
        print  $0;
    }
    '


