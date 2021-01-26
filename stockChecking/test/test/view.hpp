#ifndef _VIEW_HPP_
#define _VIEW_HPP_

#include "opencv2/imgproc.hpp"
#include <iostream>
#include <list>
#include <signal.h>
#include <pthread.h>

#define INVALID_ID  (-1)
#define SCALE_X_BASE_ON_LEFT  (-1)
#define SCALE_X_BASE_ON_RIGHT (-2)
#define ZOOM_IN               (-1)
#define ZOOM_OUT              (-2)
#define MOVING_UP             (1)
#define MOVING_DOWN           (2)
#define MOVING_LEFT           (3)
#define MOVING_RIGHT          (4)
#define MOVING_PAGE_LEFT      (5)
#define MOVING_PAGE_RIGHT     (6)
#define MOVING_HEAD           (7)
#define MOVING_TAIL           (8)

typedef unsigned long long ULL ;

class shape{
    public:
        cv::Mat     data ;
        int         lineType ; // draw this shape with specified linetype
        int         thick ;    // draw this shape with specified thick of line
        int         scale ;
        bool        bottomBase ;
        bool        autoFit ;
        cv::Scalar  color ;
        cv::Mat     canvas ;

        shape(void) :
            data(cv::Mat(0,0,CV_64F)),
            lineType(cv::LINE_AA),
            thick(1),
            scale(1),
            bottomBase(true),
            autoFit(true),
            color(cv::Scalar(255,255,255)),
            mrgL(2),
            mrgR(2),
            mrgT(2),
            mrgB(2),
            viewableMost(true),
            empty(true)
        {
            return ;
        }

        shape(
            const cv::Mat&  data,
            const cv::Mat& canvas,
            int mrgL = 2,
            int mrgR = 2,
            int mrgT = 2,
            int mrgB = 2
            ) :
            data(data),
            lineType(cv::LINE_AA),
            thick(1),
            scale(1),
            bottomBase(true),
            autoFit(true),
            color(cv::Scalar(255,255,255)),
            canvas(canvas),
            mrgL(mrgL),
            mrgR(mrgR),
            mrgT(mrgT),
            mrgB(mrgB),
            viewableMost(true),
            empty(false)
        {
            return ;
        }

        shape(const shape& rhs)
        {
            this->data=rhs.data ;
            this->lineType=rhs.lineType;
            this->thick=rhs.thick;
            this->scale=rhs.scale;
            this->bottomBase=rhs.bottomBase;
            this->autoFit=rhs.autoFit;
            this->color=rhs.color;
            this->canvas=rhs.canvas;
            this->mrgL=rhs.mrgL;
            this->mrgR=rhs.mrgR;
            this->mrgT=rhs.mrgT;
            this->mrgB=rhs.mrgB;
            this->viewableMost=rhs.viewableMost;
            this->empty=rhs.empty;
        }

        shape& operator=(const shape& rhs)
        {
            this->data=rhs.data ;
            this->lineType=rhs.lineType;
            this->thick=rhs.thick;
            this->scale=rhs.scale;
            this->bottomBase=rhs.bottomBase;
            this->autoFit=rhs.autoFit;
            this->color=rhs.color;
            this->canvas=rhs.canvas;
            this->mrgL=rhs.mrgL;
            this->mrgR=rhs.mrgR;
            this->mrgT=rhs.mrgT;
            this->mrgB=rhs.mrgB;
            this->viewableMost=rhs.viewableMost;
            this->empty=rhs.empty;

            return *this ;
        }
        virtual inline  int setAutoFit(bool autoFit){ this->autoFit=autoFit ; return 0; }
        virtual inline  int setBottomBase(bool bottomBase){this->bottomBase=bottomBase; return 0; }
        virtual inline  int setColor(const cv::Scalar& color){ this->color=color; return 0; }
        virtual int doPaint(void) = 0 ;
        virtual int doZoom(int scale, int baseX) = 0 ;
        virtual int doMoving(int dir, int shift) = 0 ;
        virtual int doMovingFocus(int dir, int shift) = 0 ;
        virtual int doUpsideDown(void) = 0 ;
        virtual int doFlip(void) = 0 ;
        virtual int setCanvas(cv::Mat& canvas) = 0 ;
        virtual int setData(const cv::Mat& data, void* tag) = 0 ;
        virtual int getDispArea(int& x1, int& y1, int& x2, int& y2) = 0 ;
        virtual int setFocus(int x, int y) = 0 ;
        virtual int getFocus(int& x, int& y) = 0 ;
        virtual int getInfoOnFocus(void* retData) = 0 ;

    protected:
        int         mrgL ;
        int         mrgR ;
        int         mrgT ;
        int         mrgB ;
        bool        viewableMost ;
        bool        empty ;
        cv::Point   focus ;

} ;

class idctLine : public shape{
    public:
        idctLine(void) ;
        idctLine(const cv::Mat& canvas) ;
        idctLine& operator=(const idctLine& rhs) ;

        virtual int doPaint(void) ;
        virtual int doZoom(int scale, int baseX) ;
        virtual int doMoving(int dir, int shift) ;
        virtual int doMovingFocus(int dir, int lftShift) ;
        virtual int doUpsideDown(void) ;
        virtual int doFlip(void) ;
        virtual int setCanvas(cv::Mat& canvas) ;
        virtual int setData(const cv::Mat& data, void* tag) ;
        virtual int getDispArea(int& x1, int& y1, int& x2, int& y2) ;
        virtual int setFocus(int x, int y) ;
        virtual int getFocus(int& x, int& y) ;
        virtual int getInfoOnFocus(void* retData) ;

    private:
} ;

class lineObj : public shape{
    public:
        /* NOTE,
           the line data in matrix is vertical (easy for resize)
           if there are several lines in matrix, each col is a single line
           */
        lineObj(void) ;
        lineObj(const cv::Mat& canvas,const std::vector<double>& data) ;
        lineObj(const cv::Mat& canvas,const cv::Mat& datas) ;
        lineObj(const cv::Mat& canvas,const cv::Mat& datas, const std::vector<int>& lineSets) ;
        lineObj& operator=(const lineObj& rhs) ;

        virtual int doPaint(void) ;
        virtual int doZoom(int scale, int baseX) ;
        virtual int doMoving(int dir, int shift) ;
        virtual int doMovingFocus(int dir, int lftShift) ;
        virtual int doUpsideDown(void) ;
        virtual int doFlip(void) ;
        virtual int setCanvas(cv::Mat& canvas) ;
        virtual int setData(const cv::Mat& data, void* tag) ;
        virtual int getDispArea(int& x1, int& y1, int& x2, int& y2) ;
        virtual int setFocus(int dataIndex, int nonuse=-1) ;
        virtual int getFocus(int& x, int& y) ; // as the normalizing, the 2 functions
        virtual int getInfoOnFocus(void* retData) ;  // should be invoked after doPaint

        
        int setColor(const cv::Scalar& color) ;
        int setLineSets(const std::vector<int>& lineSets) ;
        int setData(const cv::Mat& data, const std::vector<int>& lineSets) ;
        cv::Range getDispRange(void) ;
        int  getData(cv::Mat& reciver, const cv::Range& range) ;
        void printInfo(void) ;

        int     firstDispDataIdx ;
        int     lastDispDataIdx ;
        int     offsetX ;
        int     offsetY ;
        int     headLineIdx ; // like group id

    private:
        struct lineInfo{
            int         idxInDataMatrix ;
            bool        visible ;
            cv::Scalar  color ;
        } ;
#define GET_MATCHING_LASTDISP_DATA_IDX(firstDispDataIdx) \
        (   \
            lastDispDataIdx=(canvas.cols-mrgL-mrgR-offsetX)/scale + ((canvas.cols-mrgL-mrgR-offsetX)%scale)/(scale/2+1) - 1 + firstDispDataIdx, \
            lastDispDataIdx=(lastDispDataIdx<firstDispDataIdx)?firstDispDataIdx:lastDispDataIdx, \
            lastDispDataIdx=(lastDispDataIdx>this->data.rows-1)?this->data.rows-1:lastDispDataIdx \
        )

#define GET_MATCHING_FIRSTDISP_DATA_IDX(lastDispDataIdx) \
        (   \
            firstDispDataIdx=lastDispDataIdx+1 - (canvas.cols-mrgL-mrgR-offsetX)/scale - ((canvas.cols-mrgL-mrgR-offsetX)%scale)/(scale/2+1), \
            firstDispDataIdx=(firstDispDataIdx>lastDispDataIdx)?lastDispDataIdx:firstDispDataIdx,   \
            firstDispDataIdx=(firstDispDataIdx<0)?0:firstDispDataIdx    \
        )

