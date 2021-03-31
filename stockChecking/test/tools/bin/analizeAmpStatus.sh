#! /bin/bash

source comm.lib

_stockListOrDataFile=''
_seed='($25-$26)*100/$27'       #check (high-low)*100/ystdCls
_weight=1                       #plus 1 for the class of _seed
_gap=0.1                        #check every 0.1% amp changes
_printDetails=0
_hotData=0
_verbose=''
_daysDef=0
_geDef=2
_leDef=11
_isNotStockList=0
_baseDef=0
_shiftDef=0

trap "doExit 2" SIGINT SIGTERM SIGQUIT

function doExit()
{
    [[ -f .t.$$ ]] && rm .t.$$ 2>/dev/null
    [[ -f .t.stockListOrDataFile.$$ ]] && rm .t.stockListOrDataFile.$$ 2>/dev/null
    exit $1
}

#adjust $_days and $_shift
function _arrange()
{
# $1, days
# $2, shift
    local __days=$1
    local __shift=$2

    if [[ $__days -gt 0 ]] ; then
        head -$__days
    elif [[ $__days -eq 0 ]] ; then
        cat -
    else
        tail $__days
    fi |
    if [[ $__shift -gt 0 ]] ; then
        awk '(NR>'$__shift'){print}'
    elif [[ $__shift -lt 0 ]] ; then
        tail -r | awk '(NR>'$((-__shift))'){print}' | tail -r
    else
        cat -
    fi
}

