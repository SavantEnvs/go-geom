#!/usr/bin/env bash
#
# mayhem/build.sh — build go-geom's go-fuzz WKB harness as a sanitized libFuzzer binary.
set -euo pipefail

[ -n "${SOURCE_DATE_EPOCH:-}" ] || unset SOURCE_DATE_EPOCH

: "${CC:=clang}" ; : "${CXX:=clang++}" ; : "${LIB_FUZZING_ENGINE:=-fsanitize=fuzzer}"
: "${SANITIZER_FLAGS=-fsanitize=address}"
: "${GO_DEBUG_FLAGS:=-g -gdwarf-3}"
: "${STANDALONE_FUZZ_MAIN:=/opt/mayhem/StandaloneFuzzTargetMain.c}"
: "${MAYHEM_JOBS:=$(nproc)}"
export CC CXX LIB_FUZZING_ENGINE SANITIZER_FLAGS GO_DEBUG_FLAGS STANDALONE_FUZZ_MAIN MAYHEM_JOBS
export CGO_CFLAGS="${CGO_CFLAGS:+$CGO_CFLAGS }$GO_DEBUG_FLAGS"
export CGO_CXXFLAGS="${CGO_CXXFLAGS:+$CGO_CXXFLAGS }$GO_DEBUG_FLAGS"

export GOFLAGS="${GOFLAGS:--mod=mod}"
export GOPROXY="${GOPROXY:-file://$(go env GOMODCACHE)/cache/download,https://proxy.golang.org,direct}"

cd "$SRC"
go version

go get github.com/dvyukov/go-fuzz/go-fuzz-dep

TARGET="go-geom-encoding-wkb-fuzz"
HARNESS_DIR="mayhem/fuzz_wkb"

mkdir -p "$SRC/mayhem-build"
echo "=== building $TARGET (go-fuzz-build -libfuzzer) ==="
(
  cd "$SRC/$HARNESS_DIR"
  go-fuzz-build -libfuzzer -o "$SRC/mayhem-build/$TARGET.a"
)

$CXX $SANITIZER_FLAGS $GO_DEBUG_FLAGS $LIB_FUZZING_ENGINE \
  "$SRC/mayhem-build/$TARGET.a" -o "/mayhem/$TARGET"
echo "built /mayhem/$TARGET"

$CC $SANITIZER_FLAGS $GO_DEBUG_FLAGS -c "$STANDALONE_FUZZ_MAIN" -o "$SRC/mayhem-build/standalone_main.o"
$CXX $SANITIZER_FLAGS $GO_DEBUG_FLAGS \
  "$SRC/mayhem-build/standalone_main.o" "$SRC/mayhem-build/$TARGET.a" \
  -o "/mayhem/$TARGET-standalone"
echo "built /mayhem/$TARGET-standalone"

echo "build.sh complete"
