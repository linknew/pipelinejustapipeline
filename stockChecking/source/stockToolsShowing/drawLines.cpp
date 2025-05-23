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
#include "view.hpp"

#define  DRAW_VOL_TYPE_LINE      (1)
#define  DRAW_VOL_TYPE_FILLED    (2)

#define  MAX_SUPPORTTED_LENGTH   (365*20)
#define  MAX_SUPPORTTED_LINES   (64)

#define  MAX_WIN_WIDTH  (1280)
#define  MAX_WIN_HEIGHT (670)

#define DATA_FIX_TYPE_NONE      (0)
#define DATA_FIX_TYPE_FORWARD   (1)
#define DATA_FIX_TYPE_BACKWARD  (2)
#define DATA_FIX_TYPE_COUNT     (3)
#define DATA_FIX_TYPE_NOT_SET   (-1)

#define LINE_MARGIN_L   (2)
#define LINE_MARGIN_R   (2)
#define LINE_MARGIN_T   (2)
#define LINE_MARGIN_B   (2)

#define LEFT_VIEW_W     (160)

#define  CLEAN_SWITCHERS( switcher )                        \
         {                                                  \
             memset(&switcher, 0, sizeof(switcher) ) ;      \
         }                                                  \

#define  SETALL_SWITCHERS( switcher )                       \
         {                                                  \
             memset(&switcher, 0xff, sizeof(switcher) ) ;   \
         }                                                  \

#define  REVERT_SWITCH( switcher, position )                \
         {                                                  \
             switcher ^= 1l << (position) ;                 \
         }                                                  \

#define GET_SWITCHER_STATUS( switcher, position )           \
        (switcher & (1l << (position) ))

#define  GET_NUMBERS_PER_SCREEN(screenWidth,scale) ( ((screenWidth) - LINE_MARGIN_L - LINE_MARGIN_R) / (scale) )
#define  GET_POSITION_OF_INDEX(index, scale)   ( (index) * (scale) + (scale)/2 + LINE_MARGIN_L)
#define  RESET_DTLS_INDEX   (-MAX_SUPPORTTED_LENGTH -255)

using namespace cv;
using namespace std;
using namespace cv::dnn;

typedef int(*digtFuncPt)(int number, bool& refresh);
int digtFuncBaselineFilter( int number, bool& refresh );
int digtFuncLineFilter( int number, bool& refresh );
int digtFuncScale( int number, bool& refresh );

/* define & init */
/* color-list for lines */
static Scalar  lineColors[MAX_SUPPORTTED_LINES] = {
                        Scalar(255,127,0),
                        Scalar(0,255,0),
                        Scalar(255,255,0),
                        Scalar(255,0,255),
                        Scalar(0,0,255),
                        Scalar(0,255,255),
                        Scalar(200,200,200),
                        Scalar(255,255,255)
                    } ;
static digtFuncPt digtFuncList[] = {                // this struct for 0~9(digital keys) function switch.
                        digtFuncBaselineFilter,
                        digtFuncLineFilter,
                        digtFuncScale
                    } ;

static unsigned char    digtFuncIdx = 2 ;
static unsigned long    baseLineSwitchers = (0) ;     // if (MAX_SUPPORTTED_LINES > sizeof(int)*8), this maybe take you to a fault!!
static unsigned long    linesSwitchers = ((1<<6)-1);   // comments here, same with above line's!!
static bool             autoFit = true ;
static int              scale = 64 ;     // for x-coordinates
static int              dataFixType = DATA_FIX_TYPE_BACKWARD ;
static int              crntUsedDataFixType = DATA_FIX_TYPE_NOT_SET ;
static bool             lockScreen = false ;

int dataRangeEnd=80000;
int dataRangeStart=80000;   // all x-coordinate SHOULD(MUST!!) base on the dataRangeEnd(NOT the dataRangeStart)
int dtlsIdxOnMainView = RESET_DTLS_INDEX ;
int winW = MAX_WIN_WIDTH ;
int winH = MAX_WIN_HEIGHT ;
Mat _panel, _mainView, _bottomView, _topStatus_view, _leftDetailsView ;
Mat _linesData ;