#parse parameters
for i in "$@"; do
    [[ $i == --help ]] && echo -e "
    Usage:
        $0                      \\
           [--help]                                \\
           [--days=N [--shift=N]] [--seed=FORMULA] [--weight=FORMULA]          \\
           [--gap] [--base=N]                      \\
           [ ( [--ge=N] [--le=N] ) | ( [--top=N] | [--bottom=N] ) ]  \\
           [--hotData] [--details] [--verbose]                       \\
           [--data] stockListOrDataFile

        --days, checking in Nday, N may be positive, negative or 0.
        --shift, 
            shift Nday for --days, N may be positive, negative or 0,
            positive means skip first Ndays among --days.
            negative means ignore last Ndays among --days.
        --seed, use the specified formula to calculate the classfy_value
        --weight, plus to the class which speecified by --seed
        --gap, classfy gap
        --base, set start point for --gap
        --ge, filtes the items which classfy_value>=\$_ge
        --le, filtes the items which classfy_value<=\$_le
        --top, filtes the top N% part
        --bottom, filte the bottom N% part
        --hotData, use hotData to replace StockData/xxx.package.data
        --details, print all items which fit the conditions.
        --verbose, print each value for classfy. the display format is: CLASSFIED_VALUE @ ORIGINAL_DATA
        --data, use actual data file to replace stock list

    Notice:
        This routing uses \033[1;31mStockData/xxx.package.data\033[0m to check if --hotData or --data is NOT present.
        --days, 
            if N equal to 0,  checking whole file
            if N is positive, checking in first N days
            \033[1;31mif N is negative, checking in last  N days\033[0m.
        --data exclude with --hotData
        --ge or --le is exclude with --top or --bottom
        --top exclude with --bottom
        --top filtes at least N% items from top(sorted by percent_rate from small to big).
        --bottom filtes at least N% items from bottom(sorted by percent_rate from small to big). for example, 
            here are the distributes: [1~3)=10% [3,6)=30% [6,9)=20% [9,12)=40%.
            after sorting, they are [1~3)=10% [6,9)=20% [3,6)=30% [9,12)=40%.
            then, 
                --top=30 will get [9,12)=40%
                --top=70 will get [9,12)=40% [3,6)=30%
            as the same,
                --bottom=20 will get [1~3)=10% [6,9)=20%
                --bottom=5  will get [1~3)=10%

    Default:
        --ge=$_geDef --le=$_leDef --days=$_daysDef --gap=$_gap --seed=$_seed --weight=$_weight
    " && doExit 0

    [[ ${i%%=*} == --days ]] && _days=${i##*=} && continue
    [[ ${i%%=*} == --shift ]] && _shift=${i##*=} && continue
    [[ ${i%%=*} == --ge ]] && _ge=${i##*=} && continue
    [[ ${i%%=*} == --le ]] && _le=${i##*=} && continue
    [[ ${i%%=*} == --base ]] && _base=${i##*=} && continue
    [[ ${i%%=*} == --top ]] && _top=${i##*=} && continue
    [[ ${i%%=*} == --bottom ]] && _bottom=${i##*=} && continue
    [[ ${i%%=*} == --seed ]] && _seed=${i#*=} && continue
    [[ ${i%%=*} == --weight ]] && _weight=${i#*=} && continue
    [[ ${i%%=*} == --gap ]] && _gap=${i##*=} && continue
    [[ ${i%%=*} == --details ]] && _printDetails=1 && continue
    [[ ${i%%=*} == --hotData ]] && _hotData=1 && continue
    [[ ${i%%=*} == --verbose ]] && _verbose=1 && continue
    [[ ${i%%=*} == --data ]] && _isNotStockList=1 && continue
    [[ ${i:0:1} == '-' ]] && showErr "unrecognize option:$i\n" && doExit 1

    _stockListOrDataFile=$i
done

#check --shift
[[ -n $_shift && -z $_days ]] && showErr "--shift must under --days\n" && doExit -1
_shift=${_shift:-$_shiftDef}

#check --days
_days=${_days:-$_daysDef}

# check --top --bottom --ge --le
[[ -n $_top && (-n $_bottom || -n $_ge || -n $_le) ]] && showErr "--top exclude with --bottom or --ge or --le\n" >&2 && doExit 1
[[ -n $_bottom && (-n $_top || -n $_ge || -n $_le) ]] && showErr "--bottom exclude with --top or --ge or --le\n" >&2 && doExit 1
if [[ -z $_top && -z $_bottom ]] ; then 
    _ge=${_ge:-$_geDef}
    _le=${_le:-$_leDef}
    [[ -n $_base ]] || _base=$(awk -v awkGe=$_ge -v awkLe=$_le 'BEGIN{if(awkLe-0 < 0-awkGe) print awkLe; else print awkGe;}') # _base like the one who leave neare 0
else
    _base=${_base:-$_baseDef}
fi

# check --data --hotData
[[ $_isNotStockList -eq 1 && $_hotData -eq 1 ]] && showErr "--hotData exclude with --data\n" >&2 && doExit 1

# construct _stockListOrDataFile from stand input
if [[ -z $_stockListOrDataFile ]] ; then
    showHi "Input data for checking, press CTRL_D to end\n" >&2

    if [[ $_isNotStockList -eq 1 ]] ; then
        cat - >.t.stockListOrDataFile.$$
    else
        awk '{print $1}' >.t.stockListOrDataFile.$$
    fi
    _stockListOrDataFile=.t.stockListOrDataFile.$$
    echo >&2    # output a newline for better human readalbe
fi

# fix _stockListOrDataFile if it is a direct data file
if [[ $_isNotStockList -eq 1 ]] ; then
    echo $_stockListOrDataFile > .t.$$ && _stockListOrDataFile=.t.$$
fi

echo \# days=$_days
echo \# shift=$_shift

for i in $(awk '{print $1}' $_stockListOrDataFile) 
do  
    [[ ${i:0:1} == '#' ]] && continue

    # convrt 6digital stock id to 7digital stock id
    if [[ $_isNotStockList -ne 1 && ${#i} -eq 6 ]] ; then
        [[ ${i:0:1} == '6' ]] && i=0${i} || i=1${i}
    fi
    
    # get checking data send to pipe for checking
    if [[ $_isNotStockList -eq 1 ]] ; then
        cat $i 2>/dev/null
    elif [[ $_hotData == 1 ]] ; then
        ./playStockList.sh --print <<< $i 2>/dev/null
    else
        grep "^$i" StockData/${i:0:6}-.package.data 2>/dev/null
    fi |
    _arrange $_days $_shift |
    ./_classfy.sh --seed="$_seed" --weight="$_weight" --gap="$_gap" ${_verbose:+--verbose} --base=$_base  |
        awk -v _awkCode=$i  \
            -v _awkPrintDetails=$_printDetails \
            -v _awkGe=$_ge  \
            -v _awkLe=$_le  \
            -v _awkTop=$_top    \
            -v _awkBottom=$_bottom  \
            -v _awkFilteTop=${_top:+1}  \
            -v _awkFilteBottom=${_bottom:+1}  \
            '
            '"$awkFunction_asortSet"'   #include sortSet functions

            BEGIN{
                if(_awkFilteTop == 1) print "# top=" _awkTop ;
                else if(_awkFilteBottom == 1) print "# bottom=" _awkBottom ;
                else print "# ge=" _awkGe " Le=" _awkLe ;
            }

            # display verbose and comments
            /@|#/{
                print ;
                next ;
            }

            # loop each line
            (NR>0){
                _arry[$1] = $2 ;
                _tt += $2 ;
            }

            END{
                if(!_tt) exit 0 ;

                # do sort
                _cnt = 0 ;
                _ttFiltedRate = 0 ;
                for(i in _arry){
                    _outPut = sprintf("\t%s %6.2f%% [%.02f,%d]", _awkCode, _arry[i]*100.0/_tt, i, _arry[i]) ;
                    arry4Sorting[_cnt++] = _arry[i]"@"_outPut ;
                }
                asort(arry4Sorting,arry4Sorting,1,1) ;

                # do filte  and print result
                if(_awkFilteTop || _awkFilteBottom){

                    if(_awkFilteTop){
                        _start = 0 ;        # from _start
                        _end = _cnt ;       # to _end (not include it)
                        _step = 1 ;
                        _limit = _awkTop ;
                    }else{
                        _start = _cnt-1 ;   # from _start
                        _end = -1 ;         # to _end (not include it)
                        _step = -1 ;
                        _limit = _awkBottom ;
                    }

                    i = _start ;
                    _pos = 0 ;
                    while(i != _end){
                        _pos = index(arry4Sorting[i],"@") ;
                        _value = substr(arry4Sorting[i],1,_pos-1)*100/_tt ;
                        _outPut = substr(arry4Sorting[i],_pos+1) ;
                        _ttFiltedRate += _value ;
                        if(_awkPrintDetails) print _outPut ;
                        if(_ttFiltedRate >= _limit) break ;
                        i += _step ;
                    }

                }else{      # filte by Ge and Le
                    
                    for(i=0; i<_cnt; i++){
                        _pos = index(arry4Sorting[i],"@") ;
                        _value = substr(arry4Sorting[i],1,_pos-1)*100/_tt ;
                        _class = substr(arry4Sorting[i],
                                    index(arry4Sorting[i],"[")+1,
                                    index(arry4Sorting[i],",")-index(arry4Sorting[i],"[")) ;
                        if(_class+0>=_awkGe && _class+0<=_awkLe){
                            _outPut = substr(arry4Sorting[i],_pos+1) ;
                            _ttFiltedRate += _value ;
                            if(_awkPrintDetails) print _outPut ;
                        }
                    }
                }

                printf "%s %.2f%% [%d/%d]\n", _awkCode, _ttFiltedRate, _ttFiltedRate*_tt/100, _tt ;
            }
            '
done

doExit 0
