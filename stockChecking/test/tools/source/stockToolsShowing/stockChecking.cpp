#include <fstream>
#include <cstdlib>
#include <iostream>
#include <opencv2/core.hpp>
#include "opencv2/imgproc.hpp"
#include "opencv2/imgcodecs.hpp"
#include "opencv2/highgui.hpp"
#include "opencv2/stitching.hpp"
#include <opencv2/dnn.hpp>
#include <opencv2/core/utils/trace.hpp>
#include <istream>
#include <sstream>
#include <iomanip>
#include <signal.h>
#include <pthread.h>
#include <unistd.h>
#include "view.hpp"

/*
    lineObj refLines[5] ;
    view mainView ;
    dataSource source() ;
    */





#define UNSET                   (-1)

#define RSLT_OK                 (0)     // key has been used in current function inside.(do not use it continuas)
#define RSLT_NOTHING            (1)     // current function do not care this key. (main process need to take it)
#define RSLT_REQ_QUIT           (2)     // request to quit

#define MAX_LINES               (8)
#define ALL_ITEMS               (0)
#define LAST_ITEM               (1)

#define GAP_SECOND              (15)    // must be divd by 60
#define MAX_DAILY_CNT           (4*3600/(GAP_SECOND)+1)
#define WEEK_DAYS               (5)
#define MONTH_DAYS              (22)
#define SEASON_DAYS             (MONTH_DAYS*3)
#define HALF_YEAR_DAYS          (MONTH_DAYS*6)
#define YEAR_DAYS               (MONTH_DAYS*12)
#define HISTORY_DATA_DAYS       (YEAR_DAYS*30)
#define HOT_DATA_DAYS           (1)
#define FORECAST_DATA_DAYS      (MONTH_DAYS*6+1)
#define MAX_DAYS_NUM            (HISTORY_DATA_DAYS+HOT_DATA_DAYS+FORECAST_DATA_DAYS)

#define MAX_WIN_WIDTH           (1280)
#define MAX_WIN_HEIGHT          (670)

#define LEFT_VIEW_W             (120)

#define DATA_FIX_TYPE_NONE      (0)
#define DATA_FIX_TYPE_FORWARD   (1)
#define DATA_FIX_TYPE_BACKWARD  (2)
#define DATA_FIX_TYPE_COUNT     (3)
#define DATA_FIX_TYPE_NOT_SET   (UNSET)

#define LINE_MARGIN_L           (2)
#define LINE_MARGIN_R           (2)
#define LINE_MARGIN_T           (2)
#define LINE_MARGIN_B           (2)

#define EAGER_CHECKING_DUR      (12)

#define  GET_COUNT_OF_VIEW(screenWidth,scale) ( (screenWidth <= (LINE_MARGIN_L)+(LINE_MARGIN_R)) ? 0 : max(1,((screenWidth)-(LINE_MARGIN_L)-(LINE_MARGIN_R))/(scale)) )
#define  GET_POSITION_BY_VIEW_IDX(index, scale)   ( (index) * (scale) + (scale)/2 + (LINE_MARGIN_L) )
#define  GET_FIRST_IDX_OF_DATA_ON_VIEW(view,data,scale)   max(0,data.cols-GET_COUNT_OF_VIEW(view.cols,scale))

#define  IS_BIG_DISK(stockId)   ((stockId=="1399001" || stockId=="1399006" || stockId=="0000001" || stockId=="0000300") ? 1 : 0)
#define  PRINT_INFO(lastOne)                                                                                        \
{                                                                                                                   \
    long _date ;                                                                                                    \
    int  _i ;                                                                                                       \
                                                                                                                    \
    /* (1)stockID, (2)closePrice, (3)power, (4)amplitude, (5)trueAmplitude, (6)rsi6 */                              \
    /* (7)rsi12, (8)rsi24, (9)pwri6, (10)pwri12, (11)pwri24, (12)rsiFuture6, (13)pwriFuture12 */                    \
    /* (14)exchange, (15)volume, (16)value, (17)liveValue, (18)date (19)rsiCustom (20)pwriCustom */                 \
    /* (21)xcgAvgICustom (22) gEgrData (23) highestAmp (24)open (25)hig (26)low (27)ystdClose */                    \
    /* (28)5kline (29)22kline (30)66kline (31)132kline (32)264kline */                                              \
    _i = ((lastOne) == LAST_ITEM) ? max(gMessData.cols-1,0) : 0 ;                                                   \
    for( ; _i < gMessData.cols; _i ++){                                                                             \
        _date = (long)(gDateData.at<double>(0,_i)) ;                                                                \
        cout << setiosflags(ios::fixed) << setprecision(2)   /* set precision to 2 */                               \
             << stockId << " "                          /* stock id */                                              \
             << gLinesData.at<double>(0,_i) << " "      /* price of close */                                        \
             << gPwrData.at<double>(0,_i) << " "        /* power */                                                 \
             << gAmpData.at<double>(0,_i) << " "        /* amplitude */                                             \
             << 100.0*gValData.at<double>(0,_i)/(gVolData.at<double>(0,_i)*gYstdData.at<double>(0,_i)) - 100.0 << " "  /* actual amplitude */ \
             << gRsi6Data.at<double>(0,_i) << " "       /* RSI-6 */                                                 \
             << gRsi12Data.at<double>(0,_i) << " "       /* RSI-12 */                                               \
             << gRsi24Data.at<double>(0,_i) << " "       /* RSI-24 */                                               \
             << gPwri6Data.at<double>(0,_i) << " "       /* PWRI-6 */                                               \
             << gPwri12Data.at<double>(0,_i) << " "       /* PWRI-12 */                                             \
             << gPwri24Data.at<double>(0,_i) << " "       /* PWRI-24 */                                             \
             << ((_i==gAmpData.cols-1) ? rsiFuture6 : 0) << " "  /* RSI-FUTURE-6 */                                 \
             << ((_i==gAmpData.cols-1) ? pwriFuture12 : 0) << " " /* PWRI-FUTURE-12 */                              \
             << gXcgData.at<double>(0,_i) << " "                                                                    \
             << gVolData.at<double>(0,_i) << " "                                                                    \
             << gValData.at<double>(0,_i) << " "                                                                    \
             << gLvalData.at<double>(0,_i) << " "                                                                   \
             << (_date/(12*31)+1970) << "-" << setfill('0') << setw(2) << ((_date%(12*31)/31)+1) << "-" <<setw(2)<< ((_date%31)+1) << " "   /* date */  \
             << gRsiCustomData.at<double>(0,_i) << " "       /* RSI-CUSTOM */                                       \
             << gPwriCustomData.at<double>(0,_i) << " "       /* PWRI-CUSTOM */                                     \
             << gXcgAvgICustomData.at<double>(0,_i) << " "       /* XCG_AVG_I_CUSTOM */                             \
             << gEgrData.at<double>(0,_i) << " "              /* eager value */                                     \
             << (gHigData.at<double>(0,_i)-gYstdData.at<double>(0,_i))*100.0/gYstdData.at<double>(0,_i) << " "  /* highestAmp */ \
             << (gOpenData.at<double>(0,_i))<< " "            /* open price */                                      \
             << (gHigData.at<double>(0,_i)) << " "            /* the most high price */                             \
             << (gLowData.at<double>(0,_i)) << " "            /* the most lowh price */                             \
             << (gYstdData.at<double>(0,_i))<< " "            /* yestoday close price */                            \
             << (gKLine5.at<double>(0,_i))<< " "              /* 5_day key line */                                  \
             << (gKLine22.at<double>(0,_i))<< " "             /* 22_day key line */                                 \
             << (gKLine66.at<double>(0,_i))<< " "             /* 66 key line */                                     \
             << (gKLine132.at<double>(0,_i))<< " "            /* 132 key line */                                    \
             << (gKLine264.at<double>(0,_i))<< " "            /* 264 key line */                                    \
             << endl ;                                                                                              \
    }                                                                                                               \
}

#define  PRINT_DAILY_DATA()                                                                                         \
{                                                                                                                   \
    int  _i    = 0 ;                                                                                                \
    Mat  _du   = gDailyMessData.row(DAILY_DATA_TYPE_VAL_UP) / gDailyMessData.row(DAILY_DATA_TYPE_VOL_UP) ;          \
    Mat  _dd   = gDailyMessData.row(DAILY_DATA_TYPE_VAL_DN) / gDailyMessData.row(DAILY_DATA_TYPE_VOL_DN) ;          \
    Mat  _dr   = _du / _dd ;                                                                                        \
    Mat  _vr   = gDailyMessData.row(DAILY_DATA_TYPE_VAL_UP) / gDailyMessData.row(DAILY_DATA_TYPE_VAL_DN) ;          \
    Mat  _ar   = gDailyMessData.row(DAILY_DATA_TYPE_VOL_UP) / gDailyMessData.row(DAILY_DATA_TYPE_VOL_DN) ;          \
    long _date = (long)(gDateData.at<double>(0,gDateData.cols-1)) ;                                                 \
                                                                                                                    \
    cout << setiosflags(ios::fixed) << setprecision(2);   /* set precision to 2 */                                  \
                                                                                                                    \
    /* (1)date, (2)stockID, (3)close, (4)value, (5)amount */                                                        \
    /* (6)section value, (7)section amount, (8)up value, (9)up amount */                                            \
    /* (10)dn value, (11)down amount, (12)value rate, (13)amount rate, (14)deal rate */                             \
    for(_i=0; _i < gDailyMessData.cols; _i ++){                                                                     \
        cout << (_date/(12*31)+1970) << "-" << setfill('0') << setw(2) << ((_date%(12*31)/31)+1) << "-" <<setw(2)<< ((_date%31)+1) << " "   /* date */  \
             << stockId << " "                                                  /* stock id */                                  \
             << gDailyMessData.at<double>(DAILY_DATA_TYPE_CLS,_i) << " "        /* price of close */                            \
             << gDailyMessData.at<double>(DAILY_DATA_TYPE_VAL,_i) << " "        /* value */                                     \
             << gDailyMessData.at<double>(DAILY_DATA_TYPE_VOL,_i) << " "        /* amount */                                    \
             << gDailyMessData.at<double>(DAILY_DATA_TYPE_VALSECT,_i) << " "    /* value of section */                          \
             << gDailyMessData.at<double>(DAILY_DATA_TYPE_VOLSECT,_i) << " "    /* amount of section */                         \
             << gDailyMessData.at<double>(DAILY_DATA_TYPE_VAL_UP,_i) << " "     /* value of upper */                            \
             << gDailyMessData.at<double>(DAILY_DATA_TYPE_VOL_UP,_i) << " "     /* amount of upper */                           \
             << gDailyMessData.at<double>(DAILY_DATA_TYPE_VAL_DN,_i) << " "     /* value of downner */                          \
             << gDailyMessData.at<double>(DAILY_DATA_TYPE_VOL_DN,_i) << " "     /* amount of downner */                         \
             << _vr.at<double>(0,_i) << " "                                     /* value rate (value_upper/value_downner) */    \
             << _ar.at<double>(0,_i) << " "                                     /* amount rate (amount_upper/amount_downner) */ \
             << _dr.at<double>(0,_i) << " "                                     /* deal rate */                                 \
             << endl ;                                                                                                          \
    }                                                                                                                           \
}

enum DATA_TYPE{
    DATA_TYPE_CLOSE = 0 ,       /* do not change this index(for kLines) */
    DATA_TYPE_AVERAGE_5 ,       /* do not change this index(for kLines) */
    DATA_TYPE_AVERAGE_22 ,      /* do not change this index(for kLines) */
    DATA_TYPE_AVERAGE_66 ,      /* do not change this index(for kLines) */
    DATA_TYPE_AVERAGE_132 ,     /* do not change this index(for kLines) */
    DATA_TYPE_AVERAGE_264 ,     /* do not change this index(for kLines) */
    DATA_TYPE_HIG ,             /* do not change this index(for kLines) */
    DATA_TYPE_LOW ,             /* do not change this index(for kLines) */
    DATA_TYPE_OPEN ,
    DATA_TYPE_AVG ,
    DATA_TYPE_AMP ,
    DATA_TYPE_VOL ,
    DATA_TYPE_VAL ,
    DATA_TYPE_LVAL ,
    DATA_TYPE_YSTD ,
    DATA_TYPE_PWR ,
    DATA_TYPE_XCG ,
    DATA_TYPE_DATE ,
    DATA_TYPE_EAGER ,
    DATA_TYPE_RSI6 ,        /* stock index, do not change its position */
    DATA_TYPE_RSI12 ,       /* stock index, do not change its position */
    DATA_TYPE_RSI24 ,       /* stock index, do not change its position */
    DATA_TYPE_PWRI6 ,       /* stock index, do not change its position */
    DATA_TYPE_PWRI12 ,      /* stock index, do not change its position */
    DATA_TYPE_PWRI24 ,      /* stock index, do not change its position */
    DATA_TYPE_RSI_CUSTOM ,       /* stock index, do not change its position */
    DATA_TYPE_PWRI_CUSTOM ,      /* stock index, do not change its position */
    DATA_TYPE_XCGI_CUSTOM,      /* stock index, do not change its position */
    NUMBERS_OF_DATA_TYPE    /* after and ONLY after indexer type */
} ;

enum PAINT_TYPE{
    PAINT_TYPE_LINE = 0 ,
    PAINT_TYPE_FILLED_RECT
} ;

enum SYS_SWITCH_KEY{
    REFRESH_VIEW=0,
    REFRESH_DATA,
    CUTTING_HISTORY,
    MEASURE,
    SHOW_FORECAST,
    LOCK_SCREEN,
    SHOW_DAILY,
    AUTO_FIT
} ;

/* declare for daily */
enum DAILY_DATA_TYPE{
    DAILY_DATA_TYPE_CLS = 0,    // before restructing, keep the order unchange
    DAILY_DATA_TYPE_CLS_AVG,    // before restructing, keep the order unchange, just the average of ARITHMETIC, NOT the DEAL average
    DAILY_DATA_TYPE_DEAL_AVG,   // before restructing, keep the order unchange
    DAILY_DATA_TYPE_CLS_DEAL_AVG_DIFF2, // before restructing, keep the order unchange
    DAILY_DATA_TYPE_CLSSECT_DEALSECT_DIFF,  // before restructing, keep the order unchange
    DAILY_DATA_TYPE_CLSSECT_DEALSECT_DIFF2,  // before restructing, keep the order unchange
    DAILY_DATA_TYPE_VOL,
    DAILY_DATA_TYPE_VOLSECT,        // combine with DAILY_DATA_TYPE_VOLSECT_AVG
    DAILY_DATA_TYPE_VOLSECT_AVG,    // combine with DAILY_DATA_TYPE_VOLSECT, the data is fixed, the index of 0~6 are SPECIAL data
    DAILY_DATA_TYPE_VAL,
    DAILY_DATA_TYPE_VALSECT,
    DAILY_DATA_TYPE_DEAL_SECT,
    DAILY_DATA_TYPE_VAL_UP,
    DAILY_DATA_TYPE_VAL_DN,
    DAILY_DATA_TYPE_VOL_UP,
    DAILY_DATA_TYPE_VOL_DN,
    DAILY_DATA_TYPE_DEAL_UPDN_DIFF,
    DAILY_DATA_TYPE_DEALSECT_UPDN_DIFF,

    NUMBERS_OF_DAILY_DATA_TYPE
} ;

using namespace cv;
using namespace std;
using namespace cv::dnn;

typedef int(*digtFuncPt)(char digitalKey);
int digtFuncBaselineFilter( char c);
int digtFuncLineFilter( char c);
int digtFuncIndexFilter( char c);
int digtFuncScale( char c);

/* define & init */
/* color-list for lines */
static Scalar  lineColors[MAX_LINES] = {
                        Scalar(255,50,50),
                        Scalar(0,255,0),
                        Scalar(255,255,0),
                        Scalar(255,0,255),
                        Scalar(0,0,255),
                        Scalar(0,255,255),
                        Scalar(0,0,150),
                        Scalar(255,255,255)
                    } ;
static digtFuncPt digtFuncList[] = {                // this struct for 0~9(digital keys) function switch.
                        digtFuncBaselineFilter,
                        digtFuncLineFilter,
                        digtFuncIndexFilter,
                        digtFuncScale
                    } ;


static unsigned int     sysSwitchers = 0 ;
static unsigned int     baseLineSwitchers = (3<<2) ;        // if (MAX_LINES > sizeof(int)*8), this maybe take you to a fault!!
static unsigned int     linesSwitchers = (0xffff & (~((1<<1)|(1<<6)|(1<<7))));   // comments here, same with above line's!!
static unsigned int     indexSwitchers = ((1<<0)|(1<<4));   // rsi6 & pwri12

static unsigned char    digtFuncIdx = 3 ;
static int              scale = 1 ;     // for x-coordinates
static int              dataFixType = DATA_FIX_TYPE_BACKWARD ;
static double           rsiFuture6 = 0.0 ;
static double           pwriFuture12 = 0.0 ;
static int              rsiCustom=12 ;
static int              pwriCustom=12 ;
static int              xcgAvgICustom=12 ;
static string           stockId("") ;
static string           stockName("") ;
static int              forecastIdx = 0 ;
static float            forecastCoefficients[FORECAST_DATA_DAYS]={0} ;


#define  DATA_RANGE_UNSET   (-MAX_DAYS_NUM -255)
#define  IDX_RANGE_UNSET    (-MAX_DAYS_NUM -255)
static int              dataRangeEnd=DATA_RANGE_UNSET;     // NOT include dataRangeEnd(last index is dataRangeEnd-1)
static int              dataRangeStart=DATA_RANGE_UNSET;   // all x-coordinate SHOULD(MUST!!) base on the dataRangeStart
static int              measureIdx = IDX_RANGE_UNSET ;
static int              cuttingIdx = IDX_RANGE_UNSET ;
static int              dtlsIdxOnMainView = IDX_RANGE_UNSET ;
static int              gPanelX = 0 ;
static int              gPanelY = 0 ;
static int              gPanelW = MAX_WIN_WIDTH ;
static int              gPanelH = MAX_WIN_HEIGHT ;
Mat gPanel, gMainView, gBottomView, gIndexView, gTopStatus_view, gLeftDetailsView, gMessData;
Mat gLinesData, gLinesInfo, gYstdData, gHigData, gLowData, gOpenData, gAmpData, gXcgData, gVolData, gValData, gLvalData,
    gKLine5, gKLine22, gKLine66, gKLine132, gKLine264,
    gPwrData, gDateData, gEgrData, gRsi6Data, gRsi12Data, gRsiCustomData, gRsi24Data, gPwri6Data, gPwri12Data, gPwriCustomData, gPwri24Data, gXcgAvgICustomData ;

#define DAILY_PANEL_W       (MAX_DAILY_CNT+60)
#define DAILY_PANEL_H_SMALL (MAX_WIN_HEIGHT/4-16)
#define DAILY_PANEL_H_BIG   (DAILY_PANEL_H_SMALL*2)

#define DAILY_VOL_DISP_TYPE_NOR     (0)
#define DAILY_VOL_DISP_TYPE_UPDN    (1) // display vol with up dn
#define DAILY_VOL_DISP_TYPE_AVG     (2) // display average vol
#define DAILY_VOL_DISP_TYPE_COUNT   (3)

static bool     gBigDailyView = true ;
static int      gWinOrder = 0 ;         // 0 means only this window will be displayed.
static int      gDailyTimeline = 1 ;    // to avoid div 0
static int      gDailyVolDispType = DAILY_VOL_DISP_TYPE_AVG ;
static Mat      gDailyViewHalfHourRefPos(1, MAX_DAILY_CNT/(3600/2/GAP_SECOND), CV_16S, Scalar::all(0) );
static Mat      gDailyCls, gDailyClsAvg, gDailyDealAvg, gDailyVol, gDailyVolSect, gDailyVal, gDailyClsDealAvgDiff2, gDailyMessData ;
static Mat      gDailyPanel ;
static double   gDailyClose, gDailyHigh, gDailyLow, gDailyVolume, gDailyValue, gDailyOpen, gDailyYestodayClose, gDailyDealAverage, gDailyPriceAverage,
                gDailyDealUp, gDailyValUp, gDailyVolUp, gDailyDealDn, gDailyValDn, gDailyVolDn ;
#ifdef THREAD_SUPPORT
static          pthread_mutex_t  gMutex ;
#endif

inline void CLEAN_SWITCHERS(unsigned int* switcher )
{
    memset(switcher, 0, sizeof(unsigned int) ) ;
}

inline void SETALL_SWITCHERS( unsigned int* switcher )
{
    memset(switcher, 0xff, sizeof(unsigned int) ) ;
}

inline void TOGGLE_SWITCH(unsigned int* switcher, int position )
{
    (*switcher) ^= 1 << (position) ;
}

inline bool GET_SWITCHER_STATUS(unsigned int switcher, int position )
{
    return (switcher & (1 << (position) )) ;
}

inline void RESET_SWITCHER_STATUS(unsigned int* switcher, int position )
{
    (*switcher) &= ~(1 << (position)) ;
}

inline void SET_SWITCHER_STATUS(unsigned int* switcher, int position )
{
#if THREAD_SUPPORT
    pthread_mutex_lock(&gMutex) ;
#endif
    (*switcher) |= 1 << (position) ;
#if THREAD_SUPPORT
    pthread_mutex_unlock(&gMutex) ;
#endif
}

/* return the first displayed index of data */
int paintDataUpDn(
        const Mat&      data,
        const Mat&      sign,
        const Mat&      panel,
        const int&      scale,
        const Rect&     roi,
        const Scalar&   colorBase,
        const Scalar&   colorUp,
        const Scalar&   colorDn,
        const int&      type,
        const bool&     reversal
        )
{
    Mat     _m ;
    int     _idxS ;

    data.convertTo(_m, CV_64F) ;

    if( PAINT_TYPE_FILLED_RECT == type )     /* rectangle */
    {
        int     _x, _y, _col;
        double  _t ;
        Scalar  _color ;

        /* postive vol is INCREASE, use RED color,
           negative vol is DECRES, use GREEN color */

        _idxS=_m.cols-GET_COUNT_OF_VIEW(roi.width+LINE_MARGIN_L+LINE_MARGIN_R,scale) ;
        if(_idxS<0) _idxS=0 ;

        for(_col=_idxS; _col < _m.cols; _col++){
            _t = _m.at<double>(0, _col) ;
            _x = (_col-_idxS)*scale + roi.x ;
            _y = (reversal) ? roi.height- abs(_t) - 1 + roi.y : abs(_t) + roi.y ;

            _color = (sign.at<char>(0,_col)==0)
                   ? colorBase
                   : (sign.at<char>(0,_col)>0) ? colorUp : colorDn ;

            rectangle( panel, Point( _x, _y ), Point( _x+scale-1, (reversal) ? 0+roi.x+roi.height-1 : 0+roi.y), _color, FILLED, LINE_8 );
        }

    }else if (PAINT_TYPE_LINE == type){    /* line */
        Point               _ps;
        Point               _pe;
        double              _t;
        int                 _col ;
        Scalar              _color ;

        _idxS=_m.cols-GET_COUNT_OF_VIEW(roi.width+LINE_MARGIN_L+LINE_MARGIN_R,scale) ;
        if(_idxS<0) _idxS=0 ;
        _ps = Point( 0*scale + scale/2 +roi.x, roi.height-1 - _m.at<double>(0, _idxS) + roi.y );

        for(_col = _idxS ; _col < _m.cols ; _col++){
            _t = _m.at<double>(0, _col) ;
            _pe = (reversal)
                ? Point( (_col-_idxS)*scale + scale/2 +roi.x, roi.height-1 - abs(_t) + roi.y)
                : Point( (_col-_idxS)*scale + scale/2 +roi.x, abs(_t)+roi.y) ;

            _color = (sign.at<char>(0,_col)==0)
                   ? colorBase
                   : (sign.at<char>(0,_col)>0) ? colorUp : colorDn ;

            line( panel, _ps, _pe, _color, 1, LINE_AA);
            _ps = _pe;
        }
    }

    return _idxS ;
}

/* return the first displayed index of data */
int paintData(
        const Mat&      data,
        const Mat&      panel,
        const int&      scale,
        const Rect&     roi,
        const Scalar&   color,
        const int&      type,
        const bool&     reversal
        )
{
    Mat     _m ;
    int     _idxS ;

    data.convertTo(_m, CV_64F) ;

    if( PAINT_TYPE_FILLED_RECT == type )     /* rectangle */
    {
        int     _x, _y, _col;
        double  _t ;


        /* postive vol is INCREASE, use RED color,
           negative vol is DECRES, use GREEN color */

        _idxS=_m.cols-GET_COUNT_OF_VIEW(roi.width+LINE_MARGIN_L+LINE_MARGIN_R,scale) ;
        if(_idxS<0) _idxS=0 ;

        for(_col=_idxS; _col < _m.cols; _col++){
            _t = _m.at<double>(0, _col) ;
            _x = (_col-_idxS)*scale + roi.x ;
            _y = (reversal) ? roi.height- abs(_t) - 1 + roi.y : abs(_t) + roi.y ;

            rectangle( panel, Point( _x, _y ), Point( _x+scale-1, (reversal) ? 0+roi.x+roi.height-1 : 0+roi.y), color, FILLED, LINE_8 );
        }

    }else if (PAINT_TYPE_LINE == type){    /* line */
        Point               _ps;
        Point               _pe;
        double              _t;
        int                 _col ;

        _idxS=_m.cols-GET_COUNT_OF_VIEW(roi.width+LINE_MARGIN_L+LINE_MARGIN_R,scale) ;
        if(_idxS<0) _idxS=0 ;
        _ps = Point( 0*scale + scale/2 +roi.x, roi.height-1 - _m.at<double>(0, _idxS) + roi.y );

        for(_col = _idxS ; _col < _m.cols ; _col++){
            _t = _m.at<double>(0, _col) ;
            _pe = (reversal)
                ? Point( (_col-_idxS)*scale + scale/2 +roi.x, roi.height-1 - abs(_t) + roi.y)
                : Point( (_col-_idxS)*scale + scale/2 +roi.x, abs(_t)+roi.y) ;
            line( panel, _ps, _pe, color, 1, LINE_AA);
            _ps = _pe;
        }
    }

    return _idxS ;
}

int drawKLines(
        const Mat&      linesData,
        const Mat&      panel,
        const int&      scale,
        const Rect&     roi
        )
{
    Point       _ps;
    Point       _pe;
    Point       _ofs;
    Scalar      _color;
    Size        _orgMatrixSize;

    /* get line's origin position */
    linesData.locateROI( _orgMatrixSize, _ofs );

    for(int _lineIdx = 0 ; _lineIdx < linesData.rows; _lineIdx ++){

        if( 0 == GET_SWITCHER_STATUS(linesSwitchers, _lineIdx + _ofs.y) ){
            /* this line is disabled, do not draw it */
            continue ;
        }

        _color = ( 3 == panel.channels() )
               ? lineColors[ min( _lineIdx,  MAX_LINES - 1 ) ]
               : Scalar(255,0,0) ;
        paintData(linesData.row(_lineIdx), panel, scale, roi, _color, PAINT_TYPE_LINE, true) ;
    }

    return 0;
}

double _getTT(const Mat &m, Mat &out, size_t days, bool absCalc, bool checkLastOne)
{
    size_t  i = 0 ;
    size_t  _first = 0 ;
    double  _tt = 0 ;

    _first = checkLastOne ? max(0, m.cols - (int)days) : 0 ;

    for(i = _first; i < m.cols; i++){
        _tt += absCalc ? abs(m.at<double>(0,i)) : m.at<double>(0,i) ;

        if( i-_first >= days )
            _tt -= absCalc ? abs(m.at<double>(0,i-days)) : m.at<double>(0,i-days) ;

        if(!checkLastOne) out.at<double>(0,i) = _tt ;
    }

    return (checkLastOne ? _tt : 0) ;
}

double _getAvg(const Mat &m, Mat &out, size_t days, bool checkLastOne)
{
    size_t  i = 0 ;
    size_t  _first = 0 ;
    double  _tt = 0, _avg = 0 ;

    _first = checkLastOne ? max(0, m.cols - (int)days) : 0 ;

    for(i = _first; i < m.cols; i++){
        _tt += m.at<double>(0,i) ;

        if( i-_first >= days )
            _tt -= m.at<double>(0,i-days) ;

        _avg = _tt / min(i-_first+1,days) ;

        if(!checkLastOne) out.at<double>(0,i) = _avg ;
    }

    return (checkLastOne ? _avg : 0) ;
}

double _getAvgRateIndexer(const Mat &m, Mat &out, size_t days, bool checkLastOne)
{
    size_t  i = 0 ;
    size_t  _first = 0 ;
    double  _tt = 0, _avg = 0, _rate=0, _rateIndexer=0 ;

    _first = checkLastOne ? max(0, m.cols - (int)days) : 0 ;

    for(i = _first; i < m.cols; i++){
        _tt += m.at<double>(0,i) ;

        if( i-_first >= days )
            _tt -= m.at<double>(0,i-days) ;

        _avg = _tt / min(i-_first+1,days) ;
        _rate = m.at<double>(0,i)/max(_avg,0.000001) ;
        _rateIndexer = 100.0 - 100.0/(1+_rate) ;

        if(!checkLastOne) out.at<double>(0,i) = _rateIndexer ;
    }

    return (checkLastOne ? _rateIndexer : 0) ;
}

double _getUpDnRateIndexer(const Mat &m, Mat &out, size_t days, bool positiveSrc, bool checkLastOne)
{
    size_t  i = 0 ;
    size_t  _first = 0 ;
    double  _t = 0, _up = 0, _dn = 0, _rate=0, _rateIndexer=0 ;

    _first = checkLastOne ? max(0, m.cols - (int)days) : 0 ;

    for (i = _first ; i < m.cols ; i ++){
        /* add current to total */
        if(positiveSrc){

            _t = (i > 0) ? (m.at<double>(0,i) - m.at<double>(0,i-1) ) / max(m.at<double>(0,i-1),0.000001) : 0 ;
        }else{
            _t = m.at<double>(0,i) ;
        }
        (_t > 0) ? _up += _t : _dn -= _t ;

        /* remove the first if it is out of the range */
        if(i-_first >= days){
            if(positiveSrc){
                _t = (i-days > 0) ? (m.at<double>(0,i-days) - m.at<double>(0,i-days-1) ) / max(m.at<double>(0,i-days-1),0.000001) : 0 ;
            }else{
                _t = m.at<double>(0,i-days) ;
            }
            (_t > 0) ? _up -= _t : _dn += _t ;
        }

        /* caculate indexer value */
        _rate = _up / max(_dn,0.000001) ;
        _rateIndexer = 100.0 - 100.0/(1+_rate) ;

        if(!checkLastOne) out.at<double>(0,i) = _rateIndexer ;
    }

    return (checkLastOne ? _rateIndexer : 0) ;
}

