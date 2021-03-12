#! /bin/bash

source comm.lib

let _cmdCodeUpdate=$((1<<1))
let _cmdCodeDownload=$((1<<2))
let _cmdCodeHotData=$((1<<3))
let _cmdCodeShow=$((1<<4))
let _cmdCodeShowNext=$((1<<5))
let _cmdCodePrint=$((1<<6))
let _cmdCodePrintLastOne=$((1<<7))
let _cmdCodeCheckHitRate=$((1<<8))
let _cmdCodeAnalize=$((1<<9))
let _cmdCodeRestDatabase=$((1<<10))
let _cmdCodeDoDailyHomework=$((1<<11))
let _cmdCodeJustDoit=$((1<<12))
let _cmdCodeKeepRefresh=$((1<<13))
let _cmdCodeSilent=$((1<<14))
let _cmdCodeOrder=$((1<<15))
let _cmdCodeBG=$((1<<16))
let _cmdCodeShowDaily=$((1<<17))
let _cmdCodePackDailyData=$((1<<18))
let _cmdCodeGenRelationshipData=$((1<<19))
let _cmdCodeFixType=$((1<<20))
let _cmdCode=0

_classFile="stock.list.class.tmp"
_anaProg=""
_anaOpt=""
_pipe4Ana=/dev/stdout
_pipe4Homework=/dev/stdout

killHotDataTask()
{
    (( _cmdCode & _cmdCodeKeepRefresh )) && return 0

    _pids=`ps | awk '/getStockData.'$$'.sh/{print $1}'`
    [[ -n $_pids ]] && kill -s SIGTERM $_pids 2>/dev/null && showMsg "*[$_code]kill hot_data_retriving task\n" >&2
    return 0
}

doPacking()
{
    local _i
    local _code
    local _ext
    local _cmd
    local _list=$(ls StockData/*.data StockData/*.html.org 2>/dev/null | grep -v '-')

    for _i in $_list
    do
        _ext=${_i#*.}
        _code=${_i##*/};  _code=${_code%%.*}
        _packFile=StockData/${_code:0:6}-.package.$_ext

        if [[ $_ext == "data" ]] ; then 
            sed -i '' /^$_code/d $_packFile 2>/dev/null
        elif [[ $_ext == "html.org" ]] ; then
            sed -i '' "/'${_code:1}/d" $_packFile 2>/dev/null
        else
            : do nothing
        fi

        cat $_i >> $_packFile
        rm $_i 2>/dev/null
    done

    return 0
}

#$1 source file
#$2 destnate file
doUpdateBKAmpInfo()
{
    local srcFile=$1
    local destFile=$2
    local createDestFile=0
    local startDate

    [[ ! -f $srcFile ]] && echo "$srcFile dose not exist" >&2 && return -1
    [[ ! -f $destFile ]] && sed -n '1p' $srcFile > $destFile && createDestFile=1

    cp $destFile{,.bak} 2>/dev/null
    [[ $createDestFile -ne 1 ]] && startDate=$(sed -n '${s/ .*$//;p;}' $destFile 2>/dev/null)

    awk -v awkStartDate=$startDate '($1 > awkStartDate && !/#/){ print ; }' $srcFile    |

    awk '
        BEGIN{
            cmd = "./hotdegree.sh - --showBlockHotdegree | head -6 " ;
        }

        (!/#/){ 
            if(!last){
                last=$1;
                cnt=$2;
            }else if($1 == last){
                cnt = cnt"\n"$2;
            }else{
                print "#",last ;
                print cnt | cmd ;
                close(cmd) ;
                last=$1; 
                cnt=$2;
            } 
        }

        END{
            print "#",last ;
            print cnt | cmd
            close(cmd) ;
        }

        '   |

    awk '

        BEGIN{
            while(getline < (".BKList")){
                if($0 ~ "#") continue ;
                blockId[$2] = $1 ;
            }
            close(".BKList") ;
        }

        /[0-9]{4}-[0-9]{2}-[0-9]{2}/{
            _date = $2 ;
        }

        !/#/{
            print _date,blockId[$2],$0 ;
        }

        ' >> $destFile
}

