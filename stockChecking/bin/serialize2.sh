#! /bin/bash

source $(dirname $0)/../lib/comm.lib


#@ for example: serialize_level=2

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


echo -ne "*executing $0($$)\n" >&2

for i in "${@}"
do
    [[ ${i%%=*} == "--serialLvl" ]] && serialLvl=${i##*=} && continue
    [[ ${i%%=*} == "--typeIdx" ]] && typeIdx=${i##*=} && continue
    [[ ${i%%=*} == "--seedIdx" ]] && seedIdx=${i#*=} && continue
    [[ ${i%%=*} == "--sortIdx" ]] && sortIdx=${i#*=} && continue
    [[ ${i%%=*} == "--noAbb" ]] &&noAbb=1 && continue
    [[ ${i:0:1} == "-" ]] && echo "unknown option:$i">&2 && doExit -1
    [[ -n $fn ]] && echo "*! Multipule file specified">&2 && doExit -1
    fn=$i
done

serialLvl=${serialLvl:-3}
seedIdx=${seedIdx:-1}
typeIdx=${typeIdx:-1}
noAbb=${noAbb:-0}

echo *seedIdx="$seedIdx" >&2
echo *typeIdx="$typeIdx" >&2
echo *sortIdx="$sortIdx" >&2
echo *serialLvl="$serialLvl" >&2
echo *noAbb="$noAbb" >&2

awk -v seedIdx=$seedIdx             \
    -v typeIdx=$typeIdx             \
    -v serialLvl=$serialLvl         \
    -v noAbb=$noAbb                 \
    '

    # stack for saving serial seed/signal

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
        if(seedSerialStackIdx >= serialLvl) seedSerialStackIdx = 0 ;
        if(seedSerialStackDeep < serialLvl) seedSerialStackDeep ++ ;

        return ;
    }

    function getSerialSeed(i,s,ret)
    {
        ret = "" ;

        s = seedSerialStackIdx-seedSerialStackDeep ;    #e+1 == seedSerialStackIdx  #e-s+1 == seedSerialStackDeep ;
        if(s<0) s += serialLvl ;

        for(i=0; i<seedSerialStackDeep; i++){
            ret = ret seedSerialStack[s] ;
            if(i<seedSerialStackDeep-1) ret = ret "_" ;
            s++ ;
            if(s>=serialLvl) s=0 ;
        }

        return ret ;
    }

    BEGIN{
        serialLvl = serialLvl+0 ;
        cleanSeedStack() ;
        $0 = "" ;
    }

    {
        if($1 ~ /^ *#/) {
            print;
            next;
        }

        type = $typeIdx;
        seed = $seedIdx;

        #@ update seed/signal abbrevation table
        if(!noAbb && !(seed in seedAbbs)) seedAbbs[seed]=(seedAbbIdx++) ;

        #@ reset for new type
        if(type != typeLast) cleanSeedStack() ;
        typeLast = type ;

        pushSeedStack((noAbb) ? seed : seedAbbs[seed]) ;
        seed = getSerialSeed() ;
        $seedIdx = seed;
        print $0;
    }

    END{
        if(!noAbb){
            for(i in seedAbbs) print "#seekAbbs",i ,seedAbbs[i] ;
        }
    }

    '   $fn  |  if [[ -n $sortIdx ]]; then { sort -k${sortIdx}; }; else { cat -; }; fi

doExit 0
