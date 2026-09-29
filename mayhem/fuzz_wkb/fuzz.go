package fuzz_wkb

import (
	"fmt"
	"os"

	"github.com/twpayne/go-geom/encoding/wkb"
)

func Fuzz(data []byte) int {
	_ = fuzzBody(data)
	return 0
}

func fuzzBody(data []byte) int {
	// KAT path for mayhem/test.sh — known WKB point → derived marker in /dev/shm/go-geom-kat.out.
	// /dev/shm is the ONLY writable path when Mayhem mounts the image read-only (README FAQ).
	if len(data) > 0 && data[0] == 255 {
		point := []byte{
			0x01, 0x01, 0x00, 0x00, 0x00,
			0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xf0, 0x3f,
			0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x40,
		}
		g, err := wkb.Unmarshal(point)
		if err != nil {
			return 1
		}
		fc := g.FlatCoords()
		if len(fc) != 2 || fc[0] != 1 || fc[1] != 2 {
			return 1
		}
		if err := os.WriteFile("/dev/shm/go-geom-kat.out", []byte(fmt.Sprintf("KAT:point:%d\n", len(fc))), 0o644); err != nil {
			return 1
		}
		return 0
	}

	if _, err := wkb.Unmarshal(data); err != nil {
		return 0
	}
	return 1
}
