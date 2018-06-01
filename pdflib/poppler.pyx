from libcpp cimport bool
from libcpp.string cimport string
from cpython cimport bool as PyBool

import os
import sys
from collections import defaultdict
import six
from .utils import xmp_to_dict, parse_datestring


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
        GBool isOk()
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

    cdef cppclass TextLine:
        TextWord *getWords()
        TextLine *getNext()

    cdef cppclass TextWord:
        TextWord *getNext()
        GooString *getText()
        void getCharBBox(int charIdx, double *xMinA, double *yMinA,
           double *xMaxA, double *yMaxA)
        GBool hasSpaceAfter  ()


cdef extern from "utils/ImageOutputDev.h":
    cdef cppclass ImageOutputDev:
        ImageOutputDev(char *fileRootA, GBool pageNamesA, GBool dumpJPEGA)
        void enablePNG(GBool png)
        void enableTiff(GBool tiff)
        void enableJpeg(GBool jpeg)
        void enableJpeg2000(GBool jp2)
        void enableJBig2(GBool jbig2)
        void enableCCITT(GBool ccitt)


cdef double RESOLUTION = 300.0


cdef class Document:
    cdef: 
        PDFDoc *_doc
        ImageOutputDev *imgOut
        int _pg
        PyBool phys_layout
        double fixed_pitch

    def __cinit__(self, object fname, PyBool phys_layout=False,
                  double fixed_pitch=0):
        # Sanity checks
        if not isinstance(fname, (six.binary_type, six.text_type)):
            raise ValueError("Invalid path: " + repr(fname))
        if isinstance(fname, six.binary_type):
            fname = fname.decode(sys.getfilesystemencoding())
        if not os.path.exists(fname) or not os.path.isfile(fname):
            raise IOError("Not a valid file path: " + fname)

        self._doc = PDFDocFactory().createPDFDoc(
            GooString(fname.encode(sys.getfilesystemencoding()))
        )
        if not self._doc.isOk():
            raise IOError("Error opening file: " + fname)

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
            self._pg = 0
            raise StopIteration()
        self._pg += 1
        return self.get_page(self._pg)

    def extract_images(self, path, prefix, first_page=None, last_page=None):
        """Extract images in the document to `path`. Image file names are
        prefixed with `prefix`. `path` is created if it doesn't exist."""
        firstPage = first_page or 1
        lastPage = last_page or self.no_of_pages
        if isinstance(path, six.binary_type):
            path = path.decode(sys.getfilesystemencoding())
        if isinstance(prefix, six.binary_type):
            prefix = prefix.decode(sys.getfilesystemencoding())
        if not os.path.exists(path):
            os.makedirs(path)
        # prevent upward traversal
        prefix = os.path.normpath('/' + prefix).lstrip('/')
        path = os.path.join(path, prefix).encode(sys.getfilesystemencoding())
        imgOut = new ImageOutputDev(path, False, False)
        # export as png
        imgOut.enablePNG(True)
        self._doc.displayPages(
            <OutputDev*> imgOut, firstPage, lastPage, RESOLUTION,
            RESOLUTION, 0, True, False, False
        )
        del imgOut

    property metadata:
        def __get__(self):
            metadata = self._doc.getDocInfo()
            if metadata.isDict():
                mtdt = {}
                for i in range(0, metadata.getDict().getLength()):
                    key = metadata.getDict().getKey(i).lower()
                    val = metadata.getDict().getVal(i)
                    if val.isString():
                        mtdt[key] = val.takeString().getCString().decode(
                            'UTF-8', 'replace'
                        )
                        # is it a date?
                        if 'date' in key and mtdt[key].startswith('D:'):
                            try:
                                mtdt[key] = str(parse_datestring(mtdt[key]))
                            except ValueError:
                                pass
            else:
                mtdt = {}
            return mtdt

    property xmp_metadata:
        def __get__(self):
            metadata = self._doc.readMetadata()
            if metadata:
                return xmp_to_dict(
                    metadata.getCString().decode('UTF-8').strip()
                )
            return defaultdict(dict)


cdef class Page:
    cdef:
        int page_no
        TextPage *page
        Document doc
        TextFlow *curr_flow

    def __cinit__(self, int page_no, Document doc):
        cdef TextOutputDev *dev
        self.page_no = page_no
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
        cdef Flow flow
        if not self.curr_flow:
            raise StopIteration()
        flow = Flow(self)
        self.curr_flow = self.curr_flow.getNext()
        return flow

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
                        lines.append(line.text)
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


cdef class Line:
    cdef:
        TextLine *line
        unicode _text

    def __cinit__(self, Block block):
        self.line = block.curr_line

    def __init__(self, Block block):
        self._text = u''
        self._get_text()

    def _get_text(self):
        cdef:
            TextWord *word
            GooString *string
            list words = []

        word = self.line.getWords()
        while word:
            string = word.getText()
            words.append(string.getCString().decode('UTF-8'))
            del string
            # add space after word if necessary
            if word.hasSpaceAfter():
                words.append(u' ')
            word = word.getNext()
        self._text = u''.join(words)

    property text:
        def __get__(self):
            return self._text
