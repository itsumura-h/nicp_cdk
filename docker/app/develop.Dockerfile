FROM ubuntu:24.04 AS wasi-tools

# prevent timezone dialogue
ENV DEBIAN_FRONTEND=noninteractive

RUN apt update && \
    apt upgrade -y
RUN apt install -y \
        build-essential \
        curl \
        git

# rust
WORKDIR /root
RUN curl https://sh.rustup.rs -sSf | sh -s -- -y
ENV PATH $PATH:/root/.cargo/bin

# build ic-wasi-polyfill
WORKDIR /root
RUN git clone https://github.com/wasm-forge/ic-wasi-polyfill
WORKDIR /root/ic-wasi-polyfill
RUN rustup target add wasm32-wasip1
RUN cargo build --release --target wasm32-wasip1

# wasi2ic
WORKDIR /root
RUN cargo install wasi2ic

# ================================================================================
FROM ubuntu:24.04 AS app

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
# reference: https://github.com/ICPorts-labs/chico/blob/main/examples/HelloWorld/Dockerfile#L32
# reference: https://github.com/dfinity/examples/tree/master/c/reverse
RUN apt install -y lldb lld gcc-multilib

RUN apt autoremove -y

# icp
# https://github.com/dfinity/sdk/releases/latest
WORKDIR /root
RUN curl -OL https://internetcomputer.org/install.sh
RUN chmod +x install.sh
RUN DFXVM_INIT_YES=yes ./install.sh
RUN rm -f install.sh

# wasi
# reference: https://github.com/ICPorts-labs/chico/blob/main/examples/HelloWorld/Dockerfile#L48-L59
# https://github.com/WebAssembly/wasi-sdk/releases/latest
WORKDIR /root
ENV WASI_VERSION="25"
ENV WASI_VERSION_FULL="$WASI_VERSION.0"
RUN curl -L -o wasi-sdk.tar.gz https://github.com/WebAssembly/wasi-sdk/releases/download/wasi-sdk-${WASI_VERSION}/wasi-sdk-${WASI_VERSION_FULL}-x86_64-linux.tar.gz
RUN tar -xzf wasi-sdk.tar.gz
RUN rm wasi-sdk.tar.gz
RUN mv "wasi-sdk-${WASI_VERSION_FULL}-x86_64-linux" ".wasi-sdk"
ENV WASI_SDK_PATH "/root/.wasi-sdk"
RUN echo $WASI_SDK_PATH
ENV PATH $PATH:"${WASI_SDK_PATH}/bin"

# webt
# https://github.com/WebAssembly/wabt
RUN apt install -y wabt

# nim
WORKDIR /root
RUN curl https://nim-lang.org/choosenim/init.sh -o init.sh
RUN sh init.sh -y
RUN rm -f init.sh
ENV PATH $PATH:/root/.nimble/bin

# nimlangserver
# https://github.com/nim-lang/langserver/releases/latest
WORKDIR /root
ARG NIM_LANG_SERVER_VERSION="1.10.2"
RUN curl -o nimlangserver.tar.gz -L https://github.com/nim-lang/langserver/releases/download/v${NIM_LANG_SERVER_VERSION}/nimlangserver-linux-amd64.tar.gz
RUN tar zxf nimlangserver.tar.gz
RUN rm -f nimlangserver.tar.gz
RUN mv nimlangserver /root/.nimble/bin/

# copy from wasi-tools
WORKDIR /root
COPY --from=wasi-tools /root/ic-wasi-polyfill/target/wasm32-wasip1/release/* /root/.ic-wasi-polyfill/
ENV IC_WASI_POLYFILL_PATH "/root/.ic-wasi-polyfill"
COPY --from=wasi-tools /root/.cargo/bin/* /root/.cargo/bin/
ENV PATH $PATH:/root/.cargo/bin

# node
# https://nodejs.org/en/download/prebuilt-binaries
WORKDIR /root
ARG NODE_VERSION=22.17.0
RUN curl -OL https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-x64.tar.xz
RUN tar -xvf node-v${NODE_VERSION}-linux-x64.tar.xz
RUN rm node-v${NODE_VERSION}-linux-x64.tar.xz
RUN mv node-v${NODE_VERSION}-linux-x64 .node
ENV PATH $PATH:/root/.node/bin
# pnpm
RUN curl -fsSL https://get.pnpm.io/install.sh | bash -s -- -y

RUN git config --global --add safe.directory /application
WORKDIR /application
