#! /bin/bash

# counting the result of each seed

. comm.lib

doStart


seedSerialLvlDef=1 ;
skipNewBornDef=60 ;
taxRatPrtDef=0.001 ;
taxRatHandFeeDef=0.00035 ;
fnCodeFltDef=.t.filter.code
fnSeedFltDef=.t.filter.seed

verbose=0 ;
orgFunds=20000 ;

function Help
{
    echo -ne "
    Usage: ${0} [--serialLvl=N | -N] [--skipNewBorn=N] [--start=YY-MM-DD] [--end=YY-MM-DD] [--taxRatPrt=F] [--taxRatHandFee=F] [--verbose] [--fltCode=S] [--fltSeed=S] [--help] segFile

        --serialLvl, serial level of seed
        --skipNewBorn, skip number of new datas
        --verbose, print details of transaction
        --taxRatPrt, rate of print_fllower, is a float with unit %
        --taxRatHandFee, rate of handing fee, is a float with unit %
        --fltCode, specifiy a file for code_filter
        --fltSeed, specifiy a file for seed_filter
        --start
        --end
        --help

    Note:
        -

    Default:
        --serialLvl=$seedSerialLvlDef --skipNewBorn=$skipNewBornDef --taxRatPrt=$taxRatPrtDef --taxRatHandFee=$taxRatHandFeeDef --fltCode=$fnCodeFltDef --fltSeed=$fnSeedFltDef
\n"
}

