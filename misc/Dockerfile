FROM ubuntu:latest

RUN apt-get update

RUN apt-get install -y \
    git \
    curl \
    ripgrep \
    nodejs \
    jq

RUN curl -fsSL https://deb.nodesource.com/setup_lts.x | bash - && \
    apt-get install -y nodejs

RUN apt-get install -y \
    ninja-build \
    gettext \
    cmake \
    g++ \
    pkg-config \
    unzip \
    autoconf \
    automake \
    libtool \
    libtool-bin

RUN git clone --depth=1 https://github.com/neovim/neovim.git && \
    cd neovim && \
    make CMAKE_BUILD_TYPE=Release && \
    make install
