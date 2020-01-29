FROM debian:bullseye-slim

# based on https://github.com/ffeldhaus/docker-wireshark

ARG DEBIAN_FRONTEND=noninteractive

ENV BUILD_DEPS build-essential zlib1g-dev liblz4-dev libssl-dev libsasl2-dev python cmake libcurl4-openssl-dev pkg-config libsystemd-dev libglvnd-dev
ENV RUN_DEPS software-properties-common python3-xpra xpra xauth xpra-html5 websockify

ENV WIRESHARK_VERSION "3.2.1"
ENV WIRESHARK_NAME "wireshark"
ENV WIRESHARK_DOWNLOAD_URL "https://1.eu.dl.wireshark.org/src/all-versions/${WIRESHARK_NAME}-${WIRESHARK_VERSION}.tar.xz"

# install dependencies
RUN apt-get update && \
    apt-get install gnupg curl wget unzip -y ; \
    \
    echo "####### add repository to install Xpra and make Wireshark available via websocket" ; \
    curl -s "http://xpra.org/gpg.asc" | apt-key add - ; \
    echo "deb http://xpra.org/ bullseye main" >> /etc/apt/sources.list.d/xpra.list ; \
    \
    apt-get update ; \
    apt-get install -y --no-install-recommends $BUILD_DEPS $RUN_DEPS ; \
    \
    echo "####### Download Wireshark sources and build dependencies" ; \
    mkdir -p "/tmp/${WIRESHARK_NAME}-src" && \
    wget -q -O "/tmp/${WIRESHARK_NAME}-src/${WIRESHARK_NAME}-${WIRESHARK_VERSION}.tar.xz" "${WIRESHARK_DOWNLOAD_URL}" ; \
    cd "/tmp/${WIRESHARK_NAME}-src" && \
    tar -xJvf "${WIRESHARK_NAME}-${WIRESHARK_VERSION}.tar.xz" ; \
    /tmp/${WIRESHARK_NAME}-src/${WIRESHARK_NAME}-${WIRESHARK_VERSION}/tools/./debian-setup.sh -y --install-optional; \
    \
    echo "####### Build Wireshark from sources" ; \
    mkdir -p "/tmp/${WIRESHARK_NAME}-build" && \
    cd "/tmp/${WIRESHARK_NAME}-build" && \
    cmake "/tmp/${WIRESHARK_NAME}-src/${WIRESHARK_NAME}-${WIRESHARK_VERSION}" ; \
    cd "/tmp/${WIRESHARK_NAME}-build" && \
    make ; \
    cd "/tmp/${WIRESHARK_NAME}-build" && \
    make install ; \
    \
    echo "###### Cleanup" ; \
    cd / ; \
    rm -rf "/tmp/${WIRESHARK_NAME}-build" ; \
    rm -rf "/tmp/${WIRESHARK_NAME}-src" ; \
    apt-get purge -y --auto-remove $BUILD_DEPS ; \
    apt-get clean -y ; \
    apt-get autoclean -y ; \
    rm /var/log/dpkg.log /var/log/alternatives.log /var/log/apt/*.log ; \
    rm -rf /var/lib/apt/lists/* ;

# allow non-root users to capture network traffic
RUN setcap 'CAP_NET_RAW+eip CAP_NET_ADMIN+eip' /usr/local/bin/dumpcap

# ensure that wireshark is using text mode for best display quality in HTML5 client
RUN echo -e "\nclass-instance:wireshark=text" >> /usr/share/xpra/content-type/50_class.conf

# copy xpra config file
COPY ./xpra.conf /etc/xpra/xpra.conf

# use docker-entrypoint.sh to allow passing options to xpra and start xpra from bash
COPY docker-entrypoint.sh /docker-entrypoint.sh
ENTRYPOINT ["/docker-entrypoint.sh"]

# create run directory for xpra socket and set correct permissions
RUN mkdir -p /run/user/1000/xpra
RUN chown -R 1000 /run/user/1000

# allow wireshark user to read default certificate
RUN chmod 644 /etc/xpra/ssl-cert.pem

# add wireshark user
RUN useradd --create-home --shell /bin/bash wireshark --groups xpra --uid 1000
USER wireshark
WORKDIR /home/wireshark

# expose xpra default port
EXPOSE 14500

# set default password to access wireshark
ENV XPRA_PW wireshark

# run xpra, options --daemon and --no-printing only work if specified as parameters to xpra start
CMD ["/usr/bin/xpra","start","--daemon=no"]