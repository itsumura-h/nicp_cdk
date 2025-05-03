FROM ubuntu:24.04

# prevent timezone dialogue
ENV DEBIAN_FRONTEND=noninteractive

RUN apt update && \
    apt upgrade -y && \
    apt install -y \
    build-essential \
    libunwind-dev \
    xz-utils \
    ca-certificates \
    vim \
    wget \
    curl \
    git

# LLVM
# 引用: https://github.com/ICPorts-labs/chico/blob/main/examples/HelloWorld/Dockerfile#L32
# 引用 https://github.com/dfinity/examples/tree/master/c/reverse
RUN apt install -y lldb lld gcc-multilib

RUN apt autoremove -y

# icp
# https://github.com/dfinity/sdk/releases/latest
WORKDIR /root
ARG DFX_VERSION="0.25.1"
RUN curl -OL https://internetcomputer.org/install.sh
RUN chmod +x install.sh
ARG DFXVM_INIT_YES="yes"
RUN DFXVM_INIT_YES=$DFXVM_INIT_YES DFX_VERSION=$DFX_VERSION ./install.sh
RUN rm -f install.sh

# wasi
# 引用: https://github.com/ICPorts-labs/chico/blob/main/examples/HelloWorld/Dockerfile#L48-L59
# https://github.com/WebAssembly/wasi-sdk/releases/latest
WORKDIR /root
ENV WASI_VERSION="25"
ENV WASI_VERSION_FULL="$WASI_VERSION.0"
RUN curl -L -o wasi-sdk.tar.gz https://github.com/WebAssembly/wasi-sdk/releases/download/wasi-sdk-${WASI_VERSION}/wasi-sdk-${WASI_VERSION_FULL}-x86_64-linux.tar.gz
RUN tar -xzf wasi-sdk.tar.gz
RUN rm wasi-sdk.tar.gz
ENV WASI_SDK_PATH="/root/wasi-sdk-${WASI_VERSION_FULL}"
ENV PATH $PATH:"${WASI_SDK_PATH}-x86_64-linux/bin"
RUN echo $WASI_SDK_PATH

# webt
# https://github.com/WebAssembly/wabt
RUN apt install -y wabt

# nim
WORKDIR /root
ARG NIM_VERSION="2.2.2"
RUN curl https://nim-lang.org/choosenim/init.sh -o init.sh
RUN sh init.sh -y
RUN rm -f init.sh
ENV PATH $PATH:/root/.nimble/bin
RUN choosenim ${NIM_VERSION}

# nimlangserver
# https://github.com/nim-lang/langserver/releases/latest
WORKDIR /root
ARG NIM_LANG_SERVER_VERSION="1.10.2"
RUN curl -o nimlangserver.tar.gz -L https://github.com/nim-lang/langserver/releases/download/v${NIM_LANG_SERVER_VERSION}/nimlangserver-linux-amd64.tar.gz
RUN tar zxf nimlangserver.tar.gz
RUN rm -f nimlangserver.tar.gz
RUN mv nimlangserver /root/.nimble/bin/

# rust
WORKDIR /root
RUN curl https://sh.rustup.rs -sSf | sh -s -- -y

RUN git config --global --add safe.directory /application
WORKDIR /application