doExit()
{
    wait
    [[ -f getStockData.$$.sh ]] && rm -rf ./getStockData.$$.sh 2>/dev/null
    [[ -f .t.$$ ]] && rm -rf .t.$$ 2>/dev/null
    [[ -f $_pipe4Ana ]] && rm -rf $_pipe4Ana 2>/dev/null
    [[ -f $_pipe4Homework ]] && rm -rf $_pipe4Homework 2>/dev/null
    exit $1
}

showHelp()
{
    showMsg "
    Usage: ${0} [[--update] [--download] [--hotData [--keepRefresh]] [--resetDatabase] \\
                              [--show|--showNext|--monit [--showDaily] [--silent] [--order] [--bg]] [--fixType=F/B/N] \\
                              [--analize=filename [--analizeOptions='...']] \\
                              [--packDailyData] [--genRelationshipData] [--checkHitRate] [(--print | --printLastOne) [--output=PREFIX{}SUFFIX]] [--classFile=filename] listFile

        --download, download stock data
        --update, update stock data
        --hotData, get current data
        --keepRefresh, after program complete, keep refresh current data (does not stop data-retrieve job), this option must use under --hotData.
        --print, print stock infos(date,amplitude,power,etc.)
        --printLastOne, print the last item of stock infos(date,amplitude,power,etc.)
        --output, output to specified file, for example: --output="a/b/{}.data" will save result to a/b/code_6.data
        --monit, group of --show --showDaily --silent --order --bg
        --show, show stock info listed in the listFile
        --showNext, continue to show stock info listed in the listFile(continue the last showing operation)
        --showDaily, this option combind with --show or --showNext. show stock_daily instead of stock_history 
        --silent, this option combind with --show or --showNext. no interactivition after showing stock
        --order, this option combind with --show or --showNext. set windows order for dailyWindow(the first stock's dilayWindow order is 1)
        --bg, this option combind with --show or --showNext. show stock at background. --bg will force to enable --silent option
        --checkHitRate, check hitRate
        --classFile=filename, specify the CLASS-FILE
        --analize, analize stock with X-Index
        --analizeOptions, special arguments which required by the analize program.
        --resetDatabase, reset database.
        --packDailyData, package daily data.
        --genRelationshipData, generate relationship data.
        --doDailyHomework.  use --update to refresh stock data, find stocks in UP state, find out the possible stock which RSI-6 & PWRI-12 <= 15.
        --justDoIt. monitor stocks which RSI-6 & PWRI-12 <=15, monitor stocks which in UP state. 

    Default: --show --classFile=stock.list.class.tmp
\n"
}

pwd=$(dirname $0)

for i in "$@"
do
    [[ $i == --help ]] && showHelp && exit 0
    [[ $i == --update ]]   && ((_cmdCode |=_cmdCodeUpdate)) && continue
    [[ $i == --download ]] && ((_cmdCode |=_cmdCodeDownload)) && continue
    [[ $i == --hotData ]]  && ((_cmdCode |=_cmdCodeHotData)) && continue
    [[ $i == --keepRefresh ]] && ((_cmdCode |=_cmdCodeKeepRefresh)) && continue
    [[ $i == --print ]]    && ((_cmdCode |=_cmdCodePrint)) && continue
    [[ $i == --printLastOne ]] && ((_cmdCode |=_cmdCodePrintLastOne)) && continue
    [[ ${i%%=*} == --output ]] && _output=${i#*=} && continue
    [[ $i == --show ]]     && ((_cmdCode |=_cmdCodeShow)) && continue
    [[ $i == --showNext ]] && ((_cmdCode |=_cmdCodeShowNext)) && continue
    [[ $i == --monit ]] && ((_cmdCode |= (_cmdCodeShow|_cmdCodeSilent|_cmdCodeShowDaily|_cmdCodeOrder|_cmdCodeBG) )) && continue
    [[ $i == --silent ]] && ((_cmdCode |=_cmdCodeSilent)) && continue
    [[ $i == --showDaily ]] && ((_cmdCode |=_cmdCodeShowDaily)) && continue
    [[ $i == --order ]] && ((_cmdCode |=_cmdCodeOrder)) && continue
    [[ $i == --bg ]] && ((_cmdCode |=(_cmdCodeBG|_cmdCodeSilent) )) && continue
    [[ $i == --packDailyData ]] && ((_cmdCode |=_cmdCodePackDailyData)) && continue
    [[ ${i%%=*} == --checkHitRate ]] && ((_cmdCode |=_cmdCodeCheckHitRate)) && continue
    [[ ${i%%=*} == --fixType ]] && ((_cmdCode |=_cmdCodeFixType)) && _fixType=${i##*=} && continue
    [[ ${i%%=*} == --analize ]] && ((_cmdCode |=_cmdCodeAnalize)) && _anaProg=${i##*=} && continue
    [[ ${i%%=*} == --analizeOptions ]] && _anaOpt=${i#*=} && continue
    [[ ${i%%=*} == --classFile ]] && _classFile=${i##*=} && continue
    [[ $i == --resetDatabase ]] && ((_cmdCode=_cmdCodeRestDatabase)) && continue
    [[ $i == --doDailyHomework ]] && ((_cmdCode=_cmdCodeDoDailyHomework)) && continue
    [[ $i == --genRelationshipData ]] && ((_cmdCode |=_cmdCodeGenRelationshipData)) && continue
    [[ $i == --justDoIt ]] && ((_cmdCode=_cmdCodeJustDoit)) && continue
    [[ ${i:0:1} == "-" ]] && showErr "unknown option:$i\n" >&2 && exit 0
    _list=$i
done

#prepare
trap "wait
      killHotDataTask
      doExit 0" SIGINT SIGTERM SIGQUIT

cp "$pwd/getStockData.sh" ./getStockData.$$.sh

((_cmdCode & _cmdCodeShowNext)) && _firstCode=$(tail -1 $_classFile | sed 's/ .*//') || _firstCode='.'
((_cmdCode & _cmdCodeAnalize)) &&  _pipe4Ana=.out.$$.ana ;

if ((_cmdCode & _cmdCodeRestDatabase)) ; then
    ./resetStockDatabase.sh ${_list:+--stockList=$_list} 
    doExit 0
fi

if (( (_cmdCode & (_cmdCodeSilent | _cmdCodeShow | _cmdCodeShowNext) ) == _cmdCodeSilent )) ; then
    showErr "option --silent must combind with --show or --showNext \n">&2
    doExit 0
fi

if (( (_cmdCode & (_cmdCodeOrder | _cmdCodeShow | _cmdCodeShowNext) ) == _cmdCodeOrder )) ; then
    showErr "option --order must combind with --show or --showNext \n">&2
    doExit 0
fi

if (( (_cmdCode & (_cmdCodeShowDaily | _cmdCodeShow | _cmdCodeShowNext) ) == _cmdCodeShowDaily )) ; then
    showErr "option --showDaily must combind with --show or --showNext \n">&2
    doExit 0
fi

if (( (_cmdCode & (_cmdCodeBG | _cmdCodeShow | _cmdCodeShowNext) ) == _cmdCodeBG )) ; then
    showErr "option --bg must combind with --show or --showNext \n">&2
    doExit 0
fi

if (( (_cmdCode & (_cmdCodeFixType | _cmdCodeDoDailyHomework) ) == (_cmdCodeFixType | _cmdCodeDoDailyHomework) )) ; then
    showErr "option --fixType exclude with --doDailyHomework\n">&2
    doExit 0
fi

if [[ $((_cmdCode & (_cmdCodePrint | _cmdCodePrintLastOne) )) -eq 0 && -n $_output ]] ; then
    showErr "option --output must combin with --print or --printLastOne \n">&2
    doExit 0
fi

if ((_cmdCode & _cmdCodeDoDailyHomework)) ; then 
    rm -rf stock.list.{11DaysUp,bestBuy} 2>/dev/null
fi

if ((_cmdCode & _cmdCodeJustDoit)) ; then
    ((_cmdCode|=(_cmdCodeHotData|_cmdCodePrintLastOne|_cmdCodeAnalize) ))
    _anaProg=./analizeBestBuy.sh
    _pipe4Ana=.out.$$.ana
fi

if (( (_cmdCode & _cmdCodeKeepRefresh) && (_cmdCode & _cmdCodeHotData) == 0 )) ; then
    showErr "to enable --keepRefresh, should enable --hotData as same time\n" >&2
    exit 1
fi

((_cmdCode == 0)) && _cmdCode=$((_cmdCodeShow))

#star the loop

if (( _cmdCode & (_cmdCodeUpdate|_cmdCodeDownload|_cmdCodeDoDailyHomework|_cmdCodeJustDoit) )) ; then
    showHi "*Download 1399001 for the base of systemSync\n" >&2
    ./getStockData.$$.sh --update 1399001 2>/dev/null
    _dateEnd=$(grep "'399001" StockData/139900-.package.html.org 2>/dev/null | sed -n '${s/ .*//; s/-//g; p;}')
    _dateEnd=${_dateEnd:-$(date "+%Y%m%d")}
fi

awk '{if($1~/'$_firstCode'/) _start=1; if(_start) print $1; }' $_list |            # do not use "$_list" (because $_list can be empty)
while read _code x
do
    [[ ${_code:0:1} == '#' ]] && continue

    if [[ ${#_code} -eq 6 ]] ; then
        [[ ${_code:0:1} == '6' ]] && _code="0$_code" || _code="1$_code"
    fi
    _hotFile=StockData/$_code.html.org.hot
    _hotFileBak=StockData/.HotData/$_code.html.org.hot.$(date "+%Y-%m-%d")
    _stockDataPackage=StockData/${_code:0:6}-.package.data

    # download
    _opt=${_dateEnd:+"--dateEnd=$_dateEnd"}
    ((_cmdCode & _cmdCodeDownload)) &&  _opt+=" --download"
    ((_cmdCode & _cmdCodeUpdate ))  &&  _opt+=" --update"
    ((_cmdCode & _cmdCodeHotData )) &&  _opt+=" --hotData"
    ((_cmdCode & (_cmdCodeDownload|_cmdCodeUpdate|_cmdCodeHotData) )) && ./getStockData.$$.sh $_opt $_code >&2

    # show stock
    if ((_cmdCode & (_cmdCodeShow|_cmdCodeShowNext) )) ; then       
        let _winOrder+=1
        _showCmd="showStock.sh > $_pipe4Ana --classFile=$_classFile"
        ((_cmdCode & _cmdCodeShowDaily)) && _showCmd="$_showCmd --showDaily"
        ((_cmdCode & _cmdCodeSilent)) && _showCmd="$_showCmd --silent"
        ((_cmdCode & _cmdCodeOrder )) && _showCmd="$_showCmd --winOrder=$_winOrder"
        ((_cmdCode & _cmdCodeFixType )) && _showCmd="$_showCmd --fixType=$_fixType"
        # following cmds must be put at the end of the cmds !!!
        _showCmd="$_showCmd $_code"
        if ((_cmdCode & _cmdCodeBG)) ; then 
            $_showCmd &
        else 
            $_showCmd
        fi
    fi

    # print stock info
    if ((_cmdCode & (_cmdCodePrint|_cmdCodePrintLastOne) )) ; then       
        _tmpName=""
        [[ -n $_output ]] && _tmpName=${_output/'{}'/${_code:1}}
        ((_cmdCode & _cmdCodePrint)) && "showStock.sh" --print ${_fixType:+--fixType=$_fixType} $_code > ${_tmpName:-$_pipe4Ana}
        ((_cmdCode & _cmdCodePrintLastOne)) && "showStock.sh" --printLastOne ${_fixType:+--fixType=$_fixType} $_code > ${_tmpName:-$_pipe4Ana}
        [[ -n $_tmpName ]] && cat $_tmpName > $_pipe4Ana ;
    fi

    # do analize
    ((_cmdCode & _cmdCodeAnalize)) && [[ -f $_anaProg ]] && cat "$_pipe4Ana" | $_anaProg --code=$_code $_anaOpt

    # check hitRate
    if ((_cmdCode & _cmdCodeCheckHitRate)) ; then
        _anaOpt=''
        [[ -f .$_code.st ]] && _anaOpt+=" --searchingTab=.$_code.st" || _anaOpt+=" --printSearchingTab=.$_code.st"
        [[ -f .$_code.ct ]] && _anaOpt+=" --coefficientTab=.$_code.ct --checkHitRate" || _anaOpt+=" --printCoefficientTab=.$_code.ct"

        "showStock.sh" --print ${_fixType:+--fixType=$_fixType} $_code | ./bestBugTraning.sh $_anaOpt 
    fi

    # package daily data
    if ((_cmdCode & (_cmdCodeDoDailyHomework|_cmdCodePackDailyData) )) ; then
        mv $_hotFile $_hotFileBak 2>/dev/null
    fi

    #do daily homework
    if ((_cmdCode & _cmdCodeDoDailyHomework)) ; then
        ./getStockData.$$.sh --update --dateEnd=$_dateEnd $_code
        showHi "*[$_code]update data to $_stockDataPackage\n" >&2
        sed -i "/^${_code}/d"  $_stockDataPackage 2>/dev/null
        "showStock.sh" --print $_code >> $_stockDataPackage
    fi

    #do real time work
    #nothing need to do here

    #kill hotData retirving task
    killHotDataTask
    showMsg "*[$_code] DONE\n" >&2

done 

#postpare
if ((_cmdCode & (_cmdCodeDoDailyHomework|_cmdCodePackDailyData) )) ; then
    tar -uvf .HotData.tar StockData/.HotData && rm StockData/.HotData/*
fi

if ((_cmdCode & _cmdCodeGenRelationshipData)) ; then
    showHi "*get ampInfo files: >=9.6, >=9.4, >=4.0\n" >&2
   #cp ampGE4_countGE80.info{,.bak}     2>/dev/null
   #cp ampLE-4_countGE80.info{,.bak}    2>/dev/null
   #cp 2016_01_01_ampGE9.6_countGE5.info{,.bak}     2>/dev/null
   #cp 2016_01_01_ampLE-9.6_countGE5.info{,.bak}    2>/dev/null
    cp ampGE9.6_countGE5.info{,.bak}    2>/dev/null
    cp ampLE-9.6_countGE5.info{,.bak}   2>/dev/null
   #./_genRelationShip.sh --genAmpInfo --ampLimit=4 --countLimit=80 --save
   #./_genRelationShip.sh --genAmpInfo --ampLimit=-4 --countLimit=80 --save
   #./_genRelationShip.sh --genAmpInfo --ampLimit=9.6 --countLimit=5 --start=2016-01-01 --save=2016_01_01_ampGE9.6_countGE5.info
   #./_genRelationShip.sh --genAmpInfo --ampLimit=-9.6 --countLimit=5 --start=2016-01-01 --save=2016_01_01_ampLE-9.6_countGE5.info
    ./_genRelationShip.sh --genAmpInfo --ampLimit=9.6 --countLimit=5 --save
    ./_genRelationShip.sh --genAmpInfo --ampLimit=-9.6 --countLimit=5 --save

    #update .BKAmpGE.info and .BKAmpLE.info
    showHi "*update .BKAmpGE.info from ampGE9.6_countGE5.info\n" >&2
    doUpdateBKAmpInfo  ampGE9.6_countGE5.info  .BKAmpGE.info
    showHi "*update .BKAmpLE.info from ampLE-9.6_countGE5.info\n" >&2
    doUpdateBKAmpInfo  ampLE-9.6_countGE5.info .BKAmpLE.info

fi

wait

doExit 0
