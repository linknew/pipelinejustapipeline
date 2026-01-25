#! /bin/bash

source $(dirname $(readlink -f $0))/../lib/comm.lib


#@ for example: serial_depth=2

#@ before serialize
# a             x x x typeA X
# a-1           x x x typeA X
# a-2           x x x typeA X
# b             x x x typeB X
# b-1           x x x typeB X
# c             x x x typeC X
# c-1           x x x typeC X
# c-2           x x x typeC X

#@ after serialize
# a             x x x typeA x
# a_a-1         x x x typeA x
# a-1_a-2       x x x typeA x
# b             x x x typeB x
# b_b-1         x x x typeB x
# c             x x x typeC x
# c_c-1         x x x typeC x
# c-1_c-2       x x x typeC x

Usage()
{
    echo -ne "      \
    \nUsage:        \
    \n\t$(basename $0) [--serial_depth=<n>] [--seed_idx=<n>] [--type_idx=<n>] [--sord_idx=<n>] [--ignore_seedling] [--abb] [--test] filename    \
    \n  \
    \n\t--serial_depth, the serialized seed length    \
    \n\t--seed_idx, which filed the \"seed\" located  \
    \n\t--type_idx, which filed the \"type\" located. eg, use \"stock-code\" as the \"type\"  \
    \n\t--sort_idx, which location of the \"sorting-key\"   \
    \n\t--ignore_seedling, do not show these seedlings with length of less than serial_depth    \
    \n\t--abb, abbrevate serialized seed    \
    \n\n"
}

unit_test()
{
    echo "
        300001 seed1 2026-01-01 10.1
        300001 seed2 2026-01-02 10.2
        300001 seed3 2026-01-03 10.3
        300001 seed4 2026-01-04 10.4
        300001 seed5 2026-01-05 10.5
        #
        300002 seed1 2026-01-01 9.1
        300003 seed1 2026-01-01 8.5
        300002 seed2 2026-01-02 9.2
        300003 seed2 2026-01-02 8.4
        300002 seed3 2026-01-03 9.3
        300003 seed3 2026-01-03 8.3
        300002 seed4 2026-01-04 9.4
        300003 seed4 2026-01-04 8.2
        300002 seed5 2026-01-05 9.5
        300003 seed5 2026-01-05 8.1
        #
    " > /tmp/.t

    serial_depth=3
    seed_idx=2
    type_idx=1
    sort_idx=1
    ignore_seedling=1
    abb=1
    fn=/tmp/.t
}

echo -ne "*executing $0($$)\n" >&2

for i in "${@}"
do
    [[ $i == --help || $i == -h ]]      &&  { Usage; doExit 0; }
    [[ $i == --test ]]                  &&  { unit_test; break; }
    [[ ${i%%=*} == "--serial_depth" ]]  &&  serial_depth=${i##*=} && continue
    [[ ${i%%=*} == "--type_idx" ]]      &&  type_idx=${i##*=} && continue
    [[ ${i%%=*} == "--seed_idx" ]]      &&  seed_idx=${i#*=} && continue
    [[ ${i%%=*} == "--sort_idx" ]]      &&  sort_idx=${i#*=} && continue
    [[ ${i} == "--ignore_seedling" ]]   &&  ignore_seedling=1 && continue
    [[ ${i} == "--abb" ]]               &&  abb=1 && continue
    [[ ${i:0:1} == "-" ]]               &&  { echo "** unknown option:$i">&2; doExit -1; }
    [[ -n $fn ]]                        &&  { echo "** Multipule file specified">&2; doExit -1; }
    fn=$i
done

serial_depth=${serial_depth:-3}
seed_idx=${seed_idx:-1}
type_idx=${type_idx:-1}
ignore_seedling=${ignore_seedling:-0}
abb=${abb:-0}

echo *seed_idx="$seed_idx" >&2
echo *type_idx="$type_idx" >&2
echo *sort_idx="$sort_idx" >&2
echo *serial_depth="$serial_depth" >&2
echo *ignore_seedling="$ignore_seedling" >&2
echo *abb="$abb" >&2

awk -v seed_idx=$seed_idx                 \
    -v type_idx=$type_idx                 \
    -v serial_depth=$serial_depth             \
    -v ignoreSeedling=$ignore_seedling  \
    -v abb=$abb                         \
    '

    # stack for saving serial seed/signal

    function clearSeedStack(type)
    {
        seedSerialStackDeep[type] = 0 ;
        seedSerialStackIdx[type] = 0 ;
        return ;
    }

    function pushSeedStack(type,seed)
    {
        seedSerialStack [type,seedSerialStackIdx[type]] = seed ;
        seedSerialStackIdx[type] ++ ;
        if(seedSerialStackIdx[type] >= serial_depth) seedSerialStackIdx[type] = 0 ;
        if(seedSerialStackDeep[type] < serial_depth) seedSerialStackDeep[type] ++ ;
        return ;
    }

    function getSerialDep(type)
    {
        return seedSerialStackDeep[type];
    }

    function serialDepthOk(type)
    {
        return seedSerialStackDeep[type]==serial_depth;
    }

    function getSerialSeed(type,  i,s,ret)
    {
        ret = "" ;

        s = seedSerialStackIdx[type]-seedSerialStackDeep[type] ;
        if(s<0) s += serial_depth ;

        for(i=0; i<seedSerialStackDeep[type]; i++){
            ret = ret seedSerialStack[type,s] ;
            if(i<seedSerialStackDeep[type]-1) ret = ret "_" ;
            s++ ;
            if(s>=serial_depth) s=0 ;
        }

        return ret ;
    }

    BEGIN{
        serial_depth = serial_depth+0 ;
        $0 = "" ;
    }

    {
        if($0 ~/^[ \t]*$/) {
            next;
        }

        if($1 ~ /^#/) {
            print;
            next;
        }

        type = $type_idx;
        seed = $seed_idx;

        #@ update seed/signal abbrevation table
        if(abb && !(seed in seedAbbs)) seedAbbs[seed]=(seedAbbIdx++) ;

        #@ reset for new type
        if(!(type in seeType)) {
            clearSeedStack(type) ;
            seeType[type] = 1;
        }

        #push current seed to stack
        pushSeedStack(type, (abb) ? seedAbbs[seed] : seed) ;
        
        #show content with serialized seed
        if(ignoreSeedling && !serialDepthOk(type)) {
            next;
        }
        seed = getSerialSeed(type) ;
        $seed_idx = seed;
        print $0;
    }

    END{
        if(abb){
            for(i in seedAbbs) print "#seekAbbs",i ,seedAbbs[i] ;
        }
    }

    '   $fn  |  if [[ -n $sort_idx ]]; then { sort -k${sort_idx},${sort_idx}; }; else { cat -; }; fi

doExit 0
