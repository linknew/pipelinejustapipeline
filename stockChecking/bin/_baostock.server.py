#! /bin/python3


import baostock as bs
import pandas as pd
import sys
import os


def fetch_single(code_, start_date_, end_date_):
    rs = bs.query_history_k_data_plus(
        code=code_,
        fields="date,code,open,high,low,close,preclose,volume,amount,adjustflag,turn,tradestatus,pctChg,peTTM,psTTM,pcfNcfTTM,pbMRQ,isST",
        start_date=start_date_,
        end_date=end_date_,
        frequency="d",            # 日线
        adjustflag="3"            # 不复权
    )

    if rs is None:
        return f"ERROR:接口调用失败，返回空结果（可能参数无效或网络问题）"
    if rs.error_code != '0':
        return f"ERROR:{rs.error_msg}"

    # 提取数据并转换为 CSV
    data_list = []
    while rs.next():
        data_list.append(rs.get_row_data())
    df = pd.DataFrame(data_list, columns=rs.fields)
    return df.to_csv(index=False)


def main():
    # 接收外部传入的主输入管道名（输出管道由请求指令动态指定）
    if len(sys.argv) != 2:
        print("用法：python3 baostock.server.py <fifo_request>", file=sys.stderr)
        sys.exit(1)
    fifo_req = sys.argv[1]

    # 一次登录，全程复用
    lg = bs.login()
    if lg.error_code != '0':
        print(f"登录失败：{lg.error_msg}", file=sys.stderr)
        sys.exit(1)

    # 监听主输入管道
    with open(fifo_req, 'r') as main_in:
        while True:
            # 读取一行请求，按空格分割（忽略空行）
            line = main_in.readline().strip()
            if not line:
                continue
            
            parts = line.split()
            # 1. 处理停止指令：stop
            if parts[0] == "stop":
                break
            
            # 2. 处理数据请求指令：code startDate endDate fifo_res
            if len(parts) == 4:
                code, start_date, end_date, fifo_res = parts
                # 检查结果输出管道是否存在
                if not os.path.exists(fifo_res):
                    print(f"cannot find named pipe {fifo_res}", file=sys.stderr)
                    continue
                
                # 获取数据并写入指定输出管道
                result = fetch_single(code, start_date, end_date)
                
                # 写入结果
                with open(fifo_res, 'w') as out:
                    out.write(result + "\n")
                    out.flush()

    # 退出时登出
    bs.logout()

if __name__ == "__main__":
    main()

