from libcpp cimport bool
from libcpp.string cimport string
from cpython cimport bool as PyBool
from cpython.object cimport Py_EQ, Py_NE

import os

ctypedef bool GBool
DEF PRECISION = 1e-6


cdef extern from "cpp/poppler-version.h" namespace "poppler":
    cdef string version_string()


def poppler_version():
    return version_string()


cdef extern from "poppler/GlobalParams.h":
    GlobalParams *globalParams
    cdef cppclass GlobalParams:
        pass


globalParams = new GlobalParams()


cdef extern from "goo/GooString.h":
    cdef cppclass GooString:
        GooString(const char *sA)
        int getLength()
        char *getCString()
        char getChar(int i)


cdef extern from "poppler/OutputDev.h":
    cdef cppclass OutputDev:
        pass


cdef extern from 'poppler/Annot.h':
    cdef cppclass Annot:
        pass


cdef extern from 'poppler/Dict.h':
    cdef cppclass Dict:
        int getLength()
        char *getKey(int i)
        Object getVal(int i)


cdef extern from 'poppler/Object.h':
    cdef cppclass Object:
        GBool isDict()
        Dict *getDict()
        GBool isString()
        GooString *takeString()


cdef extern from "poppler/PDFDoc.h":
    cdef cppclass PDFDoc:
        int getNumPages()
        void displayPage(
            OutputDev *out, int page,
            double hDPI, double vDPI, int rotate,
            GBool useMediaBox, GBool crop, GBool printing,
            GBool (*abortCheckCbk)(void *data)=NULL,
            void *abortCheckCbkData=NULL,
            GBool (*annotDisplayDecideCbk)(Annot *annot, void *user_data)=NULL,
            void *annotDisplayDecideCbkData=NULL, GBool copyXRef=False
        )
        void displayPages(
            OutputDev *out, int firstPage, int lastPage,
            double hDPI, double vDPI, int rotate,
            GBool useMediaBox, GBool crop, GBool printing,
            GBool (*abortCheckCbk)(void *data)=NULL,
            void *abortCheckCbkData=NULL,
            GBool (*annotDisplayDecideCbk)(Annot *annot, void *user_data)=NULL,
            void *annotDisplayDecideCbkData=NULL
        )
        double getPageMediaWidth(int page)
        double getPageMediaHeight(int page)
        GooString *readMetadata()
        Object getDocInfo()


cdef extern from "poppler/PDFDocFactory.h":
    cdef cppclass PDFDocFactory:
        PDFDocFactory()
        PDFDoc *createPDFDoc(const GooString &uri, GooString *ownerPassword=NULL,
                             GooString *userPassword=NULL, void *guiDataA=NULL)


cdef extern from "poppler/TextOutputDev.h":
    cdef cppclass TextOutputDev:
        TextOutputDev(char *fileName, GBool physLayoutA, double fixedPitchA,
        GBool rawOrderA, GBool append)
        TextPage *takeText()
        
    cdef cppclass TextPage:
        void incRefCnt()
        void decRefCnt()
        TextFlow *getFlows()

    cdef cppclass TextFlow:
        TextFlow *getNext()
        TextBlock *getBlocks()

    cdef cppclass TextBlock:
        TextBlock *getNext()
        TextLine *getLines()
        void getBBox(double *xMinA, double *yMinA, double *xMaxA, double *yMaxA)

    cdef cppclass TextLine:
        TextWord *getWords()
        TextLine *getNext()

    cdef cppclass TextWord:
        TextWord *getNext()
        int getLength()
        GooString *getText()
        void getBBox(double *xMinA, double *yMinA, double *xMaxA, double *yMaxA)
        void getCharBBox(int charIdx, double *xMinA, double *yMinA,
           double *xMaxA, double *yMaxA)
        GBool hasSpaceAfter  ()
        TextFontInfo *getFontInfo(int idx)
        GooString *getFontName(int idx)
        double getFontSize()
        void getColor(double *r, double *g, double *b)

    cdef cppclass TextFontInfo:
        GooString *getFontName()
        double getAscent();
        double getDescent();
        GBool isFixedWidth()
        GBool isSerif()
        GBool isSymbolic()
        GBool isItalic()
        GBool isBold()


