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

#define  MAX_SUPPORTTED_LENGTH   (365*40)
#define  MAX_SUPPORTTED_LINES   (64)
#define  MAX_SCALE              (256)

#define  MAX_WIN_WIDTH  (1920)
#define  MAX_WIN_HEIGHT (1080)

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

#define  N_DATA_OF_CUR_VIEW(screenWidth,scale) ( (screenWidth<=(LINE_MARGIN_L)+(LINE_MARGIN_R)) ? 0 : max(1,((screenWidth)-(LINE_MARGIN_L)-(LINE_MARGIN_R))/(scale)) )
#define  GET_POSITION_BY_VIEW_IDX(index, scale)   ( (index) * (scale) + (scale)/2 + LINE_MARGIN_L)

using namespace cv;
using namespace std;
using namespace cv::dnn;

typedef int(*digtFuncPt)(int number, int &refresh);
int digtFuncBaselineFilter( int number, int &refresh );
int digtFuncLineFilter( int number, int &refresh );
int digtFuncScale( int number, int &refresh );

/* define & init */
/* color-list for lines */
static Scalar  lineColors[MAX_SUPPORTTED_LINES] = {
                        Scalar(255,50,50),
                        Scalar(80,80,150),
                        Scalar(255,255,0),
                        Scalar(255,0,255),
                        Scalar(0,0,255),
                        Scalar(0,255,255),
                        Scalar(0,255,0),
                        Scalar(255,125,125),
                        Scalar(255,255,255),
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

int dataRangeStart=MAX_SUPPORTTED_LENGTH;   // all x-coordinate SHOULD(MUST!!) base on the dataRangeStart(NOT the dataRangeEnd)
int dataRangeEnd=MAX_SUPPORTTED_LENGTH;
int dtlsIdx = -1;
int measureIdx = -1;
int winW = MAX_WIN_WIDTH ;
int winH = MAX_WIN_HEIGHT ;
Mat gPanel, gMainView, _bottomView, _topStatus_view, _leftDetailsView ;
Mat gLinesData ;

//@ mark mode
//@ use m<key> to creat a mark with the name <key>
//@ use '<key> to load the <key>_mark
bool mark_start = 0;        //@ create a mark with the <key>
bool load_mark = 0;         //@ load the <key>_mark
std::map<char, int> mark;   //@ key->dtlsIdx

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
    static bool     has_err = false;

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
            if(!has_err) {
                cerr << "out of rang, MAX_SUPPORTTED_LENGTH or linesLen" << '[' << MAX_SUPPORTTED_LENGTH << ',' << linesLen << ']' << endl ;
                cerr << "please note, x_dir is lines and y_dir is length of each lines" << endl;
                has_err = true;
            }
            break ;
        }

        _tmpSS.clear();
        _tmpSS.str(_tmpStr) ;

        /* extract data */
        for(_linesCnt = 0; _tmpSS.good() ; _linesCnt ++){
            if(_linesCnt >= min(linesNum, MAX_SUPPORTTED_LINES)) {
                if(!has_err) {
                    cerr << "out of rang, MAX_SUPPORTTED_LINES or linesNum" << '[' << MAX_SUPPORTTED_LINES << ',' << linesNum << ']' << endl ;
                    cerr << "please note, x_dir is lines and y_dir is length of each lines" << endl;
                    has_err = true;
                }
                break;
            }
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

int zoom_klines(int scale_)
{
    if(scale_ <= 0) scale_ = 1;
    if(scale_ == scale) return 1;

    /* adjust dtlsIdx, dataRangeStart, dataRangeEnd */
    {
        int s = dataRangeStart ;
        int e = dataRangeEnd ;
        int d = lockScreen? dtlsIdx : e-1;
        int dN = d ;
        int sN = dN - N_DATA_OF_CUR_VIEW(GET_POSITION_BY_VIEW_IDX(d-s, scale)+1+(scale-1-scale/2)+LINE_MARGIN_R, scale_) + 1 ;
        int eN = 0 ;
        int _adjust = 0 ;

        if(sN < 0){
            sN = 0 ;
        }
        eN = min(sN + N_DATA_OF_CUR_VIEW(gMainView.cols, scale_),gLinesData.cols) ;
        if(!lockScreen && eN -sN < N_DATA_OF_CUR_VIEW(gMainView.cols, scale_)){
            /* the right part maybe empty. if left part has more data undisplayed, move the view to right to fit the whole panel */
            _adjust = min(sN, N_DATA_OF_CUR_VIEW(gMainView.cols, scale_) - (eN-1 - sN + 1)) ;
            sN -= _adjust ;
        }

        dataRangeStart = sN ;
        dataRangeEnd = eN ;
        dtlsIdx = dN ;

        /*
        cout << "s=" << s << " d=" << d << " e=" << e << endl ;
        cout << "sN=" << sN << " dN=" << dN << " eN=" << eN << endl ;
        */
    }

    /* adjust scale */
    scale = scale_;
    return 0 ;
}

int zoom_klines(char zZ)
{
    int scale_ = zZ=='Z'? scale-1 : scale+1;
    return zoom_klines(scale_);
}


int digtFuncScale(
        int         number,
        int         &refresh
        )
{
    if(number<=0 || number>9) {
        return -1;
    }

    return zoom_klines(number);
}

int digtFuncLineFilter(
        int         number,
        int         &refresh
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
        int         &refresh
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
        int         &refresh     // refresh flag
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
                if(lineColors[i] == Scalar(0,0,0)) {
                    lineColors[i] = Scalar(r*step,g*step,b*step) ;
                }
                i++;
            }

    return ;
}

