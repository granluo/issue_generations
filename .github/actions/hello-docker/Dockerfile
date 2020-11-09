FROM alpine:3.11
RUN apt-get update -y
RUN apt-get install -y nginx git python-setuptools python-dev
RUN easy_install pip

COPY entrypoint.sh /entrypoint.sh
COPY test.py /test.py

ENTRYPOINT [ "/entrypoint.sh" ]