int importData(
        const char*  hisFilename,
        const char*  hotFilename,
        const int    dataFixType,
        Mat&         outputMat,
        Mat&         outputDailyMat
        )
{
#if 0
    {
        cout << hisFilename << endl ;
        cout << hotFilename << endl ;
    }
#endif

    Mat             _m ;
    ifstream        _hisData ;
    ifstream        _hotData ;
    string          _tmpStr ;
    stringstream    _tmpSS ;
    string          _crntDate ;
    string          _code ;
    string          _name ;
    string          _date ;
    string          _time ;
    int             _yyyy = 0, _mm = 0, _dd  = 0 ;
    int             _lastTimeline = 0 ;
    double          _close  = 0 ;
    double          _high  = 0 ;
    double          _lower  = 0 ;
    double          _open  = 0 ;
    double          _ystdClose  = 0 ;
    double          _amplitude  = 0 ;
    double          _exchange  = 0 ;
    double          _volume  = 0 ;
    double          _value  = 0 ;
    double          _liveValue = 0 ;
    double          _liveValueYstd = 0 ;
    double          _ampValue = 0 ;
    double          _totalValue = 0 ;
    double          _dealNum = 0 ;
    double          _average5  = 0 ;
    double          _total5  = 0 ;
    double          _average22  = 0 ;
    double          _total22  = 0 ;
    double          _average66  = 0 ;
    double          _total66 = 0 ;
    double          _average132  = 0 ;
    double          _total132 = 0 ;
    double          _average264  = 0 ;
    double          _total264  = 0 ;
    int             _upDays = 0 ;
    double          _eager= 0 ;
    int             i = 0 ;

    _hisData.open(hisFilename, ifstream::in) ;
    _hotData.open(hotFilename, ifstream::in) ;

    /* get the last date. 
       we regard the hotData as the current day's data.
       so, the history data should be after the date is great than hotData's
       */
    if(getline(_hotData, _tmpStr)){
        _crntDate = _tmpStr.substr(0,10) ;

        /* reopen the hotData file */
        _hotData.close() ;
        _hotData.open(hotFilename, ifstream::in) ;
    }

    _m.create(NUMBERS_OF_DATA_TYPE, MAX_DAYS_NUM, CV_64F) ;
    _m.setTo(Scalar(0)) ;

    /* reset/recored HalfHourRef position info */
    gDailyViewHalfHourRefPos.setTo(Scalar(0)) ;

    /* extract history&hot data */
    {
        Mat _linesData, _dateData, _higData, _lowData, _opnData, _ystdData, _ampData, _xcgData, _volData, _valData, _avrgPrice, _lvalData,
            _pwrData, _egrData, _rsi6Data, _rsi12Data, _rsi24Data, _pwri6Data, _pwri12Data, _pwri24Data,
            _xcgAvgICustomData, _rsiCustomData, _pwriCustomData;

        _linesData         = _m.rowRange(DATA_TYPE_CLOSE, DATA_TYPE_LOW+1) ;
        _dateData          = _m.row(DATA_TYPE_DATE) ;
        _higData           = _m.row(DATA_TYPE_HIG) ;
        _lowData           = _m.row(DATA_TYPE_LOW) ;
        _opnData           = _m.row(DATA_TYPE_OPEN) ;
        _ystdData          = _m.row(DATA_TYPE_YSTD) ;
        _ampData           = _m.row(DATA_TYPE_AMP) ;
        _xcgData           = _m.row(DATA_TYPE_XCG) ;
        _volData           = _m.row(DATA_TYPE_VOL) ;
        _valData           = _m.row(DATA_TYPE_VAL) ;
        _avrgPrice         = _m.row(DATA_TYPE_AVG) ;
        _lvalData          = _m.row(DATA_TYPE_LVAL) ;
        _pwrData           = _m.row(DATA_TYPE_PWR) ;
        _egrData           = _m.row(DATA_TYPE_EAGER) ;
        _rsi6Data          = _m.row(DATA_TYPE_RSI6) ;
        _rsi12Data         = _m.row(DATA_TYPE_RSI12) ;
        _rsi24Data         = _m.row(DATA_TYPE_RSI24) ;
        _pwri6Data         = _m.row(DATA_TYPE_PWRI6) ;
        _pwri12Data        = _m.row(DATA_TYPE_PWRI12) ;
        _pwri24Data        = _m.row(DATA_TYPE_PWRI24) ;
        _xcgAvgICustomData = _m.row(DATA_TYPE_XCGI_CUSTOM) ;
        _rsiCustomData     = _m.row(DATA_TYPE_RSI_CUSTOM) ;
        _pwriCustomData    = _m.row(DATA_TYPE_PWRI_CUSTOM) ;

        if(!_hisData){
            cerr << "cannot open file " << hisFilename << endl ;
            return -1 ;
        }

        /* loop items in the history & hot files and append forecastData */
        {
            int     _dataCnt = 0 ;
            int     _posOfCuttedHis = 0 ;
            bool    _hisDataIsGot = false ;
            bool    _hotDataIsGot = false ;

            if(!GET_SWITCHER_STATUS(sysSwitchers,LOCK_SCREEN) || !GET_SWITCHER_STATUS(sysSwitchers,CUTTING_HISTORY))  cuttingIdx = IDX_RANGE_UNSET ;

            /* get items from history & hot files */
            while(1){
                if(false == _hisDataIsGot && getline(_hisData, _tmpStr)){     // history data
                    if(cuttingIdx != IDX_RANGE_UNSET && _dataCnt > cuttingIdx){
                        /* do not load cutting data */
                        _hisDataIsGot = true ;
                        continue ;
                    }
                    if(!_crntDate.empty() && _crntDate <= _tmpStr.substr(0,10)){ 
                        /* do not load the data which behind the _crntDate(the date of hotData) */
                        _hisDataIsGot = true ;
                        continue ;
                    }
                }else{                              // hot data
                    static Mat  _dailyData(NUMBERS_OF_DAILY_DATA_TYPE, MAX_DAILY_CNT,CV_64F) ;
                    string      _lastHotData = "" ;
                    int         _cnt = 0 ;

                    if(_hotDataIsGot) break ;       // does not need, reserv for later

                    _dailyData.setTo(Scalar(0));

                    /* import each daily item (base item) */
                    while(getline(_hotData, _tmpStr)){
                        if(_cnt<MAX_DAILY_CNT){
                            _tmpSS.clear() ;
                            _tmpSS.str(_tmpStr) ;
                            _tmpSS >> _date >> _code >> _name >> gDailyClose >> gDailyHigh
                                   >> gDailyLow >> gDailyOpen >> gDailyYestodayClose >> _ampValue >> _amplitude
                                   >> _exchange >> gDailyVolume >> gDailyValue >> _totalValue >> _liveValue
                                   >> _dealNum >> _time ;
                            /* update close price */
                            _dailyData.at<double>(DAILY_DATA_TYPE_CLS, _cnt) = gDailyClose ;
                            /* update volume */
                            _dailyData.at<double>(DAILY_DATA_TYPE_VOL, _cnt) = gDailyVolume ;
                            /* update value */
                            _dailyData.at<double>(DAILY_DATA_TYPE_VAL, _cnt) = gDailyValue ;
                            /* update DEAL AVG */
                            if(_cnt == 0){
                                gDailyDealAverage = gDailyClose ;
                            }else if(gDailyVolume == 0 || gDailyValue == 0){
                                gDailyDealAverage = _dailyData.at<double>(DAILY_DATA_TYPE_DEAL_AVG, _cnt-1) ;
                            }else if(IS_BIG_DISK(stockId)){
                                gDailyDealAverage = (gDailyClose+_cnt*_dailyData.at<double>(DAILY_DATA_TYPE_DEAL_AVG, _cnt-1))/(_cnt+1) ;
                            }else{
                                gDailyDealAverage = gDailyValue/gDailyVolume ;
                            }
                            _dailyData.at<double>(DAILY_DATA_TYPE_DEAL_AVG, _cnt) = gDailyDealAverage ;
                            /* update volume of each unit */
                            if(_cnt == 0){
                                _dailyData.at<double>(DAILY_DATA_TYPE_VOLSECT, _cnt) = gDailyVolume ;
                            }else{
                                _dailyData.at<double>(DAILY_DATA_TYPE_VOLSECT, _cnt) = gDailyVolume - _dailyData.at<double>(DAILY_DATA_TYPE_VOL, _cnt-1) ;
                            }
                            /* update value of each unit */
                            if(_cnt == 0){
                                _dailyData.at<double>(DAILY_DATA_TYPE_VALSECT, _cnt) = gDailyValue ;
                            }else{
                                _dailyData.at<double>(DAILY_DATA_TYPE_VALSECT, _cnt) = gDailyValue - _dailyData.at<double>(DAILY_DATA_TYPE_VAL, _cnt-1) ;
                            }
                            /* update duration */
                            {
                                int _h, _m, _s ;

                                _h = (_time[0]-'0')*10+_time[1]-'0' ;
                                _m = (_time[3]-'0')*10+_time[4]-'0' ;
                                _s = (_time[6]-'0')*10+_time[7]-'0' ;
                                gDailyTimeline = _h*3600 + _m*60 + _s ;

                                /* ignore invalide data */
                                if(gDailyTimeline < _lastTimeline) continue ;
                                _lastTimeline = gDailyTimeline ;

                                if(gDailyTimeline <= 11*3600 + 30*60){      // a.m.
                                    gDailyTimeline -= (9*3600 + 30*60) ;
                                }else if(gDailyTimeline < 13*3600){         // whole a.m.
                                    gDailyTimeline = 2*3600 ;
                                }else if(gDailyTimeline <= 15*3600){        // a.m. +p.m.
                                    gDailyTimeline = 2*3600 + (gDailyTimeline - 13*3600) ;
                                }else{                                      // whole day
                                    gDailyTimeline = 4*3600 ;
                                }

                                gDailyTimeline /= GAP_SECOND ;
                                gDailyTimeline = (gDailyTimeline<=0) ? 1 : gDailyTimeline ;
                                //cerr << _h << ":" << _m << ":" << _s << " " << gDailyTimeline << endl ;

                                /* set HalfHourRef position info */
                                {
                                    if((gDailyTimeline%(3600/2/GAP_SECOND)) <= 3 && 
                                        gDailyTimeline >= (3600/2/GAP_SECOND) && 
                                        gDailyTimeline < MAX_DAILY_CNT -1){
                                        gDailyViewHalfHourRefPos.at<short>(0,gDailyTimeline/(3600/2/GAP_SECOND) -1) = _cnt ;
                                        //cerr << "set gDailyViewHalfHourRefPos " << gDailyTimeline/(3600/2/GAP_SECOND)-1 << " to " << _cnt << endl ;
                                    }
                                }
                            }

                            _cnt ++ ;
                        }

                        _lastHotData = _tmpStr ;
                    }

                    /* daily base item has loaded */
                    outputDailyMat = _dailyData.colRange(0,_cnt) ;

                    /* now, outputDailyMat is stable. let's do some more caculation according the base item */
                    if(outputDailyMat.cols>0)
                    {
                        /* get CLS_AVG */
                        {
                            Mat _n ;
                            _n = outputDailyMat.row(DAILY_DATA_TYPE_CLS_AVG);
                            _getAvg(outputDailyMat.row(DAILY_DATA_TYPE_CLS), _n, MAX_DAILY_CNT, false) ; // little trick. use MAX_DAILY_CNT to get the average(from 0 to last)
                        }

                        /* update VOL_SECT_AVG VOLSEC_AVG */
                        {
                            Mat _n ;
                            _n = outputDailyMat.row(DAILY_DATA_TYPE_VOLSECT_AVG);
                            _getAvg(outputDailyMat.row(DAILY_DATA_TYPE_VOLSECT), _n, 1*60/(GAP_SECOND), false) ;      // get average for 1 minutes

                            /* as history vol be? used, and it effected by FORWARD_FIXING/BACKWORD_FIXING, we put this code after FORWARD_FIXING/BACKWARD_FIXING
                               reset the first 7 elements(for reference)
                               index 2, vol_section_average_10days_ref,
                               index 1, vol_section_average_10days_ref * 2,
                               index 0, vol_section_average_10days_ref * 4,
                               index 3/5/6, reserved for later,
                               index 4, current vol_section_average */
                        }

                        /*  */
                        {
                            int i ;
                            Mat _dealAvg = outputDailyMat.row(DAILY_DATA_TYPE_DEAL_AVG) ;
                            Mat _clsAvg  = outputDailyMat.row(DAILY_DATA_TYPE_CLS_AVG) ;
                            Mat _diff2 = outputDailyMat.row(DAILY_DATA_TYPE_CLS_DEAL_AVG_DIFF2) ;

                            for(i=0; i<outputDailyMat.cols; i++){
                                _diff2.at<double>(0,i) = _clsAvg.at<double>(0,i) + 8*( _dealAvg.at<double>(0,i) -_clsAvg.at<double>(0,i)) ;
                            }
                        }

                        /* get DAILY_DATA_TYPE_DEAL_SECT */
                        {
                            outputDailyMat.row(DAILY_DATA_TYPE_DEAL_SECT) = outputDailyMat.row(DAILY_DATA_TYPE_VALSECT) / outputDailyMat.row(DAILY_DATA_TYPE_VOLSECT) ;
                        }

                        /* get  DAILY_DATA_TYPE_CLSSECT_DEALSECT_DIFF & DAILY_DATA_TYPE_CLSSECT_DEALSECT_DIFF2 */
                        {
                            int i ;
                            Mat _dealSect = outputDailyMat.row(DAILY_DATA_TYPE_DEAL_SECT) ;
                            Mat _clsAvg1(1,outputDailyMat.cols,CV_64F) ;
                            Mat _clsAvg2(1,outputDailyMat.cols,CV_64F) ;
                            Mat _dealAvg1(1,outputDailyMat.cols,CV_64F) ;
                            Mat _dealAvg2(1,outputDailyMat.cols,CV_64F) ;

                            _getAvg(outputDailyMat.row(DAILY_DATA_TYPE_CLS), _clsAvg1, 1*60/(GAP_SECOND), false) ;
                            _getAvg(outputDailyMat.row(DAILY_DATA_TYPE_CLS), _clsAvg2, 1*60/2/(GAP_SECOND), false) ;
                            _getAvg(_dealSect, _dealAvg1, 1*60/(GAP_SECOND), false) ;
                            _getAvg(_dealSect, _dealAvg2, 1*60/2/(GAP_SECOND), false) ;

                            outputDailyMat.row(DAILY_DATA_TYPE_CLSSECT_DEALSECT_DIFF) = _clsAvg1 + 8*(_dealAvg1 - _clsAvg1) ;
                            outputDailyMat.row(DAILY_DATA_TYPE_CLSSECT_DEALSECT_DIFF2) = _clsAvg2 + 8*(_dealAvg2 - _clsAvg2) ;
                        }

                        /* */
                        {
                            int i=0, j=0 ;
                            int _refStart=0 ;
                            double _d=0 ;
                            Mat _volSect=outputDailyMat.row(DAILY_DATA_TYPE_VOLSECT) ;
                            Mat _valSect=outputDailyMat.row(DAILY_DATA_TYPE_VALSECT) ;
                            Mat _dealSect=outputDailyMat.row(DAILY_DATA_TYPE_DEAL_SECT) ;
                            Mat _valUp=outputDailyMat.row(DAILY_DATA_TYPE_VAL_UP) ;
                            Mat _valDn=outputDailyMat.row(DAILY_DATA_TYPE_VAL_DN) ;
                            Mat _volUp=outputDailyMat.row(DAILY_DATA_TYPE_VOL_UP) ;
                            Mat _volDn=outputDailyMat.row(DAILY_DATA_TYPE_VOL_DN) ;
                            Mat _dealUpDnDiff=outputDailyMat.row(DAILY_DATA_TYPE_DEAL_UPDN_DIFF) ;
                            Mat _dealSectUpDnDiff=outputDailyMat.row(DAILY_DATA_TYPE_DEALSECT_UPDN_DIFF) ;

                            gDailyVolUp = gDailyVolDn = gDailyValUp = gDailyValDn = gDailyDealUp = gDailyDealDn = 0 ;

                            for(i=0,j=0; i<_dealSect.cols; i++){
                                if(i==0){
                                    _d = 0 ;
                                }else{
                                    _d = _dealSect.at<double>(0,i) - _dealSect.at<double>(0,j) ; 
                                    if(_d >= 0.001) _d = 1 ;
                                    else if(_d <= -0.001) _d = -1 ;
                                    else _d = 0 ;
                                }

                                if(_d==0){
                                    gDailyVolUp += _volSect.at<double>(0,i) ;
                                    gDailyValUp += _valSect.at<double>(0,i) ;
                                    gDailyVolDn += _volSect.at<double>(0,i) ;
                                    gDailyValDn += _valSect.at<double>(0,i) ;
                                }else if(_d>0){
                                    gDailyVolUp += _volSect.at<double>(0,i) ;
                                    gDailyValUp += _valSect.at<double>(0,i) ;
                                    j=i ;
                                }else{
                                    gDailyVolDn += _volSect.at<double>(0,i) ;
                                    gDailyValDn += _valSect.at<double>(0,i) ;
                                    j=i ;
                                }

                                _valUp.at<double>(0,i) =  gDailyValUp ;
                                _valDn.at<double>(0,i) =  gDailyValDn ;
                                _volUp.at<double>(0,i) =  gDailyVolUp ;
                                _volDn.at<double>(0,i) =  gDailyVolDn ;
                                assert(gDailyVolUp > 0 && gDailyVolDn > 0) ;
                                gDailyDealUp = gDailyValUp / gDailyVolUp ;
                                gDailyDealDn = gDailyValDn / gDailyVolDn ;
                                _dealUpDnDiff.at<double>(0,i) = (gDailyDealUp - gDailyDealDn);
                                //if(i>=2 && _dealUpDnDiff.at<double>(0,i-2)*_dealUpDnDiff.at<double>(0,i-1)<0) _refStart=i-1 ;
                                //cerr << gDailyDealUp/gDailyDealDn << endl ;
                                if(i == _refStart){
                                    _dealSectUpDnDiff.at<double>(0,i)=0 ;
                                }else{
                                    _dealSectUpDnDiff.at<double>(0,i)=
                                        (_valUp.at<double>(0,i)-_valUp.at<double>(0,_refStart))/(_volUp.at<double>(0,i)-_volUp.at<double>(0,_refStart))-
                                        (_valDn.at<double>(0,i)-_valDn.at<double>(0,_refStart))/(_volDn.at<double>(0,i)-_volDn.at<double>(0,_refStart));
                                }
                            }

                            /*
                            cerr << "valUp" << endl << _valUp << endl ;
                            cerr << "volUp" << endl << _volUp << endl ;
                            cerr << "valDn" << endl << _valDn << endl ;
                            cerr << "volDn" << endl << _volDn << endl ;
                            cerr << "dealSect" << _dealSectUpDnDiff << endl ;
                            */

                            //cerr << "Up  " << gDailyDealUp << "(" << gDailyValUp/1000000 << "/" << gDailyVolUp/1000000 << ")" << endl ;
                            //cerr << "Dn  " << gDailyDealDn << "(" << gDailyValDn/1000000 << "/" << gDailyVolDn/1000000 << ")" << endl ;
                            //cout << "Cnt " << gDailyClose << endl ;
                        }
                    }

                    /* get the last one as the the hotData */
                    if(GET_SWITCHER_STATUS(sysSwitchers, SHOW_FORECAST) || _lastHotData == "") break ;

                    _tmpStr = _lastHotData ;
                    _hotDataIsGot = true ;
                }

                if(_dataCnt >= MAX_DAYS_NUM){
                    cerr << "out of range, MAX_DAYS_NUM =" << MAX_DAYS_NUM << endl ;
                    break ;
                }

                /* extract data */
                {
                    _tmpSS.clear() ;
                    _tmpSS.str(_tmpStr) ;
                    _tmpSS >> _date >> _code >> _name >> _close >> _high
                           >> _lower >> _open >> _ystdClose >> _ampValue >> _amplitude
                           >> _exchange >> _volume >> _value >> _totalValue >> _liveValue
                           >> _dealNum ;
                    _code = _code.substr(1) ;
                }

                /* update normal data to matrix */
                {
                    _linesData.at<double>(0,_dataCnt) = _close ;
                    _higData.at<double>(0,_dataCnt)  = _high ;
                    _lowData.at<double>(0,_dataCnt)  = _lower ;
                    _opnData.at<double>(0,_dataCnt)  = _open ;
                    _ystdData.at<double>(0,_dataCnt) = (_ystdClose<=0) ? _open : _ystdClose ;
                    _ampData.at<double>(0,_dataCnt)  = _amplitude ;
                    _volData.at<double>(0,_dataCnt)  = _volume ;
                    _valData.at<double>(0,_dataCnt)  = _value ;
                    _lvalData.at<double>(0,_dataCnt) = _liveValue ;
                    _xcgData.at<double>(0,_dataCnt)  = _exchange ;
                }

                /* re_caculate exchange and living_value (assume the living_vol does not change) */
                if( (0 == _lvalData.at<double>(0,_dataCnt)) && (_dataCnt > 0) ){
                     _exchange = ((_lvalData.at<double>(0,_dataCnt-1) > 0) ? _volume * _ystdClose/_lvalData.at<double>(0,_dataCnt-1) : 0) *100 ;
                     _liveValue = _lvalData.at<double>(0,_dataCnt-1) * _close / _ystdClose ;
                     _xcgData.at<double>(0,_dataCnt) = _exchange ;
                     _lvalData.at<double>(0,_dataCnt) = _liveValue ;
                }

                /* get date */
                {
                    stringstream    _ss(_date) ;
                    char            _c ;
                    _ss >> _yyyy >> _c >> _mm >> _c >> _dd ;
                    _dateData.at<double>(0,_dataCnt) = (_yyyy - 1970)*12*31 + (_mm - 1)*31 + (_dd - 1) ;
                }

                /* caculate power */
                {
                    if(0 == _dataCnt){                     // first day
                        _liveValueYstd = _liveValue ;
                    }

                    if(!_liveValueYstd){
                        _pwrData.at<double>(0,_dataCnt) = 0 ;
                    }else{
                        _pwrData.at<double>(0,_dataCnt) = (_value / _liveValueYstd - _exchange/100) * 100 * 100 ;
                    }
                    _liveValueYstd = _liveValue ;
                }

                ++ _dataCnt ;
            }

            /* append forecast data */
            if(GET_SWITCHER_STATUS(sysSwitchers, SHOW_FORECAST)){
                forecastIdx = _dataCnt ;

                for(i=0; i<FORECAST_DATA_DAYS && _dataCnt < MAX_DAYS_NUM; i++, _dataCnt++){
                    _linesData.at<double>(0,_dataCnt)  = _linesData.at<double>(0,_dataCnt-1)*forecastCoefficients[i] ;
                    _higData.at<double>(0,_dataCnt)    = _linesData.at<double>(0,_dataCnt-1)*forecastCoefficients[i] ;
                    _lowData.at<double>(0,_dataCnt)    = _linesData.at<double>(0,_dataCnt-1)*forecastCoefficients[i] ;
                    _opnData.at<double>(0,_dataCnt)    = _linesData.at<double>(0,_dataCnt-1)*forecastCoefficients[i] ;
                    _ystdData.at<double>(0,_dataCnt)   = _linesData.at<double>(0,_dataCnt-1) ;
                    _ampData.at<double>(0,_dataCnt)    = (forecastCoefficients[i]-1)*100 ;
                    _volData.at<double>(0,_dataCnt)    = _volData.at<double>(0,_dataCnt-1) ;
                    _valData.at<double>(0,_dataCnt)    = _valData.at<double>(0,_dataCnt-1)*forecastCoefficients[i] ;
                    _lvalData.at<double>(0,_dataCnt)   = _lvalData.at<double>(0,_dataCnt-1)*forecastCoefficients[i] ;
                    _xcgData.at<double>(0,_dataCnt)    = _xcgData.at<double>(0,_dataCnt-1) ;
                    _dateData.at<double>(0,_dataCnt)    = i ;
                }
            }

            _m = _m.colRange(0,_dataCnt) ;      //!!! resize _m to real columns
            outputMat = _m ;
        }

        /* FORWARD/BACKWARD fix */
        {
            double      _base = 0 ;
            double      _factor = 1 ;

            if(DATA_FIX_TYPE_BACKWARD == dataFixType){

                _factor = 1 ;
                _base = _ystdData.at<double>(0,outputMat.cols-1) ;

                for (i = outputMat.cols-2 ; i >= 0 ; i --){
                    _factor *=  _base / _linesData.at<double>(0,i) ;
                    _base = _ystdData.at<double>(0,i) ;

                    _linesData.at<double>(0,i) *= _factor ;
                    _higData.at<double>(0,i) *= _factor ;
                    _lowData.at<double>(0,i) *= _factor ;
                    _opnData.at<double>(0,i) *= _factor ;
                    _ystdData.at<double>(0,i) *= _factor ;
                    _volData.at<double>(0,i) /= _factor ;
                    //_ampData.at<double>(0,i-1) /= 1 ;
                    //_xcgData.at<double>(0,i-1) /= 1 ;
                    //_valData.at<double>(0,i-1) /= 1 ;
                    //_lvalData.at<double>(0,i-1) /= 1 ;
                }
            }else if(DATA_FIX_TYPE_FORWARD == dataFixType){

                _factor = 1 ;
                _base = _linesData.at<double>(0,0) ;

                for (i = 1 ; i <= outputMat.cols - 1; i ++){
                    _factor *= _base/ _ystdData.at<double>(0,i) ;
                    _base = _linesData.at<double>(0,i) ;

                    _linesData.at<double>(0,i) *= _factor ;
                    _higData.at<double>(0,i) *= _factor ;
                    _lowData.at<double>(0,i) *= _factor ;
                    _opnData.at<double>(0,i) *= _factor ;
                    _ystdData.at<double>(0,i) *= _factor ;
                    _volData.at<double>(0,i) /= _factor ;
                    //_ampData.at<double>(0,i) *= 1 ;
                    //_xcgData.at<double>(0,i) *= 1 ;
                    //_valData.at<double>(0,i) *= 1 ;
                    //_lvalData.at<double>(0,i) *= 1 ;
                }
            }else{
                // keep current content.
            }
        }

        /* caculate average(val/vol) */
        {
            _avrgPrice = _valData / _volData ;
        }

        /* caculate average/eager datas*/
        {
            
            for (i = 0 ; i < outputMat.cols ; i ++){
                /* 5 days (1 week) */
                _total5  = (i < WEEK_DAYS) ? _total5 + _linesData.at<double>(0,i) : _total5 + _linesData.at<double>(0,i) - _linesData.at<double>(0, i-WEEK_DAYS) ;
                _average5 = _total5 / min(i+1,WEEK_DAYS);
                _linesData.at<double>(DATA_TYPE_AVERAGE_5 - DATA_TYPE_CLOSE, i) = _average5 ;

                /* 22 days (1 month)  */
                _total22  = (i < MONTH_DAYS) ? _total22 + _linesData.at<double>(0,i) : _total22 + _linesData.at<double>(0,i) - _linesData.at<double>(0, i-MONTH_DAYS) ;
                _average22 = _total22 / min(i+1,MONTH_DAYS);
                _linesData.at<double>(DATA_TYPE_AVERAGE_22 - DATA_TYPE_CLOSE, i) = _average22 ;

                /* 66 days (1 quater) */
                _total66  = (i < SEASON_DAYS) ? _total66 + _linesData.at<double>(0,i) : _total66 + _linesData.at<double>(0,i) - _linesData.at<double>(0, i-SEASON_DAYS) ;
                _average66 = _total66 / min(i+1,SEASON_DAYS);
                _linesData.at<double>(DATA_TYPE_AVERAGE_66 - DATA_TYPE_CLOSE, i) = _average66 ;

                /* 132 days (half year) */
                _total132  = (i < HALF_YEAR_DAYS) ? _total132+_linesData.at<double>(0,i) : _total132 + _linesData.at<double>(0,i) - _linesData.at<double>(0, i-HALF_YEAR_DAYS) ;
                _average132 = _total132 / min(i+1,HALF_YEAR_DAYS);
                _linesData.at<double>(DATA_TYPE_AVERAGE_132 - DATA_TYPE_CLOSE, i) = _average132 ;

                /* 264 days (1 year) */
                _total264  = (i < YEAR_DAYS) ? _total264 + _linesData.at<double>(0,i) : _total264 + _linesData.at<double>(0,i) - _linesData.at<double>(0, i-YEAR_DAYS) ;
                _average264 = _total264 / min(i+1,YEAR_DAYS);
                _linesData.at<double>(DATA_TYPE_AVERAGE_264 - DATA_TYPE_CLOSE, i) = _average264 ;

                /* eager data */
                _upDays += ((_ampData.at<double>(0,i) > 0) ? 1 : 0) ;
                if(i>=EAGER_CHECKING_DUR) _upDays -= ((_ampData.at<double>(0,i-EAGER_CHECKING_DUR) > 0) ? 1 : 0) ;
                _eager = _upDays / (EAGER_CHECKING_DUR*1.0) * 100 ;
                _egrData.at<double>(0, i) = _eager ;
            }
        }

        /* caculate RSI */
        {
            _getUpDnRateIndexer(_ampData, _rsi6Data,   6, false, false) ;
            _getUpDnRateIndexer(_ampData, _rsi12Data, 12, false, false) ;
            _getUpDnRateIndexer(_ampData, _rsi24Data, 24, false, false) ;
        }

        /* caculate PWRI */
        {
            _getUpDnRateIndexer(_pwrData, _pwri6Data,   6, false, false) ;
            _getUpDnRateIndexer(_pwrData, _pwri12Data, 12, false, false) ;
            _getUpDnRateIndexer(_pwrData, _pwri24Data, 24, false, false) ;
        }

        /* caculate rsiFuture6 & pwriFuture12 */
        {
            int     j = 0 ;
            int     i = outputMat.cols - 1 ;
            double  _RSUpFuture6=0, _RSDnFuture6=0, _RSFuture6=0 ;
            double  _PWRUpFuture12 = 0, _PWRDnFuture12 = 0, _PWRFuture12 = 0;

            for(j=max(0,i-4);j<=i;j++){
                (_ampData.at<double>(0,j) > 0) ? _RSUpFuture6 += _ampData.at<double>(0,j)
                                               : _RSDnFuture6 -= _ampData.at<double>(0,j) ;
                (_pwrData.at<double>(0,j) > 0) ? _PWRUpFuture12 += _pwrData.at<double>(0,j)
                                               : _PWRDnFuture12 -= _pwrData.at<double>(0,j);
            }

            _RSDnFuture6 -= -10.0;      // the maximue down amplitude is -10%
            _RSFuture6 = _RSUpFuture6 / max(_RSDnFuture6,0.000001) ;
            rsiFuture6 = 100.0 - 100.0/(1.0 + _RSFuture6) ;

            _PWRDnFuture12 -= -10.0;    // -10.0 == exchange(1.0) * amplitude(-10.0)
            _PWRFuture12 = _PWRUpFuture12 / max(_PWRDnFuture12,0.000001);
            pwriFuture12 = 100.0 - 100.0/(1.0+_PWRFuture12) ;
        }

        /* fix dialy data */
        {
            /* as history vol be? used, and effected by FORWARD_FIXING/BACKWORD_FIXING, we put this code here
               reset the first 7 elements(for reference)
               index 2, vol_section_average_10days_ref,
               index 1, vol_section_average_10days_ref * 2,
               index 0, vol_section_average_10days_ref * 4,
               index 3/5/6, reserved for later,
               index 4, current vol_section_average */

            Mat _n ;
            Mat _volData = outputMat.row(DATA_TYPE_VOL) ;
            double _avgOf10Days = _getAvg(_volData.colRange(0,_volData.cols-(outputDailyMat.cols?1:0)), _n,10,true)/(4*3600/(GAP_SECOND)) ;

            if(outputDailyMat.cols > 0) outputDailyMat.at<double>(DAILY_DATA_TYPE_VOLSECT_AVG,0) = _avgOf10Days*4 ;
            if(outputDailyMat.cols > 1) outputDailyMat.at<double>(DAILY_DATA_TYPE_VOLSECT_AVG,1) = _avgOf10Days*2 ;
            if(outputDailyMat.cols > 2) outputDailyMat.at<double>(DAILY_DATA_TYPE_VOLSECT_AVG,2) = _avgOf10Days ;
            if(outputDailyMat.cols > 3) outputDailyMat.at<double>(DAILY_DATA_TYPE_VOLSECT_AVG,3) = 0 ;
            if(outputDailyMat.cols > 4) outputDailyMat.at<double>(DAILY_DATA_TYPE_VOLSECT_AVG,4) = gDailyVolume / gDailyTimeline;
            if(outputDailyMat.cols > 5) outputDailyMat.at<double>(DAILY_DATA_TYPE_VOLSECT_AVG,5) = 0 ;
            if(outputDailyMat.cols > 6) outputDailyMat.at<double>(DAILY_DATA_TYPE_VOLSECT_AVG,6) = 0 ;
        }
    }

    _hisData.close() ;
    _hotData.close() ;

    return 0 ;
}

