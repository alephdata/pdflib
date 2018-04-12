from libcpp cimport bool
from libcpp.string cimport string
from cpython cimport bool as PyBool

ctypedef bool GBool


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


cdef extern from "poppler/PDFDoc.h":
    cdef cppclass PDFDoc:
        int getNumPages()
        void displayPage(OutputDev *out, int page,
           double hDPI, double vDPI, int rotate,
           GBool useMediaBox, GBool crop, GBool printing,
           GBool (*abortCheckCbk)(void *data) = NULL,
           void *abortCheckCbkData = NULL,
            GBool (*annotDisplayDecideCbk)(Annot *annot, void *user_data) = NULL,
            void *annotDisplayDecideCbkData = NULL, GBool copyXRef = False)
        void displayPages(OutputDev *out, int firstPage, int lastPage,
            double hDPI, double vDPI, int rotate,
            GBool useMediaBox, GBool crop, GBool printing,
            GBool (*abortCheckCbk)(void *data) = NULL,
            void *abortCheckCbkData = NULL,
            GBool (*annotDisplayDecideCbk)(Annot *annot, void *user_data) = NULL,
            void *annotDisplayDecideCbkData = NULL)
        double getPageMediaWidth(int page)
        double getPageMediaHeight(int page)
        GooString *readMetadata()


cdef extern from "poppler/PDFDocFactory.h":
    cdef cppclass PDFDocFactory:
        PDFDocFactory()
        PDFDoc *createPDFDoc(const GooString &uri, GooString *ownerPassword = NULL,
                             GooString *userPassword = NULL, void *guiDataA = NULL)


cdef extern from "poppler/TextOutputDev.h":
    cdef cppclass TextOutputDev:
        TextOutputDev(char *fileName, GBool physLayoutA, double fixedPitchA,
        GBool rawOrderA, GBool append)
        TextPage *takeText()
        
    cdef cppclass TextPage:
        void incRefCnt()
        void decRefCnt()


cdef extern from "utils/ImageOutputDev.h":
    cdef cppclass ImageOutputDev:
        ImageOutputDev(char *fileRootA, GBool pageNamesA, GBool dumpJPEGA)
        void enablePNG(GBool png)
        void enableTiff(GBool tiff)
        void enableJpeg(GBool jpeg)
        void enableJpeg2000(GBool jp2)
        void enableJBig2(GBool jbig2)
        void enableCCITT(GBool ccitt)


cdef double RESOLUTION=72.0


cdef class Document:
    cdef: 
        PDFDoc *_doc
        int _pg
        PyBool phys_layout
        double fixed_pitch

    def __cinit__(self, char *fname, PyBool phys_layout=False, double fixed_pitch=0):
        cdef ImageOutputDev *imgOut
        self._doc=PDFDocFactory().createPDFDoc(GooString(fname))
        self._pg=0
        self.phys_layout=phys_layout
        self.fixed_pitch=fixed_pitch
        
    def __dealloc__(self):
        if self._doc != NULL:
            del self._doc

    property no_of_pages:
        def __get__(self):
            return self._doc.getNumPages()  

    cdef void render_page(self, int page_no, OutputDev *dev):
        self._doc.displayPage(dev, page_no, RESOLUTION, RESOLUTION, 0, True, False, False)
     
    cdef object get_page_size(self, page_no):
            cdef double w,h
            w=self._doc.getPageMediaWidth(page_no)
            h= self._doc.getPageMediaHeight(page_no)
            return (w,h)

    def __iter__(self):
        return self

    def get_page(self, int pg):
        return Page(pg, self)

    def __next__(self):
        if self._pg >= self.no_of_pages:
            raise StopIteration()
        self._pg+=1
        return self.get_page(self._pg)

    def extract_images(self):
        firstPage = 1
        lastPage = self.no_of_pages
        imgOut = new ImageOutputDev("images/", False, False)
        imgOut.enablePNG(True)
        imgOut.enableTiff(True)
        imgOut.enableJpeg(True)
        imgOut.enableJpeg2000(True)
        imgOut.enableJBig2(True)
        imgOut.enableCCITT(True)
        self._doc.displayPages(
            <OutputDev*> imgOut, firstPage, lastPage, 72, 72, 0, True, False, False
        )
        del imgOut

    property metadata:
        def __get__(self):
            data = self._doc.readMetadata()
            return data.getCString().decode('UTF-8', 'replace')


cdef class Page:
    cdef:
        int page_no
        TextPage *page
        Document doc

    def __cinit__(self, int page_no, Document doc):
        cdef TextOutputDev *dev
        self.page_no=page_no
        dev = new TextOutputDev(NULL, doc.phys_layout, doc.fixed_pitch, False, False);
        doc.render_page(page_no, <OutputDev*> dev)
        self.page= dev.takeText()
        del dev
        self.doc=doc

    def __dealloc__(self):
        if self.page != NULL:
            self.page.decRefCnt()

    property page_no:
        def __get__(self):
            return self.page_no
        
    property size:
        """Size of page as (width, height)"""
        def __get__(self):
            return self.doc.get_page_size(self.page_no)
