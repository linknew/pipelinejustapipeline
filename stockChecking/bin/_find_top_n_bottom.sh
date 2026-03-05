#! /bin/bash

#
##@ 寻找最高点和最低点, 相邻2点差值小于gap的将会被移除
#
#Usage()
#{
#    echo -ne "\nUsage: $(basename $0) <7code> <gap> <1970-01-01>\n\n"
#}
#
#[[ $# -lt 1 || $# -gt 2 || ! $1 =~ ^[0-9]{7}$ ]] && { Usage; exit; }
#[[ -n $2 && ! $(date -d $2 "+%F") ]] && { Usage; exit; }
#code=$1
#gap=${2:-10}
#start=${3:-1979-01-01}
#forecast.sh --dur=22 --serialLvl=1 \
#            --coder=_1.1b_genRawData_signal_by_amp_status.sh \
#            --genSegment <<< 0000001 >& /dev/null || { echo failed to execute forecast.sh, exit $?; exit; }
#seg_data=.t22.segData.lvl1
#
#awk -v start=$start '
#    BEGIN {
#        CONVFMT="%.4f"
#        OFMT="%.2f"
#    }
#
#    {
#        if($1~"#") { next; }
#        date = $9;
#        if(date < start) { next; }
#        close_price = $11+0;
#        from[date] = $7;
#        to[date] = $8;
#        seed[date] = close_price;
#    }
#
#    END {
#        for (i in seed) {
#            print i, seed[i], from[i], to[i];
#        }
#    }
#    ' $seg_data | sort -n -k2,2                         | #cat -; exit
#awk '
#    BEGIN {
#        idx = 0;
#    }
#    {
#        keep_bigger[$1] = $2;
#        keep_smaller[$1] =$2;
#        from[$1] = $3;
#        to[$1] = $4;
#        date[idx] = $1;
#        removed_smaller[idx] = 0;
#        removed_bigger[idx] = 0;
#        idx++;
#    }
#    END {
#        #@ keep bigger
#        for(i=0; i<idx; i++) {
#            date_big = date[i];
#            from_big = from[date_big];
#            to_big = to[date_big];
#            for(j=0; j<i; j++) {
#                removed_ = removed_smaller[j];
#                if(removed_) {
#                    continue;
#                }
#                date_sml = date[j];
#                #@ remove all smaller in range of bigger
#                if(date_sml>=from_big && date_sml<=to_big) {
#                    #@ remove lower
#                    removed_smaller[j] = 1;
#                }
#                #@ remove all smaller which covered the bigger
#                from_sml = from[date_sml];
#                to_sml = to[date_sml];
#                if(date_big>=from_sml && date_big<=to_sml) {
#                    #@ remove lower
#                    removed_smaller[j] = 1;
#                }
#            }
#        }
#        #@ keep smaller
#        for(i=idx-1; i>=0; i--) {
#            date_sml = date[i];
#            from_sml = from[date_sml];
#            to_sml = to[date_sml];
#            for(j=i+1; j<idx; j++) {
#                removed_ = removed_bigger[j];
#                if(removed_) {
#                    continue;
#                }
#                date_big = date[j];
#                #@ remove all bigger in range of smaller
#                if(date_big>=from_sml && date_big<=to_sml) {
#                    #@ remove lower
#                    removed_bigger[j] = 1;
#                }
#                #@ remove all bigger which covered the smaller
#                from_big = from[date_big];
#                to_big = to[date_big];
#                if(date_sml>=from_big && date_sml<=to_big) {
#                    #@ remove lower
#                    removed_bigger[j] = 1;
#                }
#            }
#        }
#        for(i=0; i<idx; i++) {
#            print "[T]", date[i], keep_bigger[date[i]] (removed_smaller[i]? "[x]" : ""), from[date[i]], to[date[i]];
#            print "[B]", date[i], keep_smaller[date[i]] (removed_bigger[i]? "[X]" : ""), from[date[i]], to[date[i]];
#        }
#    }
#    ' |
#    grep -v 'T.*x\|B.*X' | #cat -; exit     #@ remove middles
#    sort -k2,2           | #@ sort by date
#    awk '
#        BEGIN {
#            stack_len = 0;
#            price_last = -1;
#            is_top_last = "init";
#        }
#        function push(val) {
#            stack[++stack_len] = val
#        }
#        function pop(    val) {
#            if (stack_len == 0) {
#                return "空栈"
#            }
#            val = stack[stack_len]  # 读取栈顶元素
#            delete stack[stack_len] # 删除栈顶元素
#            stack_len--             # 栈顶指针-1
#            return val
#        }
#        {
#            is_top = $1=="[T]";
#            price = $3+0;
#
#            if (is_top == is_top_last) {
#                ignore = ( (is_top && price < price_last) ||
#                           (!is_top && price > price_last) );
#                if (ignore) {
##                   print "ignored:", $0 > "/dev/tty";
#                    next;
#                }
#                else {
##                   print "remove last one:", price_last > "/dev/tty";
#                    pop();
#                }
#            }
#            push($0);
#            is_top_last = is_top;
#            price_last = price
#        }
#        END {
#            for (i=1; i<=stack_len; i++) {
#                print stack[i];
#            }
#        }
#        '       | #cat -; exit
#    awk '
#        function push(val) {
#            stack[++stack_len] = val
#        }
#        function pop(    val) {
#            if (stack_len == 0) {
#                return "空栈"
#            }
#            val = stack[stack_len]  # 读取栈顶元素
#            delete stack[stack_len] # 删除栈顶元素
#            stack_len--             # 栈顶指针-1
#            return val
#        }
#        BEGIN {
#            push("[F] 1970-01-01 0.0001 1970-02-03 1970-04-05 0 0"); #@ a fack item
#            price_last = 0.0001;
#        }
#        {
#            price = $3+0;
#            amp = (price-price_last)*100.0/price_last;
#            if (amp>-$gap && amp<$gap) {
#                $0 = pop();
#                price_last = $NF;
#                next;
#            }
#            push($0 " " amp " " price_last);
#            price_last = price;
#        }
#        END {
#            for (i=1; i<=stack_len; i++) {
#                print stack[i];
#            }
#        }
#        '
#
#exit

