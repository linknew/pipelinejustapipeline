#! /bin/bash

#. comm.lib


for i in $@
do

awk '
    '"$awkFunction_truncateIntoLines"'
    BEGIN{
        yearList = "2018, 2021" ;
        copyright = " * The right to copy, distribute, modify or otherwise make use of this software may be licensed only pursuant to the terms of an applicable Wind River license agreement."
    }

    (FNR==1){
        if($0 ~ "^/\* *=|^// *="){
            title = $0 ; sub("^/(\*|/) *=+-* *", "",title); sub(" *-*=+ *(//)?$", "", title) ;
            #print "1." FILENAME "\n" "2." $0 "\n" "3." title "\n" > "/dev/stderr" ;
            if(!title) exit -1 ;

#            while(! ($0 ~ "^ \*/") ){
#                if(!getline) print "!!Cannot find end flag @ " FILENAME > "/dev/stderr" ;
#            }

        }else{
            title = "" ;
            print "!!Cannot find module header @ " FILENAME > "/dev/stderr" ;
            exit -1 ;

        }

        print "/* " title " */\n" ;

        print "/*" ;
        yearListInCopyright = " * Copyright (c) " yearList " Wind River Systems, Inc." ;
        linesNum = truncateIntoLines(yearListInCopyright, outArry, " * ", 80) ;
        for(i=1; i<=linesNum; i++) print outArry[i] ;
        print " *" ;

        linesNum = truncateIntoLines(copyright, outArry, " * ", 80) ;
        for(i=1; i<=linesNum; i++) print outArry[i] ;
        print " */\n" ;

        print "/*" ;
        print "modification history" ;
        print "--------------------" ;
        print "20aug18,mze  helix part1" ;
        print "*/\n" ;

        print $0 ;
        next ;
    }

    {
        print ;
    }

    ' $i > $i.$$

    [[ $? -eq 0 ]] && mv $i.$$ $i || rm -rf $i.$$

done

