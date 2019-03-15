FROM ubuntu:18.04

ARG FIXBUF
ARG YAF
ARG SILK
ARG SILKDATADIR
ARG SILKY_PORT

ENV FIXBUF ${FIXBUF:-2.2.0}
ENV YAF ${YAF:-2.10.0}
ENV SILK ${SILK:-3.18.0}
ENV SILKDATADIR ${SILKDATADIR:-/data}
ENV SILKY_PORT ${SILKY_PORT:-3000}

# Normally we would clean out the apt cache here, but the node installation (who needs wget to run) updates
# the cache once again later on.
RUN apt-get update \
    && apt-get -y upgrade \
    && apt-get -y install libgnutls28-dev doxygen libglib2.0-dev libpcap-dev python-dev build-essential wget git

WORKDIR /usr/local/src/

# Create SiLK's data directory (just the empty directory; will be bind mounted read-only when running the image)
RUN test -d ${SILKDATADIR} || mkdir -p ${SILKDATADIR}

RUN export BASEDIR=$(pwd); \
    test -e libfixbuf-${FIXBUF}.tar.gz || wget https://tools.netsa.cert.org/releases/libfixbuf-${FIXBUF}.tar.gz; \
    test -e yaf-${YAF}.tar.gz || wget https://tools.netsa.cert.org/releases/yaf-${YAF}.tar.gz; \
    test -e silk-${SILK}.tar.gz || wget https://tools.netsa.cert.org/releases/silk-${SILK}.tar.gz; \
    test -d libfixbuf-${FIXBUF} || tar zxvf libfixbuf-${FIXBUF}.tar.gz; \
    test -d yaf-${YAF} || tar zxvf yaf-${YAF}.tar.gz; \
    test -d silk-${SILK} || tar zxvf silk-${SILK}.tar.gz; \
    cd ${BASEDIR}/libfixbuf-${FIXBUF}/ && ./configure && make && make install && ldconfig && \
    cd ${BASEDIR}/yaf-${YAF}/ && ./configure --enable-localtime --enable-applabel --enable-entropy && make && make install && ldconfig && \
    cd ${BASEDIR}/silk-${SILK} && ./configure --with-libfixbuf=/usr/local/lib/pkgconfig/ --with-python --enable-ipv6 --enable-localtime --enable-data-rootdir=${SILKDATADIR} && make && make install && ldconfig && \
    rm -rf ${BASEDIR}/libfixbuf-${FIXBUF} ${BASEDIR}/yaf-${YAF} ${BASEDIR}/silk-${SILK}

# The nodesource setup script runs apt-get update for us, so we'd have to clean out the lists again
# @angular/cli is for installing the 'ng' binary, used to build Silky.
RUN wget -qO- https://deb.nodesource.com/setup_11.x | bash - \
    && apt-get install -y nodejs \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && npm install -g @angular/cli

EXPOSE ${SILKY_PORT}/tcp

# services.js accepts the SILKY_PORT env variable for its listening TCP port
RUN git clone https://github.com/dhoelzer/Silky.git \
    && cd Silky && npm install --save \
    && ng build --prod

# Comment out the line below if you want to start the container with a shell
# Otherwise the container will start Silky on boot
ENTRYPOINT ["node", "/usr/local/src/Silky/service.js"]

