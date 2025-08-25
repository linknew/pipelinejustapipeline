
#! /bin/bash

# counting the result of each seed/signal

source $(dirname $0)/../lib/comm.lib

doStart


seedSerialLvlDef=3 ;
skipNewBornDef=60 ;
taxRatPrtDef=0.001 ;
taxRatHandFeeDef=0.00035 ;
pruneOrgDataDef=1 ;
noAbbDef=0 ;
keepNoneItemDef=0 ;
noSortingDef=0 ;
countingProfitDef=0 ;
verboseDef=0 ;
genSyncProfitDef=0 ;
orgFundsDef=0 ; #20000 ;
segFileDef=""
startDef="" ;
endDef="" ;

Usage()
{
    echo -ne "
    Description:
        -

    Usage:  $(basename $0) [--serialLvl=<N> | -N] [--skipNewBorn=N] [--start=YYYY-MM-DD] [--end=YYYY-MM-DD] [--taxRatPrt=F] [--taxRatHandFee=F] [--fltCode=S] [--fltSeed=S]
                     [ ( ( (--dispPruneData [--noAbb] [--keepNoneItem]) | --dispPD) [--noSorting]) | ( (--dispProfit | --dispSyncProfit) [--verbose] ) ]
                     [--help]
                     segFile

        --serialLvl, serial level of seed (-N is short cut to --serialLvl)
        --skipNewBorn, skip number of new datas
        --taxRatPrt, rate of print_fllower, is a float with unit %
        --taxRatHandFee, rate of handing fee, is a float with unit %
        --fltCode, specifiy a file for code_filter
        --fltSeed, specifiy a file for seed_filter
        --start
        --end
        --dispPruneData, display pruned data (with sorting)
        --noAbb, do not use abbrevation of seed
        --keepNoneItem, do not ignore NONE items
        --noSorting, do not sorting original data by date
        --dispPD, abberavation of --dispPruneData --noAbb --keepNoneItem
        --dispProfit, display counting profit
        --verbose, print details of counint profit
        --dispSyncProfit, display synchronoused profit, this option will auto enable --verbose
        --help

    Note:
        -

    Default:
        --serialLvl=$seedSerialLvlDef --skipNewBorn=$skipNewBornDef --taxRatPrt=$taxRatPrtDef --taxRatHandFee=$taxRatHandFeeDef
        --dispProfit
\n"
}

