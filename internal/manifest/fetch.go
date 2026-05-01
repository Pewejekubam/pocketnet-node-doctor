package manifest

import (
	"context"
	"fmt"
	"io"
	"net/http"
	"strings"
	"time"

	"github.com/pocketnet-team/pocketnet-node-doctor/internal/buildinfo"
)

// fetchTimeout is the per-request deadline for manifest GETs (D17).
const fetchTimeout = 30 * time.Second

// userAgentRoundTripper injects the custom User-Agent header (D17). Composed
// over the default transport (or a test-injected one) so TLS, redirect, and
// proxy behavior match a stock http.Client.
type userAgentRoundTripper struct {
	wrapped http.RoundTripper
	ua      string
}

func (t *userAgentRoundTripper) RoundTrip(req *http.Request) (*http.Response, error) {
	cloned := req.Clone(req.Context())
	cloned.Header.Set("User-Agent", t.ua)
	rt := t.wrapped
	if rt == nil {
		rt = http.DefaultTransport
	}
	return rt.RoundTrip(cloned)
}

// Fetch GETs the manifest at url with the doctor's standard client posture:
// 30s timeout, default redirect (up to 10), default TLS (system CA trust),
// and a custom User-Agent. https-only enforcement: refuses non-https://
// schemes (D17).
//
// transport is optional; pass nil for production. Tests inject httptest's
// transport to verify TLS-bearing manifest serving.
func Fetch(ctx context.Context, url string, transport http.RoundTripper) ([]byte, error) {
	if !strings.HasPrefix(url, "https://") {
		return nil, fmt.Errorf("manifest: refusing non-https URL: %q", url)
	}
	client := &http.Client{
		Timeout: fetchTimeout,
		Transport: &userAgentRoundTripper{
			wrapped: transport,
			ua:      fmt.Sprintf("pocketnet-node-doctor/%s (chunk-002)", buildinfo.Version),
		},
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, url, nil)
	if err != nil {
		return nil, fmt.Errorf("manifest: build request: %w", err)
	}
	resp, err := client.Do(req)
	if err != nil {
		return nil, fmt.Errorf("manifest: fetch: %w", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("manifest: HTTP %d %s", resp.StatusCode, resp.Status)
	}
	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("manifest: read body: %w", err)
	}
	return body, nil
}
