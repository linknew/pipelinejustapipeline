#! /bin/bash

usage()
{
    echo -en "Usage:\n\t$(basename $0) -login[|-logout] <owner_name>"
    echo -en "      \n\t$(basename $0) <code7> <start_YYYYMMDD> <end_YYYYMMDD> <owner_name>\n\n"
}

clean_n_exit()
{
    [[ -p $fifo_res ]] && rm $fifo_res
    exit $1
}

if [[ $1 == -h || $1 == --help ]]; then
    usage;
    exit 0;
fi

if [[ $1 == -login ]]; then
    owner=$2
    [[ -z $owner ]] && {
        echo "*Error, should be $(basename $0) -login <owner_name>" >&2;
        exit 1;
    }

    fifo_req=$owner.baostock.req
    [[ -f $fifo_req || -p $fifo_req ]] && {
        echo "*Error, file/pipe \"$fifo_req\" already exist, please remove it and try:" >&2;
        echo "        $(basename $0) -login <owner_name>" >&2;
        exit 11;
    }

    mkfifo $fifo_req || {
        echo "*Error, failed to creat named pipe \"$owner.baostock.req\"" >&2
        exit 2;
    }

    _baostock.server.py $fifo_req &
#   _pid=$!; wait $_pid
#   [[ $? -ne 0 ]] && {
#       echo "*Error, failed to start baostock.server.py" >&2
#       rm $fifo_req
#       exit 3;
#   }

    echo "Info, started baostock.server with named pipe \"$fifo_req\"" >&2
    exit 0;
fi

if [[ $1 == -logout ]]; then
    owner=$2
    [[ -z $owner ]] && {
        echo "*Error, should be $(basename $0) -logout <owner_name>" >&2;
        exit 4;
    }

    #@ stop baostock server
    fifo_req=$owner.baostock.req
    [[ -p $fifo_req ]] || {
        echo "*Error, cannot find named pipe \"$fifo_req\"" >&2;
        exit 5;
    }
    echo "stop" > $fifo_req || {
        echo "*Error, failed to stop baostock server" >&2
        exit 6;
    }

    rm $fifo_req
    echo "Info, stop baostock.server, removed named pipe \"$fifo_req\"" >&2
    exit 0;
fi

[[ ${#1} -ne 7 || ${#2} -ne 8 || ${#3} -ne 8 || $# -ne 4 ]] && {
    usage >&2
    exit 7
}

code=$1
dateStart=${2:0:4}-${2:4:2}-${2:6}
dateEnd=${3:0:4}-${3:4:2}-${3:6}
owner=$4
fifo_req=$owner.baostock.req
fifo_res=$$.baostock.res

[[ -p $fifo_req ]] || {
    echo "*Error, cannot find named pipe \"$fifo_req\", please try:" >&2;
    echo "        $(basename $0) -login <owner_name>" >&2;
    exit 10;
}

#@ create res fifo
mkfifo $fifo_res || {
    echo "failed to creat named pipe \"$$.res\" for receiving data" >&2
    clean_n_exit 8
}

#@ fix code
if   [[ ${#code} -eq 7 && ${code:0:1} == '0' ]]; then code=sh.${code:1}
elif [[ ${#code} -eq 7 && ${code:0:1} == '1' ]]; then code=sz.${code:1}
elif [[ ${#code} -eq 6 && ( ${code:0:1} == '6' || ${code:0:1} == '9' ) ]]; then code=sh.${code}
else code=sz.${code}
fi

#@ send request
req="$code $dateStart $dateEnd $fifo_res"
echo "$req" > $fifo_req || {
    echo "failed to send reqest \"$req\" to baostock.server with named pipe \"$fifo_req\"" >&2
    clean_n_exit 9
}

#@ receive result
res=$(cat $fifo_res); #echo "$res" > /dev/tty
[[ ${res:0:14} != "date,code,open" ]] && {
    echo "$res" >&2
    echo "*Error, failed to fetch data with \"$code $dateStart $dateEnd\"" >&2
    clean_n_exit 12
}

# covert format
#  from:  (1)date  (2)code      (3)open  (4)high    (5)low     (6)close   (7)preclose  (8)volume  (9)amount  (10)adjustflag  (11)turn    (12)tradestatus  (13)pctChg    (14)peTTM   (15)psTTM     (16)pcfNcfTTM  (17)pbMRQ  (18)isST
#  to:    (1)日期  (2)股票代码  (3)名称  (4)收盘价  (5)最高价  (6)最低价  (7)开盘价    (8)前收盘  (9)涨跌额  (10)涨跌幅      (11)换手率  (12)成交量       (13)成交金额  (14)总市值  (15)流通市值  (16)成交笔数

#@ show and clean
echo "$res"    \
     | iconv -f GBK -t utf8      \
     | sed -n '/^[0-9]/{ s/ //g; s/,,,/ 0 0 /g; s/,,/ 0 /g; s/,/ /g; s/None/0/g; p; }'     \
     | awk -v code=${1:1} '
        ($4>0){
            printf "%s %s %s %.2f %.2f %.2f %.2f %.2f %.2f %.2f %.2f %.2f %.2f %s %s %s\n", $1, "\047" code, "-", $6, $4, $5, $3, $7, $6-$7, $13, $11, $8/100.0,  $9/1000.0, "0", "0", "0";
            #       1  2  3  4    5    6    7    8    9    10   11   12   13   14 15 16     1          2     3    4   5   6   7   8   9      10   11   12         13         14   15   16
        } '
clean_n_exit 0

