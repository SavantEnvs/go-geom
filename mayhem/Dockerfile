FROM fuzzers/go-fuzz:1.2.0 as builder

ARG project='go-geom'
ARG fuzzTargetPath='encoding/wkb'
ARG fuzzTarget='go-geom-encoding-wkb-fuzz'

ADD . ${project}
WORKDIR ${project}
RUN GO_ENABLED=0 go-fuzz-build -libfuzzer -o /${fuzzTarget}.a ./${fuzzTargetPath}
RUN clang -fsanitize=fuzzer /${fuzzTarget}.a -o /${fuzzTarget}.libfuzzer

FROM ubuntu:20.04
COPY --from=builder /go-geom-encoding-wkb-fuzz.libfuzzer /
