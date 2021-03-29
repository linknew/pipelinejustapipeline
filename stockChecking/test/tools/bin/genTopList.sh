#! /bin/bash

stockList=stock.list.valid
#aged=stock.list.ageGE3Year
#ampped=stock.list.ageGE3Year.ampGE2.0with22.36Percent
#xchged=stock.list.ageGE3Year.ampGE2.0with22.36Percent.xchgGE1.2with60Percent

agedOrg=.t.aged.org
aged=.t.aged
ampped=.t.ampped
xchged=.t.xchged
zhenfu=.t.zhenfu
daysDef=-792
#shiftDef=-132
shiftDef=0
#daysDef=-132
toplist=.t.toplist.$(date "+%Y-%m-%d").shift$shiftDef


#1. find out stock which age great than 3-year
echo "generate stock_ist which great than 3_year ..."
cp $agedOrg{,.bak} 2>/dev/null
./_generateStockList2.sh  --age=1320 --days=792 --match=1 --checkingConditions='1' $stockList |tee $agedOrg
echo "save the result to $agedOrg"

#1.1. sort $aged according stockType(first 4 digital, such as 1300)
echo "sortting by liveValue, the first 1/3 will be alive"
cp $aged{,.bak} 2>/dev/null
awk '
    {
        code=$1 ;
        class=substr($1,1,4) ;
        cnt[class]++ ;
        lval=substr($NF,6) ;
        dim[class,cnt[class]]=lval" "code ;
    }
    END{
        sortCmd="sort -rn" ;

        for(i in cnt){
            print "#class="i,"cnt="cnt[i] ;

            for(j=1; j<=cnt[i]; j++){
                print dim[i,j] | sortCmd ;
            }
            close(sortCmd);
        }
    }
    ' $agedOrg |
awk '
    {
        if($0~"#"){
            cnt = substr($2,5) ;
            idx = 0 ;
        }else{
            if(idx < cnt/3) print $2,"lval="$1 ;
            idx++ ;
        }
    }
    ' |
tee $aged
echo "save the result to $aged"
    
#exit

#2. find out the first 1/3 highAMP stocks
echo "genertae stock_list, use the first 1/3 highAMPs ..."
cp $ampped{,.bak} 2>/dev/null
./analizeAmpStatus.sh --days=$daysDef --shift=$shiftDef --seed='$4' --ge=2 --le=100 --gap=0.3 $aged |
awk '
    !/#/{
        print $2,$1,$3
    }
    ' |
sort -n | nl | tail -r |
awk '
    (NR == 1){
        totalRec = $1 ;
    }
    (NR < totalRec/3){
        print $3,$2,$4
    }
    ' |
tee $ampped
echo "save the result to $ampped"

#3.1. find out the first 1/3 higExchange stocks
echo "generate stock_list, use the first 1/3 highExchanges..."
cp $xchged{,.bak} 2>/dev/null
./analizeAmpStatus.sh --days=$daysDef --shift=$shiftDef --seed='$14' --ge=1.2 --le=100  --gap=0.3 $aged |
awk '
    !/#/{
        print $2,$1,$3
    }
    ' |
sort -n | nl | tail -r |
awk '
    (NR == 1){
        totalRec = $1 ;
    }
    (NR < totalRec/3){
        print $3,$2,$4
    }
    ' |
tee $xchged
echo "save the result to $xchged"

#3.2. find out the first 1/3 highZhenFu!! stocks
echo "generate stock_list, use the first 1/3 highZhenFu!!..."
cp $zhenfu{,.bak} 2>/dev/null
./analizeAmpStatus.sh --days=$daysDef --shift=$shiftDef --ge=4 --le=100 --gap=0.3 $aged | 
awk '
    !/#/{
        print $2,$1,$3
    }
    ' |
sort -n | nl | tail -r |
awk '
    (NR == 1){
        totalRec = $1 ;
    }
    (NR < totalRec/3){
        print $3,$2,$4
    }
    ' |
tee $zhenfu
echo "save the result to $zhenfu"


#4. generate top list by xchged*ampped*zhenfu
awk '
    BEGIN{
        while(getline < ("'$xchged'")){
            a[$1] = $2 ;
        }
        close("'$xchged'") ;

        while(getline < ("'$ampped'")){
            b[$1] =$2 ;
        }
        close("'$ampped'") ;

        while(getline < ("'$zhenfu'")){
            c[$1] = $2 ;
        }
        close("'$zhenfu'") ;

        for(i in a){
            printf("%.2f %.2f %.2f %.2f %s\n", b[i]*a[i]*c[i], b[i], a[i], c[i], i) | "sort -nr"
        }
    }
    '   | 
awk '{ print $5,$2"(amp)",$3"(xchg)",$4"(zhenfu)","in 792 samples"; }' |
tee $toplist
echo "save the result to $toplist"

exit