int printViewInfo (
        bool        curtView
        )
{
    if( curtView ){
        PRINT_INFO(ALL_ITEMS) ;
    }else{
        PRINT_INFO(ALL_ITEMS) ;
    }
    return 0 ;
}

#if 0
/* find crosses on an black background image */
int findCross(
        Mat&            src,        // matrix for a image with black background
        Mat&            des,
        int             dens,
        Mat&            mask
        )
{
    if( dens <= 0 ){
        des = src ;
        return 0 ;
    }

    Mat         t1, t2, t3 ;

    /* get density for each element */
    {
        vector<Mat> subPlans;

        split( src, subPlans );
        t1 = subPlans[0] ;
        for(int i = 1; i < subPlans.size(); i++){
            t1 += subPlans[i] ;
        }

        t1 = t1 / t1 ;
        filter2D( t1, t2, -1, Mat::ones(3,3,CV_8U), Point( -1, -1 ), 0, BORDER_ISOLATED ) ;
        t3 = 0 ;
        t2.copyTo( t3, mask.empty()? t1 : mask) ;
    }

    /* use lookuptable for extracting specified density */
    {
        Mat         _lookUpTable(1, 256, CV_8U, Scalar::all(0)) ;
        uchar*      _p = _lookUpTable.ptr() ;

        _p[dens] = dens ;
        t1 = 0 ;
        LUT( t3, _lookUpTable, t1 );
        t2 = 0 ;
        src.copyTo( t2, t1 ) ;
    }

    /* set color to WHITE(easy to find~) and return the resutl */
    {
        if(3 == t2.channels()){
            cvtColor(t2,t2,COLOR_BGR2GRAY) ;
            cvtColor(t2,t2,COLOR_GRAY2BGR) ;
            t2 *= 255 ;
        }
        else{
            t2 *= 255 ;
            cvtColor(t2,t2,COLOR_GRAY2BGR) ;
        }
        dilate(t2, t2, Mat::ones(3,3,CV_8U), Point( -1, -1)) ;
        des = t2*1 + src*0.8 ; //addWeighted(t2,1,src,1,0,des) ;
    }

    return 0 ;
}
#else
int _getLinesFocus (
        vector<Mat>         linesData ,     /* lines data */
        Mat&                result,         /* Matrix to save focus */
        const Rect&         roi
        )
{
    Mat _mask( result.size(), CV_8U, Scalar::all(0) ) ;
    Mat _hlt( result.size(), CV_8U, Scalar::all(0) ) ;
    Mat _t1( result.size(), CV_8U, Scalar::all(0) ) ;
    Mat _t2( result.size(), CV_8U, Scalar::all(0) ) ;
    Mat _line ;

    while( !linesData.empty() ){
        _line = linesData.back() ;
        _t1 = 0 ;
        _t2 = 0 ;
        drawKLines( _line, _t1, scale, roi) ;
        _t1.copyTo( _t2, _mask) ;
        _hlt += _t2 ;
        _mask += _t1 ;
        linesData.pop_back();
    }

    /* set color to WHITE */
    _hlt *= 255 ;
    if( 3 == result.channels() ){
        cvtColor( _hlt, _hlt, COLOR_GRAY2BGR ) ;
    }

    /* make it more bigger */
    dilate(_hlt, _hlt, Mat::ones(3,3,CV_8U), Point( -1, -1)) ;

    result += _hlt ;
    return 0 ;
}
#endif

int digtFuncScale(char c)
{
    int             _rslt = RSLT_NOTHING ;

    switch( c ){
        case '1' : case '2' : case '3' : case '4' :
        case '5' : case '6' : case '7' : case '8' : case '9' :
            if(c=='9')  c = '1' ;   // reset scale, same efficient as '1'

            /* adjust dtlsIdxOnMainView, dataRangeStart, dataRangeEnd */
            {
                int s = dataRangeStart ;
                int e = dataRangeEnd ;
                int d = (dtlsIdxOnMainView == IDX_RANGE_UNSET) ? e-1 : dtlsIdxOnMainView ;
                int dN = d ;
                int sN = dN - GET_COUNT_OF_VIEW(GET_POSITION_BY_VIEW_IDX(d-s, scale)+1+(scale-1-scale/2)+LINE_MARGIN_R, c-'0') + 1 ;
                int eN = 0 ;
                int _adjust = 0 ;

                if(sN < 0){
                    sN = 0 ;
                }
                eN = min(sN + GET_COUNT_OF_VIEW(gMainView.cols, c-'0'),gLinesData.cols) ;
                if(!GET_SWITCHER_STATUS(sysSwitchers,LOCK_SCREEN) && eN -sN < GET_COUNT_OF_VIEW(gMainView.cols, c-'0')){
                    /* the right part maybe empty. if left part has more data undisplayed, move the view to right to fit the whole panel */
                    _adjust = min(sN, GET_COUNT_OF_VIEW(gMainView.cols, c-'0') - (eN-1 - sN + 1)) ;
                    sN -= _adjust ;
                }

                dataRangeStart = sN ;
                dataRangeEnd = eN ;
                if(dtlsIdxOnMainView != IDX_RANGE_UNSET) dtlsIdxOnMainView = dN ;

                /*
                cout << "s=" << s << " d=" << d << " e=" << e << endl ;
                cout << "sN=" << sN << " dN=" << dN << " eN=" << eN << endl ;
                */
            }

            /* adjust scale */
            scale = c -'0' ;
            SET_SWITCHER_STATUS(&sysSwitchers, REFRESH_VIEW) ;
            _rslt = RSLT_OK ;
            break ;

        default :
            _rslt = RSLT_NOTHING ;
            break ;
    }

    return _rslt ;
}

int digtFuncIndexFilter(char c)
{
    size_t          _i = c -'0' ;
    int             _rslt = RSLT_NOTHING ;

    if(_i>=1 && _i<=NUMBERS_OF_DATA_TYPE-DATA_TYPE_RSI6){
        TOGGLE_SWITCH(&indexSwitchers,_i-1) ;
        SET_SWITCHER_STATUS(&sysSwitchers, REFRESH_VIEW) ;
        _rslt = RSLT_OK ;
    }else if (9 == _i){
        indexSwitchers = ((1<<0)|(1<<4)) ;
        SET_SWITCHER_STATUS(&sysSwitchers, REFRESH_VIEW) ;
        _rslt = RSLT_OK ;
    }else{
        _rslt = RSLT_NOTHING ;
    }

    return _rslt ;
}

int digtFuncLineFilter(char c)
{
    int  _rslt = RSLT_NOTHING ;

    switch( c ){
        case '1' : case '2' : case '3' : case '4' :
        case '5' : case '6' : case '7' : case '8' :
            TOGGLE_SWITCH(&linesSwitchers,c-'0'-1) ;
            SET_SWITCHER_STATUS(&sysSwitchers, REFRESH_VIEW) ;
            _rslt = RSLT_OK ;
            break ;
        case '9' :      // display all lines
            SETALL_SWITCHERS(&linesSwitchers) ;
            SET_SWITCHER_STATUS(&sysSwitchers, REFRESH_VIEW) ;
            _rslt = RSLT_OK ;
            break ;
        default :
            _rslt = RSLT_NOTHING ;
            break ;
    }

    return _rslt ;
}

int digtFuncBaselineFilter(char c)
{
    int  _rslt = RSLT_NOTHING ;

    switch( c ){
        case '1' : case '2' : case '3' : case '4' :
        case '5' : case '6' : case '7' : case '8' :
            TOGGLE_SWITCH(&baseLineSwitchers,c-'0'-1) ;
            SET_SWITCHER_STATUS(&sysSwitchers, REFRESH_VIEW) ;
            _rslt = RSLT_OK ;
            break ;
        case '9' :
            CLEAN_SWITCHERS(&baseLineSwitchers) ;
            SET_SWITCHER_STATUS(&sysSwitchers, REFRESH_VIEW) ;
            _rslt = RSLT_OK ;
            break ;
        default :
            _rslt = RSLT_NOTHING ;
            break ;
    }

    return _rslt ;
}

int doDigitalFunc(char c)
{
    assert( digtFuncIdx < sizeof(digtFuncList)/sizeof(digtFuncPt) );

    return digtFuncList[ digtFuncIdx ](c) ;
}

