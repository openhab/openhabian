FROM minimum2scp/systemd-stretch

RUN apt-get update && apt-get install -y git locales
RUN git clone https://github.com/bats-core/bats-core.git && \
    cd bats-core && \
    ./install.sh /usr/local
RUN adduser openhabian --gecos "Openhabian,,," --disabled-password
RUN echo "openhabian:openhabian" | chpasswd   

COPY . /opt/openhabian/

WORKDIR /opt/openhabian/