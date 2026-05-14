FROM ubuntu:24.04

RUN apt-get update && apt-get install -y --no-install-recommends \
    cmake \
    g++ \
    make \
    ninja-build \
    python3 \
    python3-pip \
    && rm -rf /var/lib/apt/lists/*

RUN pip3 install --break-system-packages BobBuildTool==1.1.0

USER ubuntu
WORKDIR /build
