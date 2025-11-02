#! /bin/bash

# 停牌计为lose

source $(dirname $(readlink -f $0))/../lib/comm.lib

verbose=$1
taxRatPrt=$2
taxRatHandFee=$3
start=$4
end=$5
segDate=$6
fnCodeLst=$7
fnSeedLst=$8

awk -v verbose=$verbose                 \
    -v taxRatPrt=$taxRatPrt             \
    -v taxRatHandFee=$taxRatHandFee     \
    -v start=$start \
    -v end=$end     \
    -v segDate=$segDate \
    -v fnCodeLst="$fnCodeLst"   \
    -v fnSeedLst="$fnSeedLst"   \
    '

    function getOrgSeed(seedAbb,
                                        \
                        num, seedAbbList, ret, i)
    {
        if(seedAbbsRvt["size"]==0) {
            return seedAbb;
        }

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
        taxRatPrt = taxRatPrt+0 ;
        taxRatHandFee = taxRatHandFee+0 ;
        seedAbbsRvt["size"] = 0;
        codeLst["size"] = 0;
        seedLst["size"] = 0;
    }

    (FILENAME==fnCodeLst) {
        if($1 ~ "#") next;
        if(!$0) next;
        codeLst[$1] = 1;
        codeLst["size"] ++;
    }

    (FILENAME==fnSeedLst) {
        if($1 ~ "#") next;
        if(!$0) next;
        seedLst[$1] = 1;
        seedLst["size"] ++;
    }

    /^#seekAbbs/{
        #load seed/signal abbrevation table
        seedAbbsRvt[$3] = $2 ;
        seedAbbsRvt["size"] ++;
        next ;
    }

    !/#/{
        fcstStart = $7 ;
        fcstEnd = $8 ;
        curD = $9 ;
        if(curD < start) next;
        if(curD > end) next;
        if(fcstStart == "NONE") next;

        seed = $1 ;
        if(seedLst["size"]!=0 && !(seed in seedLst)) next;

        code = substr($14,13,6) ;
        if(codeLst["size"] && !(code in codeLst)) next;

        ampDur = $6+0;
#       clsPrice = $11+0 ;
        cnt_seed[seed]++ ;
        cnt_code[code]++ ;

        earn = 20000*ampDur/100;
        tax1 = 20000*taxRatHandFee;
        tax2 = (20000+earn)*(taxRatPrt+taxRatHandFee);
        profit_ = earn - tax1 - tax2;
        lose_ = (profit_<=0)? 1 : 0;
        
        profit_seeds[seed] += profit_;
        lose_seeds[seed] += lose_;

        profit_codes[code] += profit_;
        lose_codes[code] += lose_;

        if(verbose) {
#           printf("#%s earn:%.2f @%s~%s, tax:%.f, total_profit:%.2f\n",
#                   seed, earn, fcstStart, fcstEnd, tax1+tax2, profit_seeds[seed]);
#           printf("#%s earn:%.2f @%s~%s, tax:%.f, total_profit:%.2f\n",
#                   code, earn, fcstStart, fcstEnd, tax1+tax2, profit_codes[code]);
        }
    }

    END{
#       print "#seed/code  profit  cnt  lose  hit_rate"
        for(i in profit_seeds){
            rate = 1.0-lose_seeds[i]/cnt_seed[i];
            printf ("%s %.2f %d %s %.2f\n",
                    getOrgSeed(i), profit_seeds[i], cnt_seed[i],
                    ((lose_seeds[i]==0) ? "NeverLose" : lose_seeds[i]), rate);
        }
        for(i in profit_codes) {
            rate = 1-lose_codes[i]/cnt_code[i];
            printf ("%s %.2f %d %s %.2f\n",
                    i, profit_codes[i], cnt_code[i],
                    ((lose_codes[i]==0) ? "NeverLose" : lose_codes[i]), rate);
        }
    }

    '  $fnSeedLst  $fnCodeLst  $segDate

