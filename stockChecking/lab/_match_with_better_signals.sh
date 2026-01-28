
seg_data=$1
fix=${2:-0}                         #@ 0:today 1:tomorrow 2:after_tomorrow ...
today=${3:-$(date +%Y-%m-%d)}

#better_signals="
#[1k<5k<22k<66k<264k<132k]-4_[1k<5k<22k<66k<264k<132k]-5_[5k<1k<22k<66k<264k<132k]
#[1k<5k<264k<22k<132k<66k]_[1k<5k<264k<22k<132k<66k]-1_[5k<1k<264k<22k<132k<66k]
#[1k<5k<22k<264k<132k<66k]-1_[1k<5k<22k<264k<132k<66k]-2_[5k<1k<22k<264k<132k<66k]       #@+1145.97      13      3       0.77
#[1k<5k<22k<66k<264k<132k]-4_[5k<1k<22k<66k<264k<132k]_[5k<1k<22k<66k<264k<132k]-1       #@+2551.80      21      11      0.48
#[264k<1k<5k<132k<22k<66k]-2_[264k<1k<5k<132k<22k<66k]-3_[264k<1k<5k<132k<22k<66k]-4     #@+1255.45      22      14      0.36
#"

better_signals="
[1k<5k<22k<264k<132k<66k]_[1k<5k<22k<264k<132k<66k]-1_[1k<5k<22k<264k<132k<66k]-2_[5k<1k<22k<264k<132k<66k]         #+15261.59  13  5  0.62
[1k<5k<22k<66k<264k<132k]-3_[1k<5k<22k<66k<264k<132k]-4_[1k<5k<22k<66k<264k<132k]-5_[5k<1k<22k<66k<264k<132k]       #+10847.42  11  1  0.91
"

worse_signals="
[1k<5k<22k<264k<66k<132k]-3_[5k<1k<22k<264k<66k<132k]_[5k<1k<22k<264k<66k<132k]-1_[5k<1k<22k<264k<66k<132k]-2       #-1032.86   5   3  0.40
[264k<132k<1k<5k<22k<66k]-1_[264k<132k<5k<1k<22k<66k]_[264k<132k<5k<1k<22k<66k]-1_[264k<132k<1k<5k<22k<66k]         #-102.28    10  4  0.60
"

high_risk_signals="
[1k<5k<22k<264k<66k<132k]-3_[5k<1k<22k<264k<66k<132k]_[5k<1k<22k<264k<66k<132k]-1_[5k<1k<22k<264k<66k<132k]-2       #-1032.86   5   3  0.40
[264k<132k<1k<5k<22k<66k]-1_[264k<132k<5k<1k<22k<66k]_[264k<132k<5k<1k<22k<66k]-1_[264k<132k<1k<5k<22k<66k]         #-102.28    10  4  0.60
"

if [[ ${fix:0:1} == '-' ]]; then
    fix=${fix:1};
    signals="$worse_signals";
elif [[ ${fix:0:1} == '+' ]]; then
    fix=${fix:1};
    signals="$high_risk_signals";
else
    signals="$better_signals";
fi

bs=$(echo "$signals" | sed 's/[ \t]*#.*//; /^[ \t]*$/d; s/\(_[^_]*\)\{'$fix'\}$//;')
bs=$(echo "$bs" | sed 's/\[\|\]/\\&/g; s/$/\\s/;')

echo -en "\n* match $today's stocks in $seg_data with\n$better_signals---\n$bs\n\n" >&2
grep -f <(echo "$bs") $seg_data | grep "$today ....[^-]" | awk '{ print $NF, "#"$1, $9;}' | sed 's,^.*/, ,; s,.raw,,;'



