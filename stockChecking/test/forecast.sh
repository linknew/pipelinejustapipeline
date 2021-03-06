#! /bin/bash

WKD=$(dirname $0)   #working directory
BKD=$(pwd)          #back directory
cd $WKD

. comm.lib

function Help
{
    echo -ne "
    Usage: ${0} [--dur=N] [--start=YY-MM-DD] [--end=YY-MM-DD] [--build] [--genRaw] [--genSegment] [--genCounting] [--doForecast=N] [--help] list

        --dur, duration for segment data
        --start, limited the range when generate segment
        --end, limited the range when generate segment
        --genRaw, generate raw data
        --genSegment, generate segment data from raw data
        --genCounting, gencounting data from segment data
        --build, is the abbrevation of --genRaw --genSegment --genCounting
        --doForecast, make forecasting
        --help

    Note:
        If only one codeNum in the list file, make the output filename according the codeNum.

    Default: --dur=$durDef --doForecast=$doForecastDef
\n"
}

doForecastDef=1
durDef=3
genRawDef=0
genSegmentDef=0
genCountingDef=0
oprtB4Exit="cd $BKD"

echo -ne "\n*executing $0($$)\n" >&2

for i in "${@}"
do
    [[ ${i} == "--help" ]] && Help && doExit 0 "$oprtB4Exit"
    [[ ${i%%=*} == "--dur" ]] && dur=${i##*=} && continue
    [[ ${i%%=*} == "--doForecast" ]] && doForecast=${i##*=} && continue
    [[ ${i} == "--genRaw" ]] && genRaw=1 && continue
    [[ ${i} == "--genSegment" ]] && genSegment=1 && continue
    [[ ${i} == "--genCounting" ]] && genCounting=1 && continue
    [[ ${i%%=*} == "--start" ]] &&  start=${i#*=} && continue ;
    [[ ${i%%=*} == "--end" ]] && end=${i#*=} && continue ;
    [[ ${i} == "--build" ]] && genRaw=1 && genSegment=1 && genCounting=1 && continue
    [[ ${i:0:1} == "-" ]] && echo "*! Unknown option:$i">&2 && doExit -1 "$oprtB4Exit"
    [[ -n $list ]] && echo "*! Multipule list specified">&2 && doExit -1 "$oprtB4Exit"
    list=$i
done

[[ -n $list && ! -f $list ]] && echo "*! Cannot find or open [$list]">&2 && doExit -1 "$oprtB4Exit"
codes=$( awk '($1 !~ "#"){print $1}' $list )
codeNum=$(echo "$codes" | wc -w)
[[ $codeNum -le 0 ]] && echo "*! No processed item, terminal the program">&2 && doExit 0 "$oprtB4Exit"
[[ $codeNum -eq 1 ]] && postFilename=$postFilename.$codes
dur=${dur:-$durDef}
doForecast=${doForecast:-$doForecastDef}
genRaw=${genRaw:-$genRawDef}
genSegment=${genSegment:-$genSegmentDef}
genCounting=${genCounting:-$genCountingDef}
segData=.t$dur.segData
cntgData=.t$dur.counting
forecastData=.t$dur.forecast$postFilename${start:+.from.$start}${end:+.to.$end}

echo     *dur="$dur" >&2
echo     *start="$start" >&2
echo     *end="$end" >&2
echo     *genRaw="$genRaw"  >&2
echo     *genSegment="$genSegment"   >&2
echo     *genCounting="$genCounting" >&2
echo     *doForecast="$doForecast"   >&2

#generate rawData and segment data
#if 1
if [[ $genSegment -eq 1 ]] ; then
    rm -rf $segData 
    [[ $? -ne 0 ]] && echo *! Cannot remove $segData >&2 && doExit -1 "$oprtB4Exit"
fi

for i in $codes
do
    [[ $genRaw -eq 1 ]] && ./1_genKLineSortingRawData.sh $i > sorting-raw/$i.raw
    [[ $genSegment -eq 1 ]] && ./2_genSegmentUpDnRate.sh --dur=$dur --offset=1 --disSrc $i >> "$segData" && echo *Append $i\'s data to "$segData" >&2
    [[ $genRaw -eq 1 || $genSegment -eq 1 ]] && echo "----"
done
#endif

#generate counting data
#if 1
if [[ $genCounting -eq 1 ]]; then
    echo "*NOTE, only the item which in the code list will be procceed in counting" >&2

    echo $codes     | 
        awk ${start:+ -v start=$start}  \
            ${end:+ -v end=$end}        \
            '
            '"$awkFunction_split2"'

            {
                if("'"$segData"'" == FILENAME){
                    #                          1       2       3       4       5       6          7          8          9                     10
                    #[264k<66k<132k<22k<5k<1k]-3   1.94%  -8.48%  -6.65% -12.39% -10.22% 2020-07-15 2020-07-17 2020-07-17 sorting-raw/603799.raw

                    if(start && $9<start) next ;
                    if(end && $9>end) next ;
                    if($1 ~ "#") next ;
                    if($8 ~ "NONE") next ;

                    if($10 in files) print ;

                }else if("-" == FILENAME){
                    codeNum = split2($0,a," ") ;
                    for(i=0; i<codeNum; i++) files["sorting-raw/" a[i] ".raw"] = 1 ;
                }
            }
            ' - $segData    |
        ./3_countingSegMentData.sh > "$cntgData"

    echo *Save counting data to "$cntgData" >&2
fi
#endif


[[ $doForecast -eq 0 ]] && doExit 0 "$oprtB4Exit"

#generate seed-code-date info
#if 1
echo $codes | 
awk ${start:+ -v start=$start}  \
    ${end:+ -v end=$end}        \
    '
    '"$awkFunction_split2"'

    {
        if("'"$segData"'" == FILENAME){
            #                          1       2       3       4       5       6          7          8          9                     10
            #[264k<66k<132k<22k<5k<1k]-3   1.94%  -8.48%  -6.65% -12.39% -10.22% 2020-07-15 2020-07-17 2020-07-17 sorting-raw/603799.raw

            if($1 ~ "#") next ;
            if(start && $9<start) next ;
            if(end && $9>end) next ;
            if($10 in files){
                print forecastCont[$1],$9,substr($10,13,6),$1 ;
            }
        }else if("'"$cntgData"'" == FILENAME){
            #    1.........................................................................................................................................................NF
            #00002  UP/UN=  inf  UP=0002( 5.29%)  UN=0000(  inf%)  DP=0001( 1.43%)  DN=0001(-3.82%)  AP/AN= 1.00  AP=0001( 2.63%)  AN=0001(-3.76%)  [22k<5k<264k<1k<66k<132k]

            if($1 !~ "#"){
                seed = $NF ;
                $NF = "" ;
                forecastCont[seed] = $0 ;
            }
        }else if("-" == FILENAME){
            codeNum = split2($0,a," ") ;
            for(i=0; i<codeNum; i++) files["sorting-raw/" a[i] ".raw"] = 1 ;
        }
    }

    ' -  "$cntgData" "$segData" > "$forecastData"

echo *Save forecast data to "$forecastData" >&2
#endif

doExit 0 "$oprtB4Exit"