int drawLines(
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
    //linesData.locateROI( _orgMatrixSize, _ofs );

    for(int _lineIdx = 0 ; _lineIdx < linesData.rows; _lineIdx ++){

        if( 0 == GET_SWITCHER_STATUS(linesSwitchers, _lineIdx + _ofs.y) ){
            /* this line is disabled, do not draw it */
            continue ;
        }

        _ps = Point( 0*scale + scale/2 + roi.x, roi.height-1 - (int)linesData.at<double>( _lineIdx, 0) + roi.y );
        _color = ( 3 == panel.channels() )
               ? lineColors[ min( _lineIdx,  MAX_SUPPORTTED_LINES - 1 ) ]
               : Scalar(255,0,0) ;

        for( int _col = 0 ; _col<linesData.cols ; _col++){
            _pe = Point( _col*scale + scale/2 + roi.x, roi.height-1 - (int)linesData.at<double>( _lineIdx, _col ) + roi.y );
            line( panel, _ps, _pe, _color, 1, LINE_AA );
            _ps = _pe;
        }
    }

    return 0;
}

int drawVol(
        const Mat&      volData,
        const Mat&      panel,
        const int&      scale,
        const Rect&     roi,
        const Scalar&   color,
        const int&      type,
        const bool&     reversal
        )
{
    Mat     _m ;
    volData.convertTo(_m, CV_64F) ;

    if( DRAW_VOL_TYPE_FILLED == type )     /* rectangle */
    {
        int     _x, _y, _col ;
        double  _t ;


        /* postive vol is INCREASE, use RED color,
           negative vol is DECRES, use GREEN color */

        for(_col=0; _col < _m.cols; _col++){
            _t = _m.at<double>(0, _col) ;
            _x = _col*scale + roi.x ;
            _y = (reversal) ? roi.height- abs(_t) - 1 + roi.y : abs(_t) + roi.y ;

            rectangle( panel, Point( _x, _y ), Point( _x+scale-1, (reversal) ? 0+roi.x+roi.height-1 : 0+roi.y), color, FILLED, LINE_8 );
        }

    }else if (DRAW_VOL_TYPE_LINE == type){    /* line */
        Point               _ps;
        Point               _pe;
        double              _t;

        _ps = Point( 0*scale + scale/2 +roi.x, roi.height-1 - (int)_m.at<double>( 0, 0) + roi.y );

        for( int _col = 0 ; _col < _m.cols ; _col++){
            _t = (int)_m.at<double>(0, _col) ;
            _pe = (reversal)
                ? Point( _col*scale + scale/2 +roi.x, roi.height-1 - abs(_t) + roi.y)
                : Point( _col*scale + scale/2 +roi.x, abs(_t)+roi.y) ;
            line( panel, _ps, _pe, color, 1, LINE_AA);
            _ps = _pe;
        }
    }

    return 0;
}

int importData(
        const char* fileName,
        const int   linesNum,
        const int   linesLen,
        Mat&        outputMat
        )
{
    Mat             _m ;
    ifstream        _file ;
    string          _tmpStr ;
    stringstream    _tmpSS ;
    int             _linesCnt = 0 ;
    int             i = 0 ;

    assert(fileName) ;

    _m.create(min(MAX_SUPPORTTED_LINES,linesNum), min(MAX_SUPPORTTED_LENGTH, linesLen), CV_64F) ;
    _m.setTo(Scalar(0)) ;
    _file.open(fileName[0]=='-' ? "/dev/stdin" : fileName, ifstream::in) ;
    if(!_file){
        cerr << "cannot open file " << fileName << endl ;
        return -1 ;
    }

    /* loop items in the file */
    while (getline(_file, _tmpStr)){

        if(i >= min(linesLen,MAX_SUPPORTTED_LENGTH)){
            cerr << "out of rang, MAX_SUPPORTTED_LENGTH or linesLen" << '[' << MAX_SUPPORTTED_LENGTH << ',' << linesLen << ']' << endl ;
            break ;
        }

        _tmpSS.clear();
        _tmpSS.str(_tmpStr) ;

        /* extract data */
        for(_linesCnt = 0; _linesCnt < min(linesNum, MAX_SUPPORTTED_LINES); _linesCnt ++){
            _tmpSS >> _m.at<double>(_linesCnt, i) ;
        }

        ++ i ;
    }

    _file.close();
    outputMat = _m ;
    return 0 ;
}

