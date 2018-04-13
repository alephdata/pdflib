#!/bin/bash
set -e -x

cd /pdflib/

# Upgrade cmake
wget http://www.cmake.org/files/v3.2/cmake-3.2.0.tar.gz --no-check-certificate
tar -zxvf cmake-3.2.0.tar.gz
cd cmake-3.2.0
./bootstrap --prefix=/usr
gmake
gmake install
cd ..

# Install dependencies
yum install freetype-devel.x86_64 fontconfig-devel.x86_64 libjpeg-devel.x86_64

# Clone and compile poppler
git clone --branch poppler-0.63.0 --depth 1 https://anongit.freedesktop.org/git/poppler/poppler.git poppler_src
cd poppler_src/
cmake -DENABLE_SPLASH=OFF -DENABLE_UTILS=OFF -DENABLE_LIBOPENJPEG=none .
make
export POPPLER_ROOT=/pdflib/poppler_src/
cd ..

# Set shared library paths
export LD_LIBRARY_PATH="/pdflib/poppler_src/:/pdflib/poppler_src/cpp/:/usr/lib64/"
extra_directories=(/opt/_internal/*/lib/python3.5/site-packages/.libspdflib/)
extra_path=$(printf "%s:" "${extra_directories[@]}")
export LD_LIBRARY_PATH="${extra_path}${LD_LIBRARY_PATH}"

# install twine
/opt/python/cp27-cp27m/bin/pip install twine
export TWINE=/opt/python/cp27-cp27m/bin/twine

# Compile wheels
for PYBIN in /opt/python/*/bin; do
    "${PYBIN}/pip" install cython
    "${PYBIN}/pip" wheel /pdflib/ -w wheelhouse/
done

# Bundle external shared libraries into the wheels
for whl in wheelhouse/*.whl; do
    auditwheel repair "$whl" -w wheelhouse/
done

# Install packages and test
for PYBIN in /opt/python/*/bin/; do
    "${PYBIN}/pip" install python-manylinux-demo --no-index -f wheelhouse/
    (cd "$HOME"; "${PYBIN}/python" -c "import pdflib")
done