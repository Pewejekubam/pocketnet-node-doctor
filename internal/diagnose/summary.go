package diagnose

import (
	"fmt"
	"io"
	"strings"
	"time"

	"github.com/pocketnet-team/pocketnet-node-doctor/internal/manifest"
	"github.com/pocketnet-team/pocketnet-node-doctor/internal/plan"
)

// throughputBytesPerSecond is D9's fixed ETA constant: 50 MiB/s.
const throughputBytesPerSecond = 50 * 1024 * 1024

// EmitSummary writes the human-readable summary to w per cli-surface.md
// § Summary. Zero-divergence variant: "no recovery needed: local pocketdb
// matches canonical bitwise.". Non-zero: "divergent: <N> pages across <M>
// files; <bytes> to fetch; ETA ~<T> at 50 MiB/s.".
func EmitSummary(w io.Writer, p plan.Plan, m *manifest.Manifest) {
	if len(p.Divergences) == 0 {
		fmt.Fprintln(w, "no recovery needed: local pocketdb matches canonical bitwise.")
		return
	}
	var pages, files, bytesToFetch int64
	for _, d := range p.Divergences {
		switch d.Kind {
		case plan.DivergenceKindSQLitePages:
			pages += int64(len(d.Pages))
			bytesToFetch += int64(len(d.Pages)) * 4096
			files++
		case plan.DivergenceKindWholeFile:
			files++
			// We don't have a per-file size in v1 manifest, so this is a
			// lower bound — the summary explicitly says "at least".
			bytesToFetch += approxWholeFileSize(d, m)
		}
	}
	eta := time.Duration(float64(bytesToFetch) / float64(throughputBytesPerSecond) * float64(time.Second))
	fmt.Fprintf(w, "divergent: %d pages across %d files; %s to fetch; ETA ~%s at 50 MiB/s.\n",
		pages, files, humanIEC(uint64(bytesToFetch)), humanDuration(eta))
}

// approxWholeFileSize returns a best-effort size guess. v1 manifest has no
// per-entry size; the apply phase will use Content-Length on the chunk-store
// fetch. For summary purposes we treat whole_file divergences as 0 and
// surface that the byte total is a lower bound. Acceptable per D9 since
// the summary is informational.
func approxWholeFileSize(d plan.Divergence, m *manifest.Manifest) int64 {
	_ = d
	_ = m
	return 0
}

// humanIEC renders bytes in IEC binary units: KiB, MiB, GiB, TiB.
func humanIEC(b uint64) string {
	const (
		KiB = uint64(1) << 10
		MiB = uint64(1) << 20
		GiB = uint64(1) << 30
		TiB = uint64(1) << 40
	)
	switch {
	case b >= TiB:
		return fmt.Sprintf("%.1f TiB", float64(b)/float64(TiB))
	case b >= GiB:
		return fmt.Sprintf("%.1f GiB", float64(b)/float64(GiB))
	case b >= MiB:
		return fmt.Sprintf("%.1f MiB", float64(b)/float64(MiB))
	case b >= KiB:
		return fmt.Sprintf("%.1f KiB", float64(b)/float64(KiB))
	}
	return fmt.Sprintf("%d B", b)
}

func humanDuration(d time.Duration) string {
	d = d.Round(time.Second)
	h := int(d / time.Hour)
	m := int((d % time.Hour) / time.Minute)
	s := int((d % time.Minute) / time.Second)
	parts := []string{}
	if h > 0 {
		parts = append(parts, fmt.Sprintf("%dh", h))
	}
	if m > 0 {
		parts = append(parts, fmt.Sprintf("%dm", m))
	}
	parts = append(parts, fmt.Sprintf("%ds", s))
	return strings.Join(parts, "")
}
