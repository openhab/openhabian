FROM minimum2scp/systemd-buster
#FROM minimum2scp/systemd-stretch
#FROM balenalib/intel-nuc-debian-node:latest-buster

RUN apt-get update && apt-get install -y git locales python3 python3-pip jq
RUN git clone https://github.com/bats-core/bats-core.git && \
    cd bats-core && \
    ./install.sh /usr/local
RUN adduser openhabian --gecos "Openhabian,,," --disabled-password
RUN echo "openhabian:openhabian" | chpasswd   
RUN /bin/echo -n "Running on " && /usr/bin/arch

COPY . /opt/openhabian/
COPY openhabian.conf.dist /etc/openhabian.conf
RUN sed -i 's#repositoryurl=https://github.com/openhab/openhabian.git#repositoryurl=https://github.com/mstormi/openhabian.git#' /etc/openhabian.conf
RUN sed -i 's#branch=master#branch=buildfixes#' /etc/openhabian.conf

WORKDIR /opt/openhabian/

