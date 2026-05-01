package manifest

import "fmt"

// ParseTrustAnchors verifies presence of the manifest's trust_anchors field
// without inspecting its contents (FR-018). Doctor proceeds normally when
// trust_anchors is present, regardless of whether it is the empty array []
// (chunk-001 schema) or some forward-compat shape (v1.x+ extension surface).
func ParseTrustAnchors(m *Manifest) (TrustAnchors, error) {
	if m == nil {
		return TrustAnchors{}, fmt.Errorf("manifest: nil")
	}
	if len(m.TrustAnchors) == 0 {
		return TrustAnchors{}, fmt.Errorf("manifest: trust_anchors required field missing")
	}
	return TrustAnchors{Raw: m.TrustAnchors}, nil
}