#找出指定2点的值并计算差值

echo "\
#start       stop        amp
#1992-05-25  1992-11-17  -72.318   
#1993-02-15  1993-03-31  -39.7517  
#1993-04-28  1993-07-26  -42.6002  
#1993-08-16  1993-10-27  -23.9765  
#1993-12-07  1994-07-29  -67.3378  
#1994-09-13  1995-02-07  -48.4758  
#1995-04-07  1995-05-10  -16.1175  
#1995-05-22  1995-07-03  -31.6734  
#1995-08-14  1996-01-22  -33.4565  
#1996-04-29  1996-05-30  -13.8455  
#1996-07-24  1996-09-12  -14.7043  
#1996-12-09  1996-12-24  -30.6234  
#1997-05-12  1997-07-07  -26.898   
#1997-09-10  1997-09-23  -17.0437  
#1997-10-27  1997-11-27  -9.16819  
#1998-02-11  1998-03-12  -5.70065  
#1998-06-03  1998-08-17  -24.6196  
#1998-11-16  1999-02-08  -17.6172  
#1999-04-09  1999-05-18  -12.054   
#1999-06-29  1999-07-19  -14.9565  
#1999-09-09  1999-12-27  -19.6863  
#2000-08-21  2000-09-25  -11.0392  
#2001-01-10  2001-02-22  -10.273   
#2001-06-13  2001-10-22  -32.186   
#2001-12-04  2002-01-22  -23.2242  
#2002-03-21  2002-06-05  -13.2353  
#2002-07-08  2003-01-03  -23.8359  
#2003-04-15  2003-05-13  -8.95901  
#2003-06-02  2003-11-12  -16.4118  
#2004-04-06  2004-09-13  -29.0964  
#2004-09-23  2004-11-02  -11.1449  
#2004-11-22  2005-02-01  -14.0339  
#2005-03-08  2005-07-11  -23.2709  
#2005-09-19  2005-12-05  -11.5869  
#2006-07-11  2006-08-07  -11.3628  
#2007-05-29  2007-07-05  -16.5873  
#2007-10-16  2007-11-28  -21.1534  
#2008-01-14  2008-04-18  -43.7118  
#2008-05-05  2008-11-04  -54.6213  
#2008-12-08  2008-12-31  -12.9121  
#2009-08-04  2009-08-31  -23.1519  
#2009-11-23  2010-02-02  -12.0992  
#2010-04-14  2010-07-05  -25.3374  
#2010-11-08  2011-01-25  -15.2581  
#2011-04-18  2011-06-20  -14.2633  
#2011-07-15  2011-10-21  -17.8321  
#2011-11-15  2012-01-05  -15.073   
#2012-03-02  2012-03-29  -8.47425  
#2012-05-04  2012-09-26  -18.2642  
#2012-10-22  2012-12-03  -8.11085  
#2013-02-06  2013-05-02  -10.6948  
#2013-05-29  2013-06-27  -16.0929  
#2013-09-12  2013-11-13  -7.43364  
#2013-12-04  2014-01-20  -11.5691  
#2014-02-19  2014-03-20  -6.95786  
#2014-04-10  2014-04-28  -6.129    
#2015-01-26  2015-02-06  -9.08209  
#2015-06-12  2015-08-26  -43.3394  
#2015-12-22  2016-01-28  -27.2775  
#2016-04-14  2016-05-19  -8.93637  
#2016-11-29  2016-12-29  -5.69047  
#2017-04-11  2017-05-10  -7.18137  
#2017-11-13  2017-12-15  -5.26998  
2018-01-24  2018-10-18  -30.1464  
2018-11-19  2019-01-03  -8.84555  
2019-04-19  2019-06-06  -13.5441  
2019-07-01  2019-08-07  -9.0716   
2019-09-12  2019-11-29  -5.25395  
2020-01-13  2020-02-03  -11.8425  
2020-03-05  2020-03-23  -13.3969  
2020-08-18  2020-09-28  -6.76767  
2021-02-19  2021-03-10  -9.15624  
2021-06-01  2021-07-28  -7.2591   
2021-09-13  2021-11-05  -6.02366  
2021-12-13  2022-04-26  -21.5873  
2022-06-28  2022-10-31  -15.1274  
2022-12-06  2022-12-23  -5.18792  
2023-05-08  2024-02-05  -20.4069  
2024-05-20  2024-09-13  -14.7285  
2024-10-08  2024-11-26  -6.59119  
2024-12-12  2025-01-13  -8.68826  
2025-03-18  2025-04-07  -9.71415  
2025-11-13  2025-12-16  -5.07961
#start       stop        amp      \
"   |

awk '
    BEGIN {
        idx = 0;
    }
    (FILENAME=="-") {
        #@ start -> end -> amp
        if(substr($1,1,1)=="#") next;
        start_ = $1;
        end_ = $2;
        amp_ = $3;
        date_s[start_] = end_;
        date_e[end_] = amp_;
    }
    (FILENAME=="gold/.t22.segData.lvl6.top500") {
        date_ = $9;
        price_ = $11+0;
        code_ = $14;
        if(date_ in date_s) {
#           print "S", date_, price_, code_;
            price_s[code_,date_] = price_;
            completed[code_,date_s[date_]] ++;
            codes[code_] = 1;
        }
        else if(date_ in date_e) {
#           print "E", date_, price_, code_;
            price_e[code_,date_] = price_;
            completed[code_,date_] ++;
            codes[code_] = 1;
        }
    }
    END {
        for (c in codes) {
            for(s in date_s) {
                e = date_s[s];
                ps = price_s[c,s];
                pe = price_e[c,e];
                amp = date_e[e];
                print "[" completed[c,e]+0 "]", c, s, e, ps, pe, "[" amp "%]";
            }
        }
    }
    ' - gold/.t22.segData.lvl6.top500   |
grep -F '[2]' |
awk '
    {
        price_s = $5+0;
        price_e = $6+0;
        amp = (price_e-price_s)*100/price_s;
        print $0, amp "%";
    }
    '   | #cat -; exit
awk '
    {
        code = $2;
        amp = $8+0;
        if(amp>0) {
            up[code] ++;
        }
        cnt[code] ++;
    }
    END {
        for (code in cnt) {
            up_ = up[code]+0;
            cnt_ = cnt[code]+0;
            rate_ = up_*100/cnt_;
            print code, up_ "/" cnt_, "=", rate_ "%";
        }
    }
    '   |
sort -k4nr