void _doRefreshView(void)
{

    Mat     viewData ;

    /* adjust window size */
    {
        gPanelW = min(gPanelW, MAX_WIN_WIDTH);
        gPanelW = max(gPanelW, 0) ;
        gPanelH = min(gPanelH, MAX_WIN_HEIGHT);
        gPanelH = max(gPanelH, 0) ;
    }

    /* adust panle and views */
    {
        gPanel.create(gPanelH,gPanelW,CV_8UC3) ;
        gPanel.setTo(Scalar(0));
#if 0
        if(GET_SWITCHER_STATUS(sysSwitchers,LOCK_SCREEN)){
            gMainView   = gPanel( Rect(LEFT_VIEW_W, 30, gPanel.cols-LEFT_VIEW_W-10, gPanel.rows-30-80-((indexSwitchers)?80:0) ) );
            gIndexView =  gPanel( Rect(LEFT_VIEW_W, gPanel.rows - 160, gMainView.cols, 80) ) ;
            gBottomView = gPanel( Rect(LEFT_VIEW_W, gPanel.rows - 80, gMainView.cols, 80) ) ;
        }else{
            gMainView   = gPanel( Rect(0, 30, gPanel.cols-10, gPanel.rows-30-80-((indexSwitchers)?80:0) ) ) ;
            gIndexView = gPanel( Rect(0, gPanel.rows - 160, gMainView.cols, 80) ) ;
            gBottomView = gPanel( Rect(0, gPanel.rows - 80, gMainView.cols, 80) ) ;
        }
#else
            gMainView   = gPanel( Rect(LEFT_VIEW_W, 30, gPanel.cols-LEFT_VIEW_W-10, gPanel.rows-30-80-((indexSwitchers)?80:0) ) );
            gIndexView =  gPanel( Rect(LEFT_VIEW_W, gPanel.rows - 160, gMainView.cols, 80) ) ;
            gBottomView = gPanel( Rect(LEFT_VIEW_W, gPanel.rows - 80, gMainView.cols, 80) ) ;
#endif
        gTopStatus_view = gPanel.rowRange(0, 30) ;
        gLeftDetailsView = gPanel.colRange(0, LEFT_VIEW_W) ;

        gDailyPanel.create((gBigDailyView ? DAILY_PANEL_H_BIG : DAILY_PANEL_H_SMALL),DAILY_PANEL_W,CV_8UC3) ;
        gDailyPanel.setTo(Scalar(0)) ;
    }

    /* adjust data range,
       all x-coordinate SHOULD(MUST!!) base on the dataRangeStart(NOT the dataRangeStart) */
    {
        if(DATA_RANGE_UNSET == dataRangeStart) dataRangeStart = gLinesData.cols - GET_COUNT_OF_VIEW(gMainView.cols,scale) ;
        if(dataRangeStart < 0) dataRangeStart = 0 ;
        if(dataRangeStart > gLinesData.cols-1) dataRangeStart = gLinesData.cols-1 ;

        dataRangeEnd = dataRangeStart + GET_COUNT_OF_VIEW(gMainView.cols,scale) ;
        if(dataRangeEnd > gLinesData.cols) dataRangeEnd = gLinesData.cols ;
    }

    /* adjust gLinesData & gLinesInfo */
    {
        if( !GET_SWITCHER_STATUS(sysSwitchers,AUTO_FIT) ){
            normalize(gLinesData, viewData, 0+1, gMainView.rows-LINE_MARGIN_T-LINE_MARGIN_B-1, NORM_MINMAX);
            viewData = viewData.colRange(dataRangeStart,dataRangeEnd) ;
        }else{
            normalize(gLinesData.colRange(dataRangeStart,dataRangeEnd), viewData,
                      0+1, gMainView.rows-LINE_MARGIN_T-LINE_MARGIN_B-1, NORM_MINMAX); /* the upper_30 pixels for gLinesInfo */
        }
        drawKLines(viewData, gMainView, scale,
                  Rect(LINE_MARGIN_L, LINE_MARGIN_T, gMainView.cols-LINE_MARGIN_L-LINE_MARGIN_R, gMainView.rows-LINE_MARGIN_T-LINE_MARGIN_B) );
    }

    /* find focus on the lines which switcher is 'ON'.
     * highlight all focus on current view.
     */
    {
        vector<Mat>     _lines ;
        Mat             focus ;

        for( int i = 0 ; i < viewData.rows; i++ ){
            if( GET_SWITCHER_STATUS(baseLineSwitchers,i) )
                _lines.push_back( viewData.row(i) );
        }

        _getLinesFocus(_lines, gMainView,
                 Rect(LINE_MARGIN_L, LINE_MARGIN_T, gMainView.cols - LINE_MARGIN_L - LINE_MARGIN_R, gMainView.rows - LINE_MARGIN_T - LINE_MARGIN_B)) ;
    }

#if 1
    /* adjust _pwr */
    {
        Mat _t1, _t2, _v;
        Mat _p(gBottomView.size(),gBottomView.type(),Scalar::all(0)) ;
        int _posY = 0 ;

        _t2.create(gPwrData.rows, gPwrData.cols+1, CV_16S) ;

        _t1 = gPwrData * 100 ;
        _t1.convertTo(_t2.colRange(0,_t2.cols-1), CV_16S) ;
        _t2 += (32767 -20000);  // support to +20000
        _t2 -= (32767 -20000);
        _t2 += (-32768+20000);  // support to -20000
        _t2 -= (-32768+20000);

        if( !GET_SWITCHER_STATUS(sysSwitchers,AUTO_FIT) ){
            _t2.at<short int>(0, _t2.cols - 1) = 0 ;
            normalize(_t2, _t2, 0, gBottomView.rows-LINE_MARGIN_T-LINE_MARGIN_B-1, NORM_MINMAX);
            _posY = _t2.at<short int>(0, _t2.cols-1) ;
            _t2 = _t2.colRange(dataRangeStart,dataRangeEnd) ;
        }else{
            _t2 = _t2.colRange(dataRangeStart,dataRangeEnd+1) ;
            _t2.at<short int>(0, _t2.cols - 1) = 0 ;
            normalize(_t2, _t2, 0, gBottomView.rows-LINE_MARGIN_T-LINE_MARGIN_B-1, NORM_MINMAX);
            _posY = _t2.at<short int>(0, _t2.cols-1) ;
            _t2 = _t2.colRange(0, _t2.cols - 1) ;
        }

        /* finally, we can draw it */
        paintData(_t2,
                _p,
                scale,
                Rect(LINE_MARGIN_L, LINE_MARGIN_T, gBottomView.cols - LINE_MARGIN_L - LINE_MARGIN_R, gBottomView.rows - LINE_MARGIN_T - LINE_MARGIN_B),
                Scalar(255,195,0),
                PAINT_TYPE_FILLED_RECT,
                true) ;
        addWeighted(_p,1,gBottomView,0,0,gBottomView);

        /* draw the line(power = 0) for reference */
        line(   gBottomView,
                Point(0+LINE_MARGIN_L, gBottomView.rows -LINE_MARGIN_B -1 -_posY),
                Point(gBottomView.cols - LINE_MARGIN_R -1, gBottomView.rows -LINE_MARGIN_B -1 -_posY),
                Scalar(0,0,255), 1, LINE_8 ) ;
    }

    /* adjust _xcg */
    {
        Mat _t1, _t2, _v;
        Mat _p(gBottomView.size(),gBottomView.type(),Scalar::all(0)) ;

        _t1 = gXcgData*10 ;
        _t1.convertTo(_t2, CV_8U) ;
        _t2 += 55 ;     // support to 20%(because 20*10=200,200+55=255,max of CV_8U is 255)
        _v = _t2.colRange(dataRangeStart,dataRangeEnd) ;

        if( !GET_SWITCHER_STATUS(sysSwitchers,AUTO_FIT) ){
            normalize(_t2, _t2, 0, gBottomView.rows-LINE_MARGIN_T-LINE_MARGIN_B-1, NORM_MINMAX);
            _t2 = _t2.colRange(dataRangeStart,dataRangeEnd) ;
        }else{
            normalize(_v, _t2, 0, gBottomView.rows-LINE_MARGIN_T-LINE_MARGIN_B-1, NORM_MINMAX);
        }

        /* finally, we can draw it */
        paintData(_t2,
                _p,
                scale,
                Rect(LINE_MARGIN_L, LINE_MARGIN_T, gBottomView.cols - LINE_MARGIN_L - LINE_MARGIN_R, gBottomView.rows - LINE_MARGIN_T - LINE_MARGIN_B),
                Scalar(0,60,255),
                PAINT_TYPE_LINE,
                true) ;
        addWeighted(_p,1,gBottomView,1,0,gBottomView);
    }
#endif

    /* draw volume for bigDisks */
    if(IS_BIG_DISK(stockId)){
        Mat _m ;
        Mat _t, _v ;

        if( GET_SWITCHER_STATUS(sysSwitchers,AUTO_FIT) ){
            normalize(gVolData.colRange(dataRangeStart,dataRangeEnd), _m, 0+1, gBottomView.rows-LINE_MARGIN_T-LINE_MARGIN_B-1, NORM_MINMAX);
        }else{
            normalize(gVolData, _m, 0+1, gBottomView.rows-LINE_MARGIN_T-LINE_MARGIN_B-1, NORM_MINMAX);
            _m = _m.colRange(dataRangeStart,dataRangeEnd) ;
        }

        paintData(_m,
                gBottomView,
                scale,
                Rect(LINE_MARGIN_L, LINE_MARGIN_T, gBottomView.cols - LINE_MARGIN_L - LINE_MARGIN_R, gBottomView.rows - LINE_MARGIN_T - LINE_MARGIN_B),
                Scalar(255,195,0),
                PAINT_TYPE_FILLED_RECT,
                true) ;
    }

#if 0
    /* draw eager line */
    {
        Mat _m ;

        normalize(gEgrData, _m, 0+1, gBottomView.rows-LINE_MARGIN_T-LINE_MARGIN_B-1, NORM_MINMAX);
        _m = _m.colRange(dataRangeStart,dataRangeEnd) ;
        paintData(_m,
                gMainView,
                scale,
                Rect(LINE_MARGIN_L, LINE_MARGIN_T, gMainView.cols-LINE_MARGIN_L-LINE_MARGIN_R, gMainView.rows-LINE_MARGIN_T-LINE_MARGIN_B),
                Scalar(0,255,0),
                PAINT_TYPE_LINE,
                true) ;
    }
#endif

    /* draw indexer lines */
    {
        size_t  i ;
        Mat     _src, _dst ;
        Scalar  _color ;

        for (i = 0 ; i < NUMBERS_OF_DATA_TYPE - DATA_TYPE_RSI6; i++){
            if(GET_SWITCHER_STATUS(indexSwitchers,i)){
                switch (i){
                    case 0:
                        _src = gRsi6Data ;
                        _color = Scalar(0,255,0) ;
                        break ;
                    case 1:
                        _color = Scalar(0,255,0) ;
                        _src = gRsi12Data ;
                        break ;
                    case 2:
                        _color = Scalar(0,255,0) ;
                        _src = gRsi24Data ;
                        break ;
                    case 3:
                        _color = Scalar(0,255,255) ;
                        _src = gPwri6Data ;
                        break ;
                    case 4:
                        _color = Scalar(0,255,255) ;
                        _src = gPwri12Data ;
                        break ;
                    case 5:
                        _color = Scalar(0,255,255) ;
                        _src = gPwri24Data ;
                        break ;
                    case 6:
                        _color = Scalar(0,255,0) ;
                        _src = gRsiCustomData ;
                        break ;
                    case 7:
                        _color = Scalar(0,255,255) ;
                        _src = gPwriCustomData ;
                        break ;
                    case 8:
                        _color = Scalar(0,0,255) ;
                        _src = gXcgAvgICustomData;
                        break ;
                    default:
                        break ;
                }

                normalize(_src, _dst, 0+1, gIndexView.rows-LINE_MARGIN_T-LINE_MARGIN_B-1, NORM_MINMAX);
                _dst = _dst.colRange(dataRangeStart,dataRangeEnd) ;
                paintData(_dst,
                        gIndexView,
                        scale,
                        Rect(LINE_MARGIN_L, LINE_MARGIN_T, gIndexView.cols-LINE_MARGIN_L-LINE_MARGIN_R, gIndexView.rows-LINE_MARGIN_T-LINE_MARGIN_B),
                        _color,
                        PAINT_TYPE_LINE,
                        true) ;
            }

#if 1
            {
                if(GET_SWITCHER_STATUS(indexSwitchers,DATA_TYPE_PWRI_CUSTOM - DATA_TYPE_RSI6)){
                    normalize(gPwriCustomData, _dst, 0+1, gIndexView.rows-LINE_MARGIN_T-LINE_MARGIN_B-1, NORM_MINMAX);
                    _dst = _dst.colRange(dataRangeStart,dataRangeEnd) ;
                    paintData(_dst,
                            gIndexView,
                            scale,
                            Rect(LINE_MARGIN_L, LINE_MARGIN_T, gIndexView.cols-LINE_MARGIN_L-LINE_MARGIN_R, gIndexView.rows-LINE_MARGIN_T-LINE_MARGIN_B),
                            Scalar(255,255,255),
                            PAINT_TYPE_LINE,
                            false) ;
                }

                if(GET_SWITCHER_STATUS(indexSwitchers,DATA_TYPE_RSI_CUSTOM - DATA_TYPE_RSI6)){
                    normalize(gRsiCustomData, _dst, 0+1, gIndexView.rows-LINE_MARGIN_T-LINE_MARGIN_B-1, NORM_MINMAX);
                    _dst = _dst.colRange(dataRangeStart,dataRangeEnd) ;
                    paintData(_dst,
                            gIndexView,
                            scale,
                            Rect(LINE_MARGIN_L, LINE_MARGIN_T, gIndexView.cols-LINE_MARGIN_L-LINE_MARGIN_R, gIndexView.rows-LINE_MARGIN_T-LINE_MARGIN_B),
                            Scalar(255,255,255),
                            PAINT_TYPE_LINE,
                            false) ;
                }
            }
#endif
        }
    }

#if 0
    /* adjust _vol */
    {
        Mat _t = abs(gVolData) ;
        Mat _v = gVolData.colRange(dataRangeStart,dataRangeEnd) ;
        Mat _p(gBottomView.size(),gBottomView.type(),Scalar::all(0)) ;

        if( !GET_SWITCHER_STATUS(sysSwitchers,AUTO_FIT) ){
            normalize(_t, _t, 0, gBottomView.rows-LINE_MARGIN_T-LINE_MARGIN_B-1, NORM_MINMAX);
            _t = _t.colRange(dataRangeStart,dataRangeEnd) ;
        }else{
            normalize(abs(_v), _t, 0, gBottomView.rows-LINE_MARGIN_T-LINE_MARGIN_B-1, NORM_MINMAX);
        }

        /* with the above operations, the sign of the 'vol' has lost, let's recover it */
        _t = _t.mul( abs(_v) / _v);

        /* finally, we can draw it */
        paintData(_t,
                _p,
                scale,
                Rect(LINE_MARGIN_L, LINE_MARGIN_T, gBottomView.cols - LINE_MARGIN_L - LINE_MARGIN_R, gBottomView.rows - LINE_MARGIN_T - LINE_MARGIN_B),
                Scalar(0,60,255),
                PAINT_TYPE_LINE,
                true) ;
        addWeighted(_p,1,gBottomView,1,0,gBottomView);
    }
#endif

    /* draw daily panel */
    if(gDailyMessData.cols >0)
    {
        double _refLineHisVolSectAvgBase, _refLineHisVolSectAvgDbl, _refLineHisVolSectAvgQdp, _refLineHotVolSectAvg ;
        Mat dailyViewData ;

        /* draw reference lines and volSect */
        {
            /* fix some huge data */
            dailyViewData = gDailyMessData.rowRange(DAILY_DATA_TYPE_VOLSECT,DAILY_DATA_TYPE_VOLSECT_AVG+1).clone() ;
            if(dailyViewData.cols > 3){
                double _limitVol= 30*dailyViewData.at<double>(DAILY_DATA_TYPE_VOLSECT_AVG - DAILY_DATA_TYPE_VOLSECT,2) ;       /* 30*base */
                for(int i=0;i<dailyViewData.cols;i++){
                    if(dailyViewData.at<double>(DAILY_DATA_TYPE_VOLSECT - DAILY_DATA_TYPE_VOLSECT,i) > _limitVol) dailyViewData.at<double>(0,i) = _limitVol ;
                    if(dailyViewData.at<double>(DAILY_DATA_TYPE_VOLSECT_AVG - DAILY_DATA_TYPE_VOLSECT,i) > _limitVol) dailyViewData.at<double>(1,i) = _limitVol ;
                }
            }

            normalize(dailyViewData,
                      dailyViewData, 0+1, gDailyPanel.rows-LINE_MARGIN_T-LINE_MARGIN_B-1, NORM_MINMAX);
            if(dailyViewData.cols>=1) _refLineHisVolSectAvgQdp = dailyViewData.at<double>(1,0) ;
            if(dailyViewData.cols>=2) _refLineHisVolSectAvgDbl = dailyViewData.at<double>(1,1) ;
            if(dailyViewData.cols>=3) _refLineHisVolSectAvgBase = dailyViewData.at<double>(1,2) ;
            if(dailyViewData.cols>=5) _refLineHotVolSectAvg = dailyViewData.at<double>(1,4) ;

#if 1
            /* draw half hour reference lines */
            {
                Mat _view = gDailyPanel.colRange(0,gDailyPanel.cols-70) ;
                int _idxFstDtOnVu = GET_FIRST_IDX_OF_DATA_ON_VIEW(_view,dailyViewData,scale) ;
                int _idxLstDtOnVu = _idxFstDtOnVu +  GET_COUNT_OF_VIEW(_view.cols,scale) - 1 ;

                for(int i=0;i<gDailyViewHalfHourRefPos.cols;i++){
                    if(0 == gDailyViewHalfHourRefPos.at<short>(0,i)) continue ;

                    int _idxData = gDailyViewHalfHourRefPos.at<short>(0,i) ;
                    if(_idxData < _idxFstDtOnVu || _idxData > _idxLstDtOnVu) continue ;

                    int _pos = GET_POSITION_BY_VIEW_IDX(_idxData-_idxFstDtOnVu,scale) ;
                    for(int j = 0 + LINE_MARGIN_T ; j < _view.rows - LINE_MARGIN_B ; j++) {
                        if((j%5)>=2){
                            _view.at<Vec3b>(j, _pos)[0] = 50 ;
                            _view.at<Vec3b>(j, _pos)[1] = 50 ;
                            _view.at<Vec3b>(j, _pos)[2] = 127 ;
                        }
                    }
                }
            }
#endif
            /* draw volume reference lines */
            {
                if(dailyViewData.cols >= 5){    // average of section volume
                    for(int i = 0 ; i < gDailyPanel.cols - 70; i++) {
                        if((i%5)>=2){
                            gDailyPanel.at<Vec3b>(gDailyPanel.rows-LINE_MARGIN_B-1-_refLineHotVolSectAvg, i)[0] = 50 ;
                            gDailyPanel.at<Vec3b>(gDailyPanel.rows-LINE_MARGIN_B-1-_refLineHotVolSectAvg, i)[1] = 127 ;
                            gDailyPanel.at<Vec3b>(gDailyPanel.rows-LINE_MARGIN_B-1-_refLineHotVolSectAvg, i)[2] = 50 ;
                        }
                    }
                }

                if(dailyViewData.cols >= 1){    // average of history section volume * 4
                    for(int i = 0 ; i < gDailyPanel.cols - 70; i++) {
                        if((i%5)<2){
                            gDailyPanel.at<Vec3b>(gDailyPanel.rows-LINE_MARGIN_B-1-_refLineHisVolSectAvgQdp, i)[0] = 50 ;
                            gDailyPanel.at<Vec3b>(gDailyPanel.rows-LINE_MARGIN_B-1-_refLineHisVolSectAvgQdp, i)[1] = 50 ;
                            gDailyPanel.at<Vec3b>(gDailyPanel.rows-LINE_MARGIN_B-1-_refLineHisVolSectAvgQdp, i)[2] = 127 ;
                        }
                    }
                }

                if(dailyViewData.cols >= 2){    // average of history section volume * 2
                    for(int i = 0 ; i < gDailyPanel.cols - 70; i++) {
                        if((i%5)<2){
                            gDailyPanel.at<Vec3b>(gDailyPanel.rows-LINE_MARGIN_B-1-_refLineHisVolSectAvgDbl, i)[0] = 50 ;
                            gDailyPanel.at<Vec3b>(gDailyPanel.rows-LINE_MARGIN_B-1-_refLineHisVolSectAvgDbl, i)[1] = 50 ;
                            gDailyPanel.at<Vec3b>(gDailyPanel.rows-LINE_MARGIN_B-1-_refLineHisVolSectAvgDbl, i)[2] = 127 ;
                        }
                    }
                }

                if(dailyViewData.cols >= 3){    // average of history section volume
                    for(int i = 0 ; i < gDailyPanel.cols - 70; i++) {
                        if((i%5)<2){
                            gDailyPanel.at<Vec3b>(gDailyPanel.rows-LINE_MARGIN_B-1-_refLineHisVolSectAvgBase, i)[0] = 50 ;
                            gDailyPanel.at<Vec3b>(gDailyPanel.rows-LINE_MARGIN_B-1-_refLineHisVolSectAvgBase, i)[1] = 50 ;
                            gDailyPanel.at<Vec3b>(gDailyPanel.rows-LINE_MARGIN_B-1-_refLineHisVolSectAvgBase, i)[2] = 127 ;
                        }
                    }
                }
            }

            /* draw average of section volume */
            {
                if(DAILY_VOL_DISP_TYPE_NOR == gDailyVolDispType){
                    paintData(dailyViewData.row(0), gDailyPanel, scale,
                              Rect(LINE_MARGIN_L, LINE_MARGIN_T, gDailyPanel.cols-LINE_MARGIN_L-LINE_MARGIN_R-70, gDailyPanel.rows-LINE_MARGIN_T-LINE_MARGIN_B),
                              Scalar(0,200,200),
                              PAINT_TYPE_FILLED_RECT,
                              true) ;
                }else if(DAILY_VOL_DISP_TYPE_UPDN == gDailyVolDispType){
                    Mat _m(1,gDailyMessData.row(DAILY_DATA_TYPE_VOLSECT).cols,CV_8S,Scalar::all(0)) ;
                    Mat _dealSect = gDailyMessData.row(DAILY_DATA_TYPE_DEAL_SECT) ;

                    for(int i=0; i<gDailyMessData.row(DAILY_DATA_TYPE_VOLSECT).cols && i<_dealSect.cols; i++){
                        if(i==0){
                            _m.at<char>(0,i) = 0 ;
                        }else if(_dealSect.at<double>(0,i) - _dealSect.at<double>(0,i-1) >= 0.001){
                            _m.at<char>(0,i) = 1 ;
                        }else if(_dealSect.at<double>(0,i) - _dealSect.at<double>(0,i-1) <= -0.001){
                            _m.at<char>(0,i) = -1 ;
                        }else{
                            // _m.at<char>(0,i) = 0 ;
                        }
                    }
                    paintDataUpDn(dailyViewData.row(0), _m, gDailyPanel, scale,
                              Rect(LINE_MARGIN_L, LINE_MARGIN_T, gDailyPanel.cols-LINE_MARGIN_L-LINE_MARGIN_R-70, gDailyPanel.rows-LINE_MARGIN_T-LINE_MARGIN_B),
                              Scalar(200,200,200),
                              Scalar(0,0,200),
                              Scalar(0,200,0),
                              PAINT_TYPE_FILLED_RECT,
                              true) ;
                }else if(DAILY_VOL_DISP_TYPE_AVG == gDailyVolDispType){
                    paintData(dailyViewData.row(1), gDailyPanel, scale,
                              Rect(LINE_MARGIN_L, LINE_MARGIN_T, gDailyPanel.cols-LINE_MARGIN_L-LINE_MARGIN_R-70, gDailyPanel.rows-LINE_MARGIN_T-LINE_MARGIN_B),
                              Scalar(0,200,200),
                              PAINT_TYPE_FILLED_RECT,
                              true) ;
                }else{
                    ;
                }

            }
        }

        /* draw DAILY_DATA_TYPE_CLSSECT_DEALSECT_DIFF */
        if(dailyViewData.row(0).cols >=50){
#if 1
            normalize(gDailyMessData.row(DAILY_DATA_TYPE_CLSSECT_DEALSECT_DIFF), dailyViewData, 0+1, gDailyPanel.rows-LINE_MARGIN_T-LINE_MARGIN_B-1, NORM_MINMAX);
#if 1
            for(int i=0; i<dailyViewData.row(0).cols; i++){
                /* only highest and lowest will be show as the indications */
                //if(dailyViewData.row(0).at<double>(0,i) < (gDailyPanel.rows*9/10) && dailyViewData.row(0).at<double>(0,i) > (gDailyPanel.rows/10)){
                    //dailyViewData.row(0).at<double>(0,i) = (1+gDailyPanel.rows-LINE_MARGIN_T-LINE_MARGIN_B-1)/2 ;
                //}
                if(dailyViewData.row(0).at<double>(0,i) == 0+1){
                    dailyViewData.row(0).at<double>(0,i) = gDailyPanel.rows/4 ;
                }else if (dailyViewData.row(0).at<double>(0,i) == gDailyPanel.rows-LINE_MARGIN_T-LINE_MARGIN_B-1){
                    dailyViewData.row(0).at<double>(0,i) = gDailyPanel.rows/2 ;
                }else{
                    dailyViewData.row(0).at<double>(0,i) = 0 ;
                }
            }
#endif
            paintData(dailyViewData.row(0), gDailyPanel, scale,
                      Rect(LINE_MARGIN_L, LINE_MARGIN_T, gDailyPanel.cols-LINE_MARGIN_L-LINE_MARGIN_R-70, gDailyPanel.rows-LINE_MARGIN_T-LINE_MARGIN_B),
                      Scalar(255,255,0),
                      PAINT_TYPE_LINE,
                      true) ;
#endif
        }

        /* draw DAILY_DATA_TYPE_CLSSECT_DEALSECT_DIFF2 */
#if 1
        if(dailyViewData.row(0).cols >=50){
            normalize(gDailyMessData.row(DAILY_DATA_TYPE_CLSSECT_DEALSECT_DIFF2), dailyViewData, 0+1, gDailyPanel.rows-LINE_MARGIN_T-LINE_MARGIN_B-1, NORM_MINMAX);
            for(int i=0; i<dailyViewData.row(0).cols; i++){
                /* only highest and lowest will be show as the indications */
                if(dailyViewData.row(0).at<double>(0,i) == 0+1){
                    dailyViewData.row(0).at<double>(0,i) = gDailyPanel.rows/8 ;
                }else if (dailyViewData.row(0).at<double>(0,i) == gDailyPanel.rows-LINE_MARGIN_T-LINE_MARGIN_B-1){
                    dailyViewData.row(0).at<double>(0,i) = gDailyPanel.rows/4 ;
                }else{
                    dailyViewData.row(0).at<double>(0,i) = 0 ;
                }
            }
            paintData(dailyViewData.row(0), gDailyPanel, scale,
                      Rect(LINE_MARGIN_L, LINE_MARGIN_T, gDailyPanel.cols-LINE_MARGIN_L-LINE_MARGIN_R-70, gDailyPanel.rows-LINE_MARGIN_T-LINE_MARGIN_B),
                      Scalar(255,0,255),
                      PAINT_TYPE_LINE,
                      true) ;
        }
#endif

#if 0
        normalize(gDailyVolSect, dailyViewData, 0+1, gDailyPanel.rows-LINE_MARGIN_T-LINE_MARGIN_B-1, NORM_MINMAX);
        paintData(dailyViewData, gDailyPanel, scale,
                  Rect(LINE_MARGIN_L, LINE_MARGIN_T, gDailyPanel.cols-LINE_MARGIN_L-LINE_MARGIN_R-70, gDailyPanel.rows-LINE_MARGIN_T-LINE_MARGIN_B),
                  Scalar(255,0,255),
                  PAINT_TYPE_FILLED_RECT,
                  true) ;
#endif

        /* draw diff of DEAL_UP & DEAL_DN */
        {
            Mat _diff = gDailyMessData.row(DAILY_DATA_TYPE_DEAL_UPDN_DIFF) ;
            Mat _m(1,_diff.cols,CV_8S,Scalar::all(0)) ;

            for(int i=0; i<_m.cols; i++){
                _m.at<char>(0,i) = (_diff.at<double>(0,i) > _diff.at<double>(0,0))
                                 ? 1
                                 : (_diff.at<double>(0,i) < _diff.at<double>(0,0)) ? -1 : 0 ;
            }
            normalize(_diff,
                      dailyViewData,
                      0+1,
                      gDailyPanel.rows-LINE_MARGIN_T-LINE_MARGIN_B-1,
                      NORM_MINMAX) ;
            paintDataUpDn(dailyViewData, _m, gDailyPanel, scale,
                      Rect(LINE_MARGIN_L, LINE_MARGIN_T, gDailyPanel.cols-LINE_MARGIN_L-LINE_MARGIN_R-70, gDailyPanel.rows-LINE_MARGIN_T-LINE_MARGIN_B),
                      Scalar(255,255,255),
                      Scalar(0,0,255),
                      Scalar(0,0,255),
                      PAINT_TYPE_LINE,
                      true) ;
        }

#if 1
        /* draw valRate */
        {
            Mat _up = gDailyMessData.row(DAILY_DATA_TYPE_VAL_UP) ;
            Mat _dn = gDailyMessData.row(DAILY_DATA_TYPE_VAL_DN) ;
            Mat _vr = _up/_dn ;
            Mat _m(1,_vr.cols,CV_8S,Scalar::all(0)) ;

            for(int i=0; i<_m.cols; i++){
                _m.at<char>(0,i) = (_vr.at<double>(0,i) > _vr.at<double>(0,0))
                                 ? 1
                                 : (_vr.at<double>(0,i) < _vr.at<double>(0,0)) ? -1 : 0 ;
            }
            normalize(_vr,
                      dailyViewData,
                      0+1,
                      gDailyPanel.rows-LINE_MARGIN_T-LINE_MARGIN_B-1,
                      NORM_MINMAX) ;
            paintDataUpDn(dailyViewData, _m, gDailyPanel, scale,
                      Rect(LINE_MARGIN_L, LINE_MARGIN_T, gDailyPanel.cols-LINE_MARGIN_L-LINE_MARGIN_R-70, gDailyPanel.rows-LINE_MARGIN_T-LINE_MARGIN_B),
                      Scalar(255,255,255),
                      Scalar(0,255,255),
                      Scalar(255,255,0),
                      PAINT_TYPE_LINE,
                      true) ;
        }

        /* draw volRate */
        {
            Mat _up = gDailyMessData.row(DAILY_DATA_TYPE_VOL_UP) ;
            Mat _dn = gDailyMessData.row(DAILY_DATA_TYPE_VOL_DN) ;
            Mat _vr = _up/_dn ;
            Mat _m(1,_vr.cols,CV_8S,Scalar::all(0)) ;

            for(int i=0; i<_m.cols; i++){
                _m.at<char>(0,i) = (_vr.at<double>(0,i) > _vr.at<double>(0,0))
                                 ? 1
                                 : (_vr.at<double>(0,i) < _vr.at<double>(0,0)) ? -1 : 0 ;
            }
            normalize(_vr,
                      dailyViewData,
                      0+1,
                      gDailyPanel.rows-LINE_MARGIN_T-LINE_MARGIN_B-1,
                      NORM_MINMAX) ;
            paintDataUpDn(dailyViewData, _m, gDailyPanel, scale,
                      Rect(LINE_MARGIN_L, LINE_MARGIN_T, gDailyPanel.cols-LINE_MARGIN_L-LINE_MARGIN_R-70, gDailyPanel.rows-LINE_MARGIN_T-LINE_MARGIN_B),
                      Scalar(255,255,255),
                      Scalar(0,255,255),
                      Scalar(255,255,0),
                      PAINT_TYPE_LINE,
                      true) ;
        }
#endif

        /* draw hot price and average hot price */
        {
            Mat _m(1,gDailyMessData.row(DAILY_DATA_TYPE_CLS).cols,CV_8S,Scalar::all(0)) ;

            normalize(gDailyMessData.rowRange(DAILY_DATA_TYPE_CLS,DAILY_DATA_TYPE_CLS_DEAL_AVG_DIFF2+1),
                      dailyViewData, 0+1, gDailyPanel.rows-LINE_MARGIN_T-LINE_MARGIN_B-1, NORM_MINMAX);

            paintData(dailyViewData.row(DAILY_DATA_TYPE_CLS_AVG-DAILY_DATA_TYPE_CLS), gDailyPanel, scale,
                      Rect(LINE_MARGIN_L, LINE_MARGIN_T, gDailyPanel.cols-LINE_MARGIN_L-LINE_MARGIN_R-70, gDailyPanel.rows-LINE_MARGIN_T-LINE_MARGIN_B),
                      Scalar(255,255,255),
                      PAINT_TYPE_LINE,
                      true) ;
#if 0
            paintData(dailyViewData.row(DAILY_DATA_TYPE_DEAL_AVG-DAILY_DATA_TYPE_CLS), gDailyPanel, scale,
                      Rect(LINE_MARGIN_L, LINE_MARGIN_T, gDailyPanel.cols-LINE_MARGIN_L-LINE_MARGIN_R-70, gDailyPanel.rows-LINE_MARGIN_T-LINE_MARGIN_B),
                      Scalar(255,255,0),
                      PAINT_TYPE_LINE,
                      true) ;
#endif

            /* draw diff2 */
            //normalize(gDailyMessData.row(DAILY_DATA_TYPE_CLS_DEAL_AVG_DIFF2), dailyViewData, 0+1, gDailyPanel.rows-LINE_MARGIN_T-LINE_MARGIN_B-1, NORM_MINMAX);
            paintData(dailyViewData.row(DAILY_DATA_TYPE_CLS_DEAL_AVG_DIFF2-DAILY_DATA_TYPE_CLS), gDailyPanel, scale,
                      Rect(LINE_MARGIN_L, LINE_MARGIN_T, gDailyPanel.cols-LINE_MARGIN_L-LINE_MARGIN_R-70, gDailyPanel.rows-LINE_MARGIN_T-LINE_MARGIN_B),
                      Scalar(255,255,255),
                      PAINT_TYPE_LINE,
                      true) ;


            for(int i=0; i<gDailyMessData.cols; i++){
                _m.at<char>(0,i) = (gDailyCls.at<double>(0,i) > gDailyYestodayClose)
                                 ? 1
                                 : (gDailyCls.at<double>(0,i) < gDailyYestodayClose) ? -1 : 0 ;
            }
            paintDataUpDn(dailyViewData.row(DAILY_DATA_TYPE_CLS-DAILY_DATA_TYPE_CLS), _m, gDailyPanel, scale,
                      Rect(LINE_MARGIN_L, LINE_MARGIN_T, gDailyPanel.cols-LINE_MARGIN_L-LINE_MARGIN_R-70, gDailyPanel.rows-LINE_MARGIN_T-LINE_MARGIN_B),
                      Scalar(255,255,255),
                      Scalar(255,0,0),
                      Scalar(0,255,0),
                      PAINT_TYPE_LINE,
                      true) ;
        }

        /* draw volRate/high/low/current price info */
        {
            Mat _n ;
            char _buff[200] ;
            Scalar _color ;

            _color = (gDailyClose > gDailyYestodayClose) ?  Scalar(0,0,255)
                                                         : (gDailyClose == gDailyYestodayClose) ? Scalar(160,160,160)
                                                                                                : Scalar(0,255,0) ;

            if(IS_BIG_DISK(stockId)){
                sprintf(_buff, "[%s]   HLR:%4.2f(%4.2f, +%4.2f -%4.2f)  VR:%4.2f  AR:%4.2f  UP:%4.2f  DN:%4.2f  DR:%8.5f",
                        stockId.c_str(),
                        (gDailyHigh-gDailyLow)/gDailyYestodayClose*100,             // (hig-low)/ystdCls
                        (gDailyClose-gDailyYestodayClose)/gDailyYestodayClose*100,  // (cls-ystdCls)/ystdCls
                        (gDailyHigh-gDailyClose)/gDailyYestodayClose*100,           // (hig-cls)/ystdCls
                        (gDailyClose-gDailyLow)/gDailyYestodayClose*100,            // (cls-low)/ystdCls
                        (gDailyValDn==0) ? 0 : gDailyValUp/gDailyValDn,
                        (gDailyVolDn==0) ? 0 : gDailyVolUp/gDailyVolDn,
                        gDailyDealUp,
                        gDailyDealDn,
                        gDailyDealUp/gDailyDealDn) ;
                setWindowTitle(stockId,_buff) ;
                sprintf(_buff, "R: %4.2f", (gDailyValDn==0) ? 0 : gDailyValUp/gDailyValDn) ;
                putText( gDailyPanel, _buff, Point(gDailyPanel.cols-64,36+(-1)*18), 0, 0.4, Scalar(160,160,160), 0, LINE_AA );
                sprintf(_buff, "V: %4.2f", gDailyVol.at<double>(0, gDailyVol.cols-1) / _getAvg(gVolData.colRange(0,gVolData.cols-(gDailyMessData.cols?1:0)),_n,10,true) ) ;
                putText( gDailyPanel, _buff, Point(gDailyPanel.cols-64,36+0*18), 0, 0.4, Scalar(160,160,160), 0, LINE_AA );
                sprintf(_buff, "B: %-6ld", (long)gDailyYestodayClose) ;
                putText( gDailyPanel, _buff, Point(gDailyPanel.cols-64,36+1*18), 0, 0.4, Scalar(160,160,160), 0, LINE_AA );
                sprintf(_buff, "O: %-6ld", (long)gDailyOpen) ;
                putText( gDailyPanel, _buff, Point(gDailyPanel.cols-64,36+2*18), 0, 0.4, Scalar(160,160,160), 0, LINE_AA );
                sprintf(_buff, "A: %-6ld", (long)gDailyClsAvg.at<double>(0,gDailyClsAvg.cols-1)) ;
                putText( gDailyPanel, _buff, Point(gDailyPanel.cols-64,36+3*18), 0, 0.4, Scalar(255, 255, 255), 0, LINE_AA );
                sprintf(_buff, "H: %-6ld", (long)gDailyHigh) ;
                putText( gDailyPanel, _buff, Point(gDailyPanel.cols-64,36+4*18), 0, 0.4, Scalar(160,160,160), 0, LINE_AA );
                sprintf(_buff, "C: %-6ld", (long)gDailyClose) ;
                putText( gDailyPanel, _buff, Point(gDailyPanel.cols-64,36+5*18), 0, 0.4, _color, 0, LINE_AA );
                sprintf(_buff, "L: %-6ld", (long)gDailyLow) ;
                putText( gDailyPanel, _buff, Point(gDailyPanel.cols-64,36+6*18), 0, 0.4, Scalar(160,160,160), 0, LINE_AA );
            }else{
                sprintf(_buff, "[%s]   HLR:%4.2f(%4.2f, +%4.2f -%4.2f)  VR:%4.2f  AR:%4.2f  UP:%4.2f  DN:%4.2f  DR:%8.5f",
                        stockId.c_str(),
                        (gDailyHigh-gDailyLow)/gDailyYestodayClose*100,
                        (gDailyClose-gDailyYestodayClose)/gDailyYestodayClose*100,  // (cls-ystdCls)/ystdCls
                        (gDailyHigh-gDailyClose)/gDailyYestodayClose*100,
                        (gDailyClose-gDailyLow)/gDailyYestodayClose*100,
                        (gDailyValDn==0) ? 0 : gDailyValUp/gDailyValDn,
                        (gDailyVolDn==0) ? 0 : gDailyVolUp/gDailyVolDn,
                        gDailyDealUp,
                        gDailyDealDn,
                        gDailyDealUp/gDailyDealDn) ;
                setWindowTitle(stockId,_buff) ;
                //putText( gDailyPanel, _buff, Point(gDailyPanel.cols-464,36+(-1)*18), 0, 0.4, Scalar(160,160,160), 0, LINE_AA );
                sprintf(_buff, "V: %4.2f", gDailyVol.at<double>(0, gDailyVol.cols-1) / _getAvg(gVolData.colRange(0,gVolData.cols-(gDailyMessData.cols?1:0)),_n,10,true) ) ;
                putText( gDailyPanel, _buff, Point(gDailyPanel.cols-64,36+0*18), 0, 0.4, Scalar(160,160,160), 0, LINE_AA );
                sprintf(_buff, "B: %4.2f", gDailyYestodayClose) ;
                putText( gDailyPanel, _buff, Point(gDailyPanel.cols-64,36+1*18), 0, 0.4, Scalar(160,160,160), 0, LINE_AA );
                sprintf(_buff, "O: %4.2f", gDailyOpen) ;
                putText( gDailyPanel, _buff, Point(gDailyPanel.cols-64,36+2*18), 0, 0.4, Scalar(160,160,160), 0, LINE_AA );
                sprintf(_buff, "A: %4.2f", gDailyClsAvg.at<double>(0,gDailyClsAvg.cols-1)) ;
                putText( gDailyPanel, _buff, Point(gDailyPanel.cols-64,36+3*18), 0, 0.4, Scalar(255, 255, 255), 0, LINE_AA );
                sprintf(_buff, "H: %4.2f", gDailyHigh) ;
                putText( gDailyPanel, _buff, Point(gDailyPanel.cols-64,36+4*18), 0, 0.4, Scalar(160,160,160), 0, LINE_AA );
                sprintf(_buff, "C: %4.2f", gDailyClose) ;
                putText( gDailyPanel, _buff, Point(gDailyPanel.cols-64,36+5*18), 0, 0.4, _color, 0, LINE_AA );
                sprintf(_buff, "L: %4.2f", gDailyLow) ;
                putText( gDailyPanel, _buff, Point(gDailyPanel.cols-64,36+6*18), 0, 0.4, Scalar(160,160,160), 0, LINE_AA );
            }
        }
    }

    /* adjust details index line */
    {
        if(!GET_SWITCHER_STATUS(sysSwitchers,LOCK_SCREEN)){
            dtlsIdxOnMainView = IDX_RANGE_UNSET ;
        }else{
            if(IDX_RANGE_UNSET == dtlsIdxOnMainView ) dtlsIdxOnMainView  = (dataRangeEnd + dataRangeStart-1 + 1)/2 ;
            if(dtlsIdxOnMainView < 0) dtlsIdxOnMainView = 0 ;
            if(dtlsIdxOnMainView > dataRangeEnd-1) dtlsIdxOnMainView = dataRangeEnd-1 ;

            /*
            cout << "start=" << dataRangeStart << " dtlsIdxOnMainView=" << dtlsIdxOnMainView << " end=" << dataRangeEnd << endl ;
            */

            /* draw a vertical line on the dtlsIdxOnMainView  */
            Point   _ofs;
            Scalar  _color;
            Size    _orgMatrixSize;

            gMainView.locateROI( _orgMatrixSize, _ofs );

            for(int i = 0 ; i < gPanel.rows; i++) {
                if((i%20)<17){
                    gPanel.at<Vec3b>(i, GET_POSITION_BY_VIEW_IDX(dtlsIdxOnMainView-dataRangeStart,scale)+_ofs.x )[0] = 127 ;
                    gPanel.at<Vec3b>(i, GET_POSITION_BY_VIEW_IDX(dtlsIdxOnMainView-dataRangeStart,scale)+_ofs.x )[1] = 127 ;
                    gPanel.at<Vec3b>(i, GET_POSITION_BY_VIEW_IDX(dtlsIdxOnMainView-dataRangeStart,scale)+_ofs.x )[2] = 127 ;
                }
            }

            /* draw a vertical line for measure */
            {
                if(GET_SWITCHER_STATUS(sysSwitchers, MEASURE) && measureIdx != IDX_RANGE_UNSET && measureIdx > gLinesData.cols-1){
                    RESET_SWITCHER_STATUS(&sysSwitchers, MEASURE) ;
                }

                if(GET_SWITCHER_STATUS(sysSwitchers, MEASURE)){
                    int  _idx = 0 ;
                    int  _pos = 0 ;

                    if(IDX_RANGE_UNSET == measureIdx){
                        measureIdx = dtlsIdxOnMainView ;
                        _idx = dtlsIdxOnMainView - dataRangeStart ;
                    }else{
                        _idx = measureIdx - dataRangeStart ;
                    }
                    _pos = GET_POSITION_BY_VIEW_IDX(_idx,scale) ;

                    if(_pos >= LINE_MARGIN_L && _pos <= gMainView.cols-1-LINE_MARGIN_R){
                        for(int i = 0 ; i < gPanel.rows; i++) {
                            if((i%20)<17){
                                gPanel.at<Vec3b>(i, _pos+_ofs.x )[0] = 0 ;
                                gPanel.at<Vec3b>(i, _pos+_ofs.x )[1] = 0 ;
                                gPanel.at<Vec3b>(i, _pos+_ofs.x )[2] = 255 ;
                            }
                        }
                    }
                }else{
                    measureIdx = IDX_RANGE_UNSET ;
                }
            }

            /* draw a horizantl line */
            for(int i = LINE_MARGIN_L; i < gMainView.cols-LINE_MARGIN_R; i++){
                if((i%20)<17){
                    gMainView.at<Vec3b>(gMainView.rows - 1 - LINE_MARGIN_B - viewData.at<double>(0,dtlsIdxOnMainView-dataRangeStart), i)[0] = 127 ;
                    gMainView.at<Vec3b>(gMainView.rows - 1 - LINE_MARGIN_B - viewData.at<double>(0,dtlsIdxOnMainView-dataRangeStart), i)[1] = 127 ;
                    gMainView.at<Vec3b>(gMainView.rows - 1 - LINE_MARGIN_B - viewData.at<double>(0,dtlsIdxOnMainView-dataRangeStart), i)[2] = 127 ;
                }
            }

            /* draw some reference lines */
            // do something here
        }
    }

    /* redraw left info bar */
    {
        int             i ;
        stringstream    s ;

        /* show stock name & code & data-fix status */
        s.str("");
        s << " [" << stockId << "]" ;

        if(dataFixType == DATA_FIX_TYPE_FORWARD) s << " [Forward Fixing]" ;
        else if(dataFixType == DATA_FIX_TYPE_BACKWARD) s << " [Backward Fixing]" ;
        else ;
        /*(dataFixType == DATA_FIX_TYPE_FORWARD)
            ? s << " [Forward Fixing]"
            : (dataFixType == DATA_FIX_TYPE_BACKWARD)
                ? s << " [Backward Fixing]"
                : 1 ;*/
        if(GET_SWITCHER_STATUS(sysSwitchers,AUTO_FIT)) s << " [Auto Fit]" ;
        if(GET_SWITCHER_STATUS(indexSwitchers,DATA_TYPE_RSI_CUSTOM - DATA_TYPE_RSI6)) s << " [RSI_CUSTOM:" << rsiCustom <<"]";
        if(GET_SWITCHER_STATUS(indexSwitchers,DATA_TYPE_PWRI_CUSTOM - DATA_TYPE_RSI6)) s << " [PWRI_CUSTOM:" << pwriCustom <<"]";
        if(GET_SWITCHER_STATUS(indexSwitchers,DATA_TYPE_XCGI_CUSTOM - DATA_TYPE_RSI6)) s << " [XCGI_CUSTOM:" << xcgAvgICustom <<"]";
        putText( gTopStatus_view, s.str(), Point(0,22), 0, 0.4, Scalar(0, 0, 255), 0, LINE_AA );

        s.str("") ;
        /* show baseline info */
        ( digtFuncList[ digtFuncIdx ] == digtFuncBaselineFilter ) ?  s << "*Base:" : s << " Base:" ;
        putText( gLeftDetailsView, s.str(), Point(0,54), 0, 0.4, Scalar(0, 0, 255), 0, LINE_AA );
        s.str("/") ;
        for( i = 0 ; i < viewData.rows; i++ ){
            if( GET_SWITCHER_STATUS(baseLineSwitchers,i) ){
                s << i + 1 << '/' ;
            }
        }
        putText( gLeftDetailsView, s.str(), Point(20,54+1*14), 0, 0.4, Scalar(0, 0, 255), 0, LINE_AA );

        /* show line info */
        s.str("");
        (digtFuncList[ digtFuncIdx ] == digtFuncLineFilter) ? s << "*Lines:" : s << " Lines:" ;
        putText( gLeftDetailsView, s.str(), Point(0,54+2*14), 0, 0.4, Scalar(0, 0, 255), 0, LINE_AA );
        s.str("/") ;
        for( i = 0 ; i < viewData.rows; i++ ){
            if( GET_SWITCHER_STATUS(linesSwitchers,i) ){
                s << i + 1 << '/' ;
            }
        }
        putText( gLeftDetailsView, s.str(), Point(20,54+3*14), 0, 0.4, Scalar(0, 0, 255), 0, LINE_AA );

        /* show index info */
        s.str("");
        (digtFuncList[ digtFuncIdx ] == digtFuncIndexFilter) ? s << "*Indexs:" : s << " Indexs:" ;
        putText( gLeftDetailsView, s.str(), Point(0,54+4*14), 0, 0.4, Scalar(0, 0, 255), 0, LINE_AA );
        s.str("/") ;
        for( i = 0 ; i < NUMBERS_OF_DATA_TYPE - DATA_TYPE_RSI6; i++ ){
            if( GET_SWITCHER_STATUS(indexSwitchers,i) ){
                s << i + 1 << '/' ;
            }
        }
        putText( gLeftDetailsView, s.str(), Point(20,54+5*14), 0, 0.4, Scalar(0, 0, 255), 0, LINE_AA );

        /* show scale info */
        s.str("");
        (digtFuncList[ digtFuncIdx ] == digtFuncScale) ? s << "*Scale:" : s << " Scale:" ;
        putText( gLeftDetailsView, s.str(), Point(0,54+6*14), 0, 0.4, Scalar(0, 0, 255), 0, LINE_AA );
        s.str("") ;
        s << scale ;
        putText( gLeftDetailsView, s.str(), Point(20,54+7*14), 0, 0.4, Scalar(0, 0, 255), 0, LINE_AA );

        /* show details info */
        if(GET_SWITCHER_STATUS(sysSwitchers,LOCK_SCREEN)){
            double  _d = 0 ;
            long    _l = 0 ;
            Scalar  _color ;
            int     _idx = 4 ;
            int     _precision = 2 ;

            if(IS_BIG_DISK(stockId)) _precision = 0 ;

            /* date */
            s.str(" ");
            _l = (long)(gDateData.at<double>(0,dtlsIdxOnMainView)) ;
            _color = Scalar(255,255,255) ;
            s << (_l/(12*31)+1970) << "-" << ((_l%(12*31)/31)+1) << "-" << ((_l%31)+1);
            putText( gLeftDetailsView, s.str(), Point(0,120+(_idx++)*14), 0, 0.4, _color, 0, LINE_AA );

            /* k0 (today) */
            _d = gLinesData.at<double>(0,dtlsIdxOnMainView) ;
            _color = lineColors[0] ;
            s.str("");
            s << setiosflags(ios::fixed) << setprecision(_precision) << _d ;
            putText( gLeftDetailsView, s.str(), Point(1,120+(_idx)*14), 0, 0.4, _color, 0, LINE_AA );

            /* k1 (a week) */
            _d = gLinesData.at<double>(1,dtlsIdxOnMainView);
            _color = lineColors[1] ;
            s.str("");
            s << setiosflags(ios::fixed) << setprecision(_precision) << _d ;
            putText( gLeftDetailsView, s.str(), Point(41,120+(_idx)*14), 0, 0.4, _color, 0, LINE_AA );

            /* k2 (a month) */
            _d = gLinesData.at<double>(2,dtlsIdxOnMainView);
            _color = lineColors[2] ;
            s.str("");
            s << setiosflags(ios::fixed) << setprecision(_precision) << _d ;
            putText( gLeftDetailsView, s.str(), Point(82,120+(_idx++)*14), 0, 0.4, _color, 0, LINE_AA );

            /* k3 (a quarter) */
            _d = gLinesData.at<double>(3,dtlsIdxOnMainView);
            _color = lineColors[3] ;
            s.str("");
            s << setiosflags(ios::fixed) << setprecision(_precision) << _d ;
            putText( gLeftDetailsView, s.str(), Point(1,120+(_idx)*14), 0, 0.4, _color, 0, LINE_AA );

            /* k4 (hlaf year) */
            _d = gLinesData.at<double>(4,dtlsIdxOnMainView);
            _color = lineColors[4] ;
            s.str("");
            s << setiosflags(ios::fixed) << setprecision(_precision) << _d ;
            putText( gLeftDetailsView, s.str(), Point(41,120+(_idx)*14), 0, 0.4, _color, 0, LINE_AA );

            /* k5 (a year) */
            _d = gLinesData.at<double>(5,dtlsIdxOnMainView);
            _color = lineColors[5] ;
            s.str("");
            s << setiosflags(ios::fixed) << setprecision(_precision) << _d ;
            putText( gLeftDetailsView, s.str(), Point(82,120+(_idx++)*14), 0, 0.4, _color, 0, LINE_AA );

            _idx++ ;
            /* volume */
            s.str("");
            _d = gVolData.at<double>(0,dtlsIdxOnMainView)/100/10000 ;    // use 10'thousand(hand) for the unit
            _color = Scalar(127,127,127);
            s << " VOL=" << setprecision(2) << abs(_d) << "W";
            putText( gLeftDetailsView, s.str(), Point(0,120+(_idx++)*14), 0, 0.4, _color, 0, LINE_AA );

            /* value */
            s.str("");
            _d = gValData.at<double>(0,dtlsIdxOnMainView)/100/10000 ;    // use 1 Million yuan for the unit
            _color = Scalar(127,127,127);
            s << " VAL=" << abs(_d) << "M";
            putText( gLeftDetailsView, s.str(), Point(0,120+(_idx++)*14), 0, 0.4, _color, 0, LINE_AA );

            /* live-value */
            s.str("");
            _d = gLvalData.at<double>(0,dtlsIdxOnMainView)/100/10000 ; // use 10'Million(yuan) for the unit
            _color = Scalar(127,127,127);
            s << " LVal=" << (_d) << "M";
            putText( gLeftDetailsView, s.str(), Point(0,120+(_idx++)*14), 0, 0.4, _color, 0, LINE_AA );

            /* amplitude */
            s.str("");
            _d = gAmpData.at<double>(0,dtlsIdxOnMainView) ;
            _color = (_d>0) ? Scalar(0,0,255)
                           : (_d==0) ? Scalar(127,127,127)
                                    : Scalar(0,255,0) ;
            s << " AMP=" << (_d) << "%";
            putText( gLeftDetailsView, s.str(), Point(0,120+(_idx++)*14), 0, 0.4, _color, 0, LINE_AA );

            /* exchange */
            s.str("");
            _d = gXcgData.at<double>(0,dtlsIdxOnMainView) ;
            _color = Scalar(127,127,127) ;
            s << " Exchg=" << setiosflags(ios::fixed) << setprecision(2) << (_d) << '%' ;
            putText( gLeftDetailsView, s.str(), Point(0,120+(_idx++)*14), 0, 0.4, _color, 0, LINE_AA );

            /* power */
            s.str("");
            _d = gPwrData.at<double>(0,dtlsIdxOnMainView) ;
            _color = (_d>0) ? Scalar(0,0,255)
                            : (_d==0) ? Scalar(127,127,127)
                                      : Scalar(0,255,0) ;
            s << " Power=" << setiosflags(ios::fixed) << setprecision(2) << (_d) ;
            putText( gLeftDetailsView, s.str(), Point(0,120+(_idx++)*14), 0, 0.4, _color, 0, LINE_AA );

            _idx ++ ;

#if 0
            /* eager to buy */
            s.str("");
            _d = gEgrData.at<double>(0,dtlsIdxOnMainView) ;
            _color = (_d>=75) ? Scalar(0,0,255)
                              : (_d<=25) ? Scalar(0,255,0)
                                         : Scalar(127,127,127) ;
            s << " Eager=" << setiosflags(ios::fixed) << setprecision(2) << (_d) << "%";
            putText( gLeftDetailsView, s.str(), Point(0,120+(_idx++)*14), 0, 0.4, _color, 0, LINE_AA );
#endif

            /* RSI6(Relative Strongth Index) */
            s.str("");
            _d = gRsi6Data.at<double>(0,dtlsIdxOnMainView) ;
            _color = (_d>=85) ? Scalar(0,0,255)
                              : (_d<=15) ? Scalar(0,255,0)
                                         : Scalar(127,127,127) ;
            s << " RSI6=" << setiosflags(ios::fixed) << setprecision(2) << (_d) << "%";
            putText( gLeftDetailsView, s.str(), Point(0,120+(_idx++)*14), 0, 0.4, _color, 0, LINE_AA );

            /* RSI12(Relative Strongth Index) */
            s.str("");
            _d = gRsi12Data.at<double>(0,dtlsIdxOnMainView) ;
            _color = (_d>=85) ? Scalar(0,0,255)
                              : (_d<=15) ? Scalar(0,255,0)
                                         : Scalar(127,127,127) ;
            s << " RSI12=" << setiosflags(ios::fixed) << setprecision(2) << (_d) << "%";
            putText( gLeftDetailsView, s.str(), Point(0,120+(_idx++)*14), 0, 0.4, _color, 0, LINE_AA );

#if 0
            /* RSI24(Relative Strongth Index) */
            s.str("");
            _d = gRsi24Data.at<double>(0,dtlsIdxOnMainView) ;
            _color = (_d>=85) ? Scalar(0,0,255)
                              : (_d<=15) ? Scalar(0,255,0)
                                         : Scalar(127,127,127) ;
            s << " RSI24=" << setiosflags(ios::fixed) << setprecision(2) << (_d) << "%";
            putText( gLeftDetailsView, s.str(), Point(0,120+(_idx++)*14), 0, 0.4, _color, 0, LINE_AA );
#endif 

            /* PWRI6(Power Index) */
            s.str("");
            _d = gPwri6Data.at<double>(0,dtlsIdxOnMainView) ;
            _color = (_d>=85) ? Scalar(0,0,255)
                              : (_d<=15) ? Scalar(0,255,0)
                                         : Scalar(127,127,127) ;
            s << " PWRI6=" << setiosflags(ios::fixed) << setprecision(2) << (_d) << "%";
            putText( gLeftDetailsView, s.str(), Point(0,120+(_idx++)*14), 0, 0.4, _color, 0, LINE_AA );

            /* PWR12(Power Index) */
            s.str("");
            _d = gPwri12Data.at<double>(0,dtlsIdxOnMainView) ;
            _color = (_d>=85) ? Scalar(0,0,255)
                              : (_d<=15) ? Scalar(0,255,0)
                                         : Scalar(127,127,127) ;
            s << " PWRI12=" << setiosflags(ios::fixed) << setprecision(2) << (_d) << "%";
            putText( gLeftDetailsView, s.str(), Point(0,120+(_idx++)*14), 0, 0.4, _color, 0, LINE_AA );

#if 0
            /* PWR24(Power Index) */
            s.str("");
            _d = gPwri24Data.at<double>(0,dtlsIdxOnMainView) ;
            _color = (_d>=85) ? Scalar(0,0,255)
                              : (_d<=15) ? Scalar(0,255,0)
                                         : Scalar(127,127,127) ;
            s << " PWRI24=" << setiosflags(ios::fixed) << setprecision(2) << (_d) << "%";
            putText( gLeftDetailsView, s.str(), Point(0,120+(_idx++)*14), 0, 0.4, _color, 0, LINE_AA );
#endif

            /* indexes-custom */
            if(GET_SWITCHER_STATUS(sysSwitchers, MEASURE))
            {
                _idx ++ ;

                int _days = 0 ;
                int _dataS = 0 ;
                int _dataE = 0 ;
                Mat _m ;

                if(dtlsIdxOnMainView > measureIdx){
                    _dataS = measureIdx + 1 ;       // plus 1, not include the first(start) day
                    _dataE = dtlsIdxOnMainView ;
                }else{
                    _dataS = dtlsIdxOnMainView + 1 ; // plus 1, not include the first(start) day
                    _dataE = measureIdx ;
                }

                _days = rsiCustom = pwriCustom = xcgAvgICustom = _dataE - _dataS + 1 ;

                /* amp-custom */
                s.str("");
                _d = (_days<=0||gLinesData.at<double>(0,measureIdx)<=0)
                   ? 0 
                   : (gLinesData.at<double>(0,dtlsIdxOnMainView) - gLinesData.at<double>(0,measureIdx))/gLinesData.at<double>(0,measureIdx) * 100 ;
                _color = (_d>0) ? Scalar(0,0,255) : ((_d<0) ? Scalar(0,255,0) : Scalar(255,255,255)) ;
                s << " AMP-" << _days << "=" << setiosflags(ios::fixed) << setprecision(2) << abs(_d) << "%" ;
                putText( gLeftDetailsView, s.str(), Point(0,120+(_idx++)*14), 0, 0.4, _color, 0, LINE_AA );

                /* total_amp-custom */
                s.str("");
                _d = (_days>0)? _getTT(gValData.colRange(_dataS,_dataE+1), _m, _days, true, true)/10000000.0 : 0 ;
                _color = Scalar(255,0,0) ;
                s << " VALT-" << _days << "=" << setiosflags(ios::fixed) << setprecision(2) << (_d) ;
                putText( gLeftDetailsView, s.str(), Point(0,120+(_idx++)*14), 0, 0.4, _color, 0, LINE_AA );

                /* total_exchange-custom */
                s.str("");
                _d = (_days>0)? _getTT(gXcgData.colRange(_dataS,_dataE+1), _m, _days, true, true) : 0 ;
                _color = Scalar(255,0,0) ;
                s << " XCGT-" << _days << "=" << setiosflags(ios::fixed) << setprecision(2) << (_d) ;
                putText( gLeftDetailsView, s.str(), Point(0,120+(_idx++)*14), 0, 0.4, _color, 0, LINE_AA );

                /* average-custom */
                s.str("");
                _d = (_days>0)? _getAvg(gLinesData.colRange(_dataS,_dataE+1), _m, _days, true) : 0 ;
                _color = Scalar(255,0,0) ;
                s << " AVG-" << _days << "=" << setiosflags(ios::fixed) << setprecision(2) << (_d) ;
                putText( gLeftDetailsView, s.str(), Point(0,120+(_idx++)*14), 0, 0.4, _color, 0, LINE_AA );

                /* rsi-custom */
                s.str("");
                _d = (rsiCustom>0) ? _getUpDnRateIndexer(gAmpData.colRange(_dataS,_dataE+1), gRsiCustomData, _dataE - _dataS + 1, false, true) : 0 ;
                _color = (_d>=85) ? Scalar(0,0,255)
                                  : (_d<=15) ? Scalar(0,255,0)
                                             : Scalar(127,127,127) ;
                s << " RSI-" << rsiCustom << "=" << setiosflags(ios::fixed) << setprecision(2) << (_d) ;
                putText( gLeftDetailsView, s.str(), Point(0,120+(_idx++)*14), 0, 0.4, _color, 0, LINE_AA );

                /* pwri-custom */
                s.str("");
                _d = (pwriCustom>0) ? _getUpDnRateIndexer(gPwrData.colRange(_dataS,_dataE+1), gPwriCustomData, _dataE - _dataS + 1, false, true) : 0 ;
                _color = (_d>=85) ? Scalar(0,0,255)
                                  : (_d<=15) ? Scalar(0,255,0)
                                             : Scalar(127,127,127) ;
                s << " PWRI-" << pwriCustom << "=" << setiosflags(ios::fixed) << setprecision(2) << (_d) ;
                putText( gLeftDetailsView, s.str(), Point(0,120+(_idx++)*14), 0, 0.4, _color, 0, LINE_AA );

                /* xcg-custom */
                s.str("");
                _d = (xcgAvgICustom>0) ? _getUpDnRateIndexer(gXcgData.colRange(_dataS,_dataE+1), gXcgAvgICustomData, _dataE - _dataS + 1, true, true) : 0 ;
                _color = (_d>=85) ? Scalar(0,0,255)
                                  : (_d<=15) ? Scalar(0,255,0)
                                             : Scalar(127,127,127) ;
                s << " XCG-" << xcgAvgICustom << "="  << setiosflags(ios::fixed) << setprecision(2) << (_d) ;
                putText( gLeftDetailsView, s.str(), Point(0,120+(_idx++)*14), 0, 0.4, _color, 0, LINE_AA );
            }

            /* redraw daily keyline info at the left view */
            {
                _idx ++ ;

                /* pre-close */
                s.str("");
                _d = gYstdData.at<double>(0,dtlsIdxOnMainView) ;
                _color = Scalar(127,127,127) ;
                s << " YstdC=" << setiosflags(ios::fixed) << setprecision(2) << (_d) ;
                putText( gLeftDetailsView, s.str(), Point(0,120+(_idx++)*14), 0, 0.4, _color, 0, LINE_AA );

                /* open */
                s.str("");
                _d = gOpenData.at<double>(0,dtlsIdxOnMainView) ;
                _color = Scalar(127,127,127) ;
                s << " Open=" << setiosflags(ios::fixed) << setprecision(2) << (_d) ;
                putText( gLeftDetailsView, s.str(), Point(0,120+(_idx++)*14), 0, 0.4, _color, 0, LINE_AA );

                /* close */
                s.str("");
                _d = gLinesData.at<double>(0,dtlsIdxOnMainView) ;
                _color = Scalar(127,127,127) ;
                s << " Close=" << setiosflags(ios::fixed) << setprecision(2) << (_d) ;
                putText( gLeftDetailsView, s.str(), Point(0,120+(_idx++)*14), 0, 0.4, _color, 0, LINE_AA );

                /* high */
                s.str("");
                _d = gHigData.at<double>(0,dtlsIdxOnMainView) ;
                _color = Scalar(127,127,127) ;
                s << " High=" << setiosflags(ios::fixed) << setprecision(2) << (_d) ;
                putText( gLeftDetailsView, s.str(), Point(0,120+(_idx++)*14), 0, 0.4, _color, 0, LINE_AA );

                /* lower */
                s.str("");
                _d = gLowData.at<double>(0,dtlsIdxOnMainView) ;
                _color = Scalar(127,127,127) ;
                s << " Lower=" << setiosflags(ios::fixed) << setprecision(2) << (_d) ;
                putText( gLeftDetailsView, s.str(), Point(0,120+(_idx++)*14), 0, 0.4, _color, 0, LINE_AA );

                /* close, open, max, min, date */
                {
                    #define _CNT  (8)

                    double _data[][_CNT] = {
                            {
                             gLinesData.row(0).at<double>(0,dtlsIdxOnMainView) ,           // do NOT change the position of this line
                             gOpenData.row(0).at<double>(0,dtlsIdxOnMainView) ,            // do NOT change the position of this line
                             gHigData.row(0).at<double>(0, dtlsIdxOnMainView) ,            // do NOT change the position of this line
                             gLowData.row(0).at<double>(0, dtlsIdxOnMainView) ,            // do NOT change the position of this line
                             gYstdData.row(0).at<double>(0,dtlsIdxOnMainView) ,            // do NOT change the position of this line
                             gYstdData.row(0).at<double>(0,dtlsIdxOnMainView) * 0.89,      // floor, do NOT change the position of this line
                             gYstdData.row(0).at<double>(0,dtlsIdxOnMainView) * 1.11,      // ceiling, do NOT change the position of this line
                                                                                           // can add some interesting data here!!
                             gDateData.row(0).at<double>(0,dtlsIdxOnMainView) , }          // keep this line at end of each data[x]
                    };
                    Mat     _m(sizeof(_data)/sizeof(_data[0]),_CNT,CV_64F,(void*)(&_data[0][0])) ;
                    Mat     _n ;
                    Scalar  _color ;
                    int     _i, _itemsNumber, _basePosX, _basePosY;
                    double  _open, _close, _max, _min, _ystdClose, _floor, _ceiling,  _date ;

                    _itemsNumber = _m.rows ;
                    normalize(_m.colRange(0,_CNT-1), _n, 0, 14*4, NORM_MINMAX);

                    for( _i = 0 ; _i < _m.rows; _i++ ){
                        _open = _n.at<double>(_i,1) ;
                        _close = _n.at<double>(_i,0) ;
                        _max = _n.at<double>(_i,2) ;
                        _min = _n.at<double>(_i,3) ;
                        _ystdClose = _n.at<double>(_i,4) ;
                        _floor = _n.at<double>(_i,5) ;
                        _ceiling = _n.at<double>(_i,6) ;
                        _date = _n.at<double>(_i,_CNT-1) ;
                        _color = (_close > _open) ? Scalar(0,0,255) : ( (_close == _open) ? Scalar(127,127,127) : Scalar(0,255,0) ) ;
                        _basePosX = gLeftDetailsView.cols/_itemsNumber * _i + gLeftDetailsView.cols/_itemsNumber/2 - 25;
                        _basePosY = 120 + (_idx * 14) +14*4;

                        line( gLeftDetailsView, Point(8, _basePosY-_ceiling), Point(gLeftDetailsView.cols-1-58, _basePosY-_ceiling), Scalar(127,127,127), 1, LINE_8) ;
                        line( gLeftDetailsView, Point(8, _basePosY-_ystdClose), Point(gLeftDetailsView.cols-1-58, _basePosY-_ystdClose), Scalar(127,127,127), 1, LINE_8) ;
                        line( gLeftDetailsView, Point(8, _basePosY-_floor), Point(gLeftDetailsView.cols-1-58, _basePosY-_floor), Scalar(127,127,127), 1, LINE_8) ;
                        line( gLeftDetailsView, Point(_basePosX,_basePosY-_max), Point(_basePosX, _basePosY-max(_open,_close)), _color, 1, LINE_8 ) ;
                        line( gLeftDetailsView, Point(_basePosX,_basePosY-_min), Point(_basePosX, _basePosY-min(_open,_close)), _color, 1, LINE_8 ) ;
                        rectangle( gLeftDetailsView, Point(_basePosX-2, _basePosY-_open), Point(_basePosX+2, _basePosY-_close), _color, FILLED, LINE_8 );
                    }
                }
            }
        }
    }

    /* show gPanel & gDailyPanel */
    {
        if(GET_SWITCHER_STATUS(sysSwitchers,SHOW_DAILY)){
            int x,y ;

            x = (gBigDailyView) ? (MAX_WIN_WIDTH-DAILY_PANEL_W) : (MAX_WIN_WIDTH-DAILY_PANEL_W) ;
            y = (gBigDailyView) ? (gWinOrder ? 22+(DAILY_PANEL_H_SMALL+22)*(gWinOrder-1)+(DAILY_PANEL_H_SMALL-DAILY_PANEL_H_BIG) : (MAX_WIN_HEIGHT-DAILY_PANEL_H_BIG)/2 )
                                : (gWinOrder ? 22+(DAILY_PANEL_H_SMALL+22)*(gWinOrder-1) : (MAX_WIN_HEIGHT-DAILY_PANEL_H_SMALL)/2 ) ;
            if(y<0) y = 0 ;
            // window title has been set during drawing daily data
            imshow(stockId,gDailyPanel) ;
            moveWindow(stockId,x,y) ; 
        }else{
            //destroyWindow("dailyPanel") ;
            setWindowTitle(stockId,stockId) ;
            imshow(stockId,gPanel) ;
            moveWindow(stockId, gPanelX, gPanelY) ;
        }
    }

    /* set to topmost window */
    {
        /* i don't know how to do this... */
        //HWND hWinTmp = (HWND)cvGetWindowHandle("tmp");
        //HWND hWinParent = ::GetParent(hWinTmp);
        //if(hWinParent){
            //SetWindowPos(hWinParent,HWND_TOPMOST,0,0,0,0,SWP_NOSIZE|SWP_NOMOVE);
        //}
    }

    RESET_SWITCHER_STATUS(&sysSwitchers, REFRESH_VIEW) ;
    return ;
}

