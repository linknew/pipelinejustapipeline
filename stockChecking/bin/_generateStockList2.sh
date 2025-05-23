#! /bin/bash 

. ~/tools/lib/comm.lib

doStart

_age=264            # the stock must present more than one year
_days=264          # checking in last 264 days
_match=1            # at least match 1 times
price='$2'
amplitude='$4'
exchange='$14'
volume='$15'
value='$16'
liveValue='$17'
power='$3'
rsi6='$6'
rsi12='$7'
rsi24='$8'
pwr6='$9'
pwr12='$10'
pwr24='$11'

#set -- $1
for i in "$@"
do
    [[ $i == '--help' ]] &&
    echo -e "
    Usage:
        $0 [--checkingLiveVale | --checkingConditions='FORMULA'] [--days=N] [--match=N] [--age=N] [--hotData] stockList

        --checkingLiveValue, checking living value changed(list the one whoes living value increasing more than 20%). 
          this option \033[1;31mEXCLUDE\033[0m with --checkingConditions
        --checkingConditions, formula for calculating the value for checkign
        --days, checking in last \$days
        --match, the checking condtions at least success \$match times
        --age, filte stocks which age great than specified days
        --hotData, use hotData to replace the .data file
        --checkingLiveValue

    Notice:
        \033[1;31mthis routing use StockData/xxx/xxx.pakage.data if --hotData does NOT present.\033[0m

    default:
        --days=$_days 
        --match=$_match
        --age=$_age

        For example:
            $0 --days=3 --match=3 --checkingConditions='\$2>=10.1 && \$4<=3.5 && \$14<3.2' stock.list.valid

        " && doExit 0 >&2

    [[ ${i%%=*} == '--days' ]] && _days=${i##*=} && continue ;
    [[ ${i%%=*} == '--match' ]] && _match=${i##*=} && continue ;
    [[ ${i%%=*} == '--age' ]] && _age=${i##*=} && continue ;
    [[ $i == '--hotData' ]] && _hotData=1 && continue ;
    [[ $i == '--checkingLiveValue' ]] && _checkingLiveValue=1 && continue ;
    [[ ${i%%=*} == '--checkingConditions' ]] && _checkingConditions=${i#*=} && continue ;
    [[ ${i:0:1} == '-' ]] && showErr "unknown option $i\n" && doExit 1 ;
    _list=$i
done

[[ $_days -lt 0 ]] && showErr "!!--days must be great than 0\n" >&2 && doExit

if [[ -z $_checkingConditions ]] ; then
    _checkingConditions=1
else
    _checkingConditions=${_checkingConditions//price/${price}}
    _checkingConditions=${_checkingConditions//amplitude/${amplitude}}
    _checkingConditions=${_checkingConditions//exchange/${exchange}}
    _checkingConditions=${_checkingConditions//volume/${volume}}
    _checkingConditions=${_checkingConditions//value/${value}}
    _checkingConditions=${_checkingConditions//liveValue/${liveValue}}
    _checkingConditions=${_checkingConditions//power/${power}}
    _checkingConditions=${_checkingConditions//rsi6/${rsi6}}
    _checkingConditions=${_checkingConditions//rsi12/${rsi12}}
    _checkingConditions=${_checkingConditions//rsi24/${rsi24}}
    _checkingConditions=${_checkingConditions//pwr6/${pwr6}}
    _checkingConditions=${_checkingConditions//pwr12/${pwr12}}
    _checkingConditions=${_checkingConditions//pwr24/${pwr24}}
fi

showHi "
stocks must be in market more than ${_age} days
checking In $_days Days
should be matched more than $_match times
checkingConditions:$_checkingConditions
checkingLiveValue:${_checkingLiveValue:-"-"}
\n" >&2

#set -x
while read x y z;
do
    # convert 6digital id to 7digital id
    if [[ ${#x} -eq 6 ]] ; then
        [[ ${x:0:1} == 6 ]] && x=0$x || x=1$x  
    fi
    echo checking $x >&2

    # get data for checking
    if [[ $_hotData -eq 1 ]] ; then 
        checkingData=$(echo $x | playStockList.sh --hotData --print)
    else
        checkingData=$(cat StockData/${x:1}.data || grep "^$i" StockData/${x:0:6}-.package.data)
    fi
    [[ $(echo "$checkingData" | wc -l | awk '{print $1}') -lt $_age ]] && continue ;

    # do checking
    if [[ -n $_checkingLiveValue ]] ; then
        echo "$checkingData" | 
        tail -n $_days  |
        awk -v _code=$x '
            (NR==1){lv1=$17;} 
            END{
                if(NR<1) exit 0;
                lvLast=$17; 
                if(lvLast!=0 && lv1!=0 && lvLast/lv1>=1.2) printf("%s %.2f/%.2f=%.2f\n",_code,lvLast,lv1,lvLast/lv1) ; 
            }'
    else
        echo "$checkingData" |
        tail -n $_days  |
        tac |
        awk -v _code="$x"     \
            -v _awkCheckingTimes="$_match"  \
            '
            {
                if ('"$_checkingConditions"') ++matchCnt ;
                if (matchCnt >= _awkCheckingTimes){
                    print _code,"@" NR ,"price_close="$2 ,"amplitude="$4 ,"exchange="$14 ,"vol="$15 ,"lval="$17;
                    exit;
                }
            }'
    fi
done <<< "$(awk '($1 !~ /^#/){print $1}' $_list)"
#set +x
doExit 0

