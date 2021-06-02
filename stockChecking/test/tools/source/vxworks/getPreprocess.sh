#! /bin/bash

[[ $WIND_PLATFORM != "helix" || $SHLVL -lt 2 ]] && echo -ne '\n!!go, back here after you have done "wrenv.sh -p helix"\n\n' && exit

#vsbBase=/ctu-cert1_02/mli2/workspace/debug/gos_vsb
#CC=/ctu-cert1_02/mli2/workspace/vxworks/helix/compilers/llvm-10.0.1.1/LINUX64/bin/clang
#preprocInfoFile=preprocessInfo.data
#fileList=""


tag="/ctu-cert1_02/mli2/workspace/vxworks/helix/guests/vxworks-7/pkgs_v2/os/utils/zlib/src/zutil.c"

grep "$tag" check.preprocessInfo.data |
awk '
    {
        vLvl = 1 ;
        vNext = 0 ;
        tag = $0 ; gsub(/\[|\].*/, "", tag) ;
        vCmd = $0; gsub(/.*\] | \[.*/, "", vCmd) ;
        vCmd = vCmd "pwd" ;

        if(substr(tag,1,1) == "*"){
            tag = substr(tag, 2) ;
            vNext = 1 ;
        }

        print "tag" vLvl ":" substr(tag,2) ;
        print "cmd" vLvl ":" vCmd ;
        print "execute cmd" ;
        print vCmd | "/bin/bash" ;
        print close("/bin/bash") ;


        if(vNext){
            tag = $0 ; gsub(/.*\[|]$/, "", tag) ;
            vLvl ++ ;
            print "tag" vLvl ":" substr(tag,2) ;
        }

    }
    '