void _doRefreshData(
    const char*     historyData,
    const char*     hotData,
    const int       dataFixType,
    Mat&            outputMat,
    Mat&            outputDailyMat
    )
{
    importData( historyData, hotData, dataFixType, outputMat, outputDailyMat) ;
    gLinesData         = outputMat.rowRange(DATA_TYPE_CLOSE, DATA_TYPE_LOW+1) ;
    gKLine5            = outputMat.row(DATA_TYPE_AVERAGE_5) ;
    gKLine22            = outputMat.row(DATA_TYPE_AVERAGE_22) ;
    gKLine66            = outputMat.row(DATA_TYPE_AVERAGE_66) ;
    gKLine132            = outputMat.row(DATA_TYPE_AVERAGE_132) ;
    gKLine264            = outputMat.row(DATA_TYPE_AVERAGE_264) ;
    gDateData          = outputMat.row(DATA_TYPE_DATE) ;
    gHigData           = outputMat.row(DATA_TYPE_HIG) ;
    gLowData           = outputMat.row(DATA_TYPE_LOW) ;
    gOpenData           = outputMat.row(DATA_TYPE_OPEN) ;
    gYstdData          = outputMat.row(DATA_TYPE_YSTD) ;
    gAmpData           = outputMat.row(DATA_TYPE_AMP) ;
    gXcgData           = outputMat.row(DATA_TYPE_XCG) ;
    gVolData           = outputMat.row(DATA_TYPE_VOL) ;
    gValData           = outputMat.row(DATA_TYPE_VAL) ;
    gLvalData          = outputMat.row(DATA_TYPE_LVAL) ;
    gPwrData           = outputMat.row(DATA_TYPE_PWR) ;
    gEgrData           = outputMat.row(DATA_TYPE_EAGER) ;
    gRsi6Data          = outputMat.row(DATA_TYPE_RSI6) ;
    gRsi12Data         = outputMat.row(DATA_TYPE_RSI12) ;
    gRsi24Data         = outputMat.row(DATA_TYPE_RSI24) ;
    gPwri6Data         = outputMat.row(DATA_TYPE_PWRI6) ;
    gPwri12Data        = outputMat.row(DATA_TYPE_PWRI12) ;
    gPwri24Data        = outputMat.row(DATA_TYPE_PWRI24) ;
    gXcgAvgICustomData = outputMat.row(DATA_TYPE_XCGI_CUSTOM) ;
    gRsiCustomData     = outputMat.row(DATA_TYPE_RSI_CUSTOM) ;
    gPwriCustomData    = outputMat.row(DATA_TYPE_PWRI_CUSTOM) ;

    if(gDailyMessData.rows > 0 && gDailyMessData.cols > 0){
        gDailyCls = outputDailyMat.row(DAILY_DATA_TYPE_CLS) ;
        gDailyClsAvg = outputDailyMat.row(DAILY_DATA_TYPE_CLS_AVG) ;
        gDailyDealAvg = outputDailyMat.row(DAILY_DATA_TYPE_DEAL_AVG) ;
        gDailyVol = outputDailyMat.row(DAILY_DATA_TYPE_VOL) ;
        gDailyVal = outputDailyMat.row(DAILY_DATA_TYPE_VAL) ;
        gDailyVolSect = outputDailyMat.row(DAILY_DATA_TYPE_VOLSECT) ;
        gDailyClsDealAvgDiff2 = outputDailyMat.row(DAILY_DATA_TYPE_CLS_DEAL_AVG_DIFF2) ;
    }

    SET_SWITCHER_STATUS(&sysSwitchers, REFRESH_VIEW) ;
    RESET_SWITCHER_STATUS(&sysSwitchers, REFRESH_DATA) ;

    return ;
}

int _doDefault(char c)
{
    switch(c){
        case 'q':
            return RSLT_REQ_QUIT ;
            break ;
        case ';':
            TOGGLE_SWITCH(&sysSwitchers,LOCK_SCREEN) ;
            if(!GET_SWITCHER_STATUS(sysSwitchers,LOCK_SCREEN)){
                RESET_SWITCHER_STATUS(&sysSwitchers, MEASURE) ;
                RESET_SWITCHER_STATUS(&sysSwitchers, CUTTING_HISTORY) ;
                SET_SWITCHER_STATUS(&sysSwitchers, REFRESH_DATA) ;
            }
            SET_SWITCHER_STATUS(&sysSwitchers, REFRESH_VIEW) ;
            break ;
        case '0':
            if(GET_SWITCHER_STATUS(sysSwitchers,LOCK_SCREEN)){
                if(dtlsIdxOnMainView == 0) break ;

                if(dtlsIdxOnMainView == dataRangeStart){
                    dataRangeStart -= GET_COUNT_OF_VIEW(gMainView.cols,scale) ;
                    dtlsIdxOnMainView = dataRangeStart ;
                }else{
                    dtlsIdxOnMainView = dataRangeStart ;
                }
            }else{
                if(dataRangeStart == 0) break ;

                dataRangeStart = 0 ;
            }
            SET_SWITCHER_STATUS(&sysSwitchers, REFRESH_VIEW) ;
            break ;
        case '$':
            if(GET_SWITCHER_STATUS(sysSwitchers,LOCK_SCREEN)){
                if(dtlsIdxOnMainView == gLinesData.cols-1) break ;

                if(dtlsIdxOnMainView == dataRangeEnd-1){
                    dataRangeStart = dataRangeEnd ;
                    dtlsIdxOnMainView += GET_COUNT_OF_VIEW(gMainView.cols,scale) ;
                    if(dtlsIdxOnMainView > gLinesData.cols-1){
                        dtlsIdxOnMainView = gLinesData.cols-1 ;
                        dataRangeStart = DATA_RANGE_UNSET ;     // trigger range_adjust_opertion
                    }
                }else{
                    dtlsIdxOnMainView = dataRangeEnd - 1 ;
                }
            }else{
                if(dataRangeEnd == gLinesData.cols) break ;

                dataRangeStart = gLinesData.cols - GET_COUNT_OF_VIEW(gMainView.cols,scale) ;
            }
            SET_SWITCHER_STATUS(&sysSwitchers, REFRESH_VIEW) ;
            break ;
        case 'M':
            if(GET_SWITCHER_STATUS(sysSwitchers,LOCK_SCREEN))
            {
                TOGGLE_SWITCH(&sysSwitchers, MEASURE) ;
                SET_SWITCHER_STATUS(&sysSwitchers, REFRESH_VIEW) ;
            }
            break ;
        case 'R':
            digtFuncIdx = 3 ;
            scale = 1 ;
            RESET_SWITCHER_STATUS(&sysSwitchers,AUTO_FIT) ;
            gPanelH = MAX_WIN_HEIGHT/2; gPanelW = MAX_WIN_WIDTH/2;
            dataRangeStart = DATA_RANGE_UNSET ;
            RESET_SWITCHER_STATUS(&sysSwitchers,LOCK_SCREEN) ;
            RESET_SWITCHER_STATUS(&sysSwitchers,SHOW_DAILY) ;
            dtlsIdxOnMainView = IDX_RANGE_UNSET;
            rsiCustom = 0 ;
            pwriCustom = 0 ;
            xcgAvgICustom = 0 ;
            for(int _i = 0; _i < FORECAST_DATA_DAYS; _i++){
                forecastCoefficients[_i] = 1.0 ;
            }
            indexSwitchers = ((1<<0)|(1<<4)) ;
            RESET_SWITCHER_STATUS(&sysSwitchers, MEASURE) ;
            CLEAN_SWITCHERS(&baseLineSwitchers); TOGGLE_SWITCH(&baseLineSwitchers,3-1); TOGGLE_SWITCH(&baseLineSwitchers,4-1);
            SETALL_SWITCHERS(&linesSwitchers); TOGGLE_SWITCH(&linesSwitchers,2-1);
            SET_SWITCHER_STATUS(&sysSwitchers, REFRESH_VIEW) ;
            SET_SWITCHER_STATUS(&sysSwitchers, REFRESH_DATA) ;
            break ;
        case 'r':
            if(GET_SWITCHER_STATUS(sysSwitchers,LOCK_SCREEN) && GET_SWITCHER_STATUS(sysSwitchers, SHOW_FORECAST)){
                int _i = dtlsIdxOnMainView-forecastIdx ;
                if(_i < 0 || _i >= FORECAST_DATA_DAYS) _i = 0 ;
                for(; _i<FORECAST_DATA_DAYS; _i++){
                    forecastCoefficients[_i] = 1.0 ;
                }
                SET_SWITCHER_STATUS(&sysSwitchers, REFRESH_DATA) ;
            }
            break ;
        case 'p':       // print current view info
            printViewInfo(true);
            break ;
        case 'P':       // print current view info
            printViewInfo(false);
            break ;
        case 'f':       // switch fix-scale flag
            TOGGLE_SWITCH(&sysSwitchers,AUTO_FIT) ;
            SET_SWITCHER_STATUS(&sysSwitchers, REFRESH_VIEW) ;
            break ;
        case 'w':
            /* as forecast_data will ignore hotData(data of current date),
               if enable forecast_data when daily_display_mode is on, no hotData updated to view.
               must DISABLE forecast_data before changing to daily_display_mode */
            if(GET_SWITCHER_STATUS(sysSwitchers, SHOW_DAILY)){
                 if(gBigDailyView){
                    TOGGLE_SWITCH(&sysSwitchers,SHOW_DAILY) ;
                 }else{
                    gBigDailyView = true ;
                 }
            }else{
                TOGGLE_SWITCH(&sysSwitchers,SHOW_DAILY) ;
                if(gWinOrder) gBigDailyView = false ;   // when display with others, set dailyView to SMALL

                if(GET_SWITCHER_STATUS(sysSwitchers,SHOW_FORECAST)){
                    RESET_SWITCHER_STATUS(&sysSwitchers,SHOW_FORECAST) ;
                    SET_SWITCHER_STATUS(&sysSwitchers, REFRESH_DATA) ;
                }
                /* same reason with CUTTING_HISTORY */
                if(GET_SWITCHER_STATUS(sysSwitchers,CUTTING_HISTORY)){
                    RESET_SWITCHER_STATUS(&sysSwitchers,CUTTING_HISTORY) ;
                    SET_SWITCHER_STATUS(&sysSwitchers, REFRESH_DATA) ;
                }
                /* set digtFunc to scale */
                digtFuncIdx = 3 ;
            }
            SET_SWITCHER_STATUS(&sysSwitchers, REFRESH_VIEW) ;
            break ;
        case 'F':       // switch forecast mode
            TOGGLE_SWITCH(&sysSwitchers, SHOW_FORECAST) ;
            if(!GET_SWITCHER_STATUS(sysSwitchers,LOCK_SCREEN)){
                dataRangeStart = DATA_RANGE_UNSET ;     // will trigger range_adjust_opertion
            }
            SET_SWITCHER_STATUS(&sysSwitchers, REFRESH_DATA) ;
            break ;
        case 'c':
            if(GET_SWITCHER_STATUS(sysSwitchers,LOCK_SCREEN)){
                SET_SWITCHER_STATUS(&sysSwitchers, CUTTING_HISTORY) ;
                cuttingIdx = dtlsIdxOnMainView ;
                SET_SWITCHER_STATUS(&sysSwitchers, REFRESH_DATA) ;
            }
            break ;
        case 'C':
            if(GET_SWITCHER_STATUS(sysSwitchers,LOCK_SCREEN)){
                RESET_SWITCHER_STATUS(&sysSwitchers, CUTTING_HISTORY) ;
                SET_SWITCHER_STATUS(&sysSwitchers, REFRESH_DATA) ;
            }
            break ;
        case 'n':
        case 'N':
            if(GET_SWITCHER_STATUS(sysSwitchers,LOCK_SCREEN) && GET_SWITCHER_STATUS(sysSwitchers, SHOW_FORECAST)){
                int _i = dtlsIdxOnMainView-forecastIdx ;
                if(_i < 0 || _i >= FORECAST_DATA_DAYS) _i = 0 ;
                forecastCoefficients[_i] += (c=='N') ? 0.005 : -0.005 ;
                SET_SWITCHER_STATUS(&sysSwitchers, REFRESH_DATA) ;
            }
            break ;
        case 's':
            if(GET_SWITCHER_STATUS(sysSwitchers, SHOW_DAILY)){
                // switch vol display mode if dialy view is on
                gDailyVolDispType = (gDailyVolDispType + 1) % DAILY_VOL_DISP_TYPE_COUNT ;
                SET_SWITCHER_STATUS(&sysSwitchers, REFRESH_VIEW) ;
            }else{
                // smooth the line (set data fix type to NONE/FORWARD_FIX/BACKWARD_FIX)
                dataFixType = (dataFixType + 1) % DATA_FIX_TYPE_COUNT ;
                SET_SWITCHER_STATUS(&sysSwitchers, REFRESH_VIEW) ;
                SET_SWITCHER_STATUS(&sysSwitchers, REFRESH_DATA) ;
            }
            break ;
        case '|':       // to maximu width
            //if(!GET_SWITCHER_STATUS(sysSwitchers,LOCK_SCREEN)){
                gPanelW = MAX_WIN_WIDTH ;
                SET_SWITCHER_STATUS(&sysSwitchers, REFRESH_VIEW) ;
            //}
            break ;
        case '_':       //  to maximu height
            //if(!GET_SWITCHER_STATUS(sysSwitchers,LOCK_SCREEN)){
                gPanelH = MAX_WIN_HEIGHT ;
                SET_SWITCHER_STATUS(&sysSwitchers, REFRESH_VIEW) ;
            //}
            break ;
        case '\\':       //  to maximu width & height
            //if(!GET_SWITCHER_STATUS(sysSwitchers,LOCK_SCREEN)){
                gPanelH = MAX_WIN_HEIGHT ; gPanelW = MAX_WIN_WIDTH;
                SET_SWITCHER_STATUS(&sysSwitchers, REFRESH_VIEW) ;
            //}
            break ;
        case '>':
            //if(!GET_SWITCHER_STATUS(sysSwitchers,LOCK_SCREEN)){
                gPanelW += 20 ;
                SET_SWITCHER_STATUS(&sysSwitchers, REFRESH_VIEW) ;
            //}
            break ;
        case '<':
            //if(!GET_SWITCHER_STATUS(sysSwitchers,LOCK_SCREEN)){
                gPanelW -= 20 ;
                SET_SWITCHER_STATUS(&sysSwitchers, REFRESH_VIEW) ;
            //}
            break ;
        case '-':
            //if(!GET_SWITCHER_STATUS(sysSwitchers,LOCK_SCREEN)){
                gPanelH -= 10 ;
                SET_SWITCHER_STATUS(&sysSwitchers, REFRESH_VIEW) ;
            //}
            break ;
        case '+':
            //if(!GET_SWITCHER_STATUS(sysSwitchers,LOCK_SCREEN)){
                gPanelH += 10 ;
                SET_SWITCHER_STATUS(&sysSwitchers, REFRESH_VIEW) ;
            //}
            break ;
        case 'l':
        case 'L':
            {
                if(GET_SWITCHER_STATUS(sysSwitchers,LOCK_SCREEN)){
                    int step = (c == 'l') ? 1 : MONTH_DAYS ;
                    if(dtlsIdxOnMainView == gLinesData.cols-1) break ;

                    if(dtlsIdxOnMainView == dataRangeEnd-1){
                        dataRangeStart += step ;
                        dtlsIdxOnMainView += step ;
                        if(dataRangeStart + GET_COUNT_OF_VIEW(gMainView.cols,scale) > gLinesData.cols){
                            dataRangeStart = DATA_RANGE_UNSET ;
                        }
                    }else{
                        dtlsIdxOnMainView += step ;
                        if(dtlsIdxOnMainView > dataRangeEnd-1)   dtlsIdxOnMainView = dataRangeEnd-1 ;
                    }
                }else{
                    int step = (c == 'l') ? MONTH_DAYS : SEASON_DAYS ;
                    if(dataRangeEnd == gLinesData.cols) break ;

                    dataRangeStart += step ;
                    if(dataRangeStart + GET_COUNT_OF_VIEW(gMainView.cols,scale) > gLinesData.cols)
                        dataRangeStart = DATA_RANGE_UNSET ;
                }
                SET_SWITCHER_STATUS(&sysSwitchers, REFRESH_VIEW) ;
            }
            break ;
        case 'h':
        case 'H':
            {
                if(GET_SWITCHER_STATUS(sysSwitchers,LOCK_SCREEN)){
                    int step = (c == 'h') ? 1 : MONTH_DAYS ;
                    if(dtlsIdxOnMainView == 0) break ;

                    if(dtlsIdxOnMainView == dataRangeStart){
                        dataRangeStart -= step ;
                        dtlsIdxOnMainView -= step ;
                    }else{
                        dtlsIdxOnMainView -= step;
                        if(dtlsIdxOnMainView < dataRangeStart) dtlsIdxOnMainView = dataRangeStart ;
                    }
                }else{
                    if(dataRangeStart == 0) break ;

                    dataRangeStart -= (c == 'h') ? MONTH_DAYS : SEASON_DAYS ;
                }
                SET_SWITCHER_STATUS(&sysSwitchers, REFRESH_VIEW) ;
            }
            break ;
        case 'j':   // switch the 0~9 keys function
            digtFuncIdx = ( digtFuncIdx + 1 ) % ( sizeof( digtFuncList )/sizeof( digtFuncPt ) );
            SET_SWITCHER_STATUS(&sysSwitchers, REFRESH_VIEW) ;
            break ;
        case 'k':
            digtFuncIdx = (0 == digtFuncIdx)
                        ? sizeof( digtFuncList )/sizeof( digtFuncPt ) - 1
                        : digtFuncIdx - 1 ;
            SET_SWITCHER_STATUS(&sysSwitchers, REFRESH_VIEW) ;
            break ;
        default:
            break ;
        }

        return 0 ;
}

