#! /bin/bash

code_list=${1:-top.566.lst}

rm .t*lvl* .better.signals* ~/SotckData/*hot .mon.bullish.lst .mon.good.lst .wek.good.lst .tomorrow_may_die.lst 2>/dev/null

getHot.qt.batch.sh $code_list
forecast.sh  --genSegment  --dur=22 --serialLvl=6 --coder=_1.1_genKLineSortingRawData.sh            $code_list
forecast.sh  --genSegment  --dur=5  --serialLvl=2 --coder=_1.1b_genRawData_signal_by_amp_status.sh  $code_list
./_match_with_better_signals.sh  .t22.segData.lvl6  +0  |  awk '{print $1}'   |  xargs -i grep {}   $code_list > .mon.bullish.lst
./_match_with_better_signals.sh  .t22.segData.lvl6   0  |  awk '{print $1}'   |  xargs -i grep {}   $code_list > .mon.good.lst
./_match_with_better_signals.sh  .t5.segData.lvl2    0  |  awk '{print $1}'   |  xargs -i grep {}   $code_list > .wek.good.lst
./_match_with_better_signals.sh  .t5.segData.lvl2    1  |  awk '{print $1}'   |  xargs -i grep {}   $code_list > .tomorrow_may_die.lst

clear -x > /dev/tty
echo "###########一个月内可能会爬升的##########" >&2
cat .mon.good.lst 2>/dev/null
echo "###########一个月内可能会飞升的##########" >&2
cat .mon.bullish.lst 2>/dev/null
echo "###########一周内可能会爬出坑的##########" >&2
cat .wek.good.lst 2>/dev/null
echo "###########明天可能会掉进坑里的##########" >&2
cat .tomorrow_may_die.lst >&2 2>/dev/null
echo >&2
