#!  /bin/bash

ignErr=1 ;
recusive=0 ;

for i in "$@"
do
    [[ $i == -R ]] && recusive=1 && continue
    last=$i
done

[[ $recusive -eq 1 ]] && sourceFile=$(find $last -type f) || sourceFile=$@


awk '

    BEGIN{
        illegalCharList["\x00"] = "\NUL" ;
        illegalCharList["\x01"] = "\SOH" ;
        illegalCharList["\x02"] = "\STX" ;
        illegalCharList["\x03"] = "\ETX" ;
        illegalCharList["\x04"] = "\EOT" ;
        illegalCharList["\x05"] = "\ENQ" ;
        illegalCharList["\x06"] = "\ACK" ;
        illegalCharList["\x07"] = "\\a"  ;   #"\BEL";
        illegalCharList["\x08"] = "\\b"  ;   #"\BS" ;
        illegalCharList["\x09"] = "\\t"  ;   #"\HT" ;
        illegalCharList["\x0A"] = "\\n"  ;   #"\LF" ;
        illegalCharList["\x0B"] = "\\v"  ;   #"\VT" ;
        illegalCharList["\x0C"] = "\\f"  ;   #"\FF" ;
        illegalCharList["\x0D"] = "\\r"  ;   #"\CR" ;
        illegalCharList["\x0E"] = "\SO" ;
        illegalCharList["\x0F"] = "\SI" ;
        illegalCharList["\x10"] = "\DLE" ;
        illegalCharList["\x11"] = "\DC1" ;
        illegalCharList["\x12"] = "\DC2" ;
        illegalCharList["\x13"] = "\DC3" ;
        illegalCharList["\x14"] = "\DC4" ;
        illegalCharList["\x15"] = "\NAK" ;
        illegalCharList["\x16"] = "\SYN" ;
        illegalCharList["\x17"] = "\ETB" ;
        illegalCharList["\x18"] = "\CAN" ;
        illegalCharList["\x19"] = "\EM" ;
        illegalCharList["\x1A"] = "\SUB" ;
        illegalCharList["\x1B"] = "\ESC" ;
        illegalCharList["\x1C"] = "\FS" ;
        illegalCharList["\x1D"] = "\GS" ;
        illegalCharList["\x1E"] = "\RS" ;
        illegalCharList["\x1F"] = "\US" ;
        illegalCharList["\x7F"] = "\DEL" ;
    }

    {
        #check indentation position
        {
            if($0 ~ /^ *[{}]/){
                pos = match($0, /[{}]/) ;
                if(pos%4 != 1){
                    print "[check indentation of \"{\" and \"}\"]* wrong indentation width @", FILENAME ":" FNR ;
                    rsltIndent = 1 ;
                }
            }
        }

        #check length
        {
            len = length($0) ;

            if(len > 80){
                print "[check 80 byte_width limitation]* should <= 80 characters @", FILENAME ":" FNR ;
                rslt80B = 1 ;
            }
        }

        #check illegal character
        {
            num = split($0, arry, "") ;
            warnIdx = 1 ;
            warnInfo = "* find illegal charater:" ;
            foundIllegal = 0 ;
            prry = "" ;

            for(i=1; i<=num; i++){
                if(arry[i] > "~" || arry[i] < " "){
                    prry = prry "{" warnIdx "}" ;
                    warnInfo = warnInfo " " ( (arry[i] in illegalCharList) ? (illegalCharList[arry[i]] ) : ("\unk") ) "@{" warnIdx "}" ;
                    warnIdx ++ ;
                    foundIllegal = 1 ;
                }else{
                    prry = prry arry[i] ;
                }
            }

            if(foundIllegal){
                print "[check illegal characters]" warnInfo " @ " FILENAME ":" FNR " # " prry ;
                rsltIllChar = 1 ;
            }
        }
    }

    END{
        if(!rslt80B) print "[check 80 byte_width limitation]- No abnormalities found, Good J0b" ;
        if(!rsltIndent) print "[check indentation of \"{\" and \"}\"]- No abnormalities found, Good J0b" ;
        if(!rsltIllChar) print "[check illegal characters]- No abnormalities found, Good J0b" ;
    }

    '   $sourceFile


exit 

