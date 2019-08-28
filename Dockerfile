FROM minimum2scp/systemd-buster
#FROM minimum2scp/systemd-stretch
#FROM balenalib/intel-nuc-debian-node:latest-buster

RUN apt-get update && apt-get install -y git locales jq
RUN git clone https://github.com/bats-core/bats-core.git && \
    cd bats-core && \
    ./install.sh /usr/local
RUN adduser openhabian --gecos "Openhabian,,," --disabled-password
RUN echo "openhabian:openhabian" | chpasswd   
RUN /bin/echo -n "Running on " && /usr/bin/arch

COPY . /opt/openhabian/

WORKDIR /opt/openhabian/

