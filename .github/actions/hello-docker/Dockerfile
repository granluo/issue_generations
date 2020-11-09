FROM alpine:3.11

ENV PYTHONUNBUFFERED=1
RUN apk add --update --no-cache python3 && ln -sf python3 /usr/bin/python
RUN python3 -m ensurepip
RUN pip3 install --no-cache --upgrade pip setuptools

COPY entrypoint.sh /entrypoint.sh
COPY test.py /test.py

ENTRYPOINT [ "/entrypoint.sh" ]
