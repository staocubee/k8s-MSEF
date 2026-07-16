FROM ubuntu:18.04

RUN apt-get update && \
    apt-get install -y \
        openssl \
        curl \
        wget \
        sudo \
        vim \
        python3 \
        python3-pip

RUN pip3 install \
    flask==1.0 \
    django==2.1 \
    requests==2.18.0

CMD ["bash"]