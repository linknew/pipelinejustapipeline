#include "view.hpp"
#include <iostream>
#include <fstream>
#include <climits>
#include "opencv2/core.hpp"
#include "opencv2/highgui.hpp"

//using namespace std ;

#define p(c)  std::cerr << ' ' << c << ' '
#define pn(c)  std::cerr << c << std::endl

void lineObj::printInfo(void)
{
//    cout << endl ;
//    cout << "firstDispDataIdx=" << firstDispDataIdx << endl ;
//    cout << "lastDispDataIdx=" << lastDispDataIdx << endl ;
//    cout << "offsetX=" << offsetX << endl ;
//    cout << "scale=" << scale << endl ;
}

lineObj::lineObj(void)
    :
    shape(),
    dataNor(cv::Mat(0,0,CV_64F)),
    offsetX(0),
    offsetY(0),
    headLineIdx(0),
    linesInfo(0)
{
    focus.x=-1 ;
    focus.y=-1 ;
    return ;
}

lineObj::lineObj(
    const cv::Mat& canvas,
    const std::vector<double>& data) 
    : 
    shape(cv::Mat(data),canvas),
    dataNor(cv::Mat(0,0,CV_64F)),
    offsetX(0),
    offsetY(0),
    headLineIdx(0)
{
    struct lineInfo info ;
    info.idxInDataMatrix=0;
    info.visible=true;
    info.color=this->color ;
    linesInfo.push_back(info) ;

    focus.x=-1 ;
    focus.y=-1 ;
    firstDispDataIdx = 0 ;
    lastDispDataIdx = GET_MATCHING_LASTDISP_DATA_IDX(firstDispDataIdx) ;
    return ;
}

lineObj::lineObj(
    const cv::Mat& canvas,
    const cv::Mat& data
    ) : 
    shape(data,canvas),
    dataNor(cv::Mat(0,0,CV_64F)),
    offsetX(0),
    offsetY(0),
    headLineIdx(0)
{
    struct lineInfo info ;
    for(int i=0; i<data.cols; i++){
        info.idxInDataMatrix=i;
        info.visible=true;
        info.color=this->color ;
        linesInfo.push_back(info) ;
    }

    focus.x=-1 ;
    focus.y=-1 ;
    firstDispDataIdx = 0 ;
    lastDispDataIdx = GET_MATCHING_LASTDISP_DATA_IDX(firstDispDataIdx) ;
    return ;
}

lineObj::lineObj(
    const cv::Mat& canvas,
    const cv::Mat& data,
    const std::vector<int>& linesIdx
    ) : 
    shape(data,canvas),
    dataNor(cv::Mat(0,0,CV_64F)),
    offsetX(0),
    offsetY(0),
    headLineIdx(0)
    
{
    struct lineInfo info ;
    for(int i=0; i<linesIdx.size(); i++){
        info.idxInDataMatrix=linesIdx[i];
        info.visible=true;
        info.color=this->color ;
        linesInfo.push_back(info) ;
    }

    focus.x=-1 ;
    focus.y=-1 ;
    firstDispDataIdx = 0 ;
    lastDispDataIdx = GET_MATCHING_LASTDISP_DATA_IDX(firstDispDataIdx) ;
    return ;
}

lineObj& lineObj::operator=(const lineObj& rhs)
{
    if(this == &rhs) return *this ;

    shape::operator=(rhs) ;
    this->data=rhs.data ;
    this->dataNor=rhs.dataNor ;
    this->firstDispDataIdx=rhs.firstDispDataIdx ;
    this->lastDispDataIdx=rhs.lastDispDataIdx ;
    this->offsetX=rhs.offsetX ;
    this->offsetY=rhs.offsetY ;
    this->focus=rhs.focus ;
    this->headLineIdx=rhs.headLineIdx ;

    return *this ;
}

int lineObj::setColor(const cv::Scalar& color)
{
    for(int i=0; i<linesInfo.size(); i++){
        linesInfo[i].color = color ;
    }
    this->color = color ;
    return 0 ;
}

int lineObj::doPaint(void)
{
    assert(canvas.rows && canvas.cols) ;
    assert(data.rows && data.cols) ;

    /* we can use getData function to combine the new matrix for processing.
       at here we dont use it as we used a more efficent way to combine the new matrix
     */

    // get normalized data
    {
        // make a new matrix which (only) include all lines data
        // check if the lines index is continious
        cv::Mat t ;
        int max = 0 ;
        int min = dataSource::DATA_TYPE_COUNT_HOT + dataSource::DATA_TYPE_COUNT_HIS ;
        for(int i=0; i<linesInfo.size(); i++){
            if(linesInfo[i].idxInDataMatrix < min) min=linesInfo[i].idxInDataMatrix ;
            if(linesInfo[i].idxInDataMatrix > max) max=linesInfo[i].idxInDataMatrix ;
        }

        //pthread_mutex_lock(&mutex) ;
        if(max-min+1 == linesInfo.size()){
            // is continious lineSets
            t = data.colRange(min,max+1) ;
        }else{
            // the lines index are splited
            t.create(data.rows,linesInfo.size(),data.type()) ;
            for(int i=0; i<linesInfo.size(); i++)
                data.col(linesInfo[i].idxInDataMatrix).copyTo(t.col(i)) ;
        }
        if(autoFit)  t=t.rowRange(firstDispDataIdx, lastDispDataIdx+1) ;
        normalize(t,dataNor,0,canvas.rows-1-mrgT-mrgB,cv::NORM_MINMAX) ;
        //pthread_mutex_unlock(&mutex) ;

        if(!autoFit) dataNor=dataNor.rowRange(firstDispDataIdx, lastDispDataIdx+1) ;
    }

    // draw on the canvas
    {
        cv::Mat     t = dataNor.t() ;
        double*     p = t.ptr<double>(0) ;
        cv::Point   ps, pe ;
        cv::Scalar  color ;

        for(int i=0; i<linesInfo.size(); i++){
            if(!linesInfo[i].visible) continue ;
            p = t.ptr<double>(i) ;
            color = linesInfo[i].color ;

            ps = cv::Point(0*scale+scale/2+offsetX+mrgL, (bottomBase) ? (canvas.rows-1 - p[0] + offsetY - mrgB) : p[0] + offsetY + mrgT) ;
            for(int j=1; j<t.cols; j++){
                pe = cv::Point(j*scale+scale/2+offsetX+mrgL, (bottomBase) ? (canvas.rows-1 - p[j] + offsetY - mrgB) : p[j] + offsetY + mrgT) ;
                cv::line(canvas, ps, pe, color, 1, cv::LINE_AA) ;
                ps = pe ;
            }
        }
    }

    return 0 ;
}

int lineObj::doZoom(int scale, int baseX)
{
    // baseX should be in [firstDispDataIdx,lastDispDataIdx]
    if(scale == ZOOM_IN) scale = this->scale+1 ;
    else if(scale == ZOOM_OUT) scale = this->scale-1 ;
    if(scale<1) scale=1 ;
    else if(scale>64) scale=64 ;

    switch(baseX){
        case SCALE_X_BASE_ON_LEFT:
            {
                if(firstDispDataIdx<0) firstDispDataIdx = 0 ;

                if(viewableMost){
                    offsetX = 0 ;
                    lastDispDataIdx = GET_MATCHING_LASTDISP_DATA_IDX(firstDispDataIdx) ;
                    firstDispDataIdx = GET_MATCHING_FIRSTDISP_DATA_IDX(lastDispDataIdx) ;
                }else{
                    lastDispDataIdx = GET_MATCHING_LASTDISP_DATA_IDX(firstDispDataIdx) ;
                }
            }
            break ;
        case SCALE_X_BASE_ON_RIGHT:
            {
                if(lastDispDataIdx>data.rows-1) lastDispDataIdx = data.rows - 1 ;

                if(viewableMost){
                    offsetX = 0 ;
                    firstDispDataIdx = GET_MATCHING_FIRSTDISP_DATA_IDX(lastDispDataIdx) ;
                    lastDispDataIdx = GET_MATCHING_LASTDISP_DATA_IDX(firstDispDataIdx) ;
                }else{
                    int _w = (lastDispDataIdx-firstDispDataIdx+1)*this->scale+offsetX ;
                    firstDispDataIdx = lastDispDataIdx+1 - _w/scale - (_w%scale)/(scale/2+1);
                    firstDispDataIdx = firstDispDataIdx > lastDispDataIdx ? lastDispDataIdx : firstDispDataIdx ;
                    firstDispDataIdx = firstDispDataIdx < 0 ? 0 : firstDispDataIdx ;
                    offsetX = _w - (lastDispDataIdx-firstDispDataIdx+1)*scale ;
                }
            }
            break ;
        default:
            {
                if(baseX<0) baseX = 0 ;
                else if(baseX>data.rows-1) baseX = data.rows - 1 ;

                if(viewableMost){
                    offsetX = 0 ;

                    int _w=(baseX-firstDispDataIdx+1)*this->scale+offsetX ;
                    firstDispDataIdx = baseX+1 -_w/scale - (_w%scale)/(scale/2+1) ;
                    if(firstDispDataIdx>baseX) firstDispDataIdx = baseX ;
                    if(firstDispDataIdx<0) firstDispDataIdx = 0 ;

                    lastDispDataIdx = GET_MATCHING_LASTDISP_DATA_IDX(firstDispDataIdx) ;
                    firstDispDataIdx = GET_MATCHING_FIRSTDISP_DATA_IDX(lastDispDataIdx) ;

                }else{
                    int _w=(baseX-firstDispDataIdx+1)*this->scale+offsetX ;
                    firstDispDataIdx = baseX+1 - _w/scale - (_w%scale)/(scale/2+1) ;
                    if(firstDispDataIdx>baseX) firstDispDataIdx = baseX ;
                    if(firstDispDataIdx<0) firstDispDataIdx=0 ;
                    offsetX = _w - (baseX-firstDispDataIdx+1)*scale ;

                    lastDispDataIdx = GET_MATCHING_LASTDISP_DATA_IDX(firstDispDataIdx) ;
                }
            }
            break ;
    }

    // update focus
    if(focus.x>lastDispDataIdx) focus.x=lastDispDataIdx;
    else if(focus.x<firstDispDataIdx) focus.x=firstDispDataIdx ;

    // update scale
    this->scale = scale ;

    //std::cout << "scale="<<this->scale << std::endl ;
    //std::cout << "firstDispDataIdx="<<this->firstDispDataIdx << std::endl ;
    //std::cout << "lastDispDataIdx="<<this->lastDispDataIdx << std::endl ;

    return 0 ;
}

int lineObj::doMoving(int dir, int shift)
{
    assert(canvas.empty()==false && data.empty()==false) ;

    if(dir==MOVING_PAGE_LEFT || dir==MOVING_PAGE_RIGHT) 
        shift *= ((canvas.cols-mrgL-mrgR-offsetX)/scale) ;
    else if(dir==MOVING_HEAD || dir== MOVING_TAIL)
        shift = data.rows ;

    switch(dir){
        case MOVING_LEFT:       // move obg to left
        case MOVING_PAGE_LEFT:
        case MOVING_TAIL:       // move obj to SEE the tail
            offsetX -= scale*shift ;
            if(offsetX>=0){
                ;
            }else if(offsetX<0 && offsetX>-scale){
                offsetX = 0 ;
            }else{
                firstDispDataIdx += -offsetX/scale ;
                if(firstDispDataIdx>=data.rows) firstDispDataIdx=data.rows-1 ;
                offsetX = 0 ;
            }

            lastDispDataIdx = GET_MATCHING_LASTDISP_DATA_IDX(firstDispDataIdx) ;

            if(viewableMost && lastDispDataIdx >= data.rows-1){
                offsetX = 0 ;
                firstDispDataIdx = GET_MATCHING_FIRSTDISP_DATA_IDX(lastDispDataIdx) ;
            }
            break ;

        case MOVING_RIGHT:
        case MOVING_PAGE_RIGHT:
        case MOVING_HEAD:       // move obj to SEE the head
            offsetX += scale*shift ;
            if(firstDispDataIdx>=offsetX/scale){
                firstDispDataIdx -= offsetX/scale ;
                offsetX = 0 ;
            }else{
                offsetX -= firstDispDataIdx*scale ;
                if(offsetX>=canvas.cols-mrgL-mrgR) offsetX=canvas.cols-mrgL-mrgR -1 ;
                firstDispDataIdx = 0 ;
            }

            if(viewableMost && offsetX>0){
                offsetX = 0 ;
                firstDispDataIdx = 0 ;
            }

            lastDispDataIdx = GET_MATCHING_LASTDISP_DATA_IDX(firstDispDataIdx) ;
            break ;

        case MOVING_UP:
            offsetY -= scale*shift ;
            break ;

        case MOVING_DOWN:
            offsetY += scale*shift ;
            break ;

        default:
            ;
            break ;
    }

    printInfo() ;
    return 0 ;
}

int lineObj::doMovingFocus(int dir, int shift)
{
    assert(canvas.empty()==false) ;
    assert(data.empty()==false) ;
    assert(focus.x>=firstDispDataIdx) ;
    assert(focus.x<=lastDispDataIdx) ;

    if(dir==MOVING_PAGE_LEFT || dir==MOVING_PAGE_RIGHT) 
        shift *= ((canvas.cols-mrgL-mrgR-offsetX)/scale) ;
    else if(dir==MOVING_HEAD || dir== MOVING_TAIL)
        shift = data.rows ;

    switch(dir){
        case MOVING_LEFT:
        case MOVING_PAGE_LEFT:
        case MOVING_HEAD:
            if(focus.x-firstDispDataIdx>=shift){
                focus.x -= shift ;
            }else if(focus.x>firstDispDataIdx){
                focus.x = firstDispDataIdx ;
            }else{
                firstDispDataIdx -= shift ;
                doZoom(scale, SCALE_X_BASE_ON_LEFT) ;
                focus.x = firstDispDataIdx ;
            }
            break ;

        case MOVING_RIGHT:
        case MOVING_PAGE_RIGHT:
        case MOVING_TAIL:
            if(lastDispDataIdx-focus.x>=shift){
                focus.x += shift ;
            }else if(lastDispDataIdx>focus.x){
                focus.x = lastDispDataIdx ;
            }else{
                lastDispDataIdx += shift ;
                doZoom(scale, SCALE_X_BASE_ON_RIGHT) ;
                focus.x = lastDispDataIdx ;
            }
            break ;
        default:
            ;
            break ;
    }

    printInfo() ;
    return 0 ;
}

int lineObj::doUpsideDown(void)
{
    return 0 ;
}

int lineObj::doFlip(void)
{
    return 0 ;
}

int lineObj::setData(const cv::Mat& data, void* ptag)
{
    return setData(data, (ptag)? (*((std::vector<int>*)ptag)) : std::vector<int>(0) ) ;
}

int lineObj::setData(const cv::Mat& data, const std::vector<int>& lineSets)
{
    assert(data.rows && data.cols) ;

    struct lineInfo    info ;

    this->data=data ;

    // new lineSets, clear lines info and reset 
    if(lineSets.size()){
        linesInfo.clear() ;
        if(canvas.empty() == false){
            firstDispDataIdx = 0 ;
            lastDispDataIdx = GET_MATCHING_LASTDISP_DATA_IDX(firstDispDataIdx) ;
            focus.x = 0 ;
        }
    }else{
        // update firstDispDataIdx/lastDispDataIdx/focus if the length of new data less than th old one.
        doZoom(scale,SCALE_X_BASE_ON_LEFT) ;
    }

    // set lines info
    for(int i=0; i<lineSets.size(); i++){
        info.idxInDataMatrix = lineSets[i] ;
        info.visible = true ;
        info.color=this->color ;
        linesInfo.push_back(info) ;
    }

    return 0 ;
}