int printViewInfo (
        bool        curView
        )
{
    if( curView ){
        cout << "print current view infos" << endl ;
    }else{
        cout << "print whole stock infos" << endl ;
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
        drawLines( _line, _t1, scale, roi) ;
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

int digtFuncScale(
        int         number,
        bool&       refresh
        )
{
    /* adjust dtlsIdxOnMainView */
    dtlsIdxOnMainView = min(_linesData.cols, GET_NUMBERS_PER_SCREEN(_mainView.cols,number)) -
                            min(_linesData.cols, GET_NUMBERS_PER_SCREEN(_mainView.cols,scale)) +
                            dtlsIdxOnMainView ;

    /* adjust scale */
    scale = number ;
    refresh = true ;
    return 0 ;
}

int digtFuncLineFilter(
        int         number,
        bool&       refresh
        )
{
    if(number == 0){
        SETALL_SWITCHERS(linesSwitchers) ;
    }else{
        REVERT_SWITCH(linesSwitchers,number-1) ;
    }
    refresh = true ;
    return 0;
}

int digtFuncBaselineFilter(
        int         number,
        bool&       refresh
        )
{
    if(number == 0){
        CLEAN_SWITCHERS(baseLineSwitchers) ;
    }else{
        REVERT_SWITCH(baseLineSwitchers,number-1) ;
    }
    refresh = true ;
    return 0;
}

int doDigitalFunc(
        int         number,
        bool&       refresh     // refresh flag
        )
{
    assert( digtFuncIdx < sizeof(digtFuncList)/sizeof(digtFuncPt) );

    return digtFuncList[ digtFuncIdx ](number, refresh) ;
}

void initColor(int num)
{
    int     i = 0 ;
    int     step = 255/4 ;
    int     r=0, g=0, b=0 ;

    for(r=1;r<=4;r++)
        for(g=1; g<=4; g++)
            for(b=1; b<=4; b++){
                //cout << r*step << "," << g*step << "," << b*step << endl ;
                lineColors[i++] = Scalar(r*step,g*step,b*step) ;
            }

    return ;
}

int main( int argc, char** argv )
{
#if 0
    {
#define MAX_LINES_IN_SET    (9)

        lineObj     lineSetA ;
        lineObj     lineSetB ;
        dataSource  source(argv[2], "jfkljflfj") ;
        view        mainView(Mat(MAX_WIN_HEIGHT, MAX_WIN_WIDTH, CV_8UC3)) ;

        int idxsOfLineSetA[] = {
            dataSource::DATA_ID_HIS_CLS,
            dataSource::DATA_ID_HIS_HIG,
            dataSource::DATA_ID_HIS_LOW,
            dataSource::DATA_ID_HIS_OPN,
            dataSource::DATA_ID_HIS_YSTDCLS
            } ;
        int idxsOfLineSetB[] = {
            dataSource::DATA_ID_HIS_VOL
            } ;

        lineSetA.setLineSets(std::vector<int>(
                    idxsOfLineSetA,
                    idxsOfLineSetA + sizeof(idxsOfLineSetA)/sizeof(int)) ) ;
        lineSetB.setLineSets(std::vector<int>(
                    idxsOfLineSetB,
                    idxsOfLineSetB + sizeof(idxsOfLineSetB)/sizeof(int)) ) ;
        source.transportData(source.connect(lineSetA)) ;
        source.transportData(source.connect(lineSetB)) ;
        mainView.setFocus(mainView.addShape(lineSetA)) ;
        mainView.addShape(lineSetB) ;
        mainView.doOrder() ;
        mainView.doMoving(MOVING_TAIL) ;
        mainView.doMovingView(0,0) ;
        mainView.assignDataSrcUpdateListener(source) ;
        mainView.doRefresh() ;
        source.start() ;

        char c ;
        while(1){
            c = waitKey(1000) ;
            if(c == 'q') break ;
            mainView.handleKey(c) ;
        }
    }
#endif

    char        c = 0 ;
    bool        refresh = true ;
    int         idxFocusedLine = 0 ;
    string      stockCode ;
    vector<int> linesGrpInfo ;

    /* parsing arguments */
    {
        char*               _dataFile = NULL ;
        int                 _linesNum = 0 ;
        int                 _linesLen = 0 ;
        size_t              _argCnt = 0 ;
        map<size_t,char*>   _args ;

        /* _args[0], stockCode, 
         * _args[1], filename, 
         * _args[2], linesNum, 
         * _args[3], linesLength 
         *
         * --focus, default is 0
         * --scale, default is 64
         * --groups, default is SPLIT_each_line, --group=5,3 means: divid 8 lines into 2 groups, the first 5 lines is group_1 and the last 3 lines is group_2
         */

        for(int _i = 1; _i < argc; _i++){

            if (string(argv[_i]) == "--help"){
                cerr << argv[0] << " stockCode filename linesNum linesLength [--help] [--group=N1,N2,...] [--showlines=L1,L2,...] [--focus=N] [--scale=N]" << endl ;
                return 0 ;
            }

            if (string(argv[_i]).find("--group=") != string::npos){
                stringstream _ss(argv[_i]+strlen("--group=")) ;
                int _num = 0 ;
                char _t = ' ' ;
                while(_ss >> _num){
                    linesGrpInfo.push_back(_num) ;
                    _ss >> _t ;
                }
                continue ;
            }

            if (string(argv[_i]).find("--showlines=") != string::npos){
                stringstream _ss(argv[_i]+strlen("--showlines=")) ;
                int _num = 0 ;
                char _t = ' ' ;
                linesSwitchers = 0 ;
                while(_ss >> _num){
                    assert(_num <= MAX_SUPPORTTED_LINES) ;
                    linesSwitchers |= (1<<(_num-1));   // comments here, same with above line's!!
                    _ss >> _t ;
                }
                continue ;
            }

            if (string(argv[_i]).find("--focus=") != string::npos){
                idxFocusedLine = atoi(argv[_i]+strlen("--focus=")) ;
                continue ;
            }

            if (string(argv[_i]).find("--scale=") != string::npos){
                scale = atoi(argv[_i]+strlen("--scale=")) ;
                continue ;
            }

            if(argv[_i][0] == argv[_i][1] && argv[_i][0]== '-'){
                cerr << "unknown option:" << argv[_i] << endl ;
                return -1 ;
            }

            _args[_argCnt++] = argv[_i] ;
        }
        assert(_args.size() == 4) ;

        stockCode = _args[0] ;
        _dataFile = _args[1] ;
        _linesNum = atoi(_args[2]) ;
        _linesLen = atoi(_args[3]) ;
        if(linesGrpInfo.empty()) for(int _i=0; _i<_linesNum; _i++) linesGrpInfo.push_back(1) ;
        importData(_dataFile, _linesNum, _linesLen, _linesData) ;
        assert(_linesNum==_linesData.rows) ;
        assert(_linesLen==_linesData.cols) ;
        assert(idxFocusedLine<_linesNum && idxFocusedLine>=0) ;
        assert(scale>=1 && scale<=64) ;
        initColor(_linesNum) ;
    }

    while (1)
    {
        if( refresh ){
            Mat     viewData ;

            /* adjust window size */
            {
                winW = min(winW, MAX_WIN_WIDTH);
                winW = max(winW, 0) ;
                winH = min(winH, MAX_WIN_HEIGHT);
                winH = max(winH, 0) ;
            }

            /* adust panle and views */
            {
                _panel.create(winH,winW,CV_8UC3) ;
                _panel.setTo(Scalar(0));
                if(lockScreen){
                    _mainView   = _panel( Rect(LEFT_VIEW_W, 30, _panel.cols-LEFT_VIEW_W-10, _panel.rows-30-80) );
                    _bottomView = _panel( Rect(LEFT_VIEW_W, _panel.rows - 80, _mainView.cols, 80) ) ;
                }else{
                    _mainView   = _panel( Rect(0, 30, _panel.cols-10, _panel.rows-30-80) ) ;
                    _bottomView = _panel( Rect(0, _panel.rows - 80, _mainView.cols, 80) ) ;
                }
                _topStatus_view = _panel.rowRange(0, 30) ;
                _leftDetailsView = _panel.colRange(0, LEFT_VIEW_W) ;
            }

            /* adjust data range,
               all x-coordinate SHOULD(MUST!!) base on the dataRangeEnd(NOT the dataRangeStart) */
            {
                dataRangeEnd = min( _linesData.cols, dataRangeEnd) ;
                dataRangeEnd = max( min(GET_NUMBERS_PER_SCREEN(_mainView.cols,scale), _linesData.cols), dataRangeEnd ) ;
                dataRangeStart = dataRangeEnd - GET_NUMBERS_PER_SCREEN(_mainView.cols,scale);
                dataRangeStart = max(0, dataRangeStart) ;
            }

            /* adjust _linesData & _linesInfo */
            {
                int _idx = 0 ;
                int _linesNum = 0 ;
                Mat _m = _linesData.clone() ;

                for(int i = 0; i < linesGrpInfo.size(); i++){
                    _linesNum = linesGrpInfo[i] ;

                    normalize(_m(Range(_idx,_idx+_linesNum), autoFit ? Range(dataRangeStart,dataRangeEnd) : Range::all()),
                              _m(Range(_idx,_idx+_linesNum), autoFit ? Range(dataRangeStart,dataRangeEnd) : Range::all()),
                              0+1, _mainView.rows-LINE_MARGIN_T-LINE_MARGIN_B-1, NORM_MINMAX); /* the upper_30 pixels for _linesInfo */

                    _idx += _linesNum ;

                }
                assert(_idx == _linesData.rows);

                viewData = _m.colRange(dataRangeStart,dataRangeEnd) ;
                drawLines(viewData, _mainView, scale,
                          Rect(LINE_MARGIN_L, LINE_MARGIN_T, _mainView.cols-LINE_MARGIN_L-LINE_MARGIN_R, _mainView.rows-LINE_MARGIN_T-LINE_MARGIN_B) );
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

                _getLinesFocus(_lines, _mainView,
                         Rect(LINE_MARGIN_L, LINE_MARGIN_T, _mainView.cols - LINE_MARGIN_L - LINE_MARGIN_R, _mainView.rows - LINE_MARGIN_T - LINE_MARGIN_B)) ;
            }

            /* adjust details index line */
            {
                if(!lockScreen){
                    dtlsIdxOnMainView = RESET_DTLS_INDEX ;
                }else{
                    if(RESET_DTLS_INDEX == dtlsIdxOnMainView ) dtlsIdxOnMainView  = (dataRangeEnd - dataRangeStart + 1)/2 ;
                    dtlsIdxOnMainView  = min( min( GET_NUMBERS_PER_SCREEN(_mainView.cols,scale) - 1, _linesData.cols - 1 ), dtlsIdxOnMainView ) ;
                    dtlsIdxOnMainView  = max(0, dtlsIdxOnMainView ) ;

                    /* draw a vertical line on the dtlsIdxOnMainView  */
                    Point   _ofs;
                    Scalar  _color;
                    Size    _orgMatrixSize;

                    _mainView.locateROI( _orgMatrixSize, _ofs );

                    for(int i = 0 ; i < _panel.rows; i++) {
                        if((i%20)<17){
                            _panel.at<Vec3b>(i, GET_POSITION_OF_INDEX(dtlsIdxOnMainView,scale)+_ofs.x )[0] = 127 ;
                            _panel.at<Vec3b>(i, GET_POSITION_OF_INDEX(dtlsIdxOnMainView,scale)+_ofs.x )[1] = 127 ;
                            _panel.at<Vec3b>(i, GET_POSITION_OF_INDEX(dtlsIdxOnMainView,scale)+_ofs.x )[2] = 127 ;
                        }
                    }

                    /* draw a horizantl line */
                    for(int i = LINE_MARGIN_L; i < _mainView.cols-LINE_MARGIN_R; i++){
                        if((i%20)<17){
                            _mainView.at<Vec3b>(_mainView.rows - 1 - LINE_MARGIN_B - viewData.at<double>(idxFocusedLine,dtlsIdxOnMainView), i)[0] = 127 ;
                            _mainView.at<Vec3b>(_mainView.rows - 1 - LINE_MARGIN_B - viewData.at<double>(idxFocusedLine,dtlsIdxOnMainView), i)[1] = 127 ;
                            _mainView.at<Vec3b>(_mainView.rows - 1 - LINE_MARGIN_B - viewData.at<double>(idxFocusedLine,dtlsIdxOnMainView), i)[2] = 127 ;
                        }
                    }

                    /* draw some reference lines */
                    // do something here
                }
            }

#if 1
            /* redraw left info bar */
            {
                int             i ;
                stringstream    s ;

                /* show stock name & code & data-fix status */
                s.str("");
                s << stockCode ;
#if 0
                (dataFixType == DATA_FIX_TYPE_FORWARD)
                    ? s << " [Forward Fixing]"
                    : (dataFixType == DATA_FIX_TYPE_BACKWARD)
                        ? s << " [Backward Fixing]"
                        : 1 ;
#endif
                if(autoFit) s << " [Auto Fit]" ;
                putText( _topStatus_view, s.str(), Point(0,22), 0, 0.4, Scalar(0, 0, 255), 0, LINE_AA );

                s.str("") ;
                /* show baseline info */
                ( digtFuncList[ digtFuncIdx ] == digtFuncBaselineFilter ) ?  s << "*Base:" : s << " Base:" ;
                putText( _leftDetailsView, s.str(), Point(0,54), 0, 0.4, Scalar(0, 0, 255), 0, LINE_AA );
                s.str("/") ;
                for( i = 0 ; i < viewData.rows; i++ ){
                    if( GET_SWITCHER_STATUS(baseLineSwitchers,i) ){
                        s << i + 1 << '/' ;
                    }
                }
                putText( _leftDetailsView, s.str(), Point(20,54+1*14), 0, 0.4, Scalar(0, 0, 255), 0, LINE_AA );

                /* show line info */
                s.str("");
                (digtFuncList[ digtFuncIdx ] == digtFuncLineFilter) ? s << "*Lines:" : s << " Lines:" ;
                putText( _leftDetailsView, s.str(), Point(0,54+2*14), 0, 0.4, Scalar(0, 0, 255), 0, LINE_AA );
                s.str("/") ;
                for( i = 0 ; i < viewData.rows; i++ ){
                    if( GET_SWITCHER_STATUS(linesSwitchers,i) ){
                        s << i + 1 << '/' ;
                    }
                }
                putText( _leftDetailsView, s.str(), Point(20,54+3*14), 0, 0.4, Scalar(0, 0, 255), 0, LINE_AA );

                /* show scale info */
                s.str("");
                (digtFuncList[ digtFuncIdx ] == digtFuncScale) ? s << "*Scale:" : s << " Scale:" ;
                putText( _leftDetailsView, s.str(), Point(0,54+4*14), 0, 0.4, Scalar(0, 0, 255), 0, LINE_AA );
                s.str("") ;
                s << scale ;
                putText( _leftDetailsView, s.str(), Point(20,54+5*14), 0, 0.4, Scalar(0, 0, 255), 0, LINE_AA );

#if 1
                /* show details info */
                if(lockScreen){
                    double  _d = 0 ;
                    long    _l = 0 ;
                    Scalar  _color ;
                    int     _idx = 4 ;

                    for(int i = 0; i < _linesData.rows; i++){
                        _d = _linesData.at<double>(i,dataRangeStart+dtlsIdxOnMainView) ;
                        _color = lineColors[i] ;
                        s.str("");
                        s << " line-" << i+1 << "=" << setiosflags(ios::fixed) << setprecision(_d>99999?0:2) << _d ;
                        putText( _leftDetailsView, s.str(), Point(0,120+(_idx++)*14), 0, 0.4, _color, 0, LINE_AA );
                    }
                }
#endif
            }
#endif

            /* show _panel */
            {
                imshow("tmp",_panel) ;
                moveWindow( "tmp", 0, 0);
                refresh = false ;
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
        }

        c = waitKey(1000) ;
        if ('q' == c) break ;

        switch(c){
            static bool b3DM = 0 ;
            static int numRec = 0 ;
            static int step = 0 ;

            case '0': case '1': case '2': case '3': case '4':
            case '5': case '6': case '7': case '8': case '9':
                if(b3DM){
                    step ++ ;
                    numRec = numRec*10 + (c-'0') ;
                    if(step >= 3){
                        doDigitalFunc( numRec, refresh ) ;
                        b3DM = 0 ;
                        step = 0 ;
                        numRec = 0 ;
                    }
                }else if('0' == c){
                    b3DM = 1 ;
                    numRec = 0 ;
                    step = 0 ;
                }else{
                    doDigitalFunc( c-'0', refresh ) ;
                }
                break ;
            case ';':
            case ':':
                lockScreen = !lockScreen ;
                refresh = true ;
                break ;
            case '^':
                if(!lockScreen){
                    dataRangeEnd = 0 ;
                } else {
                    (0 == dtlsIdxOnMainView)
                        ?  dataRangeEnd -= GET_NUMBERS_PER_SCREEN(_mainView.cols,scale)
                        :  dtlsIdxOnMainView = 0 ;
                }
                refresh = true ;
                break ;
            case '$':
                if(!lockScreen){
                    dataRangeEnd = MAX_SUPPORTTED_LENGTH ;
                } else {
                    (GET_NUMBERS_PER_SCREEN(_mainView.cols,scale) -1 == dtlsIdxOnMainView)
                        ?  dataRangeEnd += GET_NUMBERS_PER_SCREEN(_mainView.cols,scale)
                        :  dtlsIdxOnMainView = GET_NUMBERS_PER_SCREEN(_mainView.cols,scale) -1 ;
                }
                refresh = true ;
                break ;
            case 'r':
                dataRangeEnd = 0; winH = MAX_WIN_HEIGHT/2; winW = MAX_WIN_WIDTH/2;
                CLEAN_SWITCHERS(baseLineSwitchers);
                SETALL_SWITCHERS(linesSwitchers);
                digtFuncIdx = 2 ;
                scale = 1 ;
                autoFit = false ;
                lockScreen = false ; dtlsIdxOnMainView  = RESET_DTLS_INDEX;
                refresh = true ;
                break ;
            case 'p':       // print current view info
                printViewInfo(true);
                refresh = false ;
                break ;
            case 'P':       // print current view info
                printViewInfo(false);
                refresh = false ;
                break ;
            case 'f':       // switch fix-scale flag
                autoFit = !autoFit ;
                refresh = true ;
                break ;
            case '|':       // to maximu width
                winW = MAX_WIN_WIDTH ;
                refresh =true ;
                break ;
            case '_':       //  to maximu height
                winH = MAX_WIN_HEIGHT ;
                refresh = true ;
                break ;
            case '\\':       //  to maximu width & height
                winH = MAX_WIN_HEIGHT ; winW = MAX_WIN_WIDTH;
                refresh = true ;
                break ;
#if 0
            case '>':
                winW += 20 ;
                refresh = true ;
                break ;
            case '<':
                winW -= 20 ;
                refresh = true ;
                break ;
#else
            case '>':
                scale=min(64,scale+1) ;
                refresh = true ;
                break ;
            case '<':
                scale=max(1,scale-1) ;
                refresh = true ;
                break ;
#endif
            case '-':
                winH -= 10 ;
                refresh = true ;
                break ;
            case '+':
                winH += 10 ;
                refresh = true ;
                break ;
            case 'l':
            case 'L':
                {
                    int step = (c == 'l') ? 1 : GET_NUMBERS_PER_SCREEN(_mainView.cols,scale)/20 ;
                    if(lockScreen){
                        if(GET_POSITION_OF_INDEX(dtlsIdxOnMainView,scale) + step*scale > GET_POSITION_OF_INDEX(GET_NUMBERS_PER_SCREEN(_mainView.cols,scale) - 1,scale) ) {
                            dataRangeEnd += step ;
                        }
                        dtlsIdxOnMainView += step ;
                    }else{
                        dataRangeEnd += (step + 9) ;
                    }
                    refresh = true ;
                }
                break ;
            case 'h':
            case 'H':
                {
                    int step = (c == 'h') ? 1 : GET_NUMBERS_PER_SCREEN(_mainView.cols,scale)/20 ;

                    if(lockScreen){
                        if(GET_POSITION_OF_INDEX(dtlsIdxOnMainView,scale) - step*scale < GET_POSITION_OF_INDEX(0,scale) ) {
                            dataRangeEnd -= step ;
                        }
                        dtlsIdxOnMainView -= step;
                    }else{
                        dataRangeEnd -= (step + 9) ;
                    }
                    refresh = true ;
                }
                break ;
            case 'j':   // switch the 0~9 keys function
                digtFuncIdx = ( digtFuncIdx + 1 ) % ( sizeof( digtFuncList )/sizeof( digtFuncPt ) );
                refresh = true ;
                break ;
            case 'k':
                digtFuncIdx = (0 == digtFuncIdx)
                            ? sizeof( digtFuncList )/sizeof( digtFuncPt ) - 1
                            : digtFuncIdx - 1 ;
                refresh = true ;
                break ;
            default:
                refresh = false ;
                break ;
        }
    }

    /* print the invers matrix of the result */
    return 0 ;
}
