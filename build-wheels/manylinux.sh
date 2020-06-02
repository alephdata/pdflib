#!/bin/bash
set -e -x

cd /io/

# Upgrade cmake
yum install -y wget
wget http://www.cmake.org/files/v3.2/cmake-3.2.0.tar.gz --no-check-certificate
tar -zxf cmake-3.2.0.tar.gz
cd cmake-3.2.0
./bootstrap --prefix=/usr
gmake --silent
gmake install
cd ..

# Install dependencies
yum install -y freetype-devel.x86_64 fontconfig-devel.x86_64 libpng-devel.x86_64 libtiff-devel.x86_64 libjpeg-turbo-devel

# Clone and compile poppler
git clone --branch poppler-0.63.0 --depth 1 https://anongit.freedesktop.org/git/poppler/poppler.git poppler_src
cd poppler_src/
cmake -DENABLE_SPLASH=OFF -DENABLE_UTILS=OFF -DENABLE_LIBOPENJPEG=none -DBUILD_GTK_TESTS=OFF .
make --silent
export POPPLER_ROOT=/io/poppler_src/
cd ..

# Set shared library paths
export LD_LIBRARY_PATH="/io/poppler_src/:/io/poppler_src/cpp/:/usr/lib64/:/usr/local/lib"


# install twine
/opt/python/cp37-cp37m/bin/pip install twine
export TWINE=/opt/python/cp37-cp37m/bin/twine

# Compile wheels
for PYBIN in /opt/python/cp3*/bin; do
    "${PYBIN}/pip" install cython
    "${PYBIN}/pip" wheel /io/ -w wheelhouse/
done

ls wheelhouse/

# Bundle external shared libraries into the wheels
for whl in wheelhouse/pdflib*.whl; do
    auditwheel repair "$whl" -w wheelhouse/
done

# Install packages and test
for PYBIN in /opt/python/cp3*/bin/; do
    "${PYBIN}/pip" install pdflib --no-index -f wheelhouse/
    (cd $HOME; "${PYBIN}/python" -c "import pdflib")
    "${PYBIN}/pip" install pytest
    "${PYBIN}/pytest" /io/tests/
done