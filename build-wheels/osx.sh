#!/bin/bash
set -e -x

# Install dependencies
brew install -y freetype fontconfig libjpeg libjpeg-turbo libpng libtiff

# Clone and compile poppler
git clone --branch poppler-0.63.0 --depth 1 https://anongit.freedesktop.org/git/poppler/poppler.git poppler_src
cd poppler_src/
cmake -DENABLE_SPLASH=OFF -DENABLE_UTILS=OFF -DENABLE_LIBOPENJPEG=none .
make --silent
cd ..