FROM ubuntu:latest

COPY bingo /usr/local/bin

RUN apt update && adduser --disabled-password nonroot

RUN mkdir -p /opt/bingo && mkdir -p /opt/bongo/logs/2d311402e8/

RUN touch /opt/bongo/logs/2d311402e8/main.log

RUN chown nonroot:nonroot -R /opt/bingo
RUN chown nonroot:nonroot -R /opt/bongo

COPY config.yaml /opt/bingo/

USER nonroot

EXPOSE 15466
VOLUME [ "/opt/bingo", "/opt/bongo/logs/2d311402e8" ]

ENTRYPOINT [ "bingo" ]