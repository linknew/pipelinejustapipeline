
#! /bin/bash

source $(dirname $(readlink -f $0))/../lib/comm.lib

Usage()
{
    echo -ne "
    Usage: $(basename $0) <source> <target>

        --source, source segment data file
        --target, target segment data file
        --help
    \n"
}

doExit()
{
    rm $abb_cvt >& /dev/null;
    exit $1;
}

source=$1
target=$2
abb_cvt=/tmp/.abb.cvt.$$

[[ $1 == --help || $1 == -h ]] && { Usage; doExit 0; }
[[ ! -r $source ]] && { echo "** failed to open source file \"$source\"" >&2; doExit 1; }
[[ ! -r $target ]] && { echo "** failed to open source file \"$target\"" >&2; doExit 1; }
touch $abb_cvt

#merge get merged abbrevation map
echo "* extract abbrevation maps from \"$source\" and \"$target\"" >&2
echo "* merge abbrevation map of \"$source\" into \"$target\"'s" >&2
awk -v source=$source -v target=$target '

    function add_2_seed_abb_map (seed, abb)
    {
        map_s2a[seed] = abb;
        if(abb >= new_abb_for_add) {
            new_abb_for_add = abb+1;
        }
        found_target_abb = 1;
        print "#seekAbbs", seed, abb
    }

    function merge_2_seed_abb_map (seed, abb,    cvt_abb)
    {
        if(seed in map_s2a) {
            cvt_abb = map_s2a[seed];
        }
        else {
            cvt_abb = new_abb_for_add++;
            print "#seekAbbs", seed, cvt_abb
        }
        found_source_abb = 1;
        print "#cvtAbbs", abb, cvt_abb;
    }

    ($1 == "#seekAbbs") {
        if (FILENAME == target) {
            seed = $2;
            abb = $3;
            add_2_seed_abb_map(seed, abb);
        }

        if (FILENAME == source) {
            seed = $2;
            abb = $3;
            merge_2_seed_abb_map(seed, abb);
        }
    }

    END {
        if (xor(found_source_abb, found_target_abb)) {
            print "** cannot find abbrevation map in both", source, "and", target > "/dev/stderr";
            exit 1;
        }
    }
    ' $target $source > $abb_cvt || doExit 1;   #cat $abb_cvt; doExit 0


echo "* extract segment data from \"$target\"" >&2
echo "* extract segment data from \"$source\"" >&2
echo "* replace segment data of \"$source\" with merged abbrevation map" >&2
echo "* merge segment data of \"$source\" into \"$target\"'s" >&2
echo "* insert merged abbrevation map into the merged segment data" >&2
awk -v target=$target -v source=$source -v abb_cvt=$abb_cvt '

    '"$awkFunction_split2"'

    function get_cvted_seed(seed,    a, n, i, r, f)
    {
        n = split2(seed, a, "_") ;
        f = 0;
        for(i=0; i<n; i++) {
            if (!(a[i] in cvts)) {
                f = 1;
                break;
            }
            if(i>0) {
                r = r "_";
            }
            r = r cvts[a[i]];
        }
        return f? seed : r;
    }

    (FILENAME == abb_cvt) {
        if ($1 == "#seekAbbs") {
            seed = $2;
            abb = $3;
            abbs[seed] = abb;
        }
        else if($1 == "#cvtAbbs") {
            abb = $2;
            abb_new = $3;
            cvts[abb] = abb_new;
        }
        else {
            print "** unknown content \"" $0 "\"" > "/dev/stderr";
        }
    }

    (FILENAME == target) {
        if ($1 ~ "#seekAbbs") {
            next;
        }

        date_end = $8;
        if (date_end == "NONE") {
            next;
        }

        if ($1 !~ "#") {
            date_cur = $9
            stock_code = $NF;
            last_date[stock_code] = date_cur;
        }
        print;
    }

    #@ use the map cvts to convert abbs in seed
    (FILENAME == source) {
        if ($1 ~ "#seekAbbs") {
            next;
        }

        if ($1 ~ "#") {
            print;
            next;
        }

        date_cur = $9
        stock_code = $NF;
        if(date_cur > last_date[stock_code]) {
            seed = $1;
            $1 = get_cvted_seed(seed);
            print $0;
        }
    }

    #@ dont forget the merged seed to abb map
    END {
        for(i in abbs) {
            print "#seekAbbs", i, abbs[i];
        }
    }

    ' $abb_cvt $target $source

doExit 0

