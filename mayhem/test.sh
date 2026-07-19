#!/usr/bin/env bash
#
# mayhem/test.sh — behavioral KAT via the clang-linked fuzz binary (sabotage-sensitive).
#
# go test ./... and a separate `go build` KAT are intentionally NOT the oracle: static Go ELFs ignore
# LD_PRELOAD neutering. Instead we run the libFuzzer binary with a seed that triggers the
# harness KAT path; it writes /dev/shm/go-geom-kat.out. The gate's LD_PRELOAD neuter _exit(0)s non-system
# ELFs before main, so the marker is absent and this script FAILS.
set -uo pipefail
[ -n "${SOURCE_DATE_EPOCH:-}" ] || unset SOURCE_DATE_EPOCH
cd "$SRC"

emit_ctrf() {
  local tool="$1" passed="$2" failed="$3" skipped="${4:-0}" pending="${5:-0}" other="${6:-0}"
  local tests=$(( passed + failed + skipped + pending + other ))
  cat > "${CTRF_REPORT:-$SRC/ctrf-report.json}" <<JSON
{
  "results": {
    "tool": { "name": "$tool" },
    "summary": {
      "tests": $tests,
      "passed": $passed,
      "failed": $failed,
      "pending": $pending,
      "skipped": $skipped,
      "other": $other
    }
  }
}
JSON
  printf 'CTRF {"results":{"tool":{"name":"%s"},"summary":{"tests":%d,"passed":%d,"failed":%d,"pending":%d,"skipped":%d,"other":%d}}}\n' \
    "$tool" "$tests" "$passed" "$failed" "$pending" "$skipped" "$other"
  [ "$failed" -eq 0 ]
}

KAT_SEED="$SRC/mayhem/go-geom-encoding-wkb-fuzz/testsuite/kat"
FUZZ_BIN="/mayhem/go-geom-encoding-wkb-fuzz"

if [ ! -f "$KAT_SEED" ]; then
  echo "missing KAT seed: $KAT_SEED" >&2
  emit_ctrf "go-geom-wkb-kat" 0 1
  exit 1
fi
if [ ! -x "$FUZZ_BIN" ]; then
  echo "missing fuzz binary: $FUZZ_BIN" >&2
  emit_ctrf "go-geom-wkb-kat" 0 1
  exit 1
fi

rm -f /dev/shm/go-geom-kat.out
out="$("$FUZZ_BIN" -runs=1 -max_len=64 -malloc_limit_mb=256 "$KAT_SEED" 2>&1)" || true
kat_out=""
if [ -f /dev/shm/go-geom-kat.out ]; then
  kat_out="$(cat /dev/shm/go-geom-kat.out)"
fi
if ! grep -q 'KAT:point:2' <<< "$kat_out"; then
  echo "KAT failed — expected KAT:point:2 from known WKB point (1,2)" >&2
  echo "fuzz: $out" >&2
  echo "kat: $kat_out" >&2
  emit_ctrf "go-geom-wkb-kat" 0 1
  exit 1
fi

emit_ctrf "go-geom-wkb-kat" 1 0
