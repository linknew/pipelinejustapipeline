#! /bin/bash

#format of trade items
#$1 PRICE  
#$2 VOLUME  +:bought, -:sold
#$3 STORESIZE 
#$4 DATE 
#$5 ARCHIVE 
#   0, normal
#   1, neutralized
#   >=2, reserved
#$6 TAX_PRICE 
#$7 REMAIN_VOLUME
#$8 LOCK_VOLUME     #the number of putting in stock

#somethings SPEAK_FIRST,
#store size will only appear in bought item.
#lock volume will only affect on bought item.

source ~/tools/lib/comm.lib

_tmp=''
_code=''
_list=''
_start=''
_end=''
_modDate=''


doExit()
{
    if [[ $1 -eq -1 ]] ; then
        kill -SIGTERM $$ 2>/dev/null
    fi

    rm -rf .tmp.$$ 2>/dev/null ;
    rm -rf .profitDetails.log.$$ 2>/dev/null ;
    exit $1
}

#parameters setting verification and fixing
for i in "$@"; do
    [[ $i == --help ]] && echo "
    Usage:
        $0 [--help] [--onlyOnce] [--code=stockID] [--list=listFile] [--details] [[--date=([+|-]N|yyyy-mm-dd)] | ([--start=(-N|yyyy-mm-dd)] [--end=(-N|yyyy-mm-dd)])] statementAccountFile

        --onlyOnce, only run once.
        --code, check single stock specified by 'stockId'.
        --list, NOT SUPPORT YET. check the stocks listted in 'stockList'.
        --details, print details of deals.
        --start, set the start date of the searching range. -N means pre-days of current date, +N means post-days of current date, N means currentMon-Nday
        --end, set the end date of the searching range. -N means pre-days of current date, +N means post-days of current date, N means currentMon-Nday
        --date, set --start and --end to same date

    Default:
        --start=1970-01-01 --end=\$TODAY .statementAccount

    " && doExit 0

    [[ ${i%%=*} == '--onlyOnce' ]] && _onlyOnce=1 && continue
    [[ ${i%%=*} == '--code' ]] && _code=${i##*=} && continue
    [[ ${i%%=*} == '--list' ]] && _list=${i##*=} && continue
    [[ ${i%%=*} == '--details' ]] && _details=1 && continue
    [[ ${i%%=*} == '--start' ]] && _start=${i##*=} && continue
    [[ ${i%%=*} == '--end' ]] && _end=${i##*=} && continue
    [[ ${i%%=*} == '--date' ]] && _start=${i##*=} && _end=${i##*=} && continue
    [[ ${i:0:1} == '-' ]] && showErr "unrecognized option:$i\n" >&2 && exit 1

    _statementAccountFile=$i
done

trap "doExit -1" SIGTERM SIGINT SIGQUIT

_start=$(getActualDate ${_start:-1970-01-01})
_end=$(getActualDate ${_end:-+0})
_statementAccountFile=${_statementAccountFile:-.statementAccount}
_modDate=$(ls -alT $_statementAccountFile | awk '{print $8}')

while true; do

    [[ -f .profitDetails.log.$$ ]] && :>.profitDetails.log.$$
    clrScr && cursorTo 1 1
    showMsg "\n*checking ${_code}${_code:+ }from " ; showHi "$_start"; showMsg " to "; showHi "$_end\n"
    cat $_statementAccountFile |
    awk -v _awkDateStart=$_start    \
        -v _awkDateEnd=$_end        \
        -v _awkCode=$_code          \
        -v _awkDetail=$_details     \
        '

        '"$awkFunction_asortSet"'   #include sort functions

        function getTaxPrice(   \
            price,
            vol,        #positive for BUY, nagtive for SEL, zero will returns 0!!!
            # below is local parameters
            _isSoldItem,_tax,_tax1,_tax2,_taxPrice)
        {
            if(vol == 0) return 0 ;
            if(vol < 0){ _isSoldItem = 1 ; vol = -vol ; }

            if(_isSoldItem){
                _tax1 = price * vol * STOCKMARK_TAX ;      # for stock market
                if(_tax1 < STOCKMARK_TAX_LIMIT) _tax1 = STOCKMARK_TAX_LIMIT ;
                _tax2 = price * vol * PRINT_TAX ;     # for print_flower tax
                if(_tax2 < PRINT_TAX_LIMIT) _tax2 = PRINT_TAX_LIMIT ;
                _tax = _tax1 + _tax2 ;
                _taxPrice = (price * vol - _tax)/vol ;
            }else{
                _tax = price * vol * STOCKMARK_TAX ;       # for stock market
                if(_tax < STOCKMARK_TAX_LIMIT) _tax = STOCKMARK_TAX_LIMIT ;
                _taxPrice = (price * vol + _tax)/vol ;
            }

            return _taxPrice ;
        }

        function getWorestPrice(    \
            taxPrice,
            vol,        #positive for BUY, nagtive for SEL, zero will returns 0!!!
            # below is local parameters
            _isSoldItem, _wstPriceForPrint, _wstPriceForStockMarkTax, _worestPrice )
        {
            if(vol == 0 || taxPrice == 0) return 0 ;
            if(vol < 0){ _isSoldItem = 1 ; vol = -vol ; }

            _wstPriceForPrint = PRINT_TAX_LIMIT / (vol*PRINT_TAX) ;
            _wstPriceForStockMarkTax = STOCKMARK_TAX_LIMIT / (vol*STOCKMARK_TAX) ;

            if(_isSoldItem){
                #this is sold item, get worest buy price

                #_worestPrice * vol * (1 + STOCKMARK_TAX) = taxPrice * vol ;
                _worestPrice = taxPrice / (1 + STOCKMARK_TAX) ;

                if(_worestPrice <_wstPriceForStockMarkTax){
                    #_worestPrice * vol + STOCKMARK_TAX_LIMIT = taxPrice * vol ;
                    _worestPrice = (taxPrice * vol - STOCKMARK_TAX_LIMIT) / vol ;
                }

            }else{
                #this is bought item, get worest sell price

                _worestPrice = taxPrice / (1-PRINT_TAX-STOCKMARK_TAX) ;
                
                if(_worestPrice < _wstPriceForStockMarkTax && _worestPrice < _wstPriceForPrint){
                    #taxPrice * vol = _worestPrice * vol - PRINT_TAX_LIMIT - STOCKMARK_TAX_LIMIT ;
                    _worestPrice = (taxPrice * vol + PRINT_TAX_LIMIT + STOCKMARK_TAX_LIMIT) / vol ;
                }else if(_worestPrice <_wstPriceForStockMarkTax){
                    #taxPrice * vol = _worestPrice * vol * (1-PRINT_TAX) - STOCKMARK_TAX_LIMIT ;
                    _worestPrice = (taxPrice * vol + STOCKMARK_TAX_LIMIT) / ((1-PRINT_TAX) * vol) ;
                }else if(_worestPrice <_wstPriceForPrint){
                    #taxPrice * vol = _worestPrice * vol * (1-STOCKMARK_TAX) - PRINT_TAX_LIMIT ;
                    _worestPrice = (taxPrice * vol + PRINT_TAX_LIMIT) / ((1-STOCKMARK_TAX) * vol) ;
                }
            }

            return _worestPrice ;
        }

        function neutralize(    \
            code,               #stock id
            buy,                #bought array, must be a sorted array, sorted by date(non revert) first, then sorted by price(revert)
                                #be care for, function may change the content of this array.
            sel,                #sold array, must be a sorted array, same with buy array
                                #be care for, function may change the content of this array.
            dateStart,
            dateEnd,
                                #
                                #above are parameters, below are local various
                                #
            i,j,_dateLine,_cntBuy,_cntSel,_storeSize,_lockTT,_dateLineBuy,_dateLineSel,_buyPrice,_buyVol,_selPrice,_selVol,_dealVol,_profit,
            _buyVolTT,_selVolTT,_buyValTT,_selValTT,_dealVolTT,_profitTotal,_profitBefRange,_cntBuyPreprocess,_cntSelPreprocess,
            _buyLog,_selLog,_sortFields)
        {
            _dateLine = 0"" ;
            _cntBuy = 0 ;
            _cntBuyPreprocess = 0 ;
            _cntSel = 0 ;
            _cntSelPreprocess = 0 ;
            _buyVolTT = 0 ;
            _selVolTT = 0 ;
            _storeSize = 0 ;
            printf "" >_tmpProfitLogFile;    # do initializing

            #do some preprocessing
            #this will boost the speed
            {
                while(1)
                {
                    #get range of buy array and get next dateLine for buy
                    for(i=_cntBuy; i<length(buy); i++){
                        $0 = buy[i] ;
                        if($DATE > _dateLine){
                            _dateLineBuy = $DATE ;
                            break ;
                        }
                        if($STORESIZE != "-") _storeSize = $STORESIZE ;
                        _buyVolTT += $REMAIN_VOLUME ;
                    }
                    _cntBuy = i ;
                    if(i>=length(buy)) _dateLineBuy = "9999-12-31" ;

                    #get range of sel array and get next dateLine for sel
                    for(i=_cntSel; i<length(sel); i++){
                        $0 = sel[i] ;
                        if($DATE > _dateLine){
                            _dateLineSel = $DATE ;
                            break ;
                        }
                        _selVolTT += $REMAIN_VOLUME ;
                    }
                    _cntSel = i ;
                    if(i>=length(sel)) _dateLineSel = "9999-12-31" ;

                    # no lock and buyVol equal SelVol, is a liquidation
                    if(_storeSize == 0 && _buyVolTT == _selVolTT){
                        _cntBuyPreprocess = _cntBuy ;
                        _cntSelPreprocess = _cntSel ;
                    }

                    #get next dateLine use the smaller between buy & sel
                    _dateLine = (_dateLineBuy < _dateLineSel) ? _dateLineBuy : _dateLineSel ;

                    #break if out of range
                    if(_dateLine >= dateStart) break ;
                    if(_cntSel == length(sel) && _cntBuy == length(buy)) break ;
                }

                #reset remind volume from 0 to _cntBuyPreprocess
                for(i=0; i<_cntBuyPreprocess; i++){
                    $0 = buy[i] ;
                    $REMAIN_VOLUME = 0 ;
                    buy[i] = $0 ;
                }

                #reset remind volume from 0 to _cntSelPreprocess
                for(i=0; i<_cntSelPreprocess; i++){
                    $0 = sel[i] ;
                    $REMAIN_VOLUME = 0 ;
                    sel[i] = $0 ;
                }

                _dateLine = 0"" ;
                _cntBuy = _cntBuyPreprocess ;
                _cntSel = _cntSelPreprocess ;
                _buyVolTT = 0 ;
                _selVolTT = 0 ;
                _storeSize = 0 ;
                _lockTT = 0 ;
#                print "last Buy idx="_cntBuy-1 > "/dev/stderr" ;
#                if(_cntBuy>0) print buy[_cntBuy-1]  > "/dev/stderr";
#                print "last Sel idx="_cntSel-1  > "/dev/stderr";
#                if(_cntSel>0) print sel[_cntSel-1]  > "/dev/stderr";
            }

            #do neutralize_processing
            while(1){

                #get range of buy array and get next dateLine for buy
                for(i=_cntBuy; i<length(buy); i++){
                    $0 = buy[i] ;
                    if($DATE > _dateLine){
                        _dateLineBuy = $DATE ;
                        break ;
                    }
                    if($STORESIZE != "-") _storeSize = $STORESIZE ;
                    _buyVolTT += $REMAIN_VOLUME ;
                }
                _cntBuy = i ;
                if(i>=length(buy)) _dateLineBuy = "9999-12-31" ;

                #get range of sel array and get next dateLine for sel
                for(i=_cntSel; i<length(sel); i++){
                    $0 = sel[i] ;
                    if($DATE > _dateLine){
                        _dateLineSel = $DATE ;
                        break ;
                    }
                    _selVolTT += $REMAIN_VOLUME ;
                }
                _cntSel = i ;
                if(i>=length(sel)) _dateLineSel = "9999-12-31" ;

                #now, let us do the neutralization
                if(_storeSize == 0 && _buyVolTT == _selVolTT && _buyVolTT != 0){

                    #DO LIQUIDATION!!!

                    _dealVolTT = 0 ;
                    _buyValTT = 0 ;
                    _selValTT = 0 ;

                    print "*Made a Liquidation on", _dateLine > _tmpProfitLogFile ;

                    for(i=_cntBuyPreprocess; i<_cntBuy; i++){
                        $0 = buy[i] ;
                        _buyPrice   = $TAX_PRICE+0;
                        _buyVol     = $REMAIN_VOLUME+0;
                        _dealVolTT += _buyVol ;
                        _buyValTT  += _buyVol*_buyPrice ;

                        #print log
                        if(_dateLine >= dateStart){
                            if($REMAIN_VOLUME)
                                printf("\t\t\t    [%-6.2f %-6s %-s %s %s %-6.2f %-6d %d]\n",
                                        $PRICE,$VOLUME,$STORESIZE,$DATE,$ARCHIVE,$TAX_PRICE,$REMAIN_VOLUME,$LOCK_VOLUME) >_tmpProfitLogFile;
                        }

                        #clear remind volume and lock volume and set archive
                        $REMAIN_VOLUME = 0 ;
                        $LOCK_VOLUME = 0 ;
                        $ARCHIVE = 1 ;      #already neutralized
                        buy[i] = $0 ;
                    }

                    for(i=_cntSelPreprocess; i<_cntSel; i++){
                        $0 = sel[i] ;
                        _selPrice  = $TAX_PRICE+0;
                        _selVol    = $REMAIN_VOLUME+0;
                        _selValTT += _selVol*_selPrice ;

                        #print log
                        if(_dateLine >= dateStart){
                            if($REMAIN_VOLUME)
                                printf("\t\t\t    [%-6.2f %-6s %-s %s %s %-6.2f %-6d %d]\n",
                                        $PRICE,$VOLUME,$STORESIZE,$DATE,$ARCHIVE,$TAX_PRICE,$REMAIN_VOLUME,$LOCK_VOLUME) >_tmpProfitLogFile;
                        }

                        #clear remind volume and set archive and lock volume (actually, lock volume of sel has NOT used)
                        $REMAIN_VOLUME = 0 ;
                        $LOCK_VOLUME = 0 ;
                        $ARCHIVE = 1 ;          #already neutralized
                        sel[i] = $0 ;
                    }

                    #update _profitTotal and _profitBefRange
                    _profitTotal += _selValTT-_buyValTT ;
                    if(_dateLine < dateStart) _profitBefRange += _selValTT-_buyValTT ;

                    #print digest
                    if(_dateLine >= dateStart){
                        if(_selValTT < _buyValTT){
                            _colorS =  "\033[1;31m" ;
                            _colorE =  "\033[0m" ;
                        }else{
                            _colorS = _colorE = "" ;
                        }
                        printf(_colorS"Deal %5d, Earn  %-5.0f (%.2f * %d <-- %.2f * %d)"_colorE"\n", 
                               _dealVolTT,_selValTT-_buyValTT,
                               _buyValTT/_dealVolTT,_dealVolTT,
                               _selValTT/_dealVolTT,_dealVolTT) > _tmpProfitLogFile ;;
                    }

                }else{

                    #DO NORMAL NEUTRALIZATION

                    #resort buy and sel according remind_volume & price(from BIG to SMALL)
                    {
                        if(_cntBuy > 1){
                            _sortFields[0,"prio"] =ARCHIVE ;
                            _sortFields[0,"numeric"]=1;
                            _sortFields[0,"revert"]=1;
                            _sortFields[1,"prio"]=PRICE;
                            _sortFields[1,"numeric"]=1;
                            _sortFields[1,"revert"]=1;
                            asortMult(buy,buy,1,1,_sortFields,_cntBuyPreprocess, _cntBuy-1) ;
                        }
                        if(_cntSel > 1){
                            _sortFields[0,"prio"] =ARCHIVE ;
                            _sortFields[0,"numeric"]=1;
                            _sortFields[0,"revert"]=1;
                            _sortFields[1,"prio"]=PRICE;
                            _sortFields[1,"numeric"]=1;
                            _sortFields[1,"revert"]=1;
                            asortMult(sel,sel,1,1,_sortFields, _cntSelPreprocess, _cntSel-1) ;
                        }
                    }

                    #skip the item which remind_volume is 0 (actually, we use archive==1 to check)
                    #can boost the speed!
                    {
                        for(i = _cntBuyPreprocess; i < _cntBuy; i++){
                            $0 = buy[i] ;
                            if($ARCHIVE != 1) break ;
                            _cntBuyPreprocess ++ ;
                        }

                        for(i = _cntSelPreprocess; i < _cntSel; i++){
                            $0 = sel[i] ;
                            if($ARCHIVE != 1) break ;
                            _cntSelPreprocess ++ ;
                        }

#                        print "BuyPreProcessIdx="_cntBuyPreprocess, "SelPreProcessIdx="_cntSelPreprocess ;
                    }

                    #let us update lock_val(the cheaper of bought item will be locked with high priority) on the sorted arrays first
                    {
#                       print "-->"_storeSize,_lockTT,_dateLine,_cntBuy ;
                        i = _cntBuyPreprocess ;
                        while(_lockTT > _storeSize  &&  i < _cntBuy ){
                            $0 = buy[i] ;
                            if($LOCK_VOLUME > 0){
                                j = _lockTT-_storeSize ;
                                if(j < $LOCK_VOLUME){
                                    _lockTT -= j ;
                                    $LOCK_VOLUME -= j ;
                                }else{
                                    _lockTT -= $LOCK_VOLUME ;
                                    $LOCK_VOLUME = 0 ;
                                }
                                buy[i] = $0 ;
                            }
                            i++ ;
                        }
                        i = _cntBuy-1 ;
                        while(_lockTT < _storeSize && i >= _cntBuyPreprocess){
                            $0 = buy[i] ;
                            if($LOCK_VOLUME < $REMAIN_VOLUME){
                                j = _storeSize-_lockTT ;
                                if(j < $REMAIN_VOLUME-$LOCK_VOLUME){
                                    _lockTT += j ;
                                    $LOCK_VOLUME += j ;
                                }else{
                                    _lockTT += $REMAIN_VOLUME-$LOCK_VOLUME ;
                                    $LOCK_VOLUME = $REMAIN_VOLUME ;
                                }
                                buy[i] = $0 ;
                            }
                            i-- ;
                        }
#                       print "==>"_storeSize,_lockTT,_dateLine ;
                    }

                    #use smallest SEL to neutralize the biggest BUY
                    for(i=_cntSel-1; i>=_cntSelPreprocess; i--){
                        split(sel[i], _selLog) ;
                        _selPrice=_selLog[TAX_PRICE]+0; _selVol=_selLog[REMAIN_VOLUME]-_selLog[LOCK_VOLUME] ;
                        if(_selVol <= 0) continue ;

                        for(j=_cntBuyPreprocess; j<_cntBuy; j++){
                            split(buy[j], _buyLog) ;
                            _buyPrice=_buyLog[TAX_PRICE]+0; _buyVol=_buyLog[REMAIN_VOLUME]-_buyLog[LOCK_VOLUME];
                            if(_buyVol <= 0 || _buyPrice > _selPrice) continue ;

                            #caculate profit
                            _dealVol = (_buyVol < _selVol) ? _buyVol : _selVol ;
                            _profit =  _dealVol*(_selPrice-_buyPrice) ;
                            _profitTotal += _profit ;
                            if(_dateLine < dateStart) _profitBefRange += _profit ;

                            #print some log
                            if(_dateLine >= dateStart){
                                printf("Deal %5d, Earn  %-5.0f [%-6.2f %-6s %s\t%s %s %-6.2f %-6d %d] <-- [%-6.2f %-6s %5s\t %s %s %-6.2f %-6d %d]\n",
                                        _dealVol,_profit,
                                        _selLog[PRICE],_selLog[VOLUME],_selLog[STORESIZE],_selLog[DATE],
                                        _selLog[ARCHIVE],_selLog[TAX_PRICE],_selLog[REMAIN_VOLUME],_selLog[LOCK_VOLUME],
                                        _buyLog[PRICE],_buyLog[VOLUME],_buyLog[STORESIZE],_buyLog[DATE],_buyLog[ARCHIVE],
                                        _buyLog[TAX_PRICE],_buyLog[REMAIN_VOLUME],_buyLog[LOCK_VOLUME]) >_tmpProfitLogFile;
                            }

                            #update remain volume
                            _selVol -= _dealVol ;
                            _buyLog[REMAIN_VOLUME] -= _dealVol ;
                            _selLog[REMAIN_VOLUME] -= _dealVol ;
                            if(_buyLog[REMAIN_VOLUME]+0 == 0) _buyLog[ARCHIVE] = 1 ;    #set archive to neutralized
                            if(_selLog[REMAIN_VOLUME]+0 == 0) _selLog[ARCHIVE] = 1 ;    #set archive to neutralized
                            buy[j] = _buyLog[PRICE]" "_buyLog[VOLUME]" "_buyLog[STORESIZE]" "_buyLog[DATE]" "_buyLog[ARCHIVE]" "_buyLog[TAX_PRICE]" "_buyLog[REMAIN_VOLUME]" "_buyLog[LOCK_VOLUME]" " ;

                            #this sel item is empty, break and do next one
                            if(_selVol == 0) break ;
                        }

                        #update remain volume of sel
                        sel[i] = _selLog[PRICE]" "_selLog[VOLUME]" "_selLog[STORESIZE]" "_selLog[DATE]" "_selLog[ARCHIVE]" "_selLog[TAX_PRICE]" "_selLog[REMAIN_VOLUME]" "_selLog[LOCK_VOLUME]" " ;
                    }
                }
                
                #get next dateLine use the smaller between buy & sel
                _dateLine = (_dateLineBuy < _dateLineSel) ? _dateLineBuy : _dateLineSel ;

                #break if out of range
                if(_dateLine > dateEnd) break ;
                if(_cntSel == length(sel) && _cntBuy == length(buy)) break ;
            }

            close(_tmpProfitLogFile) ;
            return _profitTotal - _profitBefRange ;
        }

        function abs(digitalNum)
        {
            return (digitalNum<0) ? -digitalNum : digitalNum ;
        }

        BEGIN\
        {
            #define sort array fields name
            PRICE = 1 ;
            VOLUME = 2 ;
            STORESIZE = 3 ;
            DATE = 4 ;
            ARCHIVE = 5 ;
            TAX_PRICE = 6 ;
            REMAIN_VOLUME = 7 ;
            LOCK_VOLUME = 8 ;
            
            #about tax
            PRINT_TAX=0.001 ;
            PRINT_TAX_LIMIT=1.0 ;
            STOCKMARK_TAX=0.0003 ;
            STOCKMARK_TAX_LIMIT=5.0 ;

            CONVFMT="%0.8f" ;
            _blurryStockId = 0 ;
            if(length(_awkCode)==0) _blurryStockId = 1 ;
            _tmpFile = ".tmp.'$$'" ;
            _tmpProfitLogFile = ".profitDetails.log.'$$'" ;
            print "---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------" ;
        }

        (substr($1,1,1) != "#")\
        {

            if($5 > _awkDateEnd) next ;

#            gsub(/X/,"",_awkCode) ;
#            if(length(_awkCode) == 7){
#                _awkCode=substr(_awkCode,2) ;
#            }
#            if(index($1,_awkCode) == 0) next ;

            if(_blurryStockId){
                if($1 !~ _awkCode) next ;
            }else{
                if($1 != _awkCode) next ;
            }

            _code = $1 ;
            if(_blurryStockId) gsub(/^X+/,"",_code) ;
            _price = $2+0 ;
            _vol = $3 ;
            _remainVol = abs($3) ;
            _storeSize = $4 ;
            _date = $5 ;
            _archive = $6 ;
            _lockVol = 0 ;
            _taxPrice = getTaxPrice(_price, _vol) ;

            # convert to 7 ditials codeId
            if(length(_code) == 6){
                sub(/^/,"1",_code) ;
                sub(/^16/,"06",_code) ;
            }

            # get stock name
            if(!stockName[_code]){
                _name=" " ;
                _bashCmd="grep "_code" stock.list | sed s/^.*\\ //" ;
                _bashCmd | getline _name ;
                stockName[_code] = _name ;
                close(_bashCmd) ;
            }

            # get bought/sold info
            tradeInfo[_code,bought[_code,"cnt"]+sold[_code,"cnt"]]= _date" "_vol" "_price ;
            if(_vol+0 >= 0){
                bought[_code,"vol"] += 0+_vol ;
                bought[_code,bought[_code,"cnt"]+0] = _price" "_vol" "_storeSize" "_date" "_archive" "_taxPrice" "_remainVol" "_lockVol ;
                bought[_code,"cnt"] += 1 ;
            }else{
                sold[_code,"vol"] -= (0+_vol) ;
                sold[_code,sold[_code,"cnt"]+0] = _price" "_vol" "_storeSize" "_date" "_archive" "_taxPrice" "_remainVol" "_lockVol ;
                sold[_code,"cnt"] += 1 ;
            }
        }

        END\
        {
            TotalTEarn = 0 ;
            TotalCash = 0 ;
            TotalStock = 0 ;
            TotalInvestment = 0 ;
            TotalProfit = 0 ;

            for(_code in stockName){

#                printf("%s",_code) > "/dev/stderr" ;
                _buyVolRemain = 0 ;
                _selVolRemain = 0 ;
                _payTotal = 0 ;
                _payRemain = 0 ;
                _earnTotal = 0 ;
                _earnRemain = 0 ;
                _tEarn = 0 ;
                _cash = 0 ;
                _stockValue = 0 ;
                _asset = 0 ;
                _investment = 0 ;
                _profit = 0 ;

                delete _buySort ;
                delete _sellSort ;

                for(i=0;i<bought[_code,"cnt"];i++){
                    _buySort[i] = bought[_code,i] ;
                }

                for(i=0;i<sold[_code,"cnt"];i++){
                    _sellSort[i] = sold[_code,i] ;
                }

                print "\n*"stockName[_code]"["_code"]","\n----------------" > _tmpFile ;
                _tEarn=neutralize(_code,_buySort,_sellSort,_awkDateStart,_awkDateEnd) ;
                if(_awkDetail){
                    print "[Details]" > _tmpFile ;
                    while( (getline < _tmpProfitLogFile) > 0 ){
                        print "    "$0 > _tmpFile ;
                    }
                    close(_tmpProfitLogFile)
                }

                _sortFields[0,"prio"]=LOCK_VOLUME;
                _sortFields[0,"numeric"]=1;
                _sortFields[0,"revert"]=1;
                _sortFields[1,"prio"]=PRICE;
                _sortFields[1,"numeric"]=1;
                _sortFields[1,"revert"]=1;
                asortMult(_buySort,_buySort,0,0,_sortFields) ;

                print "[Bought]" > _tmpFile ;
                _lockTT = 0 ;
                for(i=0;i<length(_buySort);i++) {
                    $0 = _buySort[i];
                    _lockTT += $LOCK_VOLUME ;
                    if($REMAIN_VOLUME!=0){ 
                        #printf("    %-6.2f   +%-5d   %-4d   *%-6.3f",$PRICE,$REMAIN_VOLUME,$LOCK_VOLUME,$TAX_PRICE/(1-PRINT_TAX-STOCKMARK_TAX)) > _tmpFile ;
                        printf("    %-6.2f   +%-5d   %-4d   *%-6.3f",$PRICE,$REMAIN_VOLUME,$LOCK_VOLUME,getWorestPrice($TAX_PRICE,$REMAIN_VOLUME)) > _tmpFile ;
                        for(j=1;j<=10;j++) printf("   \033[1;31m%-6.2f",$PRICE*(1+0.01*j)) > _tmpFile ;
                        printf("   \033[0m%s",$DATE) > _tmpFile ;
                        print " " > _tmpFile ;
                        _payRemain += $TAX_PRICE*$REMAIN_VOLUME ;
                        _buyVolRemain += $REMAIN_VOLUME ;
                    }
                    asset[_code,"pay"] += $TAX_PRICE*$VOLUME ;
                    if($DATE>=_awkDateStart && $DATE<=_awkDateEnd) asset[_code,"payInRng"] += $TAX_PRICE*$VOLUME ;
                }
                print (_buyVolRemain>0)?"    ---\n    "(_payRemain/_buyVolRemain)" * "(_buyVolRemain):"    /",(_lockTT>0)?"[lock "_lockTT"]":"" > _tmpFile ;

                print "[Sold]" > _tmpFile ;
                for(i=0;i<length(_sellSort);i++) {
                    $0 = _sellSort[i];
                    if($REMAIN_VOLUME!=0){ 
                        #printf("    %-6.2f   -%-5d   %-4d   *%-6.3f",$PRICE,$REMAIN_VOLUME,$LOCK_VOLUME,$TAX_PRICE/(1+STOCKMARK_TAX)) > _tmpFile ;
                        printf("    %-6.2f   -%-5d   %-4d   *%-6.3f",$PRICE,$REMAIN_VOLUME,$LOCK_VOLUME,getWorestPrice($TAX_PRICE,-$REMAIN_VOLUME)) > _tmpFile ;
                        for(j=1;j<=10;j++) printf("   \033[1;32m%-6.2f",$PRICE*(1-0.01*j)) > _tmpFile ;
                        printf("   \033[0m%s",$DATE) > _tmpFile ;
                        print " " > _tmpFile ;
                        _earnRemain+=$TAX_PRICE*$REMAIN_VOLUME ;
                        _selVolRemain+=$REMAIN_VOLUME ;
                    }
                    asset[_code,"earn"] += -$TAX_PRICE*$VOLUME ;
                    if($DATE>=_awkDateStart && $DATE<=_awkDateEnd) asset[_code,"earnInRng"] += $TAX_PRICE*$VOLUME ;
                }
                print (_selVolRemain>0)?"    ---\n    "(_earnRemain/_selVolRemain)" * "(_selVolRemain):"    /" > _tmpFile ;
                print "[Status]" > _tmpFile ;

                # get last price
                if(_selVolRemain == _buyVolRemain){
                    _lastPrice[_code] = 0 ;
                }else{
                    _bashCmd="./playStockList.sh --print --fixType=N <<< "_code" 2>/dev/null | grep "_awkDateEnd" | awk \"END{print \\$2}\" " ;
                    _bashCmd | getline _lastPrice[_code] ;
                    close(_bashCmd) ;
                }

                # print profit
                _cash = (_buyVolRemain==_selVolRemain)?0:_earnRemain;
                _stockValue = (_buyVolRemain==_selVolRemain)?0:_lastPrice[_code]*(_buyVolRemain-_selVolRemain) ;
                _asset = _cash + _stockValue ;
                _investment = (_buyVolRemain==_selVolRemain)?0:_payRemain ;
                _profit = (asset[_code,"earn"] - asset[_code,"pay"]) + _lastPrice[_code]*(_buyVolRemain-_selVolRemain) ;

                printf("    TEarn:\t  %.2f\n",_tEarn) > _tmpFile ;
                printf("    Asset:\t  %d(%d+%d)\n", _asset, _cash, _stockValue) > _tmpFile ;
                printf("    Investment:\t  %d\n", _investment) > _tmpFile ;
                printf("    Profit:\t  %d\n", _profit) > _tmpFile ;
                close(_tmpFile) ;

                if(_tEarn || _selVolRemain != _buyVolRemain || _lockTT){
                    system("cat " _tmpFile) ; 
                }else{
#                    print "\n*"stockName[_code]"["_code"]","no data filtted\n" > "/dev/stderr" ;
                }

                TotalTEarn += _tEarn ;
                TotalCash  += _cash ;
                TotalStock += _stockValue ;
                TotalInvestment += _investment ;
                TotalProfit += _profit ;
#                print " ok" > "/dev/stderr" ;
            }
            print "OK" > "/dev/stderr" ; 

            if(length(stockName)>1){
                printf ("\n======================\n%s\t %d\n%s\t %d(%d+%d)\n%s %d\n%s\t %d\n\n",
                        "TotalTEarn:", TotalTEarn,
                        "TotalAsset:", TotalCash+TotalStock, TotalCash, TotalStock,
                        "TotalInvestment:", TotalInvestment,
                        "TotalProfit:", TotalProfit) ;
            }
        }

        '

    [[ $_onlyOnce -eq 1 ]] && break ;

    while true ; do
        _tmp=$(ls -alT $_statementAccountFile | awk '{print $8}')
        if [[ $_tmp == $_modDate ]]; then
            sleep 5
        else
            _modDate=$_tmp && break
        fi
    done

done

doExit 0