int lineObj::setLineSets(const std::vector<int>& lineSets)
{
    linesInfo.clear() ;

    struct lineInfo info ;
    for(int i=0; i<lineSets.size(); i++){
        info.idxInDataMatrix = lineSets[i] ;
        info.visible = true ;
        info.color=this->color ;
        linesInfo.push_back(info) ;
    }

    if(data.empty()==false && canvas.empty()==false){
        firstDispDataIdx = 0 ;
        lastDispDataIdx = GET_MATCHING_LASTDISP_DATA_IDX(firstDispDataIdx) ;
        focus.x = 0 ;
    }

    return 0 ;
}

int lineObj::setCanvas(cv::Mat& canvas)
{
    bool firstTime = this->canvas.empty() ;

    this->canvas=canvas ;

    if(firstTime && data.empty()==false){
        firstDispDataIdx = 0 ;
        lastDispDataIdx = GET_MATCHING_LASTDISP_DATA_IDX(firstDispDataIdx) ;
        focus.x = 0 ;
    }
    return 0 ;
}

int lineObj::getDispArea(
        int& firstDispDataIdx,
        int& nonuseY1,
        int& lastDispDataIdx, 
        int& nonuseY2
        )
{
    assert(data.empty()==false && canvas.empty()==false) ;

    firstDispDataIdx = this->firstDispDataIdx ;
    lastDispDataIdx = this->lastDispDataIdx ;
    return 0 ;
}

cv::Range lineObj::getDispRange(void)
{
    int dataIdxFistDisp, nonuseY1, dataIdxLastDisp, nonuseY2 ;

    getDispArea(dataIdxFistDisp,nonuseY1,dataIdxLastDisp,nonuseY2) ;
    return cv::Range(dataIdxFistDisp,dataIdxLastDisp+1) ;
}

int lineObj::getData(cv::Mat& reciver, const cv::Range& range)
{
    assert(data.rows && data.cols) ;

    //pthread_mutex_lock(&mutex) ;
    reciver.create(range.size(),linesInfo.size(),data.type()) ;
    for(int i=0; i<linesInfo.size(); i++)
        data(range,cv::Range(i,i+1)).copyTo(reciver.col(i)) ;
    //pthread_mutex_unlock(&mutex) ;

    return 0 ;
}

int lineObj::setFocus(int dataIdx, int nonuse)
{
    assert(dataIdx>=firstDispDataIdx && dataIdx<=lastDispDataIdx) ;

    focus.x=dataIdx;  // do not caculate the postions here
    focus.y=-1 ;
    return 0 ;
}

int lineObj::getFocus(int& x, int& y)
{
    assert(focus.x>=firstDispDataIdx && focus.x<=lastDispDataIdx) ;

    x = (focus.x-firstDispDataIdx)*scale + scale/2 + offsetX + mrgL ;
    y = dataNor.at<double>(focus.x-firstDispDataIdx,headLineIdx) ;

    if(bottomBase) 
        y = canvas.rows-1 - y + offsetY - mrgB ;

    return 0 ;
}

int lineObj::getInfoOnFocus(void* retDataNonsafty)
{
    /* this function returns the actual and normalized data
     * each data of line in lineSet saved as pair<double,double>
     * and all the pair<double,double> included in a vector<pair<double,double> >.
     * as normalize only caculated in function doPaint, 
     * the data maybe INCORRECT before doPaint...
     */
    assert(retDataNonsafty && data.empty()==false && dataNor.empty()==false) ;

    std::vector<std::pair<double,double> >* p= (std::vector<std::pair<double,double> >*)retDataNonsafty ;
    p->clear() ;

    double act, normd ;
    for(int i=0; i<linesInfo.size(); i++){
        act = data.at<double>(focus.x, i) ;   // actual data
        normd = dataNor.at<double>(focus.x-firstDispDataIdx, i) ; // normalized data
        p->push_back(std::pair<double,double>(act,normd)) ;
    }

    return 0 ;
}

idctLine::idctLine(void)
{
    focus.x=-1 ;
    focus.y=-1 ;
    return ;
}

idctLine::idctLine(const cv::Mat& canvas)
    :
    shape(cv::Mat(),canvas)
{
    focus.x=-1 ;
    focus.y=-1 ;
    return ;
}

idctLine& idctLine::operator=(const idctLine& rhs)
{
    if(this==&rhs) return *this ;
    shape::operator=(rhs) ;
    this->focus=rhs.focus ;

    return *this ;
}

int idctLine::doPaint(void)
{
    assert(canvas.channels()==3) ;
    assert(canvas.depth()==CV_8U) ;
    assert(canvas.empty() == false) ;
    assert(focus.x>0 && focus.x<canvas.cols) ;
    assert(focus.y>0 && focus.y<canvas.rows ) ;

    // vertical line
    int b = color.val[0] ;
    int g = color.val[1] ;
    int r = color.val[2] ;
    int row = focus.y ;
    int col = focus.x ;

    for(int i = 0 ; i < canvas.rows; i++) {
        if((i%20)<17){
            canvas.at<cv::Vec3b>(i, col)[0] = b ;
            canvas.at<cv::Vec3b>(i, col)[1] = g ;
            canvas.at<cv::Vec3b>(i, col)[2] = r ;
        }
    }

    // horizantl line
    for(int i = 0; i < canvas.cols; i++){
        if((i%20)<17){
            canvas.at<cv::Vec3b>(row, i)[0] = b ;
            canvas.at<cv::Vec3b>(row, i)[1] = g ;
            canvas.at<cv::Vec3b>(row, i)[2] = r ;
        }
    }

    return 0 ;
}

int idctLine::doZoom(int scale, int baseX)
{
    return 0 ;
}

int idctLine::doMovingFocus(int dir, int lftShift)
{
    return 0 ;
}

int idctLine::doMoving(int dir, int lftShift)
{
    return 0 ;
}

int idctLine::doUpsideDown(void)
{
    return 0 ;
}

int idctLine::doFlip(void)
{
    return 0 ;
}

int idctLine::setCanvas(cv::Mat& canvas)
{
    this->canvas = canvas ;
    return 0 ;
}

int idctLine::setData(const cv::Mat& data, void* tag)
{
    return 0 ;
}

int idctLine::getFocus(int& x, int& y)
{
    x = focus.x ;
    y = focus.y ;
    return 0 ;
}

int idctLine::getDispArea(int& x1, int& y1, int& x2, int& y2)
{
    assert(canvas.empty()==false) ;

    x1 = 0 ;
    y1 = 0 ;
    x2 = canvas.cols-1 ;
    y2 = canvas.rows-1 ;
    return 0 ;
}

int idctLine::setFocus(int x, int y)
{
    focus.x = x ;
    focus.y = y ;
    return 0 ;
}

int idctLine::getInfoOnFocus(void* retData)
{
    return 0 ;
}

view::view(void)
    :
    mrgL(2),
    mrgR(2),
    mrgT(2),
    mrgB(2),
    indicater(),
    indicaterVisble(false),
    shapeIdKeeper(0),
    visible(true),
    autoFit(true),
    name("view"),
    focusedId(NON_SHAPE_ID),
    dataSrcUpdateListener(INVALID_ID),
    keyHandler(defaultKeyHandler),
    shapes(std::vector<struct _shape>(MAX_SHAPE_NUM))
{
    for(int i=0; i<MAX_SHAPE_NUM; i++) shapes[i].id=NON_SHAPE_ID ;
    indicater.setColor(cv::Scalar(127,127,127)) ;
    cv::namedWindow(name) ;
    return ;
}

view::view(
    const cv::Mat& canvas, 
    int(*keyHandler)(char,void*),
    int mrgL, int mrgR, int mrgT, int mrgB)
    :
    canvas(canvas),
    mrgL(mrgL),
    mrgR(mrgR),
    mrgT(mrgT),
    mrgB(mrgB),
    indicater(canvas),
    indicaterVisble(false),
    shapeIdKeeper(0),
    visible(true),
    name("view"),
    autoFit(true),
    focusedId(NON_SHAPE_ID),
    dataSrcUpdateListener(INVALID_ID),
    keyHandler(keyHandler?keyHandler:defaultKeyHandler),
    shapes(std::vector<struct _shape>(MAX_SHAPE_NUM))
{
    for(int i=0; i<MAX_SHAPE_NUM; i++) shapes[i].id=NON_SHAPE_ID ;
    indicater.setColor(cv::Scalar(127,127,127)) ;
    cv::namedWindow(name) ;
    return ;
}

int view::setCanvas(cv::Mat& canvas)
{
    this->canvas = canvas ;

    //set canvas to all shapes
    for(int i=0; i<MAX_SHAPE_NUM; i++){
        if(shapes[i].id != NON_SHAPE_ID)  shapes[i].obj->setCanvas(canvas) ;
    }
    
    //set canvas to idcater
    indicater.setCanvas(canvas) ;
    return 0 ;
}

cv::Mat& view::getCanvas(void)
{
    return canvas ;
}

view::shapeId view::addShape(
    shape&    s
    )
{
    shapeId id ;

    if( (id=assignShapeId()) == NON_SHAPE_ID || shapes[id].id != NON_SHAPE_ID)
        return NON_SHAPE_ID ;

    // set canvas for the shape
    s.setCanvas(canvas) ;
    // update shapes
    shapes[id].id = id ;
    shapes[id].obj = &s ;
    shapes[id].visible = true ;
    // update bindMap
    bindMap[id*MAX_SHAPE_NUM + id]=1 ;
    // update shapeOrders
    shapeOrders.push_front(std::pair<view::shapeId,int>(id,ORDER_NORMAL)) ;

    return id ;
}

int view::rmvShape(shapeId  id)
{
    if(recycleShapeId(id) == NON_SHAPE_ID) return -1 ;

    // update shapes
    shapes[id].id = NON_SHAPE_ID ;
    shapes[id].obj = NULL ;
    shapes[id].visible = false ;

    // update bindMap
    for(int i=0;i<MAX_SHAPE_NUM;i++) bindMap[id*MAX_SHAPE_NUM+i] = 0 ;
    for(int i=0;i<MAX_SHAPE_NUM;i++) bindMap[i*MAX_SHAPE_NUM+id] = 0 ;

    // update focusedId
    if(focusedId == id) focusedId = NON_SHAPE_ID ;

    // update shapeOrders
    for(std::list<std::pair<view::shapeId,int> >::iterator it = shapeOrders.begin();
        it != shapeOrders.end();
        ++it){
        if(it->first == id){
            shapeOrders.erase(it) ;
            break ;
        }
    }

    return 0 ;
}

int view::setShapeVisible(shapeId id, bool visible)
{
    if(shapes[id].id == NON_SHAPE_ID) return -1 ;

    shapes[id].visible = visible ;
    return 0 ;
}

bool view::getShapeVisible(shapeId id)
{
    if(shapes[id].id == NON_SHAPE_ID) return false ;

    return shapes[id].visible ;
}

int view::setFocus(shapeId id)
{
    focusedId = id ;
    return 0 ;
}

int view::setTopMost(shapeId id)
{
    std::list<std::pair<view::shapeId,int> >::iterator it ;
    for(it = shapeOrders.begin() ; it != shapeOrders.end(); ++it){
        if(it->first == id){
            it->second = ORDER_TOPMOST ;
            shapeOrders.erase(it) ;
            shapeOrders.push_front(*it) ;
            return 0 ;
        }
    }
    return -1 ;
}

int view::setBottomMost(shapeId id)
{
    std::list<std::pair<view::shapeId,int> >::iterator it ;
    for(it = shapeOrders.begin() ; it != shapeOrders.end(); ++it){
        if(it->first == id){
            it->second = ORDER_BOTTOMMOST ;
            shapeOrders.erase(it) ;
            shapeOrders.push_front(*it) ;
            return 0 ;
        }
    }
    return -1 ;
}

int view::setFloat(shapeId id)
{
    std::list<std::pair<view::shapeId,int> >::iterator it ;
    for(it = shapeOrders.begin() ; it != shapeOrders.end(); ++it){
        if(it->first == id){
            it->second = ORDER_FLOAT ;
            shapeOrders.erase(it) ;
            shapeOrders.push_front(*it) ;
            return 0 ;
        }
    }
    return -1 ;
}

int view::setToAbove(shapeId A, shapeId B)
{
    if(A==B) return 0 ;

    int count = 0 ;
    std::list<std::pair<view::shapeId,int> >::iterator it, itA, itB ;

    for(it = shapeOrders.begin(); it != shapeOrders.end() ; ++it){
        if(it->first == A){ itA = it ; ++ count ; }
        if(it->first == B){ itB = it ; ++ count ; }
        if(count >=2) break ;
    }

    if(count >=2){
        shapeOrders.erase(itA) ;
        shapeOrders.insert(itB,*itA) ;
        return 0 ;
    }

    return -1 ;
}

int view::setVisible(bool visible)
{
    visible = true ;
    return 0 ;
}

bool view::getVisible(void)
{
    return visible ;
}

int view::setBinding(shapeId sa, shapeId sb)
{
    // if sa binded with a1,a2 and sb binded with b1,b2
    // then, sa will bind with a1,a2,sb,b1,b2
    //       sb will bind with sa,a1,a2,b1,b2
    // stupid code..., need check
    if(sa == sb) return 0 ;

    for(int i=0; i<MAX_SHAPE_NUM; i++){
        if(bindMap[sa*MAX_SHAPE_NUM+i]){
            for( int j=0; j<MAX_SHAPE_NUM; j++){
                if(bindMap[sb*MAX_SHAPE_NUM+j]){
                    bindMap[i*MAX_SHAPE_NUM+j] = 1 ;
                    bindMap[j*MAX_SHAPE_NUM+i] = 1 ;
                }
            }
        }
    }

    return 0 ;
}

view::shapeId view::assignShapeId(void)
{
    if(NON_SHAPE_ID == shapeIdKeeper) return NON_SHAPE_ID ;

    for(int i=0; i<MAX_SHAPE_NUM; i++){
        int j = (shapeIdKeeper+i)%MAX_SHAPE_NUM ;
        if(0 == bindMap[j*MAX_SHAPE_NUM+j]){
            return (shapeIdKeeper = j) ;
        }
    }
    return (shapeIdKeeper = NON_SHAPE_ID) ;
}

view::shapeId view::recycleShapeId(view::shapeId id)
{
    if(shapes[id].id == NON_SHAPE_ID) return NON_SHAPE_ID ;
    if(shapeIdKeeper == NON_SHAPE_ID) shapeIdKeeper = id ;
    return id ;
}

bool view::defaultCompare(
    const std::pair<view::shapeId,int>&a, 
    const std::pair<view::shapeId,int>&b
    )
{
    return (a.second > b.second) ;
}

int view::doOrder(void)
{
    shapeOrders.sort(defaultCompare) ;
    return 0 ;
}