        cv::Mat dataNor ; // normalized data (for displaying porpose)
        std::vector<struct lineInfo>   linesInfo ;
        //ULL     bindMask ;

} ;

class view{

#define NON_SHAPE_ID        (INVALID_ID)
#define ORDER_FLOAT         (100)
#define ORDER_TOPMOST       (1024)
#define ORDER_NORMAL        (2048)
#define ORDER_BOTTOMMOST    (3072)
#define MAX_SHAPE_NUM       (64)

    public:
        typedef int shapeId ;

    private:
        struct _shape{
            shapeId id ;
            shape*  obj ;
            bool    visible ;
        } ;

    public:
        view(void) ;
        view(const cv::Mat& canvas, 
             int (*keyHandler)(char,void*)=NULL,
             int mrgL=1, int mrgR=1, int mrgT=1, int mrgB=1) ;

        int      setCanvas(cv::Mat& canvas) ;
        cv::Mat& getCanvas(void) ;
        shapeId  addShape(shape& s) ;
        int      rmvShape(shapeId id) ;
        int      setShapeVisible(shapeId id, bool visible) ;
        bool     getShapeVisible(shapeId id) ;
        int      setFocus(shapeId id) ;
        int      setTopMost(shapeId id) ;
        int      setBottomMost(shapeId id) ;
        int      setFloat(shapeId id) ;
        int      setToAbove(shapeId above, shapeId blow) ;
        int      setVisible(bool visible) ;
        bool     getVisible(void) ;
        int      setBinding(shapeId a, shapeId b) ;
        bool     getAutoFit(void) ;
        int      setAutoFit(bool autoFit) ;
        int      setKeyHandler(int (*)(char,void*)) ;

        int      doOrder(void) ;
        int      doRefresh(void) ;
        int      doMoving(int dir, int shift=0) ;
        int      doMovingFocus(int dir, int lftShift) ;
        int      doMovingView(int x, int y) ;
        int      doZoom(int scale, int baseX) ;
        int      handleKey(char key, void* tag=NULL) ;
        int      assignDataSrcUpdateListener(class dataSource& ds) ;

        std::string name ;
        bool        visible ;
        bool        autoFit ;

    private:
        static int defaultKeyHandler(char key, void* tag) ;
        static bool defaultCompare(const std::pair<shapeId,int>&a, const std::pair<shapeId,int>&b) ;
        static void dataSrcUpdateCallback(int id, int ntfType, void* tag) ; 
        inline shapeId assignShapeId(void) ;
        inline shapeId recycleShapeId(shapeId id) ;

        int      mrgL ;
        int      mrgR ;
        int      mrgT ;
        int      mrgB ;
        cv::Mat  canvas ;
        shapeId  focusedId ;
        shapeId  shapeIdKeeper ;
        idctLine indicater ;
        bool     indicaterVisble ;
        int      dataSrcUpdateListener ;

        std::vector<struct _shape>               shapes ;
        std::list<std::pair<shapeId,int> >       shapeOrders ;
        std::bitset<MAX_SHAPE_NUM*MAX_SHAPE_NUM> bindMap ;
        int (*keyHandler)(char key, void* tag) ;

} ;

class dataSource{
    public:
#define FIRST_VALID_HANDLER_ID  (100)
#define MAX_HIS_DATA_ROW        (50*365*2/3)    // 50 years
#define MAX_HOT_DATA_ROW        (4*3600)        // 4 hours
#define HOT_DATA_REFERSH_GAP    (3)             // 3 seconds
#define THREAD_STATUS_STARTED   (1)
#define THREAD_STATUS_STOPPED   (2)
#define SMOOTH_TYPE_DEFAULT     (0)             // no change
#define SMOOTH_TYPE_HEAD_SEED   (1)             // head is unchanged
#define SMOOTH_TYPE_TAIL_SEED   (2)             // tail is unchanged
#define DS_NTF_TYPE_HOT_DATA_UPDATED    (1)

