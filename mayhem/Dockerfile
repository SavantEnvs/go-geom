FROM golang:1.21 AS builder

ENV GOTOOLCHAIN=auto

ADD . /go-geom
WORKDIR /go-geom

RUN go test -c -fuzz=FuzzWkb -o /go-geom-encoding-wkb-fuzz ./encoding/wkb

FROM ubuntu:22.04
COPY --from=builder /go-geom-encoding-wkb-fuzz /
