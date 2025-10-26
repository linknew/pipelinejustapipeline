#! /bin/bash

usage() {
    echo -en "Usage:\n\t$(basename $0) <shift_days> <rated_data_file> <leader_lst_file> <follower_lst_file>\n\n"
    echo -en "\texamples:\n"
    echo -en "\t  $(basename $0) 3 last_100_days_rate.data <(echo 002780) <(echo 000880)\n"
    echo -en "\t  $(basename $0) 3 last_100_days_rate.data <(echo)        <(echo 000880)\n"
    echo -en "\t  $(basename $0) 3 last_100_days_rate.data\n"
    echo -en "\n"
}

[[ $1 == -h ]] && { usage; exit; }

shift_days=$1
rate_data=$2
leaders=${3:+$(cat $3)}
followers=${4:+$(cat $4)}

awk -v shift_days=$shift_days   \
    -v leaders="$leaders"       \
    -v followers="$followers"   \
    '                           \
    function print_last(        \
        code,                   \
                                \
        i)
    {
        if(!code) return;
        printf("summary, code %s, total %d, ups %d, dns %d, ucs %d\n",
                code,
                sum[code]["total"],
                sum[code]["ups"],
                sum[code]["dns"],
                sum[code]["ucs"]) > ".sum" ;
        printf ("%s", code) > ".sum" ;
        for(i=1; i<=sum[code]["total"]; i++) {
            printf(" %d", pfrsV[code][i]) > ".sum";
        }
        printf("\n") > ".sum" ;
    }

    function comp(          \
        len,                \
        leader,             \
        follower,           \
        shift_right_code1,  \
                            \
        i,                  \
        cnt)
    {
#       asr(n_code1 = n_code2);
        for(i=1; i<=len-shift_right_code1; i++) {
            if(and(pfrsV[leader][i], pfrsV[follower][i+shift_right_code1])) {
#               printf("Y %.2f %.2f %.2f %.2f\n",
#                       pfrsV[leader][i], pfrsV[follower][i+shift_right_code1],
#                       pfrsV_dbg[leader][i], pfrsV_dbg[follower][i+shift_right_code1]);
                cnt ++;
            }
            else {
#               printf("N %.2f %.2f %.2f %.2f\n",
#                       pfrsV[leader][i], pfrsV[follower][i+shift_right_code1],
#                       pfrsV_dbg[leader][i], pfrsV_dbg[follower][i+shift_right_code1]);
            }
        }
        printf("%s (shift_right %02d) followed by %s, length %d, rate %.2f\n",
            leader,
            shift_right_code1,
            follower,
            i-1,
            cnt/(len-shift_right_code1));
    }

    BEGIN {
        idx = 1;
        n_code = 0;
        last_code = "";
#       sum = ...;
#       pfrsV = ...;
#       code_list = ...;
        leader_n = split(leaders, _arry);
        for(i=1; i<=leader_n; i++) {
            has_leader[_arry[i]] = 1;
        }
        delete _arry
        follower_n = split(followers, _arry);
        for(i=1; i<=follower_n; i++) {
            has_follower[_arry[i]] = 1;
        }
#       print leader_n, follower_n;
#       exit
    }

    {
        code = $1;
        pfr = $2;   # price fluctuation rate
        if(code != last_code) {
            idx = 1;
            n_code ++;
            code_list[n_code] = code;
            print_last(last_code);
            last_code = code;
        }

        sum[code]["total"] ++;
        if(pfr > 0) {
            sum[code]["ups"] ++;
            pfr_abs = 1;    #(1<<0)
        }
        else if(pfr < 0) {
            sum[code]["dns"] ++;
            pfr_abs = 2;    #(1<<1)
        }
        else {
            sum[code]["ucs"] ++;
#           pfr_abs = 3;    #(1&2)
            pfr_abs = 0;    #(...)
        }
        pfrsV[code][idx] = pfr_abs;
#       pfrsV_dbg[code][idx] = pfr;
        idx ++;
    }

    END {
        print_last(code);
        for(i=1; i<=n_code; i++) {
            leader = code_list[i];
            if(leader_n && !(leader in has_leader)) { continue; }
            for(j=1; j<=n_code; j++) {
                follower = code_list[j];
                if(follower_n && !(follower in has_follower)) { continue; }
                if(sum[leader]["total"] != sum[follower]["total"]) { continue; }
                if(sum[leader]["total"]-20 <= shift_days) { continue; }
                comp(sum[leader]["total"], leader, follower, shift_days);
            }
        }
    }
    ' $rate_data