for i in "${@}"
do
    [[ ${i} == "--help" ]] && Usage >&2 && doExit 0
    [[ ${i%%=*} == "--serialLvl" ]] && seedSerialLvl=${i##*=} && continue
    [[ ${i%%=*} == "--skipNewBorn" ]] && skipNewBorn=${i##*=} && continue
    [[ ${i%%=*} == "--taxRatPrt" ]] && taxRatPrt=${i##*=} && continue
    [[ ${i%%=*} == "--taxRatHandFee" ]] && taxRatHandFee=${i##*=} && continue
    [[ ${i%%=*} == "--dispPruneData" ]] &&dispPruneData=1 && continue
    [[ ${i%%=*} == "--noAbb" ]] &&noAbb=1 && continue
    [[ ${i%%=*} == "--keepNoneItem" ]] &&keepNoneItem=1 && continue
    [[ ${i%%=*} == "--dispPD" ]] && dispPruneData=1 && noAbb=1 && keepNoneItem=1 && continue
    [[ ${i%%=*} == "--noSorting" ]] && noSorting=1 && continue
    [[ ${i%%=*} == "--dispProfit" ]] && dispProfit=1 && continue
    [[ ${i%%=*} == "--verbose" ]] && verbose=1 && continue
    [[ ${i%%=*} == "--dispSyncProfit" ]] && dispSyncProfit=1 && verbose=1 && continue
    [[ ${i%%=*} == "--fltCode" ]] && fnCodeFlt=${i##*=} && continue
    [[ ${i%%=*} == "--fltSeed" ]] && fnSeedFlt=${i##*=} && continue
    [[ ${i%%=*} == "--start" ]] &&  start=${i#*=} && continue ;
    [[ ${i%%=*} == "--end" ]] && end=${i#*=} && continue ;
    [[ ${i:0:2} == "--" ]] && echo "*! Unknown option:$i">&2 && doExit -1
    [[ ${i:0:1} == "-" && (${i:1:1} > "0" && ${i:1:1} < ":") ]] && seedSerialLvl=${i:1} && continue     #@ FIXME, seedSerialLvl>=10??
    [[ ${i:0:1} == "-" ]] && echo "*! Unknown option:$i">&2 && doExit -1
    [[ -n $segFile ]] && echo "*! Multipule segFile specified">&2 && doExit -1
    segFile=$i
done

[[ $verbose -eq 1 && $dispProfit -eq 0 && $dispSyncProfit -eq 0 ]] && showErr "--verbose must bind with --dispProfit or --dispSyncProfit\n" >&2 && doExit -1
[[ $noAbb -eq 1 && $dispPruneData -eq 0 ]] && showErr "--noAbb must bind with --dispPruneData\n" >&2 && doExit -1
[[ $keepNoneItem -eq 1 && $dispPruneData -eq 0 ]] && showErr "--keepNoneItem must bind with --dispPruneData\n" >&2 && doExit -1
[[ $noSorting -eq 1 && $dispPruneData -eq 0 ]] && showErr "--noSorting must bind with --dispPruneData\n" >&2 && doExit -1
[[ $((dispPruneData + dispProfit + dispSyncProfit)) -eq 0 ]] && dispProfit=1 && showWarn "*no display contnet, set --dispProfit as default\n" >&2
[[ -n $fnCodeFlt && ! -f $fnCodeFlt ]] && showErr "cannot find or open code filter\"$fnCodeFlt\"\n" && doExit -1
[[ -n $fnSeedFlt && ! -f $fnSeedFlt ]] && showErr "cannot find or open seed filter\"$fnSeedFlt\"\n" && doExit -1

[[ $((dispPruneData + dispProfit + dispSyncProfit)) -ge 2 ]] && showErr "only one of --dispPruneData/--dispProfit/--dispSyncProfit exist\n" >&2 && exit -1


[[ $dispPruneData ]] && pruneOrgData=1
[[ $dispProfit ]] && pruneOrgData=1 && countingProfit=1
[[ $dispSyncProfit ]] && pruneOrgData=1 && countingProfit=1 && genSyncProfit=1

taxRatPrt=${taxRatPrt:-$taxRatPrtDef}
skipNewBorn=${skipNewBorn:-$skipNewBornDef}
taxRatHandFee=${taxRatHandFee:-$taxRatHandFeeDef}
seedSerialLvl=${seedSerialLvl:-$seedSerialLvlDef}
pruneOrgData=${pruneOrgData:-$pruneOrgDataDef}
noAbb=${noAbb:-$noAbbDef}
keepNoneItem=${keepNoneItem:-$keepNoneItemDef}
noSorting=${noSorting:-$noSortingDef}
countingProfit=${countingProfit:-$countingProfitDef}
verbose=${verbose:-$verboseDef}
genSyncProfit=${genSyncProfit:-$genSyncProfitDef}
orgFunds=${orgFunds:-$orgFundsDef}
segFile=${segFile:-$segFileDef}
start=${start:-$startDef}
end=${end:-$endDef}

# in $segFile, the data list by stocks, but we want:
#   * the data sorting by date
# if the dates are same, we want:
#   * list these data by stock number

#before arrange
#   (1)sorting (2)upAMPCeiling (3)upAMPFloor (4)dnAMPCeiling (5)dnAMPFloor (6)durAmp (7)dateStart (8)dateEnd (9)curDate (10)open (11)close (12)hig (13)low (14)srcFile
#after arrange
#   (1)srcFile (2)sorting (3)upAMPCeiling (4)upAMPFloor (5)dnAMPCeiling (6)dnAMPFloor (7)durAmp (8)dateStart (9)dateEnd (10)curDate (11)open (12)close (13)hig (14)low

# do arrange,
#   **OBSOLATED** skip new brone stock,
#   skip the data not included in specified date,
#   ignore "NONE"
#   move code to the head
# sort by curDate
# do demonstration

#print parameter info
echo -ne "#
#PARAMETER_INFO: generated by $(readlink -f $0)
#PARAMETER_INFO: pruneOrgData=$pruneOrgData
#PARAMETER_INFO: countingProfit=$countingProfit
#PARAMETER_INFO: genSyncProfit=$genSyncProfit
#PARAMETER_INFO: start=$start
#PARAMETER_INFO: end=$end
#PARAMETER_INFO: segFile=$segFile
#PARAMETER_INFO: verbose=$verbose
#PARAMETER_INFO: noAbb=$noAbb
#PARAMETER_INFO: keepNoneItem=$keepNoneItem
#PARAMETER_INFO: noSorting=$noSorting
#PARAMETER_INFO: fnCodeFlt=$fnCodeFlt
#PARAMETER_INFO: fnSeedFlt=$fnSeedFlt
#PARAMETER_INFO: seedSerialLvl=$seedSerialLvl
#PARAMETER_INFO: skipNewBorn=$skipNewBorn
#PARAMETER_INFO: taxRatPrt=$taxRatPrt
#PARAMETER_INFO: taxRatHandFee=$taxRatHandFee
#PARAMETER_INFO: orgFunds=$orgFunds
#\n"

#if pruneOrgData
if [[ $pruneOrgData -eq 1 ]]; then
awk -v skipNewBorn=$skipNewBorn     \
    -v startDate=$start             \
    -v endDate=$end                 \
    -v fnCodeFlt="$fnCodeFlt"   \
    -v fnSeedFlt="$fnSeedFlt"   \
    -v seedSerialLvl=$seedSerialLvl \
    -v noAbb=$noAbb                 \
    -v keepNoneItem=$keepNoneItem   \
    '

    # stack for saving serial seed/signal

    function cleanSeedStack()
    {
        seedSerialStackDeep=0 ;
        seedSerialStackIdx = 0 ;
        return ;
    }

    function pushSeedStack(seed)
    {
        seedSerialStack [seedSerialStackIdx] = seed ;
        seedSerialStackIdx ++ ;
        if(seedSerialStackIdx >= seedSerialLvl) seedSerialStackIdx = 0 ;
        if(seedSerialStackDeep < seedSerialLvl) seedSerialStackDeep ++ ;

        return ;
    }

    function getSerialSeed(i,s,ret)
    {
        ret = "" ;

        s = seedSerialStackIdx-seedSerialStackDeep ;    #e+1 == seedSerialStackIdx  #e-s+1 == seedSerialStackDeep ;
        if(s<0) s += seedSerialLvl ;

        for(i=0; i<seedSerialStackDeep; i++){
            ret = ret seedSerialStack[s] ;
            if(i<seedSerialStackDeep-1) ret = ret "_" ;
            s++ ;
            if(s>=seedSerialLvl) s=0 ;
        }

        return ret ;
    }

    BEGIN{
        seedSerialLvl = seedSerialLvl+0 ;
        cleanSeedStack() ;

        #load code filter table
        {
            if(fnCodeFlt) {
                while( (getline <fnCodeFlt) > 0) {
                    if(substr($1,1) == "#") continue;
                    aFilterCode[$1] = 1;
                }
                close(fnCodeFlt);
            }
        }

        #load serial_seed filter table
        {
            if(fnSeedFlt) {
                while( (getline <fnSeedFlt) > 0) {
                    if(substr($1,1) == "#") continue;
                    if(noAbb){
                        aFilterSeed[$1] = 1 ;
                    }else{
                        num = split($1, seeds, "_") ;

                        #use serial_seed filter list to update seed/signal abbrevation table
                        for(j=1; j<=num; j++){
                            seed = seeds[j] ;
                            if(!(seed in seedAbbs)) seedAbbs[seed] = (seedAbbIdx++) ;
                            seeds[j] = seedAbbs[seed] ;
                        }

                        #use seed abbrevation table to create serial_seed filter table
                        seedAbb = "" ;
                        for(j=1; j<=num; j++){
                            seedAbb = seedAbb seeds[j] ;
                            if(j<num) seedAbb = seedAbb "_" ;
                        }
                        aFilterSeed[seedAbb] = 1 ;
                    }
                }
                close(fnSeedFlt);
            }
        }

        $0 = "" ;
    }

    ($1 !~ /#/){
        code = substr($14,13,6) ;
        cnt[code]++ ;
        if(cnt[code] <= skipNewBorn) next ;

        curD = $9;
        if(startDate && curD < startDate) next ;
        if(endDate && curD > endDate) next ;

        fcstStart = $7 ;
        if(!keepNoneItem && fcstStart == "NONE") next ;

        if(fnCodeFlt && (!(code in aFilterCode)) ) next ;

        if(!noAbb && !($1 in seedAbbs)) seedAbbs[$1]=(seedAbbIdx++) ;     # update seed/signal abbrevation table
        if(code != codeLast) cleanSeedStack() ;
        codeLast = code ;
        pushSeedStack((noAbb) ? $1 : seedAbbs[$1]) ;
#       print "*",$1 > "/dev/stderr";
        seed = getSerialSeed() ;
#       print "*",seed > "/dev/stderr" ;
        if(fnSeedFlt && (!(seed in aFilterSeed)) ) next ;
        $1 = "" ;
        $14 = "" ;
        print code,seed,$0 ;
    }

    END{
        if(!noAbb){
            for(i in seedAbbs) print "#seekAbbs",i ,seedAbbs[i] ;
        }
    }

    '   $segFile    |   { [[ $noSorting -eq 1 ]] && cat - || segSort.sh -10; }
fi      | cat -
#endif  /*pruneOrgData*/
doExit 0

#if countingProfit
if [[ $countingProfit -eq 0 ]] ; then
    cat -
else
    awk -v verbose=$verbose                 \
        -v orgFunds=$orgFunds               \
        -v taxRatPrt=$taxRatPrt             \
        -v taxRatHandFee=$taxRatHandFee     \
        '

        function getOrgSeed(seedAbb,
                                            \
                            num, seedAbbList, ret, i)
        {
            num = split(seedAbb, seedAbbList, "_") ;
            for(i=1; i<num; i++){
                ret = ret seedAbbsRvt[seedAbbList[i]] "_" ;
            }
            if(num>0) ret = ret seedAbbsRvt[seedAbbList[num]] ;

            return ret ;
        }

        BEGIN{
            OFMT="%.2f" ;
            stockNum = 0 ;
            orgFunds = orgFunds+0 ;
            taxRatPrt = taxRatPrt+0 ;
            taxRatHandFee = taxRatHandFee+0 ;
        }

        /^#seekAbbs/{
            #load seed/signal abbrevation table
            seedAbbsRvt[$3] = $2 ;
            next ;
        }

        !/#/{
            seed = $2 ;
            ampDur = $7/100 ;
            fcstStart = $8 ;
            fcstEnd = $9 ;
            curD = $10 ;
            code = $1 ;
            clsP = $12 ;
            cntCode[code]++ ;
            cntSeed[seed]++ ;

            #@ counting profit by each seed/signal
            if(!(seed in profit_signals)){
                profit_signals[seed] = 0;
                lose_signals[seed] = 0;
            }else{
                if(curD < aEnd[seed]){
                    if(verbose) print "#",curD,code,getOrgSeed(seed),"IGNR("ampDur*100"%) in processing [" aCur[seed] "~" aEnd[seed] ") \t@",$0 ;
                }
                else {
                    dealCnt_seed[seed] ++;
                }
            }

            #@ counting profit by each code
            #@ prepare base_funds * (forecast_dur+1) to ensure we have money to bug the this code every day
            #@ FIXME, cur dur is hardcode to 3
            if(!(code in profit_codes)) {
                profit_codes[code] = orgFunds * 4;
                lose_codes[code] = 0;
            }
            else {
            }
            dealCnt_code[code]++;


            aCur[seed] = curD ;          code_cur[code] = curD;
            aStart[seed] = fcstStart ;  start_code[code] = fcstStart;
            aEnd[seed] = fcstEnd ;      end_code[code] = fcstEnd;
            if(verbose) print "#",curD,code,getOrgSeed(seed),"DEAL("ampDur*100"%), [" aCur[seed] "~" aEnd[seed] "), \t@",$0 ;

            #stockNum = int(profit_signals[seed]/((1+taxRatHandFee)*clsP)) ;
            stockNum = int(20000/((1+taxRatHandFee)*clsP)) ;
            profit_signals[seed] -= (stockNum*clsP)*(1+taxRatHandFee) ;
            profit_signals[seed] = int(profit_signals[seed]*100)/100.0 ;              # the smallest unit is 1 Fen.
            if(verbose) print "#",curD,code,getOrgSeed(seed),"BOUT("ampDur*100"%)",stockNum,"*",clsP,"and profit_signals left",profit_signals[seed] ;

            profit_signals[seed] += (stockNum*clsP)*(1+ampDur)*(1-taxRatHandFee-taxRatPrt) ;
            profit_signals[seed] = int(profit_signals[seed]*100)/100.0 ;              # the smallest unit is 1 Fen.
            if(verbose) print "#",curD,code,getOrgSeed(seed),"SOLD("ampDur*100"%)",stockNum,"with up rates",ampDur*100"% and profit_signals left",profit_signals[seed] ;

            stockNum = int(20000/((1+taxRatHandFee)*clsP)) ;
            profit_codes[code] -= (stockNum*clsP)*(1+taxRatHandFee) ;
            profit_codes[code] = int(profit_codes[code]*100)/100.0 ;              # the smallest unit is 1 Fen.
            if(verbose) print "##",curD,code,getOrgSeed(seed),"BOUT("ampDur*100"%)",stockNum,"*",clsP,"and profit_codes left",profit_codes[code] ;

            profit_codes[code] += (stockNum*clsP)*(1+ampDur)*(1-taxRatHandFee-taxRatPrt) ;
            profit_codes[code] = int(profit_codes[code]*100)/100.0 ;              # the smallest unit is 1 Fen.
            if(verbose) print "##",curD,code,getOrgSeed(seed),"SOLD("ampDur*100"%)",stockNum,"with up rates",ampDur*100"% and profit_codes left",profit_codes[code] ;


            #if(profit_signals[seed]+0 < 20000) lose_signals[seed]++ ;
            if(ampDur<=0) {
                lose_signals[seed]++ ;
                lose_codes[code]++ ;
            }
        }

        END{
            print "#seri_seeds    funds    n_effect_/_n_total   n_lose    hitrate_effect_*_hitrate_total"
            for(i in profit_signals){
                rate = 1-lose_signals[i]/dealCnt_seed[i];
                mult_eff_up = dealCnt_seed[i] * (dealCnt_seed[i]-lose_signals[i]) / 8192;
                printf ("%s %.2f %d/%d %s %d,%.2f\n",
                        getOrgSeed(i), profit_signals[i], dealCnt_seed[i], cntSeed[i],
                        ((lose_signals[i]==0) ? "NeverLose" : lose_signals[i]),
                        mult_eff_up, rate);
            }
            for(i in profit_codes) {
                rate = 1-lose_codes[i]/dealCnt_code[i];
                mult_eff_up = dealCnt_code[i] * (dealCnt_code[i]-lose_codes[i]) / 8192;
                printf ("%s %.2f %d/%d %s %d,%.2f\n",
                        i, profit_codes[i], dealCnt_code[i], cntCode[i],
                        ((lose_codes[i]==0) ? "NeverLose" : lose_codes[i]),
                        mult_eff_up, rate);
            }
        }

        '
fi          |
#endif  /*countingProfit*/

#if genSyncProfit
if [[ $genSyncProfit -eq 0 ]] ; then
    cat -
else
    awk     \
        '

        BEGIN{
            cntDate = 0 ;
            cntSeed = 0 ;
            fundsInit = 20000 ;
            #listDate[date]=(cntDate++) ;
            #listSeed[seed]=(cntSeed++) ;
            #funds[listSeed[seedIdx],listDate[dateIdx]]=... ;
        }

        /SOLD/{

            # SOLD entries arranged by date

            date = $2 ;
            seed = $4 ;

            if(!(date in listDate)){
                listDate[date] = cntDate ;
                aDate[cntDate] = substr(date,3,2) substr(date,6,2) substr(date,9,2) ;
                cntDate++ ;
            }

            if(!(seed in listSeed)){
                listSeed[seed] = cntSeed ;
                aSeed[cntSeed] = seed ;
                cntSeed++ ;
            }

            funds[listSeed[seed],listDate[date]] = $NF ;
        }

        END{
            print "cntSeed=" cntSeed, "cntDate=" cntDate;
            # print map info: seed line-number seg-number,  line-1 is the date
            for(idxSeed=0; idxSeed<cntSeed; idxSeed++){
                print "#", aSeed[idxSeed], "line-" idxSeed+2, "seg-" idxSeed+2 ;
            }
print 1;

            # fill init funds
            for(seedIdx=0; seedIdx<cntSeed; seedIdx++){
                if(!(seedIdx SUBSEP 0 in funds)) funds[seedIdx,0] = fundsInit ;
            }
print 2;

            # fill whole funds table
            for(idxDate=0; idxDate<cntDate; idxDate++){
                for(idxSeed=0; idxSeed<cntSeed; idxSeed++){
                    if(!(idxSeed SUBSEP idxDate in funds)) funds[idxSeed,idxDate] = funds[idxSeed,idxDate-1] ;
                }
            }
print 3;

            # print funds table
            for(idxDate=0; idxDate<cntDate; idxDate++){
                printf aDate[idxDate] " ";
                for(idxSeed=0; idxSeed<cntSeed; idxSeed++){
                    printf("%9.2f ",funds[idxSeed,idxDate]) ;
                }
                print "" ;
            }
            print "*seg=" cntSeed+1, "rec=" cntDate > "/dev/stderr" ;   # information for drawLine.sh
        }

        '
fi
#endif /*genSyncProfit*/



doExit 0





#grep 300017 $segFile |
#
#awk '
#    function fClean()
#    {
#        delete cnt ;
#        delete funds ;
#        delete dirs ;
#        return 0 ;
#    }
#
#    function fPrt(      \
#                        \
#        i)
#    {
#        for(i in cnt){
#            print funds[i], dirs[i]/cnt[i], dirs[i], cnt[i], codeLast, i ;
#        }
#        return 0 ;
#    }
#
#    BEGIN{
#        OFMT="%.2f" ;
#        fundsOrg = 1 ;  #original funds
#        codeLast = "" ;
#        codeCur = "" ;
#    }
#
#    !/#/{
#        seedCur = seedLast $1 ;
#        #seedLast = $1 ;
#        codeCur = substr($NF, 13, 6) ;
#        durAmp = $6+0 ;
#
#        if(codeCur != codeLast){
#            fPrt() ;
#            fClean() ;
#            codeLast = codeCur ;
#        }
#
#        cnt[seedCur] ++ ;
#        if(!(seedCur in funds)) funds[seedCur] = fundsOrg ;
#        funds[seedCur] = funds[seedCur] * (100+durAmp) / 100 ;
#        dirs[seedCur] = (durAmp > 0) ? dirs[seedCur]+1 : dirs[seedCur]-1 ;
#    }
#
#    END{
#        fPrt() ;
#    }
#
#    '
#
#doExit
#
#
#
