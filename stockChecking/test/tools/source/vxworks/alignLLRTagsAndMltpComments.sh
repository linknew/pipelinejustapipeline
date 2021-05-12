#! /bin/bash


# align LLR tag(right alignment) and multip_line_comment_in_declaration(first line alignment)


for i in $@
do

echo $i

awk '
    
    BEGIN{
        eightySpace="                                                                                " ;
        /* __DR__
    }


    /^[ \t]*\/\*.*\*\/[ \t]*/{

        # the following part of multip_comment_in_declaration

        if(alignP){
            #gsub(/(^[ \t]*)|([ \t]*$)/,"",$0) ;        #awk bug?
            sub(/(^[ \t]*)/,"",$0) ;
            sub(/([ \t]*$)/,"",$0) ;
            print substr(eightySpace,1,alignP-1) $0 ;
        }else{
            print ;
        }
        next ;
    }    

    /\/\*.*\*\//{

        # the first line of multip_comment_in_declaration

        alignP = index($0,"/*") ;
        print ;
        next ;
    }

    {
        alignP = 0 ;
        print ;
    }

    '   $i  | diff -Z $i -

done


exit ;