        enum DATA_TYPE_HIS{
            DATA_ID_HIS_DATE = 0 ,
            DATA_ID_HIS_CLS ,
            DATA_ID_HIS_HIG ,
            DATA_ID_HIS_LOW ,
            DATA_ID_HIS_OPN ,
            DATA_ID_HIS_YSTDCLS ,
            DATA_ID_HIS_AMPV ,
            DATA_ID_HIS_AMPL ,
            DATA_ID_HIS_XCG ,
            DATA_ID_HIS_VOL ,
            DATA_ID_HIS_VAL ,
            DATA_ID_HIS_TTVAL ,
            DATA_ID_HIS_LIVVAL ,
            DATA_ID_HIS_DEALCNT ,
            DATA_TYPE_COUNT_HIS
        } ;

        enum DATA_TYPE_HOT{
            DATA_ID_HOT_DATE = 0 ,
            DATA_ID_HOT_CLS ,
            DATA_ID_HOT_HIG ,
            DATA_ID_HOT_LOW ,
            DATA_ID_HOT_OPN ,
            DATA_ID_HOT_YSTDCLS ,
            DATA_ID_HOT_AMPV ,
            DATA_ID_HOT_AMPL ,
            DATA_ID_HOT_XCG ,
            DATA_ID_HOT_VOL ,
            DATA_ID_HOT_VAL ,
            DATA_ID_HOT_TTVAL ,
            DATA_ID_HOT_LIVVAL ,
            DATA_ID_HOT_DEALCNT ,
            DATA_ID_HOT_TIME ,
            DATA_TYPE_COUNT_HOT
        } ;

    private:
        struct connectInfo{
            int                 id ;
            shape*              ps ;
            void*               ptag ;
            bool                autoTransport ;
        } ;

        struct notifyInfo{
            int                 id ;        // id for listener
            void(*cb)(int,int,void*) ;      // call back from listner
            void*               tag ;       // tag from listener
        } ;

    public:
        dataSource(const std::string& history, const std::string& hot) ;
        ~dataSource(void){ std::cout << "destory dataSource" << std::endl ;if(tid) pthread_kill(tid,9) ; }

        int start(void) ;
        int stop(void) ;
        int regNotify(void (*fct)(int id, int ntfType,void* tag),void* tag) ;
        int disNotify(int id) ;
        int connect(shape& s, void* tag=NULL, bool autoTransport=true) ;
        int disConnect(int id) ;
        int setAutoTransportData(int id, bool autoTransport) ;
        int getAutoTransportData(int id, bool& autoTransport) ;
        int transportData(int id) ;

    private:
        static void* hotDataUpdater(void* tag) ; // thread to update Hot data
        const inline cv::Mat read(int id){ return messDataHisFixed.col(id); }
        const inline cv::Mat read(int from, int to){ return messDataHisFixed.colRange(from,to); }

        int loadHisData(bool forceReload, bool updateWithHotData) ;
        int loadHotData(bool forceReload) ;
        int smoothData(int smoothType, bool onlyFixHotData) ;
        int transportData(void) ;
        int updateNotify(void) ;
        int update(bool forceReloadHisData, 
                   bool forceReloadHotData,
                   bool updateLastHisItemWithHot,
                   bool onlyFixHotData,
                   bool doTransportData = true,
                   bool doUpdateNotify = true) ;

        std::string hisFilename ;
        std::string hotFilename ;
        int         smoothType ;
        cv::Mat     messDataHot ;
        cv::Mat     messDataHis ;
        cv::Mat     messDataHisFixed ;
        std::vector<struct notifyInfo>      notifyHandler ;
        std::vector<struct connectInfo>     connectHandler ;

        int              status ;
        pthread_t        tid ;
        pthread_mutex_t  mutex ;
} ;

#endif
