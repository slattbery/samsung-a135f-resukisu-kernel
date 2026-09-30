FROM ubuntu:latest

WORKDIR /src

COPY . .

RUN apt install \
    base-devel \
    bc \
    ccache \
    clang \
    llvm \
    lld \
    flex \
    bison \
    cpio \
    perl \
    python \
    git \
    openssl \
    libelf \
    pahole \
    dtc \
    cpio \
    rsync \
    wget \
    unzip \
    zip

CMD ["./build.sh"]
