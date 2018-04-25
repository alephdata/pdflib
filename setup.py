#!/usr/bin/env python
from __future__ import print_function

import os
import sys

from setuptools import Extension, setup

try:
    from Cython.Build import cythonize
    from Cython.Distutils import build_ext
except ImportError:
    print('You need to install cython first - pip install cython',
          file=sys.stderr)
    sys.exit(1)


POPPLER_ROOT = os.environ.get('POPPLER_ROOT', '')
if not POPPLER_ROOT:
    print('Please clone and compile poppler from source and set POPPLER_ROOT '
          'environment variable. See README for more info.', file=sys.stderr)
    sys.exit(1)

if sys.platform == 'darwin':
    # OS X extras
    extra_compile_args = [
        "-std=c++11", "-stdlib=libc++", "-mmacosx-version-min=10.7"
    ]
else:
    extra_compile_args = ["-std=c++11"]

POPPLER_CPP_LIB_DIR = os.path.join(POPPLER_ROOT, 'cpp/')
POPPLER_UTILS_DIR = os.path.join(POPPLER_ROOT, 'utils/')
poppler_ext = Extension('pdflib.poppler',
                        ['pdflib/poppler.pyx',
                         os.path.join(POPPLER_UTILS_DIR, 'ImageOutputDev.cc')],
                        language='c++',
                        extra_compile_args=extra_compile_args,
                        include_dirs=[
                            POPPLER_ROOT, os.path.join(POPPLER_ROOT, 'poppler')
                        ],
                        library_dirs=[POPPLER_ROOT, POPPLER_CPP_LIB_DIR],
                        libraries=['poppler', 'poppler-cpp'])

setup(
    name='pdflib',
    version='0.1.2',
    description="python bindings for poppler",
    install_requires=['cython', 'lxml'],
    packages=['pdflib'],
    ext_modules=cythonize([poppler_ext]),
    zip_safe=False,
    cmdclass={'build_ext': build_ext},
)