int view::doRefresh(void)
{
    canvas.setTo(0) ;
    if(!visible){
        imshow(name,canvas) ;
        return 0 ;
    }

    // paint shapes
    for(int i=0; i<shapes.size(); i++){
        if(shapes[i].visible){
            shapes[i].obj->doPaint() ;
        }
    }

    // paint indicater
    if(indicaterVisble && focusedId != NON_SHAPE_ID){
        int x,y ;
        shapes[focusedId].obj->getFocus(x,y) ;
        indicater.setFocus(x,y) ;
        indicater.doPaint() ;
    }

    imshow(name,canvas) ;
    return 0 ;
}

int view::doMoving(int dir, int shift)
{
    if(focusedId==NON_SHAPE_ID || shapes[focusedId].id==NON_SHAPE_ID) return -1 ;

    // doMoving on binding shape
    for(int i=0;i<MAX_SHAPE_NUM;i++){
        if(bindMap[focusedId*MAX_SHAPE_NUM+i]) 
            shapes[i].obj->doMoving(dir,shift) ;
    }
    
    return 0 ;
}

int view::doMovingFocus(int dir, int shift)
{
    if(focusedId==NON_SHAPE_ID || shapes[focusedId].id==NON_SHAPE_ID) return -1 ;

    // doMoving on binding shape
    for(int i=0;i<MAX_SHAPE_NUM;i++){
        if(bindMap[focusedId*MAX_SHAPE_NUM+i]) 
            shapes[i].obj->doMovingFocus(dir,shift) ;
    }
    
    return 0 ;
}

int view::doMovingView(int x, int y)
{
    cv::moveWindow(name,x,y) ;
    return 0 ;
}

int view::doZoom(int scale, int baseX)
{
    if(focusedId==NON_SHAPE_ID || shapes[focusedId].id==NON_SHAPE_ID) return -1 ;

    for(int i=0;i<MAX_SHAPE_NUM;i++){
        if(bindMap[focusedId*MAX_SHAPE_NUM+i]) 
            shapes[i].obj->doZoom(scale,baseX) ;
    }
    
    return 0 ;
}

bool view::getAutoFit(void)
{
    return autoFit ;
}

int view::setAutoFit(bool autoFit)
{
    if(focusedId==NON_SHAPE_ID || shapes[focusedId].id==NON_SHAPE_ID) return -1 ;

    this->autoFit = autoFit ;

    // update to each shapes
    for(int i=0;i<MAX_SHAPE_NUM;i++){
        //if(bindMap[focusedId*MAX_SHAPE_NUM+i] && shapes[i].visible) 
        if(bindMap[focusedId*MAX_SHAPE_NUM+i]) 
            shapes[i].obj->setAutoFit(autoFit) ;
    }
    
    return 0 ;
}

void view::dataSrcUpdateCallback(int id, int ntfType, void* tag)
{
    view* pv = (view*)tag ;
    assert(tag && id==pv->dataSrcUpdateListener) ;
    
    switch(ntfType){
        case DS_NTF_TYPE_HOT_DATA_UPDATED:
            pn("view received hot data updated notify") ;
            pv->doRefresh() ;
            break ;
        default:
            break ;
    }

    return ;
}

int view::assignDataSrcUpdateListener(dataSource& ds)
{
    dataSrcUpdateListener = ds.regNotify(dataSrcUpdateCallback,this) ;
    assert(dataSrcUpdateListener != INVALID_ID) ;
    return 0 ;
}

int view::defaultKeyHandler(char key, void* tag)
{
    assert(tag) ;
    view* pv=(view*)tag ;

    switch(key){
        case '1': case '2': case '3': case '4': case '5':
        case '6': case '7': case '8': case '9':
            pv->doZoom(key-'0',SCALE_X_BASE_ON_RIGHT) ;
            pv->doRefresh() ;
            break ;
        case 'h':
        case 'H':
            if(pv->indicaterVisble)
                pv->doMovingFocus(MOVING_LEFT,key=='h'?1:22) ;
            else
                pv->doMoving(MOVING_LEFT,key=='h'?1:22) ;
            pv->doRefresh() ;
            break ;
        case 'l':
        case 'L':
            if(pv->indicaterVisble)
                pv->doMovingFocus(MOVING_RIGHT,key=='l'?1:22) ;
            else
                pv->doMoving(MOVING_RIGHT,key=='l'?1:22) ;
            pv->doRefresh() ;
            break ;
        case 'j':
        case 'J':
            //pv->doMoving(MOVING_DOWN,key=='j'?1:22) ;
            //pv->doRefresh() ;
            break ;
        case 'k':
        case 'K':
            //pv->doMoving(MOVING_UP,key=='k'?1:22) ;
            //pv->doRefresh() ;
            break ;
        case 'f':
            pv->setAutoFit(!(pv->getAutoFit())) ;
            pv->doRefresh() ;
            break ;
        case '+':
        case '=':
            pv->doZoom(ZOOM_IN,SCALE_X_BASE_ON_RIGHT) ;
            pv->doRefresh() ;
            break ;
        case '-':
            pv->doZoom(ZOOM_OUT,SCALE_X_BASE_ON_RIGHT) ;
            pv->doRefresh() ;
            break ;
        case '0':
            {
                if(pv->indicaterVisble)
                    pv->doMovingFocus(MOVING_PAGE_LEFT, 1) ;
                else
                    pv->doMoving(MOVING_HEAD, 1) ;
            }
            pv->doRefresh() ;
            break ;
        case '$':
            {
                if(pv->indicaterVisble)
                    pv->doMovingFocus(MOVING_PAGE_RIGHT, 1) ;
                else
                    pv->doMoving(MOVING_TAIL, 1) ;
            }
            pv->doRefresh() ;
            break ;
        case 'n':
            static int i = 1 ;
            ((lineObj*)(pv->shapes[0].obj))->headLineIdx=((i++)%4) ;
            pv->doRefresh() ;
            break ;
        case ';':
            pv->indicaterVisble = !(pv->indicaterVisble) ;
            if(pv->indicaterVisble){
                assert(pv->focusedId != NON_SHAPE_ID) ;

                int x1,y1,x2,y2 ;
                for(int i=0; i<MAX_SHAPE_NUM; i++){
                    if(pv->bindMap[pv->focusedId*MAX_SHAPE_NUM+i]){
                        // set all binded shape's focus
                        pv->shapes[i].obj->getDispArea(x1,y1,x2,y2) ;
                        pv->shapes[i].obj->setFocus((x1+x2)/2,(y1+y2)/2) ;

                        // update indicater
                        if(i == pv->focusedId){
                            pv->shapes[i].obj->getFocus(x1,y1) ;
                            pv->indicater.setFocus(x1,y1) ;
                        }
                    }
                }
            }
            pv->doRefresh() ;
            break ;
    }

    return 0 ;
}

int view::setKeyHandler(int (*keyHandler)(char,void*))
{
    this->keyHandler = keyHandler ? keyHandler : defaultKeyHandler ;
    return 0 ;
}

int view::handleKey(char key, void* tag)
{
    return keyHandler(key, tag ? tag : this) ;
}

dataSource::dataSource(const std::string& history, const std::string& hot)
{
    hisFilename = history;
    hotFilename = hot;
    messDataHot = cv::Mat(cv::Mat(0,DATA_TYPE_COUNT_HOT,CV_64F)) ;
    messDataHis = cv::Mat(cv::Mat(0,DATA_TYPE_COUNT_HIS,CV_64F)) ;
    messDataHisFixed = cv::Mat(cv::Mat(0,DATA_TYPE_COUNT_HIS,CV_64F)) ;
    smoothType = SMOOTH_TYPE_TAIL_SEED ;
    status = THREAD_STATUS_STOPPED ;
    pthread_mutex_init(&mutex,0) ;
    pthread_create(&tid, NULL, hotDataUpdater, this) ;
    update(1,1,1,0,1,0) ;
}

void* dataSource::hotDataUpdater(void* tag)
{
    assert(tag!=NULL) ;

    int         sigNum ;
    sigset_t    set ;

    sigemptyset(&set) ;
    sigaddset(&set,SIGUSR1) ;
    sigaddset(&set,SIGUSR2) ;
    sigprocmask(SIG_SETMASK, &set, NULL) ;
    dataSource* pSource = (dataSource*)tag ;

    while(1){
        pn("i am here waiting signal") ;
        sigwait(&set, &sigNum) ;
        pn("i heared something") ;

        if(pSource->status != THREAD_STATUS_STARTED) continue ;
        switch(sigNum){
        case SIGUSR1:
            pn("receive SIGUSR1") ;
            pSource->update(0,0,1,1) ;
            break ;
        case SIGUSR2:
            pn("receive SIGUSR2") ;
            pSource->update(0,1,1,1) ;
            break ;
        default:
            std::cerr << "How did you get here? Go and check you code!" << std::endl ;
            break ;
        }
    }
}

int dataSource::start(void)
{
    pn("start hotData listening"); pn("lock 2") ;
    pthread_mutex_lock(&mutex) ;
    status = THREAD_STATUS_STARTED ;
    pthread_mutex_unlock(&mutex) ;
    pn("unlock 2") ;
    return 0 ;
}

int dataSource::stop(void)
{
    pn("stop hotData listening") ; pn("lock 3") ;
    pthread_mutex_lock(&mutex) ;
    status = THREAD_STATUS_STOPPED ;
    pthread_mutex_unlock(&mutex) ;
    pn("unlock 3") ;
    return 0 ;
}

int dataSource::regNotify(void (*cb)(int, int, void*), void* tag)
{
    assert(cb) ;
    struct notifyInfo  ntf ;

    ntf.id = (notifyHandler.empty()) ? FIRST_VALID_HANDLER_ID : notifyHandler.back().id + 1 ;
    ntf.cb = cb ;
    ntf.tag= tag ;
    notifyHandler.push_back(ntf) ;
    pn("reg notifyer") ;
    std::cerr << notifyHandler.size() << std::endl ;

    return ntf.id ;
}

int dataSource::disNotify(int id)
{
    for(std::vector<struct notifyInfo>::iterator it = notifyHandler.begin();
        it != notifyHandler.end();
        ++ it){
        if(it->id == id){
            notifyHandler.erase(it) ;
            return 0 ;
        }
    }

    return -1 ;
}

int dataSource::connect(shape& s, void* ptag, bool autoTransport)
{
    struct connectInfo  info ;

    info.id  = (connectHandler.empty()) ? FIRST_VALID_HANDLER_ID : connectHandler.back().id + 1 ;
    info.ps  = &s ;
    info.ptag = ptag ;
    connectHandler.push_back(info) ;

    return info.id ;
}

int dataSource::disConnect(int id)
{
    for(std::vector<struct connectInfo>::iterator it = connectHandler.begin();
        it != connectHandler.end();
        ++ it){
        if(it->id == id){
            connectHandler.erase(it) ;
            return 0 ;
        }
    }

    return -1 ;
}

int dataSource::setAutoTransportData(int id, bool autoTransport)
{
    for(int i=0; i<connectHandler.size(); i++){
        if(connectHandler[i].id == id){
            connectHandler[i].autoTransport = autoTransport ;
            return 0 ;
        }
    }

    return -1 ;
}

int dataSource::getAutoTransportData(int id, bool& autoTransport)
{
    for(int i=0; i<connectHandler.size(); i++){
        if(connectHandler[i].id == id){
            autoTransport = connectHandler[i].autoTransport ;
            return 0 ;
        }
    }

    return -1 ;
}

int dataSource::loadHisData(bool forceReload, bool updateWithHotData)
{
    std::stringstream   ss ;
    std::string date, code, name ;
    double cls, hig, low, opn, ystdCls, ampV, ampL, xcg, vol, val ;
    double ttVal, livVal, dealCnt ;
    int    rowCnt ;
    char   line[1024] ;

    pn("loadHisData"); pn("lock 4") ;
    pthread_mutex_lock(&mutex) ;

    std::ifstream   historyIFS ;
    historyIFS.open((hisFilename=="-") ? "/dev/stdin" : hisFilename, std::ifstream::in) ;
    if(!historyIFS){
        std::cerr << "cannot open file " << hisFilename << std::endl ;
        pthread_mutex_unlock(&mutex) ;
        return -1 ;
    }

    // extract history origin data
    if(forceReload) messDataHis.resize(0,cv::Scalar(0)) ;
    if(messDataHis.empty())
    {
        //pn("messDataHis is empty") ;
        rowCnt = 0 ;
        while(historyIFS.getline(line, sizeof(line)-1)){

            if(++rowCnt > MAX_HIS_DATA_ROW){
                std::cerr << "50 years passed. I'm too old to support YOU" << std::endl ;
                break ;
            }

            if(rowCnt > messDataHis.rows){
                messDataHis.resize(messDataHis.rows+5*365*2/3,cv::Scalar(0)) ; // alloc more 5 years buff
                //pn("rowCnt=") ; pn(rowCnt) ;
                //pn("resize messDataHis to") ; pn(messDataHis.rows) ;
            }

            ss.clear() ;
            ss.str(line) ;
            ss >> date >> code >> name >> cls >> hig >> low >> opn >> ystdCls
               >> ampV>> ampL >> xcg >> vol >> val >> ttVal >> livVal >> dealCnt ;

            double* p = messDataHis.ptr<double>(rowCnt-1) ;
            p[DATA_ID_HIS_CLS]     = cls ;
            p[DATA_ID_HIS_CLS]     = cls ;
            p[DATA_ID_HIS_HIG]     = hig ;
            p[DATA_ID_HIS_LOW]     = low ;
            p[DATA_ID_HIS_OPN]     = opn ;
            p[DATA_ID_HIS_YSTDCLS] = ystdCls ;
            p[DATA_ID_HIS_AMPV]    = ampV ;
            p[DATA_ID_HIS_AMPL]    = ampL ;
            p[DATA_ID_HIS_XCG]     = xcg ;
            p[DATA_ID_HIS_VOL]     = vol ;
            p[DATA_ID_HIS_VAL]     = val ;
            p[DATA_ID_HIS_TTVAL]   = ttVal ;
            p[DATA_ID_HIS_LIVVAL]  = livVal ;
            p[DATA_ID_HIS_DEALCNT] = dealCnt ;
            // nonDigital data should be transfored to Digital(double) data
            p[DATA_ID_HIS_DATE]    = stoi(date.substr(0,4))*365+
                                     stoi(date.substr(5,2))*31+
                                     stoi(date.substr(8,2)) ;

            /*
            double* pp = (rowCnt>=2) ? messDataHis.ptr<double>(rowCnt-2) : p ;
            // if no liveVal or xchange data
            if(p[DATA_ID_HIS_LIVVAL]==0 && rowCnt>=2){
                double ttVol = pp[DATA_ID_HIS_LIVVAL]/pp[DATA_ID_HIS_CLS] ;
                p[DATA_ID_HIS_XCG] = (ttVol==0) ? 0 : p[DATA_ID_HIS_VOL]/ttVol*100 ;
                p[DATA_ID_HIS_LIVVAL] = p[DATA_ID_HIS_CLS]*ttVol ;
            }

            // caculate power
            {
                p[DATA_ID_HIS_PWR] = (pp[DATA_ID_HIS_LIVVAL]==0)
                                   ? (p[DATA_ID_HIS_VAL]/pp[DATA_ID_HIS_LIVVAL]-p[DATA_ID_HIS_XCG]/100)*100*100 
                                   : 0 ;
            }
            */

        }
        historyIFS.close() ;
    }else{
        rowCnt = messDataHis.rows ;
    }

    // copy last hot data to history data
    if(updateWithHotData && messDataHot.rows)
    {
        bool needUpdate = false ;

        if(rowCnt == 0){
            messDataHis.resize(rowCnt+1,cv::Scalar(0)) ;
            ++rowCnt ;
            needUpdate = true ;
            //pn("add a new line to his data for last hot data") ;
        }else if( messDataHis.at<double>(rowCnt-1, DATA_ID_HIS_DATE) <
            messDataHot.at<double>(messDataHot.rows-1, DATA_ID_HOT_DATE) ){
            messDataHis.resize(rowCnt+1,cv::Scalar(0)) ;
            ++rowCnt ;
            needUpdate = true ;
            //pn("add a new line to his data for last hot data") ;
        }else if( messDataHis.at<double>(rowCnt-1, DATA_ID_HIS_DATE) ==
            messDataHot.at<double>(messDataHot.rows-1, DATA_ID_HOT_DATE) ){
            messDataHis.row(rowCnt-1).setTo(cv::Scalar(0)) ;
            //pn("clear last line of his data for last hot data") ;
            needUpdate = true ;
        }else{
            // i want goto...
            needUpdate = false ;
        }

        if(needUpdate){
            double* pHis = messDataHis.ptr<double>(rowCnt-1) ;
            double* pHot = messDataHot.ptr<double>(messDataHot.rows-1) ;

            pHis[DATA_ID_HIS_DATE]    = pHot[DATA_ID_HIS_DATE] ;
            pHis[DATA_ID_HIS_CLS]     = pHot[DATA_ID_HIS_CLS] ;
            pHis[DATA_ID_HIS_HIG]     = pHot[DATA_ID_HIS_HIG] ;
            pHis[DATA_ID_HIS_LOW]     = pHot[DATA_ID_HIS_LOW] ;
            pHis[DATA_ID_HIS_OPN]     = pHot[DATA_ID_HIS_OPN] ;
            pHis[DATA_ID_HIS_YSTDCLS] = pHot[DATA_ID_HIS_YSTDCLS] ;
            pHis[DATA_ID_HIS_AMPV]    = pHot[DATA_ID_HIS_AMPV] ;
            pHis[DATA_ID_HIS_AMPL]    = pHot[DATA_ID_HIS_AMPL] ;
            pHis[DATA_ID_HIS_XCG]     = pHot[DATA_ID_HIS_XCG] ;
            pHis[DATA_ID_HIS_VOL]     = pHot[DATA_ID_HIS_VOL] ;
            pHis[DATA_ID_HIS_VAL]     = pHot[DATA_ID_HIS_VAL] ;
            pHis[DATA_ID_HIS_TTVAL]   = pHot[DATA_ID_HIS_TTVAL] ;
            pHis[DATA_ID_HIS_LIVVAL]  = pHot[DATA_ID_HIS_LIVVAL] ;
            pHis[DATA_ID_HIS_DEALCNT] = pHot[DATA_ID_HIS_DEALCNT] ;
            //pn("update last hot data to last his data") ;
        }
    }

    // set to actually size
    assert(rowCnt <= messDataHis.rows) ;
    if(rowCnt < messDataHis.rows) messDataHis.resize(rowCnt) ;
    pn("load origin His data completed, rsize to actually size:") ; pn(messDataHis.rows) ;

    pthread_mutex_unlock(&mutex) ;
    pn("unlock 4") ;
    return 0 ;
}

int dataSource::loadHotData(bool forceReload)
{
    std::stringstream   ss ;
    std::string date, code, name, time ;
    double cls, hig, low, opn, ystdCls, ampV, ampL, xcg, vol, val ;
    double ttVal, livVal, dealCnt ;
    char   line[1024] ;
    int    rowCnt ;

    pn("loadHotData"); pn("lock 5") ;
    pthread_mutex_lock(&mutex) ;

    // extract hot orign data
    std::ifstream   hotIFS ;
    hotIFS.open(hotFilename, std::ifstream::in) ;
    if(!hotIFS){
        std::cerr << "cannot open file " << hotFilename << std::endl ;
        pthread_mutex_unlock(&mutex) ;
        return -1 ;
    }

    if(messDataHot.empty()) messDataHot.reserve(MAX_HOT_DATA_ROW) ;
    if(forceReload) messDataHot.resize(0,cv::Scalar(0)) ;
    //pn("messDataHot.size():") ; pn(messDataHot.size()) ;
    rowCnt = 0 ;

    //pn("start to read HotData") ;
    while(hotIFS.getline(line, sizeof(line)-1)){

        if(++rowCnt > MAX_HOT_DATA_ROW){
            std::cerr << "50 years passed. I'm too old to support YOU" << std::endl ;
            break ;
        }

        //pn(rowCnt) ;
        if(rowCnt <= messDataHot.rows){
            //pn("skip, as it loaded before") ;
            continue;                     // have loaded before
        }
        else{
            messDataHot.resize(messDataHot.rows+1, cv::Scalar(0)) ; // add one more row
            //pn("resize messDataHot to") ;
            //pn(messDataHot.rows) ;
        }

        ss.clear() ;
        ss.str(line) ;
        ss >> date >> code >> name >> cls >> hig >> low >> opn >> ystdCls
           >> ampV>> ampL >> xcg >> vol >> val >> ttVal >> livVal >> dealCnt >> time ;

        double* p = messDataHot.ptr<double>(rowCnt-1) ;
        p[DATA_ID_HOT_CLS]     = cls ;
        p[DATA_ID_HOT_CLS]     = cls ;
        p[DATA_ID_HOT_HIG]     = hig ;
        p[DATA_ID_HOT_LOW]     = low ;
        p[DATA_ID_HOT_OPN]     = opn ;
        p[DATA_ID_HOT_YSTDCLS] = ystdCls ;
        p[DATA_ID_HOT_AMPV]    = ampV ;
        p[DATA_ID_HOT_AMPL]    = ampL ;
        p[DATA_ID_HOT_XCG]     = xcg ;
        p[DATA_ID_HOT_VOL]     = vol ;
        p[DATA_ID_HOT_VAL]     = val ;
        p[DATA_ID_HOT_TTVAL]   = ttVal ;
        p[DATA_ID_HOT_LIVVAL]  = livVal ;
        p[DATA_ID_HOT_DEALCNT] = dealCnt ;
        // nonDigital data should be transfored to Digital(double) data
        p[DATA_ID_HOT_DATE]    = stoi(date.substr(0,4))*365+
                                 stoi(date.substr(5,2))*31+
                                 stoi(date.substr(8,2)) ;
        p[DATA_ID_HOT_TIME]    = stoi(time.substr(0,2))*3600+
                                 stoi(time.substr(3,2))*60+
                                 stoi(time.substr(6,2)) ;
    }

    hotIFS.close() ;
    pthread_mutex_unlock(&mutex) ;
    pn("unlock 5") ;
    return 0 ;
}

