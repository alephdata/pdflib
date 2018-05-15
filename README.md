pdflib
-------

[![Build Status](https://travis-ci.org/alephdata/pdflib.svg?branch=master)](https://travis-ci.org/alephdata/pdflib)

Python binding for poppler.

## Installation

Using pip: `pip install pdflib`

From source:

- Clone poppler source code and compile it:

```
git clone --branch poppler-0.63.0 --depth 1 https://anongit.freedesktop.org/git/poppler/poppler.git poppler_src
cd poppler_src/
cmake -DENABLE_SPLASH=OFF -DENABLE_UTILS=OFF -DENABLE_LIBOPENJPEG=none .
make
```

- Set `POPPLER_SRC` environment variable

```
export POPPLER_ROOT=/pdflib/poppler_src/
```

- Install cython

```
pip install cython
```

- Build extension

```
python setup.py build_ext --inplace
```

## Usage

```
>>> from pdflib import Document
>>> doc = Document("path/to/file.pdf")
```

Getting metadata

```
>>> print(doc.metadata)
>>> print(doc.xmp_metadata)
```

Getting text content of each page

```
>>> for page in doc:
        print(' \n'.join(page.lines).strip())
```

Getting images from each page

```
>>> for page in doc:
        page.extract_images(path='images', prefix='img')
```

LICENSE
-------
pdflib is available under GPL v3 (poppler is GPL).