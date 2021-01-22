#! /bin/bash


echo yes
echo 1>&2 no
echo 1>&4 output to 4
read x 0<&19
echo $'read from .3(<19)': $x

exit 

WKD=$(dirname $0)   #working directory
BKD=$(pwd)          #back directory
cd $WKD

. comm.lib

durDef=3





doStart
doExit

for i in "${@}"
do
    [[ ${i} == "--help" ]] && Help && doExit 0 "$oprtB4Exit"
    [[ ${i%%=*} == "--dur" ]] && dur=${i##*=} && continue
    [[ ${i%%=*} == "--adjust4UpHit" ]] && adjust4UpHit=${i##*=} && continue
    [[ ${i:0:1} == "-" ]] && echo "*! Unknown option:$i">&2 && doExit -1 "$oprtB4Exit"
    [[ -n $list ]] && echo "*! Multipule list specified">&2 && doExit -1 "$oprtB4Exit"
    list=$i
done

[[ -n $list && ! -f $list ]] && echo "*! Cannot find or open [$list]">&2 && doExit -1 "$oprtB4Exit"
codes=$( awk '($1 !~ "#"){print $1}' $list )
dur=${dur:-$durDef}
segData=.t$dur.segData
cntgData=.t$dur.counting
adjust4UpHit=${adjust4UpHit:-0}

[[ ! -f $segData ]] && echo "*! Cannot find or open $segData">&2 && doExit -1
[[ ! -f $cntgData ]] && echo "*! Cannot find or open $cntgData">&2 && doExit -1


#awk                                 \
#    -v codes="$(echo $codes)"       \
#    -v segData="$segData"           \
#    -v adjust4UpHit=$adjust4UpHit   \
#    '
#    BEGIN{
#        codeNum = split(codes,codeA," ") ;
#    }
#
#    ($1 !~ "#"){
#        seed[$NF] = $0 ;
#    }
#
#    END{
#        for(i=1; i<=codeNum; i++){
#            grepCmd = "grep " codeA[i] " " segData ;
#            cntUp["H"] = 0 ;
#            cntUp["M"] = 0 ;
#            cntDn["H"] = 0 ;
#            cntDn["M"] = 0 ;
#            cntCls["H"] = 0 ;
#            cntCls["M"] = 0 ;
#
#            while( grepCmd | getline){
#                $0 = $0 " | " seed[$1] " @" codeA[i] ;
#                gsub(/= +/,"=") ;
#                gsub(/\( +/,"(") ;
#                gsub(/ +\)/,")") ;
#                $0 = $1 " " $2 " " $5 " " $6 " | " $11 " " $13 " " $16 " " $17 " " $NF ;
#                gsub(/AP\/AN=/,"") ;
#                gsub(/DN=.*\(/,"") ;
#                gsub(/UP=.*\(|\)/,"") ;
#                #   1                           2       3       4       5   6       7       8       9       10
#                #[1k<5k<22k<66k<132k<264k]-4    7.92%   0.00%   6.99%   |   04968   3.74%   -4.31%  0.87    @300017
#                f[1] = ($2+adjust4UpHit>=$7+0) ? "H" : "M" ;
#                f[2] = ($3+0<=$8+0) ? "H" : "M" ;
#                f[3] = ($4+0>=0 && $9+0>=1) || ($4+0<0 && $9+0<1) ? "H" : "M" ;
#                print f[1] f[2] f[3],$0 ;
#                cntUp[f[1]] ++ ;
#                cntDn[f[2]] ++ ;
#                cntCls[f[3]] ++ ;
#            }
#            close(grepCmd) ;
#            cnt["H"] = cntUp["H"]+cntDn["H"]+cntCls["H"] ;
#            cnt["M"] = cntUp["M"]+cntDn["M"]+cntCls["M"] ;
#            printf("*%6s\t%7s(%8s %8s) \t%7s(%8s %8s) \t%7s(%8s %8s) \t%9s(%8s %9s)   \
#                  \n*%6s\t%7.2f(%8d %8d) \t%7.2f(%8d %8d) \t%7.2f(%8d %8d) \t%9.2f(%8d %9d)\n",
#                    codeA[i], "H/T","Hit","Total","UPH/UPT","UPHit","UPTotal","DNH/DNT","DNHit","DNTotal","CLSH/CLST","CLSNHit","CLSNTotal",
#                    codeA[i],cnt["H"]/(cnt["H"]+cnt["M"]),cnt["H"],cnt["H"]+cnt["M"],
#                    cntUp["H"]/(cntUp["H"]+cntUp["M"]),cntUp["H"],cntUp["H"]+cntUp["M"],
#                    cntDn["H"]/(cntDn["H"]+cntDn["M"]),cntDn["H"],cntDn["H"]+cntDn["M"],
#                    cntCls["H"]/(cntCls["H"]+cntCls["M"]),cntCls["H"],cntCls["H"]+cntCls["M"])  > "/dev/stderr" ;
#
#        }
#    }
#
#    ' $cntgData
#
#doExit

code=300017

#1. scan in counting file, find out seeds whose Up positive value is great than adjust4UpHit
contFromCountingData=$(
    awk                             \
    -v adjust4UpHit=$adjust4UpHit   \
    '
    !/#/{
        cont = $0 ;
        sub(/.*UP=[^(]*\( */, "") ;
        if($1+0>adjust4UpHit) print substr($NF,2)" @", cont ;
    }
    ' $cntgData
)
seedsFromCountingData=$(echo "$contFromCountingData" | sed 's/@.*//')
echo "$seedsFromCountingData" > .t
echo "$contFromCountingData" > .t1

#2. use these seeds, filter the items which up positive value is less equal to 0 in specified stock segment data
contFromSegmentData=$(grep $code $segData | grep "$seedsFromCountingData")
seedsIgnore=$(echo "$contFromSegmentData" | awk '($2+0<=0){print substr($1,2)" " ;}' | sort -u)
seedsFromSegmentData=$(echo "$contFromSegmentData" | sed 's/\[//; s/ .*/ /;' | grep -v "$seedsIgnore" | sort -u)
echo "$seedsFromSegmentData" > .t2
echo "$contFromSegmentData" > .t3

#3. used these seeds to find out the items in counint datas
echo "$contFromCountingData" | grep "$seedsFromSegmentData" |  sed 's/.*@ *//' | tee .t4
doExit

