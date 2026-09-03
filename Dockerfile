FROM alpine:3.22

ARG ZIGER_BINARY
COPY ${ZIGER_BINARY} /usr/local/bin/ziger

RUN mkdir -p /share /store && chown -R 65532:65532 /share /store

EXPOSE 8888
VOLUME ["/share", "/store"]

ENTRYPOINT ["/usr/local/bin/ziger"]
