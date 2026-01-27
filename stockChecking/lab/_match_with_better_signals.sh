
seg_data=$1
fix=$2                              #@ 0:today 1:tomorrow 2:after_tomorrow ...
today=${3:-$(date +%Y-%m-%d)}
better_signal="
[1k<5k<22k<66k<264k<132k]-4_[1k<5k<22k<66k<264k<132k]-5_[5k<1k<22k<66k<264k<132k]
[1k<5k<264k<22k<132k<66k]_[1k<5k<264k<22k<132k<66k]-1_[5k<1k<264k<22k<132k<66k]
[1k<5k<22k<264k<132k<66k]-1_[1k<5k<22k<264k<132k<66k]-2_[5k<1k<22k<264k<132k<66k]       #@+1145.97      13      3       0.77
[1k<5k<22k<66k<264k<132k]-4_[5k<1k<22k<66k<264k<132k]_[5k<1k<22k<66k<264k<132k]-1       #@+2551.80      21      11      0.48
[264k<1k<5k<132k<22k<66k]-2_[264k<1k<5k<132k<22k<66k]-3_[264k<1k<5k<132k<22k<66k]-4     #@+1255.45      22      14      0.36
"

bs=$(echo "$better_signal" | sed 's/[ \t]*#.*//; /^[ \t]*$/d; s/\(_[^_]*\)\{'$fix'\}$//;')
#[[ $fix == 1 ]] && bs=$(echo "$bs" | sed 's/\(_[^_]*\)\{'$fix'\}$//;')
#[[ $fix == 2 ]] && bs=$(echo "$bs" | sed 's/\(_[^_]*\)\{1\}$//;')
#[[ $fix == 3 ]] && bs=$(echo "$bs" | sed 's/\(_[^_]*\)\{2\}$//;')
bs=$(echo "$bs" | sed 's/\[\|\]/\\&/g; s/$/\\s/;')

echo -en "\n* match $today's stocks in $seg_data with\n$better_signal---\n$bs\n\n" >&2
grep -f <(echo "$bs") $seg_data | grep "$today ....[^-]" | sed 's,[ \t]+*.*/, ,; s,.raw,,;' | awk '{print $2, "#" $1}'



