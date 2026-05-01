// Package plan models the plan.json artifact emitted by `diagnose` and
// consumed by `apply`. Mirror of contracts/plan.schema.json. The plan is
// self-authenticating via SelfHash (SHA-256 over the canonical-form payload
// with self_hash removed).
package plan

// Plan is the top-level emitted artifact.
type Plan struct {
	FormatVersion     int               `json:"format_version"`
	CanonicalIdentity CanonicalIdentity `json:"canonical_identity"`
	Divergences       []Divergence      `json:"divergences"`
	SelfHash          string            `json:"self_hash"`
}

type CanonicalIdentity struct {
	BlockHeight          int64  `json:"block_height"`
	ManifestHash         string `json:"manifest_hash"`
	PocketnetCoreVersion string `json:"pocketnet_core_version"`
}

const (
	DivergenceKindSQLitePages = "sqlite_pages"
	DivergenceKindWholeFile   = "whole_file"
)

// Divergence is the discriminated union over DivergenceKind. Marshal/Unmarshal
// dispatch on Kind. Exactly one of Pages or (Hash + ExpectedSource) is
// meaningful per kind.
type Divergence struct {
	Kind           string `json:"divergence_kind"`
	Path           string `json:"path"`
	Pages          []Page `json:"pages,omitempty"`
	ExpectedHash   string `json:"expected_hash,omitempty"`
	ExpectedSource string `json:"expected_source,omitempty"`
}

type Page struct {
	Offset       int64  `json:"offset"`
	ExpectedHash string `json:"expected_hash"`
}

// FormatVersion is the plan-format version this build emits.
const FormatVersion = 1