int dataSource::smoothData(int smoothType, bool onlyFixHotData)
{
    /* Note
     * this function must be invoked after loadHotData(xx,xx,true)
     */
    double rate ;

    pn("lock 10") ;
    pthread_mutex_lock(&mutex) ;
    if(onlyFixHotData && !messDataHisFixed.empty()){
        // update last hisData to hisDataFixed
        pn("only smooth last hotData") ;

        if(messDataHisFixed.at<double>(messDataHisFixed.rows-1,DATA_ID_HIS_DATE) < messDataHis.at<double>(messDataHot.rows-1,DATA_ID_HIS_DATE)){
            messDataHisFixed.resize(messDataHisFixed.rows+1, cv::Scalar(0)) ;
        }

        // update last hisDataFixed from last hitData (hotData already update to hisData, we need not updat from hotData)
        messDataHisFixed.at<double>(messDataHisFixed.rows-1,DATA_ID_HIS_CLS)     = messDataHis.at<double>(messDataHis.rows-1,DATA_ID_HIS_CLS) ;
        messDataHisFixed.at<double>(messDataHisFixed.rows-1,DATA_ID_HIS_HIG)     = messDataHis.at<double>(messDataHis.rows-1,DATA_ID_HIS_HIG) ;
        messDataHisFixed.at<double>(messDataHisFixed.rows-1,DATA_ID_HIS_LOW)     = messDataHis.at<double>(messDataHis.rows-1,DATA_ID_HIS_LOW) ;
        messDataHisFixed.at<double>(messDataHisFixed.rows-1,DATA_ID_HIS_OPN)     = messDataHis.at<double>(messDataHis.rows-1,DATA_ID_HIS_OPN) ;
        messDataHisFixed.at<double>(messDataHisFixed.rows-1,DATA_ID_HIS_YSTDCLS) = messDataHis.at<double>(messDataHis.rows-1,DATA_ID_HIS_YSTDCLS) ;
        messDataHisFixed.at<double>(messDataHisFixed.rows-1,DATA_ID_HIS_VOL)     = messDataHis.at<double>(messDataHis.rows-1,DATA_ID_HIS_VOL) ;

        if(smoothType == SMOOTH_TYPE_HEAD_SEED){
            pn("do smooth with HEAD SEED") ;
            rate = messDataHisFixed.at<double>(messDataHisFixed.rows-2,DATA_ID_HIS_CLS) / 
                   messDataHisFixed.at<double>(messDataHisFixed.rows-1,DATA_ID_HIS_YSTDCLS) ;
            if(rate != 1){
                messDataHisFixed.at<double>(messDataHisFixed.rows-1,DATA_ID_HIS_CLS) *= rate ;
                messDataHisFixed.at<double>(messDataHisFixed.rows-1,DATA_ID_HIS_HIG) *= rate ;
                messDataHisFixed.at<double>(messDataHisFixed.rows-1,DATA_ID_HIS_LOW) *= rate ;
                messDataHisFixed.at<double>(messDataHisFixed.rows-1,DATA_ID_HIS_OPN) *= rate ;
                messDataHisFixed.at<double>(messDataHisFixed.rows-1,DATA_ID_HIS_YSTDCLS) *= rate ;
                messDataHisFixed.at<double>(messDataHisFixed.rows-1,DATA_ID_HIS_VOL) /= rate ;
            }
        }else if(smoothType == SMOOTH_TYPE_TAIL_SEED){
            pn("do smooth with TAIL SEED") ;
            rate = messDataHisFixed.at<double>(messDataHisFixed.rows-1,DATA_ID_HIS_YSTDCLS) /
                   messDataHisFixed.at<double>(messDataHisFixed.rows-2,DATA_ID_HIS_CLS) ;
            if(rate != 1){
                for(int i=0; i<messDataHisFixed.rows-1; i++){
                    messDataHisFixed.at<double>(i,DATA_ID_HIS_CLS) *= rate ;
                    messDataHisFixed.at<double>(i,DATA_ID_HIS_HIG) *= rate ;
                    messDataHisFixed.at<double>(i,DATA_ID_HIS_LOW) *= rate ;
                    messDataHisFixed.at<double>(i,DATA_ID_HIS_OPN) *= rate ;
                    messDataHisFixed.at<double>(i,DATA_ID_HIS_YSTDCLS) *= rate ;
                    messDataHisFixed.at<double>(i,DATA_ID_HIS_VOL) /= rate ;
                }
            }
        }else{
            pn("do smooth with DEFAULT") ;
            ;
        }

    }else{
        // update whole hisData to hisDataFixed
        //pn("smooth whole hisDataFixed") ;

        int step ;
        int curDataIdx, curSeedIdx, prvSeedIdx ;
        double  curSeed, prvSeed ;

        messDataHis.copyTo(messDataHisFixed) ;

        if(smoothType == SMOOTH_TYPE_DEFAULT){
            // do nothing
            ;
        }else{
            if(smoothType == SMOOTH_TYPE_HEAD_SEED){
                step = 1 ;
                curDataIdx = 1 ;
                curSeedIdx = DATA_ID_HIS_YSTDCLS ;
                prvSeedIdx = DATA_ID_HIS_CLS ;
            }else{
                step = -1 ;
                curDataIdx = messDataHisFixed.rows-2 ;
                curSeedIdx = DATA_ID_HIS_CLS ;
                prvSeedIdx = DATA_ID_HIS_YSTDCLS ;
            }

            for(int i=0; i<messDataHisFixed.rows-1; i++){
                prvSeed = messDataHisFixed.at<double>(curDataIdx-step, prvSeedIdx) ;
                curSeed = messDataHisFixed.at<double>(curDataIdx, curSeedIdx) ;
                rate = prvSeed/curSeed ;
                //pn("curDataIdx="); pn(curDataIdx) ;
                //pn("rate="); pn(prvSeed); pn(curSeed); pn(rate) ;
                if(rate != 1){
                    messDataHisFixed.at<double>(curDataIdx,DATA_ID_HIS_CLS) *= rate ;
                    messDataHisFixed.at<double>(curDataIdx,DATA_ID_HIS_HIG) *= rate ;
                    messDataHisFixed.at<double>(curDataIdx,DATA_ID_HIS_LOW) *= rate ;
                    messDataHisFixed.at<double>(curDataIdx,DATA_ID_HIS_OPN) *= rate ;
                    messDataHisFixed.at<double>(curDataIdx,DATA_ID_HIS_YSTDCLS) *= rate ;
                    messDataHisFixed.at<double>(curDataIdx,DATA_ID_HIS_VOL) /= rate ;
                }
                curDataIdx += step ;
            }
        }
    }

    std::cerr << messDataHisFixed.row(0) << std::endl ;
    pthread_mutex_unlock(&mutex) ;
    pn("unlock 10") ;
    return 0 ;
}

int dataSource::update(
    bool forceReloadHisData, 
    bool forceReloadHotData, 
    bool updateLastHisItemWithHot,
    bool onlyFixHotData,
    bool doTransportData,
    bool doUpdateNotify)
{
    loadHotData(forceReloadHotData) ;
    loadHisData(forceReloadHisData, updateLastHisItemWithHot) ;
    smoothData(smoothType,onlyFixHotData) ;
    if(doTransportData) transportData() ;
    if(doUpdateNotify) updateNotify() ;

    return 0 ;
}

int dataSource::updateNotify(void)
{
    pn("updateNotify"); pn("lock 7") ;
    pthread_mutex_lock(&mutex) ;
    p(" notify size=") ;p(notifyHandler.size()) ; p("  id="); std::cerr << notifyHandler[0].id << std::endl ;
    for(int i=0; i<notifyHandler.size(); i++){
        notifyHandler[i].cb(
            notifyHandler[i].id,
            DS_NTF_TYPE_HOT_DATA_UPDATED,
            notifyHandler[i].tag) ;
    }
    pthread_mutex_unlock(&mutex) ;
    pn("unlock 7") ;
    
    return 0 ;
}

int dataSource::transportData(int id)
{
    int i ;
    pn("transportData"); pn("lock 8") ;
    pthread_mutex_lock(&mutex) ;
    for(i=0; i<connectHandler.size(); i++){
        if(connectHandler[i].id == id){
            connectHandler[i].ps->setData(messDataHisFixed,NULL) ;
            break ;
        }
    }
    pthread_mutex_unlock(&mutex) ;
    pn("unlock 8") ;

    assert (i<connectHandler.size()) ;
    return 0 ;
}

int dataSource::transportData(void)
{
    pn("transportData"); pn("lock 8") ;
    pthread_mutex_lock(&mutex) ;
    for(int i=0; i<connectHandler.size(); i++)
        connectHandler[i].ps->setData(messDataHisFixed,NULL) ;
    pthread_mutex_unlock(&mutex) ;
    pn("unlock 8") ;

    return 0 ;
}