for i in "${@}"
do
    [[ ${i} == "--help" ]] && Help && doExit 0
    [[ ${i%%=*} == "--serialLvl" ]] && seedSerialLvl=${i##*=} && continue
    [[ ${i%%=*} == "--skipNewBorn" ]] && skipNewBorn=${i##*=} && continue
    [[ ${i%%=*} == "--taxRatPrt" ]] && taxRatPrt=${i##*=} && continue
    [[ ${i%%=*} == "--taxRatHandFee" ]] && taxRatHandFee=${i##*=} && continue
    [[ ${i%%=*} == "--verbose" ]] && verbose=1 && continue
    [[ ${i%%=*} == "--fltCode" ]] && fnCodeFlt=${i##*=} && continue
    [[ ${i%%=*} == "--fltSeed" ]] && fnSeedFlt=${i##*=} && continue
    [[ ${i%%=*} == "--start" ]] &&  start=${i#*=} && continue ;
    [[ ${i%%=*} == "--end" ]] && end=${i#*=} && continue ;
    [[ ${i:0:2} == "--" ]] && echo "*! Unknown option:$i">&2 && doExit -1
    [[ ${i:0:1} == "-" && (${i:1:1} > "0" && ${i:1:1} < ":") ]] && seedSerialLvl=${i:1} && continue     # < ':' means <='9'
    [[ ${i:0:1} == "-" ]] && echo "*! Unknown option:$i">&2 && doExit -1
    [[ -n $segFile ]] && echo "*! Multipule segFile specified">&2 && doExit -1
    segFile=$i
done

taxRatPrt=${taxRatPrt:-$taxRatPrtDef}
fnCodeFlt=${fnCodeFlt:-$fnCodeFltDef}
fnSeedFlt=${fnSeedFlt:-$fnSeedFltDef}
skipNewBorn=${skipNewBorn:-$skipNewBornDef}
taxRatHandFee=${taxRatHandFee:-$taxRatHandFeeDef}
seedSerialLvl=${seedSerialLvl:-$seedSerialLvlDef}

listFltCode=$( echo $( awk '($1 !~ /^#/){ print $1; }' $fnCodeFlt) )
listFltSeed=$( echo $( awk '($1 !~ /^#/){ print $1; }' $fnSeedFlt) )

# in $segFile, the data list by stocks, but we want:
#   * the data sorting by date
# if the dates are same, we want:
#   * list these data by stock number

#before arrange
#   (1)sorting (2)upAMPCeiling (3)upAMPFloor (4)dnAMPCeiling (5)dnAMPFloor (6)durAmp (7)dateStart (8)dateEnd (9)curDate (10)open (11)close (12)hig (13)low (14)srcFile
#after arrange
#   (1)srcFile (2)sorting (3)upAMPCeiling (4)upAMPFloor (5)dnAMPCeiling (6)dnAMPFloor (7)durAmp (8)dateStart (9)dateEnd (10)curDate (11)open (12)close (13)hig (14)low

# do arrange,
#   skip new brone stock,
#   skip the data not included in specified date,
#   ignore "NONE"
#   move code to the head
# sort by curDate
# do demonstration


awk -v skipNewBorn=$skipNewBorn     \
    -v startDate=$start             \
    -v endDate=$end                 \
    -v listFltCode="$listFltCode"   \
    -v listFltSeed="$listFltSeed"   \
    -v seedSerialLvl=$seedSerialLvl \
    '

    # stack for saving serial seed

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
            $0 = listFltCode ;
            filterNumCode = NF ;
            for(i=1; i<=filterNumCode; i++) aFilterCode[$i] = 1 ;
        }

        #load serial_seed filter table
        {
            $0 = listFltSeed ;
            filterNumSeed = NF ;

            for(i=1; i<=filterNumSeed; i++){
                num = split($i, aTmpArry, "_") ;

                #use serial_seed filter list to update seed abbrevation table
                for(j=1; j<=num; j++){
                    seed = aTmpArry[j] ;
                    if(!(seed in seedAbbs)) seedAbbs[seed] = (seedAbbIdx++) ;
                    aTmpArry[j] = seedAbbs[seed] ;
                }

                #use seed abbrevation table to create serial_seed filter table
                seedAbb = "" ;
                for(j=1; j<=num; j++){
                    seedAbb = seedAbb aTmpArry[j] ;
                    if(j<num) seedAbb = seedAbb "_" ;
                }
                aFilterSeedAbb[seedAbb] = 1 ;
            }
        }

        $0 = "" ;
    }

    !($1~/#/){
        if(!($1 in seedAbbs)) seedAbbs[$1]=(seedAbbIdx++) ;     # update seed abbrevation table
        code = substr($14,13,6) ;
        if(code != codeLast) cleanSeedStack() ;
        codeLast = code ;
        pushSeedStack(seedAbbs[$1]) ;
        #print "*",$1 > "dev/stderr";
        seed = getSerialSeed() ;
        #print "*",seed > "/dev/stderr" ;

        fcstStart = $7 ;
        fcstEnd = $8 ;
        cur = $9 ;
        cnt[code]++ ;

        if(filterNumCode && (!(code in aFilterCode)) ) next ;
        if(filterNumSeed && (!(seed in aFilterSeedAbb)) ) next ;
        if(cnt[code] <= skipNewBorn) next ;
        if(startDate && cur < startDate) next ;
        if(endDate && cur > endDate) next ;
        if(fcstStart == "NONE") next ;

        $1 = "" ;
        $14 = "" ;
        print code,seed,$0 ;
    }

    END{
        #print seed abbrevation table, Processing into a shape that easily for segSort.sh
        for(i in seedAbbs) print "#seekAbbs",i ,seedAbbs[i],0 ,0 ,0 ,0 ,0 ,0 ,0 ;
    }

    '   $segFile        |   
#cat - ; doExit ;
    segSort.sh -10      |

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
            #load seed abbrevation table
            seedAbbsRvt[$3] = $2 ;
            next ;
        }

        !/#/{
            seed = $2 ;
            ampDur = $7/100 ;
            fcstStart = $8 ;
            fcstEnd = $9 ;
            cur = $10 ;
            code = $1 ;
            clsP = $12 ;
            cntCode[code]++ ;
            cntSeed[seed]++ ;

            if(seed in aFunds){
                if(cur < aEnd[seed]){
                    if(verbose) print "#",cur,getOrgSeed(seed),"IGNORE, in processing [" aCur[seed] "~" aEnd[seed] ") \t@",$0 ;
                    next ;
                }
            }else{
                aFunds[seed] = orgFunds ;
            }

            cntSeedDeal[seed] ++ ;
            aCur[seed] = cur ;
            aStart[seed] = fcstStart ;
            aEnd[seed] = fcstEnd ;
            if(verbose) print "#",cur,getOrgSeed(seed),"DEAL, [" aCur[seed] "~" aEnd[seed] "), \t@",$0 ;

            stockNum = int(aFunds[seed]/((1+taxRatHandFee)*clsP)) ;
            aFunds[seed] -= (stockNum*clsP)*(1+taxRatHandFee) ;
            aFunds[seed] = int(aFunds[seed]*100)/100.0 ;              # the smallest unit is 1 Fen.
            if(verbose) print "#",cur,getOrgSeed(seed),"BOUGHT",stockNum,"*",clsP,"and funds left",aFunds[seed] ;

            aFunds[seed] += (stockNum*clsP)*(1+ampDur)*(1-taxRatHandFee-taxRatPrt) ;
            aFunds[seed] = int(aFunds[seed]*100)/100.0 ;              # the smallest unit is 1 Fen.
            if(verbose) print "#",cur,getOrgSeed(seed),"SOLD",stockNum,"with up rates",ampDur*100"% and funds left",aFunds[seed] ;
        }

        END{
            for(i in aFunds){
                print aFunds[i],getOrgSeed(i),cntSeedDeal[i] "/" cntSeed[i] ;
            }
        }

        '   |   cat - ; doExit 0

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
            seed = $3 ;

            if(!(date in listDate)){
                listDate[date] = cntDate ;
                cntDate++ ;
            }

            if(!(seed in listSeed)){
                listSeed[seed] = cntSeed ;
                cntSeed++ ;
            }

            funds[listSeed[seed],listDate[date]] = $NF ;
        }

        END{
            for(seedIdx=0; seedIdx<cntSeed; seedIdx++){
                if(!(seedIdx SUBSEP 0 in funds)) funds[seedIdx,0] = fundsInit ;
            }

            for(idxDate=0; idxDate<cntDate; idxDate++){
                for(idxSeed=0; idxSeed<cntSeed; idxSeed++){
                    if(!(idxSeed SUBSEP idxDate in funds)) funds[idxSeed,idxDate] = funds[idxSeed,idxDate-1] ;
                    printf("%9.2f ",funds[idxSeed,idxDate]) ;
                }
                print "" ;
            }
        }

        '

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
