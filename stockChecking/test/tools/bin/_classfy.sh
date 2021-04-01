#! /bin/bash
source comm.lib

_gap=1
_seed='$1'
_weight=1
_verbose=0
_base=0

for i in "$@"; do
    [[ $i == --help ]] && echo "
    Usage:
        $0 [--help] [--gap=N] [--base=N] [--seed=FORMULA_CLASS_SEED] [--weight=FORMULA_CLASS_VALUE] [--verbose] srcFile

        --gap, split data with the of gap
        --base, set the base for gap
        --seed, formula for caculating the checking value
        --weight, the value will add to the classfied filed, default is 1
        --verbose, print each value for classfy. the display format is: CLASSFIED_VALUE @ ORIGINAL_DATA
    
    Default:
        --seed=$_seed --weight=$_weight --base=0 --gap=$_gap
    " && exit 0

    [[ ${i%%=*} == '--seed' ]] && _seed=${i#*=} && continue
    [[ ${i%%=*} == '--weight' ]] && _weight=${i#*=} && continue
    [[ ${i%%=*} == '--gap' ]] && _gap=${i##*=} && continue
    [[ ${i%%=*} == '--base' ]] && _base=${i##*=} && continue
    [[ ${i%%=*} == '--verbose' ]] && _verbose=1 && continue
    [[ ${i:0:1} == '-' ]] && showErr "unknown option $i\n" && exit

    _srcFile=$i
done

cat - <<-EOF
	# base=$_base
	# gap=$_gap
	# seed=$_seed
	# weight=$_weight
EOF

#start the main routine
awk -v _awkGap=$_gap            \
    -v _awkBase=$_base          \
    -v _awkVerbose=$_verbose    \
    '

    '"$awkFunction_around"'     # include function around

    {
        # ... float operation is f***
        # int(1.2/0.1) returns 11... blooding with angry
        # to avoid this, we will enlarge the seed to seed*1000 first, then recover it
        # why 1000? because we want keep 3digital behind dot.

        _val = ('"$_seed"') ;
        _idx = around((_val-_awkBase)*1000/_awkGap/1000)*_awkGap+_awkBase ;
        #print "-->",_val,_idx
        _arry[_idx] += ('"$_weight"') ;
        if(_awkVerbose) print _val," @ ",$0 ;
    }

    END{
        for(i in _arry){
            print i, _arry[i]
        }
    }

' $_srcFile