void calc_data_range(bool reset_start, bool reset_dtls, bool reset_measure)
{
    if(reset_start) dataRangeStart = gLinesData.cols - N_DATA_OF_CUR_VIEW(gMainView.cols,scale) ;
    if(dataRangeStart < 0) dataRangeStart = 0 ;
    if(dataRangeStart > gLinesData.cols-1) dataRangeStart = gLinesData.cols-1 ;
    dataRangeEnd = dataRangeStart + N_DATA_OF_CUR_VIEW(gMainView.cols,scale) ;
    if(dataRangeEnd > gLinesData.cols) dataRangeEnd = gLinesData.cols ;

    if(reset_dtls) dtlsIdx = (dataRangeEnd + (dataRangeStart-1) )/2 ;
    if(dtlsIdx < 0) dtlsIdx = 0 ;
    if(dtlsIdx > gLinesData.cols-1) dtlsIdx = gLinesData.cols-1 ;

    if(reset_measure) measureIdx = -1;
}

uint64_t get_timestamp_ms()
{
    return std::chrono::duration_cast<std::chrono::milliseconds>(
        std::chrono::system_clock::now().time_since_epoch()
    ).count();
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
                cerr << argv[0] << " stockCode filename linesNum linesLength [--help] [--group=NumOfGrp1,NumOfGrp2,...] [--showlines=L1,L2,...] [--focus=N] [--scale=N]" << endl ;
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
                idxFocusedLine = atoi(argv[_i]+strlen("--focus="))-1/*humen*/ ;
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
        importData(_dataFile, _linesNum, _linesLen, gLinesData) ;
        assert(_linesNum==gLinesData.rows) ;
        assert(_linesLen==gLinesData.cols) ;
        assert(idxFocusedLine<_linesNum && idxFocusedLine>=0) ;
        assert(scale>=1 && scale<=MAX_SCALE) ;
        initColor(_linesNum) ;
    }

    char    c = 0 ;
    int     refresh = 2/* reset calc_data_range*/ ;
    bool    b3DM = 0 ;  //@ 3 digtial mode, when start with 0, the 3 digital mode is on. 001==1, 010==10, 099=99
    int     step_b3DM = 0 ;
    int     numRec = 0 ;
    int     step_mv_act = 0;
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
                gPanel.create(winH,winW,CV_8UC3) ;
                gPanel.setTo(Scalar(0));
                if(lockScreen){
                    gMainView   = gPanel( Rect(LEFT_VIEW_W, 30, gPanel.cols-LEFT_VIEW_W-10, gPanel.rows-30-80) );
                    _bottomView = gPanel( Rect(LEFT_VIEW_W, gPanel.rows - 80, gMainView.cols, 80) ) ;
                }else{
                    //gMainView   = gPanel( Rect(0, 30, gPanel.cols-10, gPanel.rows-30-80) ) ;
                    //_bottomView = gPanel( Rect(0, gPanel.rows - 80, gMainView.cols, 80) ) ;
                    gMainView   = gPanel( Rect(LEFT_VIEW_W, 30, gPanel.cols-LEFT_VIEW_W-10, gPanel.rows-30-80) );
                    _bottomView = gPanel( Rect(LEFT_VIEW_W, gPanel.rows - 80, gMainView.cols, 80) ) ;
                }
                _topStatus_view = gPanel.rowRange(0, 30) ;
                _leftDetailsView = gPanel.colRange(0, LEFT_VIEW_W) ;
            }

            /* adjust data range,
               all x-coordinate SHOULD(MUST!!) base on the dataRangeEnd(NOT the dataRangeStart) */
            if (refresh == 2) {
                calc_data_range(true, false, false);
            }

            /* adjust gLinesData & _linesInfo */
            {
                int _idx = 0 ;
                int _linesNum = 0 ;
                Mat _m = gLinesData.clone() ;

                for(int i = 0; i < linesGrpInfo.size(); i++){
                    _linesNum = linesGrpInfo[i] ;

                    normalize(_m(Range(_idx,_idx+_linesNum), autoFit ? Range(dataRangeStart,dataRangeEnd) : Range::all()),
                              _m(Range(_idx,_idx+_linesNum), autoFit ? Range(dataRangeStart,dataRangeEnd) : Range::all()),
                              0+1, gMainView.rows-LINE_MARGIN_T-LINE_MARGIN_B-1, NORM_MINMAX); /* the upper_30 pixels for _linesInfo */

                    _idx += _linesNum ;

                }
                assert(_idx == gLinesData.rows);

                viewData = _m.colRange(dataRangeStart,dataRangeEnd) ;
                drawLines(viewData, gMainView, scale,
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

            /* adjust details index line */
            {
                if(!lockScreen){
                }else{
                    Point   _ofs;
                    Size    _orgMatrixSize;

                    gMainView.locateROI( _orgMatrixSize, _ofs );

                    /* draw a vertical line for measure */
                    if (lockScreen && measureIdx>=0) {
                        int  _idx = 0 ;
                        int  _pos = 0 ;

                        _idx = measureIdx - dataRangeStart ;
                        _pos = GET_POSITION_BY_VIEW_IDX(_idx,scale) ;

                        if(_pos >= LINE_MARGIN_L && _pos <= gMainView.cols-1-LINE_MARGIN_R){
                            for(int i = 0 ; i < gPanel.rows; i++) {
                                if((i%20)>4){
                                    gPanel.at<Vec3b>(i, _pos+_ofs.x )[0] = 0 ;
                                    gPanel.at<Vec3b>(i, _pos+_ofs.x )[1] = 0 ;
                                    gPanel.at<Vec3b>(i, _pos+_ofs.x )[2] = 255 ;
                                }
                            }
                        }
                    }

                    /* draw a vertical line on the dtlsIdx  */
                    int     _color_r = (mark_start||load_mark)? 0   : 127;
                    int     _color_g = (mark_start||load_mark)? 127 : 127;
                    int     _color_b = (mark_start||load_mark)? 0   : 127;
                    for(int i = 0 ; i < gPanel.rows; i++) {
                        if((i%20)<16){
                            gPanel.at<Vec3b>(i, GET_POSITION_BY_VIEW_IDX(dtlsIdx-dataRangeStart,scale)+_ofs.x )[0] = _color_b ;
                            gPanel.at<Vec3b>(i, GET_POSITION_BY_VIEW_IDX(dtlsIdx-dataRangeStart,scale)+_ofs.x )[1] = _color_g ;
                            gPanel.at<Vec3b>(i, GET_POSITION_BY_VIEW_IDX(dtlsIdx-dataRangeStart,scale)+_ofs.x )[2] = _color_r ;
                        }
                    }

                    /* draw a horizantl line */
                    for(int i = LINE_MARGIN_L; i < gMainView.cols-LINE_MARGIN_R; i++){
                        if((i%20)<17){
                            gMainView.at<Vec3b>(gMainView.rows - 1 - LINE_MARGIN_B - viewData.at<double>(idxFocusedLine,dtlsIdx-dataRangeStart), i)[0] = 127 ;
                            gMainView.at<Vec3b>(gMainView.rows - 1 - LINE_MARGIN_B - viewData.at<double>(idxFocusedLine,dtlsIdx-dataRangeStart), i)[1] = 127 ;
                            gMainView.at<Vec3b>(gMainView.rows - 1 - LINE_MARGIN_B - viewData.at<double>(idxFocusedLine,dtlsIdx-dataRangeStart), i)[2] = 127 ;
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
                int             text_hi = 20;

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
                if(mark_start) s << " [marking]";
                if(load_mark) s << " [marker]";
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
                putText( _leftDetailsView, s.str(), Point(20,54+1*text_hi), 0, 0.4, Scalar(0, 0, 255), 0, LINE_AA );

                /* show line info */
                s.str("");
                (digtFuncList[ digtFuncIdx ] == digtFuncLineFilter) ? s << "*Lines:" : s << " Lines:" ;
                putText( _leftDetailsView, s.str(), Point(0,54+2*text_hi), 0, 0.4, Scalar(0, 0, 255), 0, LINE_AA );
                s.str("/") ;
                for( i = 0 ; i < viewData.rows; i++ ){
                    if( GET_SWITCHER_STATUS(linesSwitchers,i) ){
                        s << i + 1 << '/' ;
                    }
                }
                putText( _leftDetailsView, s.str(), Point(20,54+3*text_hi), 0, 0.4, Scalar(0, 0, 255), 0, LINE_AA );

                /* show scale info */
                s.str("");
                (digtFuncList[ digtFuncIdx ] == digtFuncScale) ? s << "*Scale:" : s << " Scale:" ;
                putText( _leftDetailsView, s.str(), Point(0,54+4*text_hi), 0, 0.4, Scalar(0, 0, 255), 0, LINE_AA );
                s.str("") ;
                s << scale ;
                putText( _leftDetailsView, s.str(), Point(20,54+5*text_hi), 0, 0.4, Scalar(0, 0, 255), 0, LINE_AA );

#if 1
                int info_idx = 4 ;

                /* show details info */
                if(lockScreen){
                    double  _d = 0 ;
                    long    _l = 0 ;
                    Scalar  _color ;

                    for(int i = 0; i < gLinesData.rows; i++){
                        _d = gLinesData.at<double>(i,dtlsIdx) ;
                        _color = lineColors[i] ;
                        s.str("");
                        s << " line-" << i+1 << " = " << setiosflags(ios::fixed) << setprecision(_d>99999?0:2) << _d ;
                        putText( _leftDetailsView, s.str(), Point(0,120+(info_idx++)*text_hi), 0, 0.4, _color, 0, LINE_AA );
                    }
                }

                /* show measures */
                if (measureIdx >= 0) {
                    assert(lockScreen);
                    info_idx += 4 ;

                    int _days = 0 ;
                    int _dataS = 0 ;
                    int _dataE = 0 ;
                    double _d = 0 ;
                    Scalar  _color ;
                    Mat _m ;

                    if(dtlsIdx > measureIdx){
                        _dataS = measureIdx + 1 ;       // plus 1, not include the first(start) day
                        _dataE = dtlsIdx ;
                    }else{
                        _dataS = dtlsIdx + 1 ; // plus 1, not include the first(start) day
                        _dataE = measureIdx ;
                    }
                    _days = _dataE - _dataS + 1 ;

                    s.str("");
                    s << " Dur-" << _days;
                    putText( _leftDetailsView, s.str(), Point(0,120+(info_idx++)*text_hi), 0, 0.4, Scalar(255,255,255), 0, LINE_AA );

                    for(i=0; i<gLinesData.rows; i++) {
                        Mat _lineData = gLinesData.row(i) ;

                        /* amp-custom */
                        if(_days<=0||_lineData.at<double>(0,measureIdx)<=0) {
                            _d = 0;
                        }
                        else {
                            double a = round(_lineData.at<double>(0,dtlsIdx) * 100);
                            double b = round(_lineData.at<double>(0,measureIdx) * 100);
                            _d = (a-b)/b*100;
                        }

                        _color = lineColors[i] ;
                        s.str(""); s << " line-" << i+1 << " = ";
                        putText( _leftDetailsView, s.str(), Point(0,120+(info_idx)*text_hi), 0, 0.4, _color, 0, LINE_AA );

                        _color = (_d>0) ? Scalar(0,0,255) : ((_d<0) ? Scalar(0,255,0) : Scalar(255,255,255)) ;
                        s.str(""); s << setiosflags(ios::fixed) << setprecision(2) << abs(_d) << "%" ;
                        putText( _leftDetailsView, s.str(), Point(80,120+(info_idx++)*text_hi), 0, 0.4, _color, 0, LINE_AA );

#if 0
                        /* total_amp-custom */
                        s.str("");
                        _d = (_days>0)? _getTT(gValData.colRange(_dataS,_dataE+1), _m, _days, true, true)/10000000.0 : 0 ;
                        _color = Scalar(255,0,0) ;
                        s << " VALT-" << _days << "=" << setiosflags(ios::fixed) << setprecision(2) << (_d) ;
                        putText( gLeftDetailsView, s.str(), Point(0,120+(info_idx++)*text_hi), 0, 0.4, _color, 0, LINE_AA );

                        /* total_exchange-custom */
                        s.str("");
                        _d = (_days>0)? _getTT(gXcgData.colRange(_dataS,_dataE+1), _m, _days, true, true) : 0 ;
                        _color = Scalar(255,0,0) ;
                        s << " XCGT-" << _days << "=" << setiosflags(ios::fixed) << setprecision(2) << (_d) ;
                        putText( gLeftDetailsView, s.str(), Point(0,120+(info_idx++)*text_hi), 0, 0.4, _color, 0, LINE_AA );

                        /* average-custom */
                        s.str("");
                        _d = (_days>0)? _getAvg(_focusLineData.colRange(_dataS,_dataE+1), _m, _days, true) : 0 ;
                        _color = Scalar(255,0,0) ;
                        s << " AVG-" << _days << "=" << setiosflags(ios::fixed) << setprecision(2) << (_d) ;
                        putText( gLeftDetailsView, s.str(), Point(0,120+(info_idx++)*text_hi), 0, 0.4, _color, 0, LINE_AA );

                        /* rsi-custom */
                        s.str("");
                        _d = (rsiCustom>0) ? _getUpDnRateIndexer(gAmpData.colRange(_dataS,_dataE+1), gRsiCustomData, _dataE - _dataS + 1, false, true) : 0 ;
                        _color = (_d>=85) ? Scalar(0,0,255)
                                          : (_d<=15) ? Scalar(0,255,0)
                                                     : Scalar(200,200,200) ;
                        s << " RSI-" << rsiCustom << "=" << setiosflags(ios::fixed) << setprecision(2) << (_d) ;
                        putText( gLeftDetailsView, s.str(), Point(0,120+(info_idx++)*text_hi), 0, 0.4, _color, 0, LINE_AA );

                        /* pwri-custom */
                        s.str("");
                        _d = (pwriCustom>0) ? _getUpDnRateIndexer(gPwrData.colRange(_dataS,_dataE+1), gPwriCustomData, _dataE - _dataS + 1, false, true) : 0 ;
                        _color = (_d>=85) ? Scalar(0,0,255)
                                          : (_d<=15) ? Scalar(0,255,0)
                                                     : Scalar(200,200,200) ;
                        s << " PWRI-" << pwriCustom << "=" << setiosflags(ios::fixed) << setprecision(2) << (_d) ;
                        putText( gLeftDetailsView, s.str(), Point(0,120+(info_idx++)*text_hi), 0, 0.4, _color, 0, LINE_AA );

                        /* xcg-custom */
                        s.str("");
                        _d = (xcgAvgICustom>0) ? _getUpDnRateIndexer(gXcgData.colRange(_dataS,_dataE+1), gXcgAvgICustomData, _dataE - _dataS + 1, true, true) : 0 ;
                        _color = (_d>=85) ? Scalar(0,0,255)
                                          : (_d<=15) ? Scalar(0,255,0)
                                                     : Scalar(200,200,200) ;
                        s << " XCG-" << xcgAvgICustom << "="  << setiosflags(ios::fixed) << setprecision(2) << (_d) ;
                        putText( gLeftDetailsView, s.str(), Point(0,120+(info_idx++)*text_hi), 0, 0.4, _color, 0, LINE_AA );
#endif
                    }
                }
#endif
            }
#endif

            /* show gPanel */
            {
                imshow("tmp",gPanel) ;
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

        c = waitKey(1000000) ;
        static uint64_t last_timestamp = 0;
        uint64_t now = get_timestamp_ms();
        uint64_t gap = now - last_timestamp;
        last_timestamp = now;

        if (mark_start) {
            assert(lockScreen);
            if(c>='a' && c<='z') {
                mark[c] = dtlsIdx;
            }
            if(c>0) {
                mark_start = false;
                refresh = true ;
            }
            continue;
        }

        if (load_mark) {
            assert(lockScreen);
            if(mark.find(c) != mark.end()) {
                if(mark[c] != dtlsIdx) {
                    int new_idx = mark[c];
                    mark['\''] = dtlsIdx;   //@ update last_mark
                    dtlsIdx = new_idx;
                    if (dataRangeStart > dtlsIdx) {
                        dataRangeStart = dtlsIdx;
                        calc_data_range(false, false, false);
                    }
                    if (dataRangeEnd < dtlsIdx+1) {
                        dataRangeStart += dtlsIdx+1 - dataRangeEnd;
                        calc_data_range(false, false, false);
                    }
                }
            }
            if(c>0) {
                load_mark = false;
                refresh = true ;
            }
            continue;
        }

        if ('q' == c) break ;

        switch(c) {

            case '0': case '1': case '2': case '3': case '4':
            case '5': case '6': case '7': case '8': case '9':
                if(b3DM){
                    step_b3DM ++ ;
                    numRec = numRec*10 + (c-'0') ;
                    if(step_b3DM >= 2){
                        doDigitalFunc( numRec, refresh ) ;
                        b3DM = 0 ;
                        step_b3DM = 0 ;
                        numRec = 0 ;
                    }
                }else if('0' == c){
                    b3DM = 1 ;
                    numRec = 0 ;
                    step_b3DM = 0 ;
                }else{
                    doDigitalFunc( c-'0', refresh ) ;
                }
                refresh = true;
                break ;
            case ';':
            case ':':
                lockScreen = !lockScreen ;
                calc_data_range(false, true, true);
                refresh = true ;
                break ;
            case 'r':
                dtlsIdx = -1;
                measureIdx = -1;
                dataRangeStart = 0;
                dataRangeEnd = 0;
                winH = MAX_WIN_HEIGHT/2; winW = MAX_WIN_WIDTH/2;
                CLEAN_SWITCHERS(baseLineSwitchers);
                SETALL_SWITCHERS(linesSwitchers);
                digtFuncIdx = 2 ;
                scale = 1 ;
                autoFit = false ;
                lockScreen = false ;
                calc_data_range(true, true, true);
                refresh = true ;
                break ;
            case 'm':
                if(lockScreen) {
                    mark_start = true;
                }
                refresh = true;
                break;
            case '\'':
                if(lockScreen) {
                    load_mark = true;
                }
                refresh = true;
                break;
            case 'M':
                if (lockScreen) {
                    measureIdx = dtlsIdx;
                    mark['M'] = dtlsIdx;    //@ auto mark 'M'
                    refresh = true ;
                }
                break;
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
            case 'z':
            case 'Z':
                zoom_klines(c);
                refresh = true;
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
            case '^':
            case 'h':
            case 'H':
                if(!lockScreen) {
                    /**/ if(c=='^') step_mv_act = MAX_SUPPORTTED_LENGTH;
                    else if(c=='h') step_mv_act = 1;
                    else if(c=='H') step_mv_act = max(1, N_DATA_OF_CUR_VIEW(gMainView.cols,scale)/20);
                    dataRangeStart -= step_mv_act ;
                }
                else {
                    /**/ if(c=='^') step_mv_act = max(1, N_DATA_OF_CUR_VIEW(gMainView.cols,scale));
                    else if(c=='h') step_mv_act = 1;
                    else if(c=='H') step_mv_act = max(1, N_DATA_OF_CUR_VIEW(gMainView.cols,scale)/20);
                    if (gap>=3000) {
                        printf("%ld-----\n", gap);
                        mark['\''] = dtlsIdx;
                    }
                    if (dtlsIdx -  step_mv_act >= dataRangeStart) {
                        dtlsIdx -= step_mv_act;
                    }
                    else if (dtlsIdx != dataRangeStart) {
                        dtlsIdx = dataRangeStart;
                    }
                    else {
                        dtlsIdx -= step_mv_act;
                        dataRangeStart = dtlsIdx;
                    }
                }
                calc_data_range(false, false, false);
                refresh = true ;
                break ;
            case '$':
            case 'l':
            case 'L':
                if(!lockScreen) {
                    /**/ if(c=='$') step_mv_act = MAX_SUPPORTTED_LENGTH;
                    else if(c=='l') step_mv_act = 1;
                    else if(c=='L') step_mv_act = max(1, N_DATA_OF_CUR_VIEW(gMainView.cols,scale)/20);
                    dataRangeStart += step_mv_act;
                    dataRangeEnd += step_mv_act ;
                }
                else {
                    /**/ if(c=='$') step_mv_act = max(1, N_DATA_OF_CUR_VIEW(gMainView.cols,scale));
                    else if(c=='l') step_mv_act = 1;
                    else if(c=='L') step_mv_act = max(1, N_DATA_OF_CUR_VIEW(gMainView.cols,scale)/20);
                    if (gap>=3000) {
                        printf("%ld!-----\n", gap);
                        mark['\''] = dtlsIdx;
                    }
                    if (dtlsIdx +  step_mv_act <= dataRangeEnd-1) {
                        dtlsIdx += step_mv_act;
                    }
                    else if (dtlsIdx != dataRangeEnd-1) {
                        dtlsIdx = dataRangeEnd-1;
                    }
                    else {
                        dtlsIdx += step_mv_act;
                        dataRangeStart += step_mv_act;
                        dataRangeEnd += step_mv_act ;
                    }
                }
                calc_data_range(dataRangeEnd > gLinesData.cols, false, false);
                refresh = true ;
                break ;
            case 'J':
            case 'K':
                if(lockScreen) {
                    idxFocusedLine += c=='J'? 1 : -1;
                    idxFocusedLine = (idxFocusedLine + gLinesData.rows) % gLinesData.rows;
                    refresh = true;
                }
                break;
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
