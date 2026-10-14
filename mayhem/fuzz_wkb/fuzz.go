package fuzz_wkb

import (
	"encoding/binary"
	"fmt"
	"math"
	"os"

	"github.com/twpayne/go-geom"
	"github.com/twpayne/go-geom/encoding/ewkb"
	"github.com/twpayne/go-geom/encoding/wkb"
)

var layouts = []geom.Layout{geom.NoLayout, geom.XY, geom.XYZ, geom.XYM, geom.XYZM}

// buildGeom constructs a geometry from the fuzz input: byte 0 picks the type, byte 1 the layout
// (including NoLayout), the rest is flat coordinates.
func buildGeom(data []byte) geom.T {
	if len(data) < 2 {
		return nil
	}
	layout := layouts[int(data[1])%len(layouts)]
	stride := layout.Stride()
	var flat []float64
	if stride > 0 {
		for rest := data[2:]; len(rest) >= 8 && len(flat) < 64*stride; rest = rest[8:] {
			flat = append(flat, math.Float64frombits(binary.LittleEndian.Uint64(rest)))
		}
		flat = flat[:len(flat)/stride*stride]
	}
	switch data[0] % 8 {
	case 0:
		if len(flat) >= stride {
			flat = flat[:stride]
		}
		return geom.NewPointFlat(layout, flat)
	case 1:
		return geom.NewLineStringFlat(layout, flat)
	case 2:
		return geom.NewPolygonFlat(layout, flat, []int{len(flat)})
	case 3:
		return geom.NewMultiPoint(layout)
	case 4:
		return geom.NewMultiLineString(layout)
	case 5:
		return geom.NewMultiPolygon(layout)
	case 6:
		return geom.NewGeometryCollection()
	default:
		return geom.NewPointEmpty(layout)
	}
}

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

	if g := buildGeom(data); g != nil {
		for _, bo := range []binary.ByteOrder{wkb.NDR, wkb.XDR} {
			_, _ = wkb.Marshal(g, bo)
			_, _ = ewkb.Marshal(g, bo)
		}
	}

	if _, err := wkb.Unmarshal(data); err != nil {
		return 0
	}
	return 1
}