void* listener(void* p)
{
    int         sigNum ;
    sigset_t    _set ;

    sigemptyset(&_set) ;
    sigaddset(&_set,SIGUSR1) ;
    sigprocmask(SIG_SETMASK, &_set, NULL) ;

    while(1){
        sigwait(&_set, &sigNum) ;

        switch(sigNum){
        case SIGUSR1:
        case SIGUSR2:
            //cout << "main received " << sigNum << endl ;
            SET_SWITCHER_STATUS(&sysSwitchers, REFRESH_DATA) ;
            break ;
        default:
            cerr << "How did you get here? Go and check you code!" << endl ;
            break ;
        }
    }
}

int main( int argc, char** argv )
{
#if 0
    {
        Range r(7,16) ;
        cout << r.size() << endl ; 
        Mat m1(10,10,CV_32F) ;
        Mat m2(20,20,CV_32F) ;

        cout << m1.size() << endl ;
        m2.copyTo(m1) ;
        cout << m1.size() << endl ;
        float*p1 = m1.ptr<float>(0) ;
        float*p2 = m2.ptr<float>(0) ;
        cout << p1 << endl ;
        cout << p2 << endl ;
        return 0 ;
    }
    { 
        Mat m1(0,10,CV_8U) ;
        cout << m1.size() << endl ;
        cout << m1.empty() << endl ;
        return 0 ;

        uchar *p ;
        Mat m(10,10,CV_8U) ;
        //m.reserve(600) ;
         p = m.ptr<uchar>(300); cout << p << endl ;
         p[0]=3 ;
        m.resize(9) ;
         p = m.ptr(0); cout << p << endl ;
        m.resize(4) ;
         p = m.ptr(0); cout << p << endl ;

        return 0 ;
    }
    {
        Mat m(10,10,CV_8U,Scalar::all(1)) ;
        uchar* p=m.ptr<uchar>(0) ;
        if(m.isContinuous()) for(int i=0;i<m.total();i++) p[i]=i ;


        Mat o(m,Rect(2,2,5,5)) ;
        o.resize(8,Scalar(1,2,3)) ;
        o.at<uchar>(1,1)=233 ;
        cout << o << endl ;
        cout << m << endl ;
        return 0 ;
    }
        

    Mat m=(Mat_<int>(3,3)<<1,2,3,  4,5,6,  7,8,9) ;
    Mat n=(Mat_<int>(3,3)<<2,4,6,  1,1,1,  1,1,1) ;
    Mat o=(Mat_<int>(3,3)<<1,1,1,  1,1,1,  1,1,1) ;
    Mat p(o) ;

    cout << p << endl ;
    o = n/m ;
    cout << p << endl ;
    return 0 ;
#endif

    char                _c = 0 ;
    map<size_t,char*>   _args ;
    size_t              _argCnt = 0 ;
    bool                _firstLooking = false ;
    bool                _print = false ;
    bool                _printLastOne = false ;
    char*               _hotData = NULL ;
    char*               _searchingDate = NULL ;     // to find the firstLooking_date
#if THREAD_SUPPORT
    pthread_t           _tid = 0 ;
#endif

    /* import data from files
     * _args[0]                  :   stock name  //cannot support chinese...
     * _args[1]                  :   stock code
     * _args[2]                  :   hisData(history data)
     * _args[3]                  :   hisData count  // expired arguments
     * _args[4]                  :   hotData(current data)
     * _args[5]                  :   hotData count  // expired arguments
     */

    /* parsing arguments */
    for(int _i = 1; _i < argc; _i++){
        if (string(argv[_i]) == "--help"){
            cerr << endl << "Usage: " << endl << argv[0] << " [--print] [--printLastOne] [--showDaily] [--winOrder] [--fixType F/B/N] stockName stockCode hisDataFile hisDataRecNum hotDataFile hotDataRecNum" << endl << endl ;
            return 0 ;
        }

        if (string(argv[_i]) == "--print"){
            _print = true ;
            continue ;
        }

        if (string(argv[_i]) == "--printLastOne"){
            _printLastOne = true ;
            continue ;
        }

        if (string(argv[_i]) == "--showDaily"){
            SET_SWITCHER_STATUS(&sysSwitchers,SHOW_DAILY) ;
            continue ;
        }

        if (string(argv[_i]) == "--firstLooking"){
            _i++ ;
            if(_i >= argc){
                cerr << "!!need specify a date" << endl ;
                return -1 ;
            }
            if(10 != strlen(argv[_i])){
                cerr << "!!use yyyy-mm-dd for date format" << endl ;
                return -1 ;
            }
            _searchingDate = argv[_i] ;
            _firstLooking = true ;
            continue ;

        }

        if (string(argv[_i]) == "--fixType"){
            _i++ ;
            switch(argv[_i][0]){
                case 'F' :
                    dataFixType =  DATA_FIX_TYPE_FORWARD ;
                    break ;
                case 'B' :
                    dataFixType =  DATA_FIX_TYPE_BACKWARD ;
                    break ;
                case 'N' :
                    dataFixType =  DATA_FIX_TYPE_NONE ;
                    break ;
                default:
                    cerr << "unknown parameter: --fixType " << argv[_i] << endl << endl ;
                    return -1 ;
            }
            continue ;
        }

        if (string(argv[_i]) == "--winOrder"){
            _i++ ;
            if(_i >= argc){
                cerr << "need specify a value for posX" << endl ;
                return -1 ;
            }

            gWinOrder = atoi(argv[_i]) ;
            if(gWinOrder <= 0){
                cerr << "winOrder must great than 0" << endl ;
                return -1 ;
            }

            gBigDailyView = false ;  // set daily to samll as there are several window need to be displayed.
            continue ;
        }

        if(argv[_i][0] == argv[_i][1] && argv[_i][0]== '-'){
            cerr << "unknown option:" << argv[_i] << endl ;
            return -1 ;
        }

        _args[_argCnt++] = argv[_i] ;
    }

    for(int _i = 0; _i < FORECAST_DATA_DAYS; _i++){
        forecastCoefficients[_i] = 1.0 ;
    }

    stockName = _args[0] ;
    stockId = _args[1] ;
    _hotData = _args[4] ;
    SET_SWITCHER_STATUS(&sysSwitchers, REFRESH_DATA) ;
    SET_SWITCHER_STATUS(&sysSwitchers, REFRESH_VIEW) ;

#if THREAD_SUPPORT
    pthread_mutex_init(&gMutex, NULL) ;
    pthread_create(&_tid, NULL, listener, NULL) ;
#endif

    /* creat all views */
    //{
#if 0
        view mainView(Mat(670-270,1280-320,CV_8UC3)) ;
        dataSource source(_args[2], _args[4]) ;
        lineObj lines ;

        int linesDataIdx[] = {
                          dataSource::DATA_ID_HIS_CLS,
                          dataSource::DATA_ID_HIS_HIG,
                          dataSource::DATA_ID_HIS_LOW,
                          dataSource::DATA_ID_HIS_OPN,
                          dataSource::DATA_ID_HIS_YSTDCLS
                          } ;
        lines.setLineSets(std::vector<int>(linesDataIdx,linesDataIdx+sizeof(linesDataIdx)/sizeof(int))) ;
        source.transportData(source.connect(lines, NULL)) ;
        mainView.setFocus(mainView.addShape(lines)) ;
        mainView.doOrder() ;
        mainView.doMoving(MOVING_LEFT,2000000) ;
        mainView.doMovingView(270,0) ;
        mainView.doRefresh() ;
        mainView.assignDataSrcUpdateListener(source) ;
        source.start() ;
        //return 0 ;
#endif
    //}

    while (1)
    {
        if(GET_SWITCHER_STATUS(sysSwitchers, REFRESH_DATA)){
            _doRefreshData(_args[2], _hotData, dataFixType, gMessData, gDailyMessData) ;
#if 0
            PRINT_DAILY_DATA() ;
#endif
        }

        if(_printLastOne){
            PRINT_INFO(LAST_ITEM) ;
            return 0 ;
        }

        if(_print){
            PRINT_INFO(ALL_ITEMS) ;
            return 0 ;
        }

        if(_firstLooking){

            int   _i = 0 ;
            long  _dateIdx = 0 ;
            
            _dateIdx = ( ( (_searchingDate[0]-'0')*1000+
                           (_searchingDate[1]-'0')*100+
                           (_searchingDate[2]-'0')*10+
                           (_searchingDate[3]-'0') ) - 1970) * 12 * 31 
                       +
                       ( ( (_searchingDate[5]-'0')*10+
                           (_searchingDate[6]-'0') ) - 1)*31
                       +
                       ( ( (_searchingDate[8]-'0')*10+
                           (_searchingDate[9]-'0') ) - 1) ;

            for(_i=0; _i<gDateData.cols; _i++){
                if(_dateIdx <= gDateData.at<double>(0,_i)) break ;
            }

            if(_i<gDateData.cols){
                measureIdx = _i ;
                dataRangeStart = max(0, measureIdx - GET_COUNT_OF_VIEW(gPanelW-LEFT_VIEW_W-10, scale)/2) ;
                SET_SWITCHER_STATUS(&sysSwitchers,MEASURE) ;
                SET_SWITCHER_STATUS(&sysSwitchers,LOCK_SCREEN) ;
            }else{
                cerr << "!!Cannot find " << _searchingDate << endl ;
            }

            _firstLooking = 0 ;
        }

        if(GET_SWITCHER_STATUS(sysSwitchers, REFRESH_VIEW)){
            _doRefreshView() ;
        }

        _c = 0 ;
        _c = waitKey(1000) ;

#if 0
        //preProcess(_c) ;
        if(_c == 'q') break ;
        mainView.handleKey(_c,&mainView) ;
        //postProcess(_c) ;
#else
        if(RSLT_NOTHING == doDigitalFunc(_c)){
            if(RSLT_REQ_QUIT == _doDefault(_c)) break ;
        }
#endif
    }

    return 0 ;
}

//int main( int argc, char** argv )
//{
//    Mat src, hsv;
//    if( argc != 2 || !(src=imread(argv[1], 1)).data )
//    return -1;
//    cvtColor(src, hsv, COLOR_BGR2HSV);
//    // Quantize the hue to 30 levels
//    // and the saturation to 32 levels
//    int hbins = 30, sbins = 32;
//    int histSize[] = {hbins, sbins};
//    // hue varies from 0 to 179, see cvtColor
//    float hranges[] = { 0, 180 };
//    // saturation varies from 0 (black-gray-white) to
//    // 255 (pure spectrum color)
//    float sranges[] = { 0, 256 };
//    const float* ranges[] = { hranges, sranges };
//    MatND hist;
//    // we compute the histogram from the 0-th and 1-st channels
//    int channels[] = {0, 1};
//    calcHist( &hsv, 1, channels, Mat(), // do not use mask
//    hist, 2, histSize, ranges,
//    true, // the histogram is uniform
//    false );
//    double maxVal=0;
//    minMaxLoc(hist, 0, &maxVal, 0, 0);
//    int scale = 10;
//    Mat histImg = Mat::zeros(sbins*scale, hbins*10, CV_8UC3);
//    for( int h = 0; h < hbins; h++ )
//        for( int s = 0; s < sbins; s++ )
//        {
//            float binVal = hist.at<float>(h, s);
//            int intensity = cvRound(binVal*255/maxVal);
//            rectangle(  histImg, Point(h*scale, s*scale),
//                        Point( (h+1)*scale - 1, (s+1)*scale - 1),
//                        Scalar::all(intensity),
//                        CV_FILLED );
//        }
//    namedWindow( "Source", 1 );
//    imshow( "Source", src );
//    namedWindow( "H-S Histogram", 1 );
//    imshow( "H-S Histogram", histImg );
//    waitKey();
//}

//int main(int argc, char** argv)
//{
//    Mat src, dst;
//    String imageName( "../data/lena.jpg" ); // by default
//    if (argc > 1)
//    {
//        imageName = argv[1];
//    }
//
//    src = imread( imageName, IMREAD_COLOR );
//    if( src.empty() )
//    { return -1; }
//
//    vector<Mat> bgr_planes;
//    split( src, bgr_planes );
//
//    int histSize = 256;
//    float range[] = { 0, 256 } ;
//    const float* histRange =  range ;
//
//    bool uniform = true; bool accumulate = false;
//    Mat b_hist, g_hist, r_hist;
//    calcHist( &bgr_planes[0], 1, 0, Mat(), b_hist, 1, &histSize, &histRange, uniform, accumulate );
//    calcHist( &bgr_planes[1], 1, 0, Mat(), g_hist, 1, &histSize, &histRange, uniform, accumulate );
//    calcHist( &bgr_planes[2], 1, 0, Mat(), r_hist, 1, &histSize, &histRange, uniform, accumulate );
//    // Draw the histograms for B, G and R
//    int hist_w = 512; int hist_h = 400;
//    int bin_w = cvRound( (double) hist_w/histSize );
//    Mat histImage( hist_h, hist_w, CV_8UC3, Scalar( 0,0,0) );
//    normalize(b_hist, b_hist, 0, histImage.rows, NORM_MINMAX, -1, Mat() );
//    normalize(g_hist, g_hist, 0, histImage.rows, NORM_MINMAX, -1, Mat() );
//    normalize(r_hist, r_hist, 0, histImage.rows, NORM_MINMAX, -1, Mat() );
//    for( int i = 1; i < histSize; i++ )
//    {
//        line( histImage, Point( bin_w*(i-1), hist_h - cvRound(b_hist.at<float>(i-1)) ) ,
//        Point( bin_w*(i), hist_h - cvRound(b_hist.at<float>(i)) ),
//        Scalar( 255, 0, 0), 2, 8, 0  );
//        line( histImage, Point( bin_w*(i-1), hist_h - cvRound(g_hist.at<float>(i-1)) ) ,
//        Point( bin_w*(i), hist_h - cvRound(g_hist.at<float>(i)) ),
//        Scalar( 0, 255, 0), 2, 8, 0  );
//        line( histImage, Point( bin_w*(i-1), hist_h - cvRound(r_hist.at<float>(i-1)) ) ,
//        Point( bin_w*(i), hist_h - cvRound(r_hist.at<float>(i)) ),
//        Scalar( 0, 0, 255), 2, 8, 0  );
//    }
//    namedWindow("calcHist Demo", WINDOW_AUTOSIZE );
//    imshow("calcHist Demo", histImage );
//    waitKey(0);
//    return 0;
//}

//int main( int, char** argv )
//{
//    Mat src, dst;
//    const char* source_window = "Source image";
//    const char* equalized_window = "Equalized Image";
//    src = imread( argv[1], IMREAD_COLOR );
//    if( src.empty() ) { cout<<"Usage: ./EqualizeHist_Demo <path_to_image>"<<endl;
//        return -1;
//    }
//
//    cvtColor( src, src, COLOR_BGR2GRAY );
//    equalizeHist( src, dst );
//    namedWindow( source_window, WINDOW_AUTOSIZE );
//    namedWindow( equalized_window, WINDOW_AUTOSIZE );
//    imshow( source_window, src );
//    imshow( equalized_window, dst );
//    waitKey(0);
//    return 0;
//}
//
////const char* source_window = "Source image";
////const char* warp_window = "Warp";
////const char* warp_rotate_window = "Warp + Rotate";
////int main( int, char** argv )
////{
////    Point2f srcTri[3];
////    Point2f dstTri[3];
////    Mat rot_mat( 2, 3, CV_32FC1 );
////    Mat warp_mat( 2, 3, CV_32FC1 );
////    Mat src, warp_dst, warp_rotate_dst;
////
////    src = imread( argv[1], IMREAD_COLOR );
////    warp_dst = Mat::zeros( src.rows, src.cols, src.type() );
////
////    srcTri[0] = Point2f( 0,0 );
////    srcTri[1] = Point2f( src.cols - 1.f, 0 );
////    srcTri[2] = Point2f( 0, src.rows - 1.f );
////    dstTri[0] = Point2f( src.cols*0.0f, src.rows*0.33f );
////    dstTri[1] = Point2f( src.cols*0.85f, src.rows*0.25f );
////    dstTri[2] = Point2f( src.cols*0.15f, src.rows*0.7f );
////    warp_mat = getAffineTransform( srcTri, dstTri );
////    warpAffine( src, warp_dst, warp_mat, warp_dst.size() );
////
////    Point center = Point( warp_dst.cols/2, warp_dst.rows/2 );
////    double angle = -50.0;
////    double scale = 0.6;
////    rot_mat = getRotationMatrix2D( center, angle, scale );
////    warpAffine( warp_dst, warp_rotate_dst, rot_mat, warp_dst.size() );
////
////    namedWindow( source_window, WINDOW_AUTOSIZE );
////    imshow( source_window, src );
////    namedWindow( warp_window, WINDOW_AUTOSIZE );
////    imshow( warp_window, warp_dst );
////    namedWindow( warp_rotate_window, WINDOW_AUTOSIZE );
////    imshow( warp_rotate_window, warp_rotate_dst );
////    waitKey(0);
////    return 0;
////}
////
//////Mat src, dst;
//////Mat map_x, map_y;
//////const char* remap_window = "Remap demo";
//////int ind = 0;
//////void update_map( void );
//////int main(int argc, const char** argv)
//////{
//////    CommandLineParser parser(argc, argv, "{@image |../data/chicky_512.png|input image name}");
//////    std::string filename = parser.get<std::string>(0);
//////    src = imread( filename, IMREAD_COLOR );
//////    dst.create( src.size(), src.type() );
//////    map_x.create( src.size(), CV_32FC1 );
//////    map_y.create( src.size(), CV_32FC1 );
//////    namedWindow( remap_window, WINDOW_AUTOSIZE );
//////    for(;;) {
//////        char c = (char)waitKey(  );
//////        if( c == 27 )
//////        { break; }
//////        update_map();
//////        remap( src, dst, map_x, map_y, INTER_LINEAR, BORDER_CONSTANT, Scalar(0, 0, 0) );
//////        // Display results
//////        imshow( remap_window, dst );
//////    }
//////    return 0;
//////}
//////
//////void update_map( void )
//////{
//////    ind = ind%4;
//////    for( int j = 0; j < src.rows; j++ ) {
//////        for( int i = 0; i < src.cols; i++ ) {
//////            switch( ind ) {
//////                case 0:
//////                    if( i > src.cols*0.25 && i < src.cols*0.75 && j > src.rows*0.25 && j < src.rows*0.75 )
//////                    {
//////                        map_x.at<float>(j,i) = 2*( i - src.cols*0.25f ) + 0.5f ;
//////                        map_y.at<float>(j,i) = 2*( j - src.rows*0.25f ) + 0.5f ;
//////                    }
//////                    else
//////                    {
//////                        map_x.at<float>(j,i) = 0 ;
//////                        map_y.at<float>(j,i) = 0 ;
//////                    }
//////                    break;
//////                case 1:
//////                    map_x.at<float>(j,i) = (float)i ;
//////                    map_y.at<float>(j,i) = (float)(src.rows - j) ;
//////                    break;
//////                case 2:
//////                    map_x.at<float>(j,i) = (float)(src.cols - i) ;
//////                    map_y.at<float>(j,i) = (float)j ;
//////                    break;
//////                case 3:
//////                    map_x.at<float>(j,i) = (float)(src.cols - i) ;
//////                    map_y.at<float>(j,i) = (float)(src.rows - j) ;
//////                    break;
//////            } // end of switch
//////        }
//////    }
//////    ind++;
//////}
//////
////////static void help()
////////{
////////        cout << "\nThis program demonstrates circle finding with the Hough transform.\n"
////////                "Usage:\n"
////////                "./houghcircles <image_name>, Default is ../data/board.jpg\n" << endl;
////////}
////////
////////int main(int argc, char** argv)
////////{
////////    cv::CommandLineParser parser(argc, argv,
////////        "{help h ||}{opt1 o1 ||}{opt2 o2 ||}{opt3 o3 ||}{opt4 o4 ||}{@image|../data/board.jpg|}"
////////        );
////////
////////    if (parser.has("help")) {
////////        help();
////////        return 0;
////////    }
////////
////////    string filename = parser.get<string>("@image");
////////    cout << filename << endl ;
////////
////////    Mat img = imread(filename, IMREAD_COLOR);
////////    if(img.empty()) {
////////        help();
////////        cout << "can not open " << filename << endl;
////////        return -1;
////////    }
////////
////////    Mat gray;
////////    Mat up ;
////////    cvtColor(img, gray, COLOR_BGR2GRAY);
////////    pyrUp(gray,gray,Size(gray.cols*2, gray.rows*2)) ;
////////    medianBlur(gray, gray, 5);
////////    imshow("tmp",gray);
////////    waitKey();
////////
////////    vector<Vec3f> circles;
////////    HoughCircles(gray, circles, HOUGH_GRADIENT, 1,
////////        gray.rows/16, // change this value to detect circles with different distances to each other
////////        100, 30, 60, 120 // change the last two parameters
////////        // (min_radius & max_radius) to detect larger circles
////////        );
////////    cout << circles.size() << endl ;
////////    cvtColor(gray, img, COLOR_GRAY2BGR);
////////    for( size_t i = 0; i < circles.size(); i++ ) {
////////        Vec3i c = circles[i];
////////        circle( img, Point(c[0], c[1]), c[2], Scalar(0,0,255), 3, LINE_AA);
////////        circle( img, Point(c[0], c[1]), 2, Scalar(0,255,0), 3, LINE_AA);
////////    }
////////
////////    imshow("detected circles", img);
////////    waitKey();
////////    return 0;
////////}
////////
//////////Mat src, dst, tmp;
//////////const char* window_name = "Pyramids Demo";
//////////int main( int argc ,char ** argv )
//////////{
//////////    printf( "\n Zoom In-Out demo  \n " );
//////////    printf( "------------------ \n" );
//////////    printf( " * [u] -> Zoom in  \n" );
//////////    printf( " * [d] -> Zoom out \n" );
//////////    printf( " * [ESC] -> Close program \n \n" );
//////////    src = imread( argv[1] ); // Loads the test image
//////////    if( src.empty() ) {
//////////        printf(" No data! -- Exiting the program \n");
//////////        return -1;
//////////    }
//////////
//////////    tmp = src;
//////////    dst = tmp;
//////////    imshow( window_name, dst );
//////////    for(;;)
//////////    {
//////////        char c = (char)waitKey(0);
//////////        if( c == 27 ) { break; }
//////////        if( c == 'u' ) { pyrUp( tmp, dst, Size( tmp.cols*2, tmp.rows*2 ) );
//////////            printf( "** Zoom In: Image x 2 \n" );
//////////        }
//////////        else if( c == 'd' ) { pyrDown( tmp, dst, Size( tmp.cols/2, tmp.rows/2 ) );
//////////            printf( "** Zoom Out: Image / 2 \n" );
//////////        }
//////////        imshow( window_name, dst );
//////////        tmp = dst;
//////////    }
//////////    return 0;
//////////}
//////////
////////////static void help()
////////////{
////////////    cout << "\nThis program demonstrates line finding with the Hough transform.\n"
////////////    "Usage:\n"
////////////    "./houghlines <image_name>, Default is ../data/pic1.png\n" << endl;
////////////}
////////////int main(int argc, char** argv)
////////////{
////////////    cv::CommandLineParser parser(argc, argv,
////////////    "{help h||}{@image|../data/pic1.png|}"
////////////    );
////////////    if (parser.has("help"))
////////////    {
////////////        help();
////////////        return 0;
////////////    }
////////////    string filename = parser.get<string>("@image");
////////////    if (filename.empty())
////////////    {
////////////        help();
////////////        cout << "no image_name provided" << endl;
////////////        return -1;
////////////    }
////////////    Mat src = imread(filename, 0);
////////////    if(src.empty())
////////////    {
////////////        help();
////////////        cout << "can not open " << filename << endl;
////////////        return -1;
////////////    }
////////////    Mat dst, cdst;
////////////    Canny(src, dst, 50, 200, 3);
////////////    cvtColor(dst, cdst, COLOR_GRAY2BGR);
////////////#if 0
////////////    vector<Vec2f> lines;
////////////    HoughLines(dst, lines, 1, CV_PI/180, 100, 0, 0 );
////////////    for( size_t i = 0; i < lines.size(); i++ )
////////////    {
////////////        float rho = lines[i][0], theta = lines[i][1];
////////////        Point pt1, pt2;
////////////        double a = cos(theta), b = sin(theta);
////////////        double x0 = a*rho, y0 = b*rho;
////////////        pt1.x = cvRound(x0 + 1000*(-b));
////////////        pt1.y = cvRound(y0 + 1000*(a));
////////////        pt2.x = cvRound(x0 - 1000*(-b));
////////////        pt2.y = cvRound(y0 - 1000*(a));
////////////        line( cdst, pt1, pt2, Scalar(0,0,255), 3, CV_AA);
////////////    }
////////////#else
////////////    vector<Vec4i> lines;
////////////    HoughLinesP(dst, lines, 1, CV_PI/180, 50, 50, 10 );
////////////    for( size_t i = 0; i < lines.size(); i++ )
////////////    {
////////////        Vec4i l = lines[i];
////////////        line( cdst, Point(l[0], l[1]), Point(l[2], l[3]), Scalar(0,0,255), 3, LINE_AA);
////////////    }
////////////#endif
////////////    imshow("source", src);
////////////    imshow("detected lines", cdst);
////////////    waitKey();
////////////    return 0;
////////////}
////////////
////////////
//////////////Mat src, src_gray;
//////////////Mat dst, detected_edges;
//////////////int edgeThresh = 1;
//////////////int lowThreshold;
//////////////int const max_lowThreshold = 100;
//////////////int ratio = 3;
//////////////int kernel_size = 3;
//////////////const char* window_name = "Edge Map";
//////////////static void CannyThreshold(int, void*)
//////////////{
//////////////    blur( src_gray, detected_edges, Size(3,3) );
//////////////    Canny( detected_edges, detected_edges, lowThreshold, lowThreshold*::ratio, kernel_size );
//////////////    dst = Scalar::all(0);
//////////////    src.copyTo( dst, detected_edges);
//////////////    imshow( window_name, dst );
//////////////}
//////////////int main( int, char** argv )
//////////////{
//////////////    src = imread( argv[1], IMREAD_COLOR ); // Load an image
//////////////    if( src.empty() )
//////////////    { return -1; }
//////////////    dst.create( src.size(), src.type() );
//////////////    cvtColor( src, src_gray, COLOR_BGR2GRAY );
//////////////    namedWindow( window_name, WINDOW_AUTOSIZE );
//////////////    createTrackbar( "Min Threshold:", window_name, &lowThreshold, max_lowThreshold, CannyThreshold );
//////////////    CannyThreshold(0, 0);
//////////////    waitKey(0);
//////////////    return 0;
//////////////}
//////////////
////////////////int main( int argc, char** argv )
////////////////{
////////////////    Mat src, src_gray, dst;
////////////////    int kernel_size = 3;
////////////////    int scale = 1;
////////////////    int delta = 0;
////////////////    int ddepth = CV_16S;
////////////////    const char* window_name = "Laplace Demo";
////////////////    String imageName("../data/lena.jpg"); // by default
////////////////    if (argc > 1)
////////////////    {
////////////////    imageName = argv[1];
////////////////    }
////////////////    src = imread( imageName, IMREAD_COLOR ); // Load an image
////////////////    if( src.empty() )
////////////////    { return -1; }
////////////////    GaussianBlur( src, src, Size(3,3), 0, 0, BORDER_DEFAULT );
////////////////    cvtColor( src, src_gray, COLOR_BGR2GRAY ); // Convert the image to grayscale
////////////////    Mat abs_dst;
////////////////    Laplacian( src_gray, dst, ddepth, kernel_size, scale, delta, BORDER_DEFAULT );
////////////////    convertScaleAbs( dst, abs_dst );
////////////////    imshow( window_name, abs_dst );
////////////////    waitKey(0);
////////////////    return 0;
////////////////}
//////////////
////////////////int main( int argc, char** argv )
////////////////{
////////////////    Mat src, src_gray;
////////////////    Mat grad;
////////////////    const char* window_name = "Sobel Demo - Simple Edge Detector";
////////////////    int scale = 1;
////////////////    int delta = 0;
////////////////    int ddepth = CV_16S;
////////////////    String imageName("../data/lena.jpg"); // by default
////////////////    if (argc > 1)
////////////////    {
////////////////    imageName = argv[1];
////////////////    }
////////////////    src = imread( imageName, IMREAD_COLOR ); // Load an image
////////////////    if( src.empty() )
////////////////    { return -1; }
////////////////    GaussianBlur( src, src, Size(3,3), 0, 0, BORDER_DEFAULT );
////////////////    cvtColor( src, src_gray, COLOR_BGR2GRAY );
////////////////    Mat grad_x, grad_y, dst_laplacian;
////////////////    Mat abs_grad_x, abs_grad_y, abs_laplacian;
////////////////    //Scharr( src_gray, grad_x, ddepth, 1, 0, scale, delta, BORDER_DEFAULT );
////////////////    Sobel( src_gray, grad_x, ddepth, 1, 0, 3, scale, delta, BORDER_DEFAULT );
////////////////    //Scharr( src_gray, grad_y, ddepth, 0, 1, scale, delta, BORDER_DEFAULT );
////////////////    Sobel( src_gray, grad_y, ddepth, 0, 1, 3, scale, delta, BORDER_DEFAULT );
////////////////    Laplacian( src_gray, dst_laplacian, ddepth, 3, scale, delta, BORDER_DEFAULT );
////////////////    convertScaleAbs( grad_x, abs_grad_x );
////////////////    convertScaleAbs( grad_y, abs_grad_y );
////////////////    convertScaleAbs( dst_laplacian, abs_laplacian );
////////////////    addWeighted( abs_grad_x, 0.5, abs_grad_y, 0.5, 0, grad );
////////////////    imshow("x",abs_grad_x);
////////////////    imshow("y",abs_grad_y);
////////////////    imshow( "laplacian", abs_laplacian );
////////////////    imshow( window_name, grad );
////////////////    waitKey(0);
////////////////    return 0;
////////////////}
//////////////
////////////////Mat src, dst;
////////////////int top, bottom, left, right;
////////////////int borderType;
////////////////const char* window_name = "copyMakeBorder Demo";
////////////////RNG rng(12345);
////////////////
////////////////int main( int argc, char** argv )
////////////////{
////////////////    String imageName("../data/lena.jpg"); // by default
////////////////    if (argc > 1)
////////////////    {
////////////////    imageName = argv[1];
////////////////    }
////////////////    src = imread( imageName, IMREAD_COLOR ); // Load an image
////////////////    if( src.empty() )
////////////////    {
////////////////    printf(" No data entered, please enter the path to an image file \n");
////////////////    return -1;
////////////////    }
////////////////    printf( "\n \t copyMakeBorder Demo: \n" );
////////////////    printf( "\t -------------------- \n" );
////////////////    printf( " ** Press 'c' to set the border to a random constant value \n");
////////////////    printf( " ** Press 'r' to set the border to be replicated \n");
////////////////    printf( " ** Press 'ESC' to exit the program \n");
////////////////    namedWindow( window_name, WINDOW_AUTOSIZE );
////////////////    ::top = (int) (0.25*src.rows); ::bottom = (int) (0.25*src.rows);
////////////////    ::left = (int) (0.25*src.cols); ::right = (int) (0.25*src.cols);
////////////////    dst = src;
////////////////    imshow( "src", src );
////////////////    imshow( window_name, dst );
////////////////    for(;;)
////////////////    {
////////////////        char c = (char)waitKey(500);
////////////////        if( c == 27 )
////////////////        { break; }
////////////////        else if( c == 'c' )
////////////////        { borderType = BORDER_CONSTANT; }
////////////////        else if( c == 'r' )
////////////////        { borderType = BORDER_REPLICATE; }
////////////////        Scalar value( rng.uniform(0, 255), rng.uniform(0, 255), rng.uniform(0, 255) );
////////////////        copyMakeBorder( src, dst, ::top, ::bottom, ::left, ::right, borderType, value );
////////////////        imshow( window_name, dst );
////////////////    }
////////////////    return 0;
////////////////}
//////////////
//int main ( int argc, char** argv )
//{
//    Mat src, dst;
//    Mat kernel;
//    Point anchor;
//    double delta;
//    int ddepth;
//    int kernel_size;
//    const char* window_name = "filter2D Demo";
//    String imageName("../data/lena.jpg"); // by default
//    if (argc > 1)
//    {
//        imageName = argv[1];
//    }
//    src = imread( imageName, IMREAD_COLOR ); // Load an image
//    if( src.empty() )
//    { return -1; }
//    anchor = Point( -1, -1 );
//    delta = 0;
//    ddepth = -1;
//    int ind = 0;
//    for(;;)
//    {
//        char c = (char)waitKey(500);
//        if( c == 27 ) { break; }
//
//        kernel_size = 3 + 2*( ind%5 );
//        kernel = Mat::ones( kernel_size, kernel_size, CV_32F )/ (float)(kernel_size*kernel_size);
//        filter2D(src, dst, ddepth , kernel, anchor, delta, BORDER_DEFAULT );
//        imshow( window_name, dst );
//        ind++;
//    }
//    return 0;
//}
//////////////
//////////////
////////////////void on_low_r_thresh_trackbar(int, void *);
////////////////void on_high_r_thresh_trackbar(int, void *);
////////////////void on_low_g_thresh_trackbar(int, void *);
////////////////void on_high_g_thresh_trackbar(int, void *);
////////////////void on_low_b_thresh_trackbar(int, void *);
////////////////void on_high_b_thresh_trackbar(int, void *);
////////////////int low_r=30, low_g=30, low_b=30;
////////////////int high_r=100, high_g=100, high_b=100;
////////////////int main()
////////////////{
////////////////    Mat frame, frame_threshold;
////////////////    VideoCapture cap(0);
////////////////    namedWindow("Video Capture", WINDOW_NORMAL);
////////////////    namedWindow("Object Detection", WINDOW_NORMAL);
////////////////    //-- Trackbars to set thresholds for RGB values
////////////////    createTrackbar("Low R","Object Detection", &low_r, 255, on_low_r_thresh_trackbar);
////////////////    createTrackbar("High R","Object Detection", &high_r, 255, on_high_r_thresh_trackbar);
////////////////    createTrackbar("Low G","Object Detection", &low_g, 255, on_low_g_thresh_trackbar);
////////////////    createTrackbar("High G","Object Detection", &high_g, 255, on_high_g_thresh_trackbar);
////////////////    createTrackbar("Low B","Object Detection", &low_b, 255, on_low_b_thresh_trackbar);
////////////////    createTrackbar("High B","Object Detection", &high_b, 255, on_high_b_thresh_trackbar);
////////////////    while((char)waitKey(1)!='q'){
////////////////    cap>>frame;
////////////////    if(frame.empty())
////////////////    break;
////////////////    //-- Detect the object based on RGB Range Values
////////////////    inRange(frame,Scalar(low_b,low_g,low_r), Scalar(high_b,high_g,high_r),frame_threshold);
////////////////    //-- Show the frames
////////////////    imshow("Video Capture",frame);
////////////////    imshow("Object Detection",frame_threshold);
////////////////    }
////////////////    return 0;
////////////////}
////////////////void on_low_r_thresh_trackbar(int, void *)
////////////////{
////////////////    low_r = min(high_r-1, low_r);
////////////////    setTrackbarPos("Low R","Object Detection", low_r);
////////////////}
////////////////void on_high_r_thresh_trackbar(int, void *)
////////////////{
////////////////    high_r = max(high_r, low_r+1);
////////////////    setTrackbarPos("High R", "Object Detection", high_r);
////////////////}
////////////////void on_low_g_thresh_trackbar(int, void *)
////////////////{
////////////////    low_g = min(high_g-1, low_g);
////////////////    setTrackbarPos("Low G","Object Detection", low_g);
////////////////}
////////////////void on_high_g_thresh_trackbar(int, void *)
////////////////{
////////////////    high_g = max(high_g, low_g+1);
////////////////    setTrackbarPos("High G", "Object Detection", high_g);
////////////////}
////////////////void on_low_b_thresh_trackbar(int, void *)
////////////////{
////////////////    low_b= min(high_b-1, low_b);
////////////////    setTrackbarPos("Low B","Object Detection", low_b);
////////////////}
////////////////void on_high_b_thresh_trackbar(int, void *)
////////////////{
////////////////    high_b = max(high_b, low_b+1);
////////////////    setTrackbarPos("High B", "Object Detection", high_b);
////////////////}
//////////////
/////////////////* Find best class for the blob (i. e. class with maximal probability) */
////////////////static void getMaxClass(const Mat &probBlob, int *classId, double *classProb)
////////////////{
////////////////    Mat probMat = probBlob.reshape(1, 1); //reshape the blob to 1x1000 matrix
////////////////    Point classNumber;
////////////////    minMaxLoc(probMat, NULL, classProb, NULL, &classNumber);
////////////////    *classId = classNumber.x;
////////////////}
////////////////static std::vector<String> readClassNames(const char *filename = "synset_words.txt")
////////////////{
////////////////    std::vector<String> classNames;
////////////////    std::ifstream fp(filename);
////////////////    if (!fp.is_open())
////////////////    {
////////////////    std::cerr << "File with classes labels not found: " << filename << std::endl;
////////////////    exit(-1);
////////////////    }
////////////////    std::string name;
////////////////    while (!fp.eof())
////////////////    {
////////////////    std::getline(fp, name);
////////////////    if (name.length())
////////////////    classNames.push_back( name.substr(name.find(' ')+1) );
////////////////    }
////////////////    fp.close();
////////////////    return classNames;
////////////////}
////////////////int main(int argc, char **argv)
////////////////{
////////////////    CV_TRACE_FUNCTION();
////////////////    String modelTxt = "bvlc_googlenet.prototxt";
////////////////    String modelBin = "bvlc_googlenet.caffemodel";
////////////////    String imageFile = (argc > 1) ? argv[1] : "space_shuttle.jpg";
////////////////    Net net = dnn::readNetFromCaffe(modelTxt, modelBin);
////////////////    if (net.empty())
////////////////    {
////////////////        std::cerr << "Can't load network by using the following files: " << std::endl;
////////////////        std::cerr << "prototxt:   " << modelTxt << std::endl;
////////////////        std::cerr << "caffemodel: " << modelBin << std::endl;
////////////////        std::cerr << "bvlc_googlenet.caffemodel can be downloaded here:" << std::endl;
////////////////        std::cerr << "http://dl.caffe.berkeleyvision.org/bvlc_googlenet.caffemodel" << std::endl;
////////////////        exit(-1);
////////////////    }
////////////////    Mat img = imread(imageFile);
////////////////    if (img.empty())
////////////////    {
////////////////    std::cerr << "Can't read image from the file: " << imageFile << std::endl;
////////////////    exit(-1);
////////////////    }
////////////////    //GoogLeNet accepts only 224x224 RGB-images
////////////////    Mat inputBlob = blobFromImage(img, 1, Size(224, 224),
////////////////    Scalar(104, 117, 123));   //Convert Mat to batch of images
////////////////    Mat prob;
////////////////    cv::TickMeter t;
////////////////    for (int i = 0; i < 10; i++)
////////////////    {
////////////////    CV_TRACE_REGION("forward");
////////////////    net.setInput(inputBlob, "data");        //set the network input
////////////////    t.start();
////////////////    prob = net.forward("prob");                          //compute output
////////////////    t.stop();
////////////////    }
////////////////    int classId;
////////////////    double classProb;
////////////////    getMaxClass(prob, &classId, &classProb);//find the best class
////////////////    std::vector<String> classNames = readClassNames();
////////////////    std::cout << "Best class: #" << classId << " '" << classNames.at(classId) << "'" << std::endl;
////////////////    std::cout << "Probability: " << classProb * 100 << "%" << std::endl;
////////////////    std::cout << "Time: " << (double)t.getTimeMilli() / t.getCounter() << " ms (average from " << t.getCounter() << " iterations)" << std::endl;
////////////////    return 0;
////////////////} //main
//////////////
////////////////bool try_use_gpu = false;
////////////////Stitcher::Mode mode = Stitcher::PANORAMA;
////////////////vector<Mat> imgs;
////////////////string result_name = "result.jpg";
////////////////void printUsage();
////////////////int parseCmdArgs(int argc, char** argv);
////////////////int main(int argc, char* argv[])
////////////////{
////////////////    int retval = parseCmdArgs(argc, argv);
////////////////    if (retval) return -1;
////////////////    Mat pano;
////////////////    Ptr<Stitcher> stitcher = Stitcher::create(mode, try_use_gpu);
////////////////    Stitcher::Status status = stitcher->stitch(imgs, pano);
////////////////    if (status != Stitcher::OK)
////////////////    {
////////////////    cout << "Can't stitch images, error code = " << int(status) << endl;
////////////////    return -1;
////////////////    }
////////////////    imwrite(result_name, pano);
////////////////    return 0;
////////////////}
////////////////void printUsage()
////////////////{
////////////////    cout <<
////////////////    "Images stitcher.\n\n"
////////////////    "stitching img1 img2 [...imgN]\n\n"
////////////////    "Flags:\n"
////////////////    "  --try_use_gpu (yes|no)\n"
////////////////    "      Try to use GPU. The default value is 'no'. All default values\n"
////////////////    "      are for CPU mode.\n"
////////////////    "  --mode (panorama|scans)\n"
////////////////    "      Determines configuration of stitcher. The default is 'panorama',\n"
////////////////    "      mode suitable for creating photo panoramas. Option 'scans' is suitable\n"
////////////////    "      for stitching materials under affine transformation, such as scans.\n"
////////////////    "  --output <result_img>\n"
////////////////    "      The default is 'result.jpg'.\n";
////////////////}
////////////////int parseCmdArgs(int argc, char** argv)
////////////////{
////////////////    if (argc == 1)
////////////////    {
////////////////    printUsage();
////////////////    return -1;
////////////////    }
////////////////    for (int i = 1; i < argc; ++i)
////////////////    {
////////////////    if (string(argv[i]) == "--help" || string(argv[i]) == "/?")
////////////////    {
////////////////    printUsage();
////////////////    return -1;
////////////////    }
////////////////    else if (string(argv[i]) == "--try_use_gpu")
////////////////    {
////////////////    if (string(argv[i + 1]) == "no")
////////////////    try_use_gpu = false;
////////////////    else if (string(argv[i + 1]) == "yes")
////////////////    try_use_gpu = true;
////////////////    else
////////////////    {
////////////////    cout << "Bad --try_use_gpu flag value\n";
////////////////    return -1;
////////////////    }
////////////////    i++;
////////////////    }
////////////////    else if (string(argv[i]) == "--output")
////////////////    {
////////////////    result_name = argv[i + 1];
////////////////    i++;
////////////////    }
////////////////    else if (string(argv[i]) == "--mode")
////////////////    {
////////////////    if (string(argv[i + 1]) == "panorama")
////////////////    mode = Stitcher::PANORAMA;
////////////////    else if (string(argv[i + 1]) == "scans")
////////////////    mode = Stitcher::SCANS;
////////////////    else
////////////////    {
////////////////    cout << "Bad --mode flag value\n";
////////////////    return -1;
////////////////    }
////////////////    i++;
////////////////    }
////////////////    else
////////////////    {
////////////////    Mat img = imread(argv[i]);
////////////////    if (img.empty())
////////////////    {
////////////////    cout << "Can't read image '" << argv[i] << "'\n";
////////////////    return -1;
////////////////    }
////////////////    imgs.push_back(img);
////////////////    }
////////////////    }
////////////////    return 0;
////////////////}
//////////////
////////////////int threshold_value = 0;
////////////////int threshold_type = 3;
////////////////int const max_value = 255;
////////////////int const max_type = 4;
////////////////int const max_BINARY_value = 255;
////////////////Mat src, src_gray, dst;
////////////////const char* window_name = "Threshold Demo";
////////////////const char* trackbar_type = "Type: \n 0: Binary \n 1: Binary Inverted \n 2: Truncate \n 3: To Zero \n 4: To Zero Inverted";
////////////////const char* trackbar_value = "Value";
////////////////void Threshold_Demo( int, void* );
////////////////int main( int argc, char** argv )
////////////////{
////////////////    String imageName("../data/stuff.jpg"); // by default
////////////////    if (argc > 1)
////////////////    {
////////////////    imageName = argv[1];
////////////////    }
////////////////    src = imread( imageName, IMREAD_COLOR ); // Load an image
////////////////    if( src.empty() )
////////////////    { return -1; }
////////////////    cvtColor( src, src_gray, COLOR_BGR2GRAY ); // Convert the image to Gray
////////////////    namedWindow( window_name, WINDOW_AUTOSIZE ); // Create a window to display results
////////////////    createTrackbar( trackbar_type,
////////////////    window_name, &threshold_type,
////////////////    max_type, Threshold_Demo ); // Create Trackbar to choose type of Threshold
////////////////    createTrackbar( trackbar_value,
////////////////    window_name, &threshold_value,
////////////////    max_value, Threshold_Demo ); // Create Trackbar to choose Threshold value
////////////////    Threshold_Demo( 0, 0 ); // Call the function to initialize
////////////////    for(;;)
////////////////    {
////////////////    char c = (char)waitKey( 20 );
////////////////    if( c == 27 )
////////////////    { break; }
////////////////    }
////////////////}
////////////////void Threshold_Demo( int, void* )
////////////////{
////////////////    /* 0: Binary
////////////////    1: Binary Inverted
////////////////    2: Threshold Truncated
////////////////    3: Threshold to Zero
////////////////     4: Threshold to Zero Inverted
////////////////        */
////////////////    threshold( src_gray, dst, threshold_value, max_BINARY_value,threshold_type );
////////////////    imshow( window_name, dst );
////////////////}
//////////////
////////////////int main (int argc , char ** argv)
////////////////{
////////////////    RNG rng(-1);
////////////////    int i,j;
////////////////
////////////////    Mat m=imread(argv[1],IMREAD_COLOR) ;
////////////////    Mat g ,bw;
////////////////    cvtColor(m,g,CV_BGR2GRAY);
////////////////
////////////////
////////////////    //{
////////////////    //    g=Mat_<uchar>(10,10);
////////////////    //    for(i=0;i<10;i++){
////////////////    //        uchar* p = g.ptr<uchar>(i) ;
////////////////    //        for(j=0;j<10;j++)
////////////////    //            *p++=rng.uniform(0,123) ;
////////////////    //    }
////////////////    //    resize(g, g, Size(), 30, 30, INTER_NEAREST);
////////////////    //    cout << g << endl ;
////////////////    //}
////////////////
////////////////
////////////////    adaptiveThreshold(~g, bw, 255, CV_ADAPTIVE_THRESH_MEAN_C, THRESH_BINARY, 15, -2);
////////////////    imshow("m",m);
////////////////    imshow("g",g);
////////////////    imshow("bw",bw);
////////////////
////////////////
////////////////    Mat ho,ve;
////////////////
////////////////    Mat hoStructure = getStructuringElement(MORPH_RECT, Size(200,1));
////////////////    Mat veStructure = getStructuringElement(MORPH_RECT, Size(1,5));
////////////////    veStructure = Scalar::all(1);
////////////////    /*
////////////////    veStructure.at<uchar>(0,0)=0;
////////////////    veStructure.at<uchar>(0,1)=0;
////////////////    veStructure.at<uchar>(0,3)=0;
////////////////    veStructure.at<uchar>(0,4)=0;
////////////////
////////////////    veStructure.at<uchar>(1,0)=0;
////////////////    veStructure.at<uchar>(1,4)=0;
////////////////
////////////////    veStructure.at<uchar>(3,0)=0;
////////////////    veStructure.at<uchar>(3,4)=0;
////////////////
////////////////    veStructure.at<uchar>(4,0)=0;
////////////////    veStructure.at<uchar>(4,1)=0;
////////////////    veStructure.at<uchar>(4,3)=0;
////////////////    veStructure.at<uchar>(4,4)=0;
////////////////    cout << veStructure << endl ;
////////////////    */
////////////////
////////////////    erode(bw, ho, hoStructure, Point(-1, -1));
////////////////    dilate(ho, ho, hoStructure, Point(-1, -1));
////////////////    //imshow("ho",ho);
////////////////
////////////////    erode(bw, ve, veStructure, Point(-1, -1));
////////////////    dilate(ve, ve, veStructure, Point(-1, -1));
////////////////    imshow("ve",ve);
////////////////    waitKey(0);
////////////////
////////////////
////////////////    return 0 ;
////////////////}
//////////////
////////////////int main(int, char** argv)
////////////////{
////////////////    // Load the image
////////////////    Mat src = imread(argv[1]);
////////////////    // Check if image is loaded fine
////////////////    if(!src.data)
////////////////    cerr << "Problem loading image!!!" << endl;
////////////////    // Show source image
////////////////    imshow("src", src);
////////////////    // Transform source image to gray if it is not
////////////////    Mat gray;
////////////////    if (src.channels() == 3)
////////////////    {
////////////////    cvtColor(src, gray, CV_BGR2GRAY);
////////////////    }
////////////////    else
////////////////    {
////////////////    gray = src;
////////////////    }
////////////////    // Show gray image
////////////////    imshow("gray", gray);
////////////////    // Apply adaptiveThreshold at the bitwise_not of gray, notice the ~ symbol
////////////////    Mat bw;
////////////////    adaptiveThreshold(~gray, bw, 255, CV_ADAPTIVE_THRESH_MEAN_C, THRESH_BINARY, 15, -2);
////////////////    // Show binary image
////////////////    imshow("binary", bw);
////////////////    // Create the images that will use to extract the horizontal and vertical lines
////////////////    Mat horizontal = bw.clone();
////////////////    Mat vertical = bw.clone();
////////////////    // Specify size on horizontal axis
////////////////    int horizontalsize = horizontal.cols / 30;
////////////////    // Create structure element for extracting horizontal lines through morphology operations
////////////////    Mat horizontalStructure = getStructuringElement(MORPH_RECT, Size(horizontalsize,1));
////////////////    // Apply morphology operations
////////////////    erode(horizontal, horizontal, horizontalStructure, Point(-1, -1));
////////////////    dilate(horizontal, horizontal, horizontalStructure, Point(-1, -1));
////////////////    // Show extracted horizontal lines
////////////////    imshow("horizontal", horizontal);
////////////////    // Specify size on vertical axis
////////////////    int verticalsize = vertical.rows / 30;
////////////////    // Create structure element for extracting vertical lines through morphology operations
////////////////    Mat verticalStructure = getStructuringElement(MORPH_RECT, Size( 1,verticalsize));
////////////////    // Apply morphology operations
////////////////    erode(vertical, vertical, verticalStructure, Point(-1, -1));
////////////////    dilate(vertical, vertical, verticalStructure, Point(-1, -1));
////////////////    // Show extracted vertical lines
////////////////    imshow("vertical", vertical);
////////////////    // Inverse vertical image
////////////////    bitwise_not(vertical, vertical);
////////////////    imshow("vertical_bit", vertical);
////////////////    // Extract edges and smooth image according to the logic
////////////////    // 1. extract edges
////////////////    // 2. dilate(edges)
////////////////    // 3. src.copyTo(smooth)
////////////////    // 4. blur smooth img
////////////////    // 5. smooth.copyTo(src, edges)
////////////////    // Step 1
////////////////    Mat edges;
////////////////    adaptiveThreshold(vertical, edges, 255, CV_ADAPTIVE_THRESH_MEAN_C, THRESH_BINARY, 3, -2);
////////////////    imshow("edges", edges);
////////////////    // Step 2
////////////////    Mat kernel = Mat::ones(2, 2, CV_8UC1);
////////////////    dilate(edges, edges, kernel);
////////////////    imshow("dilate", edges);
////////////////    // Step 3
////////////////    Mat smooth;
////////////////    vertical.copyTo(smooth);
////////////////    // Step 4
////////////////    blur(smooth, smooth, Size(2, 2));
////////////////    // Step 5
////////////////    smooth.copyTo(vertical, edges);
////////////////    // Show final result
////////////////    imshow("smooth", vertical);
////////////////    waitKey(0);
////////////////    return 0;
////////////////}
//////////////
////////////////int DELAY_CAPTION = 1500;
////////////////int DELAY_BLUR = 100;
////////////////int MAX_KERNEL_LENGTH = 31;
////////////////Mat src; Mat dst;
////////////////char window_name[] = "Smoothing Demo";
////////////////int display_caption( const char* caption );
////////////////int display_dst( int delay );
////////////////int main( int argc , char** argv )
////////////////{
////////////////    namedWindow( window_name, WINDOW_AUTOSIZE );
////////////////    src = imread( argv[1], IMREAD_COLOR );
////////////////
////////////////    if( display_caption( "Original Image" ) != 0 ) { return 0; }
////////////////    dst = src.clone();
////////////////    if( display_dst( DELAY_CAPTION ) != 0 ) { return 0; }
////////////////
////////////////    if( display_caption( "Homogeneous Blur" ) != 0 ) { return 0; }
////////////////    for ( int i = 1; i < MAX_KERNEL_LENGTH; i = i + 2 ) {
////////////////        blur( src, dst, Size( i, i ), Point(-1,-1) );
////////////////        if( display_dst( DELAY_BLUR ) != 0 ) { return 0; }
////////////////    }
////////////////
////////////////    if( display_caption( "Gaussian Blur" ) != 0 ) { return 0; }
////////////////    for ( int i = 1; i < MAX_KERNEL_LENGTH; i = i + 2 )
////////////////    { GaussianBlur( src, dst, Size( i, i ), 0, 0 );
////////////////    if( display_dst( DELAY_BLUR ) != 0 ) { return 0; } }
////////////////
////////////////    if( display_caption( "Median Blur" ) != 0 ) { return 0; }
////////////////    for ( int i = 1; i < MAX_KERNEL_LENGTH; i = i + 2 )
////////////////    { medianBlur ( src, dst, i );
////////////////    if( display_dst( DELAY_BLUR ) != 0 ) { return 0; } }
////////////////
////////////////    if( display_caption( "Bilateral Blur" ) != 0 ) { return 0; }
////////////////    for ( int i = 1; i < MAX_KERNEL_LENGTH; i = i + 2 )
////////////////    { bilateralFilter ( src, dst, i, i*2, i/2 );
////////////////    if( display_dst( DELAY_BLUR ) != 0 ) { return 0; } }
////////////////
////////////////    display_caption( "End: Press a key!" );
////////////////    waitKey(0);
////////////////    return 0;
////////////////}
////////////////int display_caption( const char* caption )
////////////////{
////////////////    dst = Mat::zeros( src.size(), src.type() );
////////////////    putText( dst, caption,
////////////////    Point( src.cols/4, src.rows/2),
////////////////    FONT_HERSHEY_COMPLEX, 1, Scalar(255, 255, 255) );
////////////////    imshow( window_name, dst );
////////////////    int c = waitKey( DELAY_CAPTION );
////////////////    if( c >= 0 ) { return -1; }
////////////////    return 0;
////////////////}
////////////////int display_dst( int delay )
////////////////{
////////////////    imshow( window_name, dst );
////////////////    int c = waitKey ( delay );
////////////////    if( c >= 0 ) { return -1; }
////////////////    return 0;
////////////////}
//////////////
//////////////int main()
//////////////{
//////////////    //{
//////////////    //    Mat m(5,5,CV_8U) ;
//////////////    //    Mat n;
//////////////    //    Mat o;
//////////////    //    int i , j;
//////////////    //    uchar*p ;
//////////////
//////////////    //    for(i=0;i<5;i++){
//////////////    //        p = m.ptr<uchar>(i);
//////////////    //        for(j=0;j<5;j++)
//////////////    //            *p++=i*5+j+1;
//////////////    //    }
//////////////
//////////////    //    Mat element = getStructuringElement( 1, Size( 2*1 + 1, 2*1+1 ), Point( -1, -1 ) );
//////////////    //    erode( m, n, element );
//////////////    //    dilate( m, o, element );
//////////////
//////////////    //    cout << m << endl << endl << endl ;
//////////////    //    cout << n << endl << endl << endl ;
//////////////    //    cout << o << endl ;
//////////////    //}
//////////////
//////////////    Mat input_image = (Mat_<uchar>(8, 8) <<
//////////////        0,   0,   0,   0,   0,   0,   0,   0,
//////////////        0, 255, 255, 255,   0,   0,   0, 255,
//////////////        0, 255, 255, 255,   0,   0,   0,   0,
//////////////        0, 255, 255, 255,   0, 255,   0,   0,
//////////////        0,   0, 255,   0,   0,   0,   0,   0,
//////////////        0,   0, 255,   0,   0, 255, 255,   0,
//////////////        0, 255,   0, 255,   0,   0, 255,   0,
//////////////        0, 255, 255,   0,   0,   0,   0,   0);
//////////////    cout << "input" << endl << input_image << endl << endl ;
//////////////
//////////////    Mat complation = input_image.clone() ;
//////////////    MatIterator_<uchar> it, end ;
//////////////    for(it = complation.begin<uchar>() , end = complation.end<uchar>(); it != end ; it ++ )
//////////////        *it = 255 - *it ;
//////////////    cout << "complation" << endl << complation << endl << endl ;
//////////////
//////////////    Mat kernel = (Mat_<int>(3, 3) <<
//////////////         0,  1, 0,
//////////////         1, -1, 1,
//////////////         0,  1, 0);
//////////////    cout << "kernel" << endl << kernel << endl << endl ;
//////////////
//////////////    Mat output_image;
//////////////
//////////////    /*
//////////////    Mat element = getStructuringElement( 1, Size( 3, 3), Point( -1, -1 ) );
//////////////
//////////////    //erode with kernel { 0,1,0, 1,0,1, 0,1,0 }
//////////////    element.at<char>(1,1) = 0;
//////////////    erode(input_image,output_image,element);
//////////////    cout << "kernel for AerodeB1" << endl << element << endl << endl ;
//////////////    cout << "erode" << endl << output_image << endl << endl ;
//////////////
//////////////    //erode the complation with kernel { 0,0,0, 0,1,0, 0,0,0 }
//////////////    for(int i=0;i<9;i++){
//////////////        element.at<char>(i/3,i%3) = 0 ;
//////////////    }
//////////////    element.at<char>(1,1)=1;
//////////////    erode(complation,output_image,element) ;
//////////////    cout << "kernel for A'erodeB2" << endl << element << endl << endl ;
//////////////    cout << "erode" << endl << output_image << endl << endl ;
//////////////
//////////////    */
//////////////
//////////////    morphologyEx(input_image, output_image, MORPH_HITMISS, kernel);
//////////////    cout << "morphology" << endl << output_image << endl << endl ;
//////////////    const int rate = 30;
//////////////    kernel = (kernel + 1) * 127;
//////////////    kernel.convertTo(kernel, CV_8U);
//////////////    resize(kernel, kernel, Size(), rate, rate, INTER_NEAREST);
//////////////    imshow("kernel", kernel);
//////////////    resize(input_image, input_image, Size(), rate, rate, INTER_NEAREST);
//////////////    imshow("Original", input_image);
//////////////    moveWindow( "Original", kernel.cols,0);
//////////////    resize(output_image, output_image, Size(), rate, rate, INTER_NEAREST);
//////////////    imshow("Hit or Miss", output_image);
//////////////    moveWindow( "Hit or Miss", input_image.cols+kernel.cols,0);
//////////////    waitKey(0);
//////////////    return 0;
//////////////}
//////////////
////////////////int main (int argc, char ** argv)
////////////////{
////////////////    Mat m = imread(argv[1]) ;
////////////////    Mat n ;
////////////////
////////////////    resize(m,n,Size(),2.0,2.0,INTER_CUBIC) ;
////////////////
////////////////    imshow("tmp",n);
////////////////    waitKey(0);
////////////////    return 0 ;
////////////////}
//////////////
//////////////
////////////////Mat src, dst;
////////////////int morph_elem = 0;
////////////////int morph_size = 0;
////////////////int morph_operator = 0;
////////////////int const max_operator = 6;
////////////////int const max_elem = 2;
////////////////int const max_kernel_size = 21;
////////////////const char* window_name = "Morphology Transformations Demo";
////////////////void Morphology_Operations( int, void* );
////////////////int main( int argc, char** argv )
////////////////{
////////////////      String imageName("../data/baboon.jpg"); // by default
////////////////        if (argc > 1)
////////////////              {
////////////////                    imageName = argv[1];
////////////////                      }
////////////////          src = imread(imageName, IMREAD_COLOR); // Load an image
////////////////            if( src.empty() )
////////////////                    { return -1; }
////////////////              namedWindow( window_name, WINDOW_AUTOSIZE ); // Create window
////////////////                createTrackbar("Operator:\n 0: Opening - 1: Closing  \n 2: Gradient - 3: Top Hat \n 4: Black Hat", window_name, &morph_operator, max_operator, Morphology_Operations );
////////////////                  createTrackbar( "Element:\n 0: Rect - 1: Cross - 2: Ellipse", window_name,
////////////////                                            &morph_elem, max_elem,
////////////////                                                              Morphology_Operations );
////////////////                    createTrackbar( "Kernel size:\n 2n +1", window_name,
////////////////                                              &morph_size, max_kernel_size,
////////////////                                                                Morphology_Operations );
////////////////                      Morphology_Operations( 0, 0 );
////////////////                        waitKey(0);
////////////////                          return 0;
////////////////}
////////////////void Morphology_Operations( int, void* )
////////////////{
////////////////      // Since MORPH_X : 2,3,4,5 and 6
////////////////      int operation = morph_operator ;
////////////////        Mat element = getStructuringElement( morph_elem, Size( 2*morph_size + 1, 2*morph_size+1 ), Point( morph_size, morph_size ) );
////////////////          morphologyEx( src, dst, operation, element );
////////////////            imshow( window_name, dst );
////////////////}
//////////////
////////////////#include "opencv2/imgproc.hpp"
////////////////#include "opencv2/imgcodecs.hpp"
////////////////#include "opencv2/highgui.hpp"
////////////////#include <iostream>
////////////////
////////////////using namespace cv;
////////////////using namespace std;
////////////////
////////////////Mat src, erosion_dst, dilation_dst;
////////////////int erosion_elem = 0;
////////////////int erosion_size = 0;
////////////////int dilation_elem = 0;
////////////////int dilation_size = 0;
////////////////int const max_elem = 2;
////////////////int const max_kernel_size = 21;
////////////////void Erosion( int, void* );
////////////////void Dilation( int, void* );
////////////////
////////////////int main( int, char** argv )
////////////////{
////////////////    src = imread( argv[1], IMREAD_COLOR );
////////////////    //Mat src(500,500,CV_8U,Scalar::all(255));
////////////////    //putText( src, "OpenCV forever!", Point(3,200), 0, 1, Scalar(0, 0, 0), 2, 8 );
////////////////    //imwrite("./tmp.bmp",src) ;
////////////////    //return 0 ;
////////////////    //imshow("tmp", src) ;
////////////////    //waitKey(0);
////////////////    //moveWindow( "tmp", 200,0);
////////////////    //waitKey(0);
////////////////    //return 0 ;
////////////////
////////////////
////////////////
////////////////    if( src.empty() ) { return -1; }
////////////////
////////////////    namedWindow( "Erosion Demo", WINDOW_AUTOSIZE );
////////////////    namedWindow( "Dilation Demo", WINDOW_AUTOSIZE );
////////////////    moveWindow( "Dilation Demo", src.cols, 0 );
////////////////    createTrackbar( "Element:\n 0: Rect \n 1: Cross \n 2: Ellipse",
////////////////                    "Erosion Demo",
////////////////                    &erosion_elem, max_elem,
////////////////                    Erosion );
////////////////    createTrackbar( "Kernel size:\n 2n +1",
////////////////                    "Erosion Demo",
////////////////                    &erosion_size, max_kernel_size,
////////////////                    Erosion );
////////////////    createTrackbar( "Element:\n 0: Rect \n 1: Cross \n 2: Ellipse",
////////////////                    "Dilation Demo",
////////////////                    &dilation_elem, max_elem,
////////////////                    Dilation );
////////////////    createTrackbar( "Kernel size:\n 2n +1",
////////////////                    "Dilation Demo",
////////////////                    &dilation_size, max_kernel_size,
////////////////                    Dilation );
////////////////    Erosion( 0, 0 );
////////////////    Dilation( 0, 0 );
////////////////    waitKey(0);
////////////////    return 0;
////////////////}
////////////////
////////////////void Erosion( int, void* )
////////////////{
////////////////    int erosion_type = 0;
////////////////    if( erosion_elem == 0 ){ erosion_type = MORPH_RECT; }
////////////////    else if( erosion_elem == 1 ){ erosion_type = MORPH_CROSS; }
////////////////    else if( erosion_elem == 2) { erosion_type = MORPH_ELLIPSE; }
////////////////
////////////////    Mat element = getStructuringElement( erosion_type, Size( 2*erosion_size + 1, 2*erosion_size+1 ), Point( erosion_size, erosion_size ) );
////////////////    erode( src, erosion_dst, element );
////////////////    imshow( "Erosion Demo", erosion_dst );
////////////////}
////////////////
////////////////void Dilation( int, void* )
////////////////{
////////////////    int dilation_type = 0;
////////////////    if( dilation_elem == 0 ){ dilation_type = MORPH_RECT; }
////////////////    else if( dilation_elem == 1 ){ dilation_type = MORPH_CROSS; }
////////////////    else if( dilation_elem == 2) { dilation_type = MORPH_ELLIPSE; }
////////////////
////////////////    Mat element = getStructuringElement( dilation_type, Size( 2*dilation_size + 1, 2*dilation_size+1 ), Point( dilation_size, dilation_size ) );
////////////////    dilate( src, dilation_dst, element );
////////////////    imshow( "Dilation Demo", dilation_dst );
////////////////}
////////////////
//////////////////#include <opencv2/core.hpp>
//////////////////#include <opencv2/imgproc.hpp>
//////////////////#include <opencv2/imgcodecs.hpp>
//////////////////#include <opencv2/highgui.hpp>
//////////////////#include <iostream>
//////////////////
//////////////////using namespace cv ;
//////////////////using namespace std ;
//////////////////
//////////////////int main (void)
//////////////////{
//////////////////    Mat m(400,400,CV_8UC3,Scalar::all(0));
//////////////////
//////////////////    putText( m, "OpenCV forever!", Point(50,150), 0, 1, Scalar(255, 255, 255), 2, 8 );
//////////////////    m.at<Vec3b>(50,100)[0]=255;
//////////////////    m.at<Vec3b>(50,100)[1]=0;
//////////////////    m.at<Vec3b>(50,100)[2]=0;
//////////////////    circle( m, Point(50, 100), 1, Scalar(  255,   0,   0), 1, 8 );
//////////////////    imwrite("test.bmp", m);
//////////////////    imshow("tmp", m);
//////////////////    waitKey(0);
//////////////////
//////////////////    return 0 ;
//////////////////}
////////////////
//////////////////#include <opencv2/core.hpp>
//////////////////#include <opencv2/imgproc.hpp>
//////////////////#include "opencv2/imgcodecs.hpp"
//////////////////#include <opencv2/highgui.hpp>
//////////////////#include <opencv2/ml.hpp>
//////////////////using namespace cv;
//////////////////using namespace cv::ml;
//////////////////int main(int, char**)
//////////////////{
//////////////////    // Data for visual representation
//////////////////    int width = 512, height = 512;
//////////////////    Mat image = Mat::zeros(height, width, CV_8UC3);
//////////////////
//////////////////    // Set up training data
//////////////////    int labels[4] = {1, -1, -1, -1};
//////////////////    float trainingData[4][2] = { {501, 10}, {255, 10}, {501, 255}, {10, 501} };
//////////////////    Mat trainingDataMat(4, 2, CV_32FC1, trainingData);
//////////////////    Mat labelsMat(4, 1, CV_32SC1, labels);
//////////////////
//////////////////    // Train the SVM
//////////////////    Ptr<SVM> svm = SVM::create();
//////////////////    svm->setType(SVM::C_SVC);
//////////////////    svm->setKernel(SVM::LINEAR);
//////////////////    svm->setTermCriteria(TermCriteria(TermCriteria::MAX_ITER, 100, 1e-6));
//////////////////    svm->train(trainingDataMat, ROW_SAMPLE, labelsMat);
//////////////////
//////////////////    // Show the decision regions given by the SVM
//////////////////    Vec3b green(0,255,0), blue (255,0,0);
//////////////////    for (int i = 0; i < image.rows; ++i)
//////////////////        for (int j = 0; j < image.cols; ++j)
//////////////////        {
//////////////////            Mat sampleMat = (Mat_<float>(1,2) << j,i);
//////////////////            float response = svm->predict(sampleMat);
//////////////////            if (response == 1)
//////////////////            image.at<Vec3b>(i,j)  = green;
//////////////////            else if (response == -1)
//////////////////            image.at<Vec3b>(i,j)  = blue;
//////////////////        }
//////////////////
//////////////////    // Show the training data
//////////////////    int thickness = -1;
//////////////////    int lineType = 8;
//////////////////    circle( image, Point(501,  10), 5, Scalar(  0,   0,   0), thickness, lineType );
//////////////////    circle( image, Point(255,  10), 5, Scalar(255, 255, 255), thickness, lineType );
//////////////////    circle( image, Point(501, 255), 5, Scalar(255, 255, 255), thickness, lineType );
//////////////////    circle( image, Point( 10, 501), 5, Scalar(255, 255, 255), thickness, lineType );
//////////////////
//////////////////    // Show support vectors
//////////////////    thickness = 2;
//////////////////    lineType  = 8;
//////////////////    Mat sv = svm->getUncompressedSupportVectors();
//////////////////    for (int i = 0; i < sv.rows; ++i)
//////////////////    {
//////////////////        const float* v = sv.ptr<float>(i);
//////////////////        circle( image,  Point( (int) v[0], (int) v[1]),   6,  Scalar(128,  128,  128), thickness, lineType);
//////////////////    }
//////////////////    imwrite("result.png", image);        // save the image
//////////////////    imshow("SVM Simple Example", image); // show it to the user
//////////////////    waitKey(0);
//////////////////}
////////////////////#include "opencv2/core.hpp"
////////////////////#include "opencv2/imgproc.hpp"
////////////////////#include "opencv2/highgui.hpp"
////////////////////#include <iostream>
////////////////////
////////////////////using namespace cv ;
////////////////////using namespace std ;
////////////////////
////////////////////int main ( int argc, char ** argv )
////////////////////{
////////////////////    FileStorage fs;
////////////////////    cout << fs.open("./tmp.xml",FileStorage::READ|FileStorage::WRITE) << endl ;
////////////////////
////////////////////    fs << "thisisa" << 'aaaa' << "hello" << "hi" ;
////////////////////
////////////////////    fs << "MAP" << "[" << "d1" << "d2" << "d3" << "]" ;
////////////////////
////////////////////    return 0 ;
////////////////////}
//////////////////////#include "opencv2/core.hpp"
//////////////////////#include "opencv2/imgproc.hpp"
//////////////////////#include "opencv2/imgcodecs.hpp"
//////////////////////#include "opencv2/highgui.hpp"
//////////////////////#include <iostream>
//////////////////////using namespace cv;
//////////////////////using namespace std;
//////////////////////static void help(void)
//////////////////////{
//////////////////////        cout << endl
//////////////////////                    <<  "This program demonstrated the use of the discrete Fourier transform (DFT). " << endl
//////////////////////                            <<  "The dft of an image is taken and it's power spectrum is displayed."          << endl
//////////////////////                                    <<  "Usage:"                                                                      << endl
//////////////////////                                            <<  "./discrete_fourier_transform [image_name -- default ../data/lena.jpg]"       << endl;
//////////////////////}
//////////////////////int main(int argc, char ** argv)
//////////////////////{
//////////////////////
//////////////////////    Mat j,k,l;
//////////////////////
//////////////////////    j=Mat_<Vec3b>(10,10,1) ;
//////////////////////    j+=Scalar::all(1);
//////////////////////
//////////////////////    cout << format(Mat(j,Rect(0,0,2,2)),Formatter::FMT_PYTHON) << endl ;
//////////////////////
//////////////////////
//////////////////////
//////////////////////    help();
//////////////////////    const char* filename = argc >=2 ? argv[1] : "../data/lena.jpg";
//////////////////////
//////////////////////    Mat I(300,400,CV_8U,Scalar::all(0));
//////////////////////    putText( I, "OpenCV forever!", Point(3,200), 0, 1, Scalar(255, 0, 0), 2, 8 );
//////////////////////    imshow("tmp",I);
//////////////////////
//////////////////////
//////////////////////    //imshow("tmp",I);
//////////////////////    //waitKey(0);
//////////////////////    //return 0 ;
//////////////////////
//////////////////////
//////////////////////    //Mat I = imread(filename, IMREAD_GRAYSCALE);
//////////////////////    if( I.empty()){
//////////////////////    cout << "Error opening image" << endl;
//////////////////////    return -1;
//////////////////////    }
//////////////////////
//////////////////////    Mat padded;                            //expand input image to optimal size
//////////////////////    int m = getOptimalDFTSize( I.rows );
//////////////////////    int n = getOptimalDFTSize( I.cols ); // on the border add zero values
//////////////////////    copyMakeBorder(I, padded, 0, m - I.rows, 0, n - I.cols, BORDER_CONSTANT, Scalar::all(0));
//////////////////////    cout << Mat(I,Rect(0,0,10,10)) << endl ;
//////////////////////    Mat planes[] = {Mat_<float>(padded), Mat::zeros(padded.size(), CV_32F)};
//////////////////////    Mat complexI;
//////////////////////    merge(planes, 2, complexI);         // Add to the expanded another plane with zeros
//////////////////////    cout << Mat(planes[0],Rect(0,0,10,10)) << endl ;
//////////////////////    dft(complexI, complexI);            // this way the result may fit in the source matrix
//////////////////////    cout << Mat(complexI,Rect(0,0,10,10)) << endl ;
//////////////////////    // compute the magnitude and switch to logarithmic scale
//////////////////////    // => log(1 + sqrt(Re(DFT(I))^2 + Im(DFT(I))^2))
//////////////////////    split(complexI, planes);                   // planes[0] = Re(DFT(I), planes[1] = Im(DFT(I))
//////////////////////    magnitude(planes[0], planes[1], planes[0]);// planes[0] = magnitude
//////////////////////    Mat magI = planes[0];
//////////////////////    cout << format(Mat(magI,Rect(0,0,10,10)),Formatter::FMT_PYTHON) << endl;
//////////////////////    magI += Scalar::all(1);                    // switch to logarithmic scale
//////////////////////    log(magI, magI);
//////////////////////    // crop the spectrum, if it has an odd number of rows or columns
//////////////////////    magI = magI(Rect(0, 0, magI.cols & -2, magI.rows & -2));
//////////////////////    // rearrange the quadrants of Fourier image  so that the origin is at the image center
//////////////////////    int cx = magI.cols/2;
//////////////////////    int cy = magI.rows/2;
//////////////////////    Mat q0(magI, Rect(0, 0, cx, cy));   // Top-Left - Create a ROI per quadrant
//////////////////////    Mat q1(magI, Rect(cx, 0, cx, cy));  // Top-Right
//////////////////////    Mat q2(magI, Rect(0, cy, cx, cy));  // Bottom-Left
//////////////////////    Mat q3(magI, Rect(cx, cy, cx, cy)); // Bottom-Right
//////////////////////    Mat tmp;                           // swap quadrants (Top-Left with Bottom-Right)
//////////////////////    q0.copyTo(tmp);
//////////////////////    q3.copyTo(q0);
//////////////////////    tmp.copyTo(q3);
//////////////////////    q1.copyTo(tmp);                    // swap quadrant (Top-Right with Bottom-Left)
//////////////////////    q2.copyTo(q1);
//////////////////////    tmp.copyTo(q2);
//////////////////////    cout << format(Mat(magI,Rect(0,0,3,3)),Formatter::FMT_PYTHON) << endl ;
//////////////////////    normalize(magI, magI, 0, 1, NORM_MINMAX); // Transform the matrix with float values into a
//////////////////////    Mat h=Mat_<char>(magI);
//////////////////////    cout << format(Mat(h,Rect(0,0,3,3)),Formatter::FMT_PYTHON) << endl ;
//////////////////////    // viewable image form (float between values 0 and 1).
//////////////////////    imshow("Input Image"       , h   );    // Show the result
//////////////////////    imshow("spectrum magnitude", magI);
//////////////////////    waitKey();
//////////////////////    return 0;
//////////////////////}
//////////////////////////#include <iostream>
//////////////////////////#include <opencv2/core.hpp>
//////////////////////////#include <opencv2/highgui.hpp>
//////////////////////////#include <opencv2/imgproc.hpp>
//////////////////////////
//////////////////////////using namespace cv;
//////////////////////////using std::endl;
//////////////////////////using std::cout;
//////////////////////////
//////////////////////////int main (void)
//////////////////////////{
//////////////////////////    Mat m(2,5,CV_8U,Scalar::all(0)) ;
//////////////////////////    Mat_<int>n(m) ;
//////////////////////////    Mat_<char>o(m) ;
//////////////////////////
//////////////////////////    Mat p[]={m,n} ;
//////////////////////////    Mat q ;
//////////////////////////
//////////////////////////
//////////////////////////
//////////////////////////    merge(p,2,q) ;
//////////////////////////    cout << q.depth() << endl ;
//////////////////////////    cout << format(q,Formatter::FMT_PYTHON) << endl ;
//////////////////////////
//////////////////////////
//////////////////////////    return 0 ;
//////////////////////////}
//////////////////////////
/////////////////////////////**
////////////////////////////   * @file Drawing_1.cpp
////////////////////////////    * @brief Simple geometric drawing
////////////////////////////     * @author OpenCV team
////////////////////////////      */
////////////////////////////#include <opencv2/core.hpp>
////////////////////////////#include <opencv2/imgproc.hpp>
////////////////////////////#include <opencv2/highgui.hpp>
////////////////////////////
////////////////////////////#define w 400
////////////////////////////
////////////////////////////using namespace cv;
////////////////////////////
/////////////////////////////// Function headers
////////////////////////////void MyEllipse( Mat img, double angle );
////////////////////////////void MyFilledCircle( Mat img, Point center );
////////////////////////////void MyPolygon( Mat img );
////////////////////////////void MyLine( Mat img, Point start, Point end );
////////////////////////////
/////////////////////////////**
////////////////////////////   * @function main
////////////////////////////    * @brief Main function
////////////////////////////     */
////////////////////////////int main( void ){
////////////////////////////
////////////////////////////      //![create_images]
////////////////////////////      /// Windows names
////////////////////////////      char atom_window[] = "Drawing 1: Atom";
////////////////////////////        char rook_window[] = "Drawing 2: Rook";
////////////////////////////
////////////////////////////          /// Create black empty images
////////////////////////////          Mat atom_image = Mat::zeros( w, w, CV_8UC3 );
////////////////////////////            Mat rook_image = Mat::zeros( w, w, CV_8UC3 );
////////////////////////////              //![create_images]
////////////////////////////
////////////////////////////              /// 1. Draw a simple atom:
////////////////////////////              /// -----------------------
////////////////////////////
////////////////////////////              //![draw_atom]
////////////////////////////              /// 1.a. Creating ellipses
////////////////////////////              MyEllipse( atom_image, 90 );
////////////////////////////                MyEllipse( atom_image, 0 );
////////////////////////////                  MyEllipse( atom_image, 45 );
////////////////////////////                    MyEllipse( atom_image, -45 );
////////////////////////////
////////////////////////////                      /// 1.b. Creating circles
////////////////////////////                      MyFilledCircle( atom_image, Point( w/2, w/2) );
////////////////////////////                        //![draw_atom]
////////////////////////////
////////////////////////////                        /// 2. Draw a rook
////////////////////////////                        /// ------------------
////////////////////////////
////////////////////////////                        //![draw_rook]
////////////////////////////                        /// 2.a. Create a convex polygon
////////////////////////////                        MyPolygon( rook_image );
////////////////////////////
////////////////////////////                          //![rectangle]
////////////////////////////                          /// 2.b. Creating rectangles
////////////////////////////                          rectangle( rook_image,
////////////////////////////                                           Point( 0, 7*w/8 ),
////////////////////////////                                                    Point( w, w),
////////////////////////////                                                             Scalar( 0, 255, 255 ),
////////////////////////////                                                                      FILLED,
////////////////////////////                                                                               LINE_8 );
////////////////////////////                            //![rectangle]
////////////////////////////
////////////////////////////                            /// 2.c. Create a few lines
////////////////////////////                            MyLine( rook_image, Point( 0, 15*w/16 ), Point( w, 15*w/16 ) );
////////////////////////////                              MyLine( rook_image, Point( w/4, 7*w/8 ), Point( w/4, w ) );
////////////////////////////                                MyLine( rook_image, Point( w/2, 7*w/8 ), Point( w/2, w ) );
////////////////////////////                                  MyLine( rook_image, Point( 3*w/4, 7*w/8 ), Point( 3*w/4, w ) );
////////////////////////////                                    //![draw_rook]
////////////////////////////
////////////////////////////                                    /// 3. Display your stuff!
////////////////////////////                                    imshow( atom_window, atom_image );
////////////////////////////                                      moveWindow( atom_window, 0, 200 );
////////////////////////////                                        imshow( rook_window, rook_image );
////////////////////////////                                          moveWindow( rook_window, w, 200 );
////////////////////////////
////////////////////////////                                          Mat m=rook_image.clone();
////////////////////////////                                          addWeighted(m,0.8,atom_image,0.2,0,m);
////////////////////////////
////////////////////////////                                          imshow("m",m);
////////////////////////////                                          moveWindow("m",2*w,200);
////////////////////////////
////////////////////////////
////////////////////////////
////////////////////////////                                            waitKey( 0 );
////////////////////////////                                              return(0);
////////////////////////////}
////////////////////////////
/////////////////////////////// Function Declaration
////////////////////////////
/////////////////////////////**
////////////////////////////   * @function MyEllipse
////////////////////////////    * @brief Draw a fixed-size ellipse with different angles
////////////////////////////     */
//////////////////////////////![my_ellipse]
////////////////////////////void MyEllipse( Mat img, double angle )
////////////////////////////{
////////////////////////////      int thickness = 2;
////////////////////////////        int lineType = 8;
////////////////////////////
////////////////////////////          ellipse( img,
////////////////////////////                         Point( w/2, w/2 ),
////////////////////////////                                Size( w/4, w/16 ),
////////////////////////////                                       angle,
////////////////////////////                                              0,
////////////////////////////                                                     360,
////////////////////////////                                                            Scalar( 255, 0, 0 ),
////////////////////////////                                                                   thickness,
////////////////////////////                                                                          lineType );
////////////////////////////}
//////////////////////////////![my_ellipse]
////////////////////////////
/////////////////////////////**
////////////////////////////   * @function MyFilledCircle
////////////////////////////    * @brief Draw a fixed-size filled circle
////////////////////////////     */
//////////////////////////////![my_filled_circle]
////////////////////////////void MyFilledCircle( Mat img, Point center )
////////////////////////////{
////////////////////////////      circle( img,
////////////////////////////                    center,
////////////////////////////                          w/32,
////////////////////////////                                Scalar( 0, 0, 255 ),
////////////////////////////                                      FILLED,
////////////////////////////                                            LINE_8 );
////////////////////////////}
//////////////////////////////![my_filled_circle]
////////////////////////////
/////////////////////////////**
////////////////////////////   * @function MyPolygon
////////////////////////////    * @brief Draw a simple concave polygon (rook)
////////////////////////////     */
//////////////////////////////![my_polygon]
////////////////////////////void MyPolygon( Mat img )
////////////////////////////{
////////////////////////////      int lineType = LINE_8;
////////////////////////////
////////////////////////////        /** Create some points */
////////////////////////////        Point rook_points[1][20];
////////////////////////////          rook_points[0][0]  = Point(    w/4,   7*w/8 );
////////////////////////////            rook_points[0][1]  = Point(  3*w/4,   7*w/8 );
////////////////////////////              rook_points[0][2]  = Point(  3*w/4,  13*w/16 );
////////////////////////////                rook_points[0][3]  = Point( 11*w/16, 13*w/16 );
////////////////////////////                  rook_points[0][4]  = Point( 19*w/32,  3*w/8 );
////////////////////////////                    rook_points[0][5]  = Point(  3*w/4,   3*w/8 );
////////////////////////////                      rook_points[0][6]  = Point(  3*w/4,     w/8 );
////////////////////////////                        rook_points[0][7]  = Point( 26*w/40,    w/8 );
////////////////////////////                          rook_points[0][8]  = Point( 26*w/40,    w/4 );
////////////////////////////                            rook_points[0][9]  = Point( 22*w/40,    w/4 );
////////////////////////////                              rook_points[0][10] = Point( 22*w/40,    w/8 );
////////////////////////////                                rook_points[0][11] = Point( 18*w/40,    w/8 );
////////////////////////////                                  rook_points[0][12] = Point( 18*w/40,    w/4 );
////////////////////////////                                    rook_points[0][13] = Point( 14*w/40,    w/4 );
////////////////////////////                                      rook_points[0][14] = Point( 14*w/40,    w/8 );
////////////////////////////                                        rook_points[0][15] = Point(    w/4,     w/8 );
////////////////////////////                                          rook_points[0][16] = Point(    w/4,   3*w/8 );
////////////////////////////                                            rook_points[0][17] = Point( 13*w/32,  3*w/8 );
////////////////////////////                                              rook_points[0][18] = Point(  5*w/16, 13*w/16 );
////////////////////////////                                                rook_points[0][19] = Point(    w/4,  13*w/16 );
////////////////////////////
////////////////////////////                                                  const Point* ppt[1] = { rook_points[0] };
////////////////////////////                                                    int npt[] = { 20 };
////////////////////////////
////////////////////////////                                                      fillPoly( img,
////////////////////////////                                                                      ppt,
////////////////////////////                                                                              npt,
////////////////////////////                                                                                      1,
////////////////////////////                                                                                              Scalar( 255, 255, 255 ),
////////////////////////////                                                                                                      lineType );
////////////////////////////}
//////////////////////////////![my_polygon]
////////////////////////////
/////////////////////////////**
////////////////////////////   * @function MyLine
////////////////////////////    * @brief Draw a simple line
////////////////////////////     */
//////////////////////////////![my_line]
////////////////////////////void MyLine( Mat img, Point start, Point end )
////////////////////////////{
////////////////////////////      int thickness = 2;
////////////////////////////        int lineType = LINE_8;
////////////////////////////
////////////////////////////          line( img,
////////////////////////////                      start,
////////////////////////////                          end,
////////////////////////////                              Scalar( 0, 0, 0 ),
////////////////////////////                                  thickness,
////////////////////////////                                      lineType );
////////////////////////////}
//////////////////////////////![my_line]
////////////////////////////
//////////////////////////////#include "opencv2/imgcodecs.hpp"
//////////////////////////////#include "opencv2/highgui.hpp"
//////////////////////////////#include <iostream>
//////////////////////////////using namespace std;
//////////////////////////////using namespace cv;
//////////////////////////////int main( int argc, char** argv )
//////////////////////////////{
//////////////////////////////    double alpha = 1.0; /*< Simple contrast control */
//////////////////////////////    int beta = 0;       /*< Simple brightness control */
//////////////////////////////    String imageName("../data/lena.jpg"); // by default
//////////////////////////////    if (argc > 1)
//////////////////////////////    {
//////////////////////////////        imageName = argv[1];
//////////////////////////////    }
//////////////////////////////    Mat image = imread( imageName );
//////////////////////////////    Mat new_image = Mat::zeros( image.size(), image.type() );
//////////////////////////////    cout << " Basic Linear Transforms " << endl;
//////////////////////////////    cout << "-------------------------" << endl;
//////////////////////////////    cout << "* Enter the alpha value [1.0-3.0]: "; cin >> alpha;
//////////////////////////////    cout << "* Enter the beta value [0-100]: ";    cin >> beta;
//////////////////////////////    for( int y = 0; y < image.rows; y++ ) {
//////////////////////////////        for( int x = 0; x < image.cols; x++ ) {
//////////////////////////////            for( int c = 0; c < 3; c++ ) {
//////////////////////////////                new_image.at<Vec3b>(y,x)[c] =
//////////////////////////////                saturate_cast<uchar>( alpha*( image.at<Vec3b>(y,x)[c] ) + beta );
//////////////////////////////            }
//////////////////////////////        }
//////////////////////////////    }
//////////////////////////////    namedWindow("Original Image", WINDOW_AUTOSIZE);
//////////////////////////////    namedWindow("New Image", WINDOW_AUTOSIZE);
//////////////////////////////    imshow("Original Image", image);
//////////////////////////////    imshow("New Image", new_image);
//////////////////////////////    waitKey();
//////////////////////////////    return 0;
//////////////////////////////}
////////////////////////////////#include <iostream>
////////////////////////////////#include <vector>
////////////////////////////////#include <opencv2/opencv.hpp>
////////////////////////////////#include <opencv2/imgproc.hpp>
////////////////////////////////
////////////////////////////////using namespace cv;
////////////////////////////////using std::vector;
////////////////////////////////using std::endl;
////////////////////////////////using std::cout;
////////////////////////////////
////////////////////////////////int main(int argc, char** argv )
////////////////////////////////{
////////////////////////////////    Rect r(0,0,600,400);
////////////////////////////////    Mat m = imread(argv[1]);
////////////////////////////////    Mat m1=m(r);
////////////////////////////////    Mat n = imread(argv[2]);
////////////////////////////////    Mat n1=n(r);
////////////////////////////////    Mat o = imread(argv[3]);
////////////////////////////////    Mat o1=o(r);
////////////////////////////////
////////////////////////////////
////////////////////////////////    Mat d;
////////////////////////////////    addWeighted(m1,0.7,n1,0.3,0,d);
////////////////////////////////    addWeighted(d,0.3,o1,0.7,0,m);
////////////////////////////////
////////////////////////////////    namedWindow("image", WINDOW_AUTOSIZE);
////////////////////////////////    imshow("image", m);
////////////////////////////////    waitKey();
////////////////////////////////
////////////////////////////////    return 0 ;
////////////////////////////////}