cdef extern from "utils/ImageOutputDev.h":
    cdef cppclass ImageOutputDev:
        ImageOutputDev(char *fileRootA, GBool pageNamesA, GBool dumpJPEGA)
        void enablePNG(GBool png)
        void enableTiff(GBool tiff)
        void enableJpeg(GBool jpeg)
        void enableJpeg2000(GBool jp2)
        void enableJBig2(GBool jbig2)
        void enableCCITT(GBool ccitt)


cdef double RESOLUTION = 72.0


cdef class Document:
    cdef: 
        PDFDoc *_doc
        int _pg
        PyBool phys_layout
        double fixed_pitch

    def __cinit__(self, char *fname, PyBool phys_layout=False,
                  double fixed_pitch=0):
        cdef ImageOutputDev *imgOut
        self._doc = PDFDocFactory().createPDFDoc(GooString(fname))
        self._pg = 0
        self.phys_layout = phys_layout
        self.fixed_pitch = fixed_pitch
        
    def __dealloc__(self):
        if self._doc != NULL:
            del self._doc

    property no_of_pages:
        def __get__(self):
            return self._doc.getNumPages()  

    cdef void render_page(self, int page_no, OutputDev *dev):
        self._doc.displayPage(
            dev, page_no, RESOLUTION, RESOLUTION, 0, True, False, False
        )

    cdef object get_page_size(self, page_no):
            cdef double w, h
            w = self._doc.getPageMediaWidth(page_no)
            h = self._doc.getPageMediaHeight(page_no)
            return (w, h)

    def __iter__(self):
        return self

    def get_page(self, int pg):
        return Page(pg, self)

    def __next__(self):
        if self._pg >= self.no_of_pages:
            raise StopIteration()
        self._pg += 1
        return self.get_page(self._pg)

    def extract_images(self, path, prefix, first_page=None, last_page=None):
        """Extract images in the document to `path`. Image file names are
        prefixed with `prefix`. `path` is created if it doesn't exist."""
        firstPage = first_page or 1
        lastPage = last_page or self.no_of_pages
        if not os.path.exists(path):
            os.makedirs(path)
        # prevent upward traversal
        prefix = os.path.normpath('/' + prefix).lstrip('/')
        imgOut = new ImageOutputDev(os.path.join(path, prefix), False, False)
        # export as png
        imgOut.enablePNG(True)
        # imgOut.enableTiff(True)
        # imgOut.enableJpeg(True)
        # imgOut.enableJpeg2000(True)
        # imgOut.enableJBig2(True)
        # imgOut.enableCCITT(True)
        self._doc.displayPages(
            <OutputDev*> imgOut, firstPage, lastPage, 72,
            72, 0, True, False, False
        )
        del imgOut

    property metadata:
        def __get__(self):
            metadata = self._doc.getDocInfo()
            if metadata.isDict():
                mtdt = {}
                for i in range(0, metadata.getDict().getLength()):
                    key = metadata.getDict().getKey(i)
                    val = metadata.getDict().getVal(i)
                    if val.isString():
                        mtdt[key] = val.takeString().getCString().decode(
                            'UTF-8', 'replace'
                        )
            else:
                mtdt = {}
            return mtdt

    property xmp_metadata:
        def __get__(self):
            metadata = self._doc.readMetadata()
            if metadata:
                return metadata.getCString().decode('UTF-8')
            return None


cdef class Page:
    cdef:
        int page_no
        TextPage *page
        Document doc
        TextFlow *curr_flow

    def __cinit__(self, int page_no, Document doc):
        cdef TextOutputDev *dev
        self.page_no=page_no
        dev = new TextOutputDev(NULL, doc.phys_layout, doc.fixed_pitch, False, False)
        doc.render_page(page_no, <OutputDev*> dev)
        self.page = dev.takeText()
        del dev
        self.curr_flow = self.page.getFlows()
        self.doc = doc

    def __dealloc__(self):
        if self.page != NULL:
            self.page.decRefCnt()

    def __iter__(self):
        return self

    def __next__(self):
        cdef Flow f
        if not self.curr_flow:
            raise StopIteration()
        f = Flow(self)
        self.curr_flow = self.curr_flow.getNext()
        return f

    property page_no:
        def __get__(self):
            return self.page_no

    property size:
        """Size of page as (width, height)"""
        def __get__(self):
            return self.doc.get_page_size(self.page_no)

    property lines:
        def __get__(self):
            lines = []
            for flow in self:
                for block in flow:
                    for line in block:
                        lines.append(line.text.encode('UTF-8'))
            return lines

    def extract_images(self, path, prefix):
        self.doc.extract_images(
            path=path, prefix=prefix,
            first_page=self.page_no, last_page=self.page_no
        )


cdef class Flow:
    cdef:
        TextFlow *flow
        TextBlock *curr_block

    def __cinit__(self, Page pg):
        self.flow = pg.curr_flow
        self.curr_block = self.flow.getBlocks()

    def __iter__(self):
        return self

    def __next__(self):
        cdef Block b
        if not self.curr_block:
            raise StopIteration()
        b = Block(self)
        self.curr_block = self.curr_block.getNext()
        return b


cdef class Block:
    cdef:
        TextBlock *block
        TextLine *curr_line

    def __cinit__(self, Flow flow):
        self.block = flow.curr_block
        self.curr_line = self.block.getLines()

    def __iter__(self):
        return self

    def __next__(self):
        cdef Line line
        if not self.curr_line:
            raise StopIteration()
        line = Line(self)
        self.curr_line = self.curr_line.getNext()
        return line

    property bbox:
        def __get__(self):
            cdef double x1, y1, x2, y2
            self.block.getBBox(&x1, &y1, &x2, &y2)
            return  BBox(x1, y1, x2, y2)


cdef class BBox:
    cdef double x1, y1, x2, y2

    def __cinit__(self, double x1, double y1, double x2, double y2 ):
        self.x1 = x1
        self.x2 = x2
        self.y1 = y1
        self.y2 = y2

    def as_tuple(self):
        return self.x1, self.y1, self.x2, self.y2

    def __getitem__(self, i):
        if i == 0:
            return self.x1
        elif i == 1:
            return self.y1
        elif i == 2:
            return self.x2
        elif i == 3:
            return self.y2
        raise IndexError()

    property x1:
        def __get__(self):
            return self.x1
        def __set__(self, double val):
            self.x1 = val

    property x2:
        def __get__(self):
            return self.x2
        def __set__(self, double val):
            self.x2 = val

    property y1:
        def __get__(self):
            return self.y1
        def __set__(self, double val):
            self.y1 = val

    property y2:
        def __get__(self):
            return self.y2
        def __set__(self, double val):
            self.y2 = val


cdef class Line:
    cdef:
        TextLine *line
        double x1, y1, x2, y2
        unicode _text
        list _bboxes

    def __cinit__(self, Block block):
        self.line = block.curr_line

    def __init__(self, Block block):
        self._text=u''  # text bytes
        self.x1 = 0
        self.y1 = 0
        self.x2 = 0
        self.y2 = 0
        self._bboxes = []
        self._get_text()
        assert len(self._text) == len(self._bboxes)

    def _get_text(self):
        cdef:
            TextWord *word
            GooString *string
            double bx1,bx2, by1, by2
            list words = []
            int offset = 0, i, wlen
            BBox last_bbox
            # FontInfo last_font
            double r, g, b

        word = self.line.getWords()
        while word:
            wlen = word.getLength()
            # gets bounding boxes for all characters
            for i in range(wlen):
                word.getCharBBox(i, &bx1, &by1, &bx2, &by2 )
                last_bbox = BBox(bx1,by1,bx2,by2)
                # if previous word is space update it's right end
                if i == 0 and words and words[-1] == u' ':
                    self._bboxes[-1].x2=last_bbox.x1

                self._bboxes.append(last_bbox)
            # and then text as UTF-8 bytes
            string = word.getText()
            words.append(string.getCString().decode('UTF-8')) # decoded to python unicode string
            del string
            #calculate line bbox
            word.getBBox(&bx1, &by1, &bx2, &by2)
            if bx1 < self.x1 or self.x1 == 0:
                self.x1 = bx1
            if by1 < self.y1 or self.y1 == 0:
                self.y1 = by1
            if bx2 > self.x2:
                self.x2 = bx2
            if by2 > self.y2:
                self.y2 = by2
            # add space after word if necessary
            if word.hasSpaceAfter():
                words.append(u' ')
                self._bboxes.append(BBox(last_bbox.x2, last_bbox.y1, last_bbox.x2, last_bbox.y2))
            word = word.getNext()
        self._text= u''.join(words)

    property bbox:
        def __get__(self):
            return BBox(self.x1,self.y1,self.x2,self.y2)

    property text:
        def __get__(self):
            return self._text

    property char_bboxes:
        def __get__(self):
            return self._bboxes
