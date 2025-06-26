FROM ubuntu:24.04

# prevent timezone dialogue
ENV DEBIAN_FRONTEND=noninteractive

RUN apt update && \
    apt upgrade -y
RUN apt install -y \
        build-essential \
        curl \
        git
RUN apt autoremove -y

WORKDIR /root
# node
# https://nodejs.org/en/download/prebuilt-binaries
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

