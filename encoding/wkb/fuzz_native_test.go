package wkb

import "testing"

func FuzzWkb(f *testing.F) {
	f.Fuzz(func(t *testing.T, data []byte) {
		_, _ = Unmarshal(data)
	})
}
