//go:build !plugin

package cobol

import (
	"encoding/json"
	"testing"
)

// TestShimExposesForestSurface pins the drop-in contract (VEND-01, D-03): the shim
// must expose the same three functions forest's binding.go exposes, with the same
// behavior, so a later gortex change cannot fail as an undefined symbol at the
// resolution boundary.
func TestShimExposesForestSurface(t *testing.T) {
	if GetLanguage() == nil {
		t.Fatal("GetLanguage() returned nil, want non-nil unsafe.Pointer")
	}

	sample := GetQuery("sample")
	if len(sample) == 0 {
		t.Fatal("GetQuery(\"sample\") returned empty, want non-empty bytes")
	}

	sampleScm := GetQuery("sample.scm")
	if string(sampleScm) != string(sample) {
		t.Fatalf("GetQuery(\"sample.scm\") = %q, want %q (suffix should be trimmed and re-appended)", sampleScm, sample)
	}

	if Info() == "" {
		t.Fatal("Info() returned empty string, want non-empty JSON")
	}
}

// TestShimEmbedsThisForksGrammar asserts Info() returns THIS fork's grammar.json,
// not forest v1.9.1's 327-byte placeholder (VEND-01, D-16/T-01-02). The length
// threshold — not an exact byte count — is deliberate: it survives a legitimate
// grammar change in phase 2 while still catching a regression to forest's stale copy.
func TestShimEmbedsThisForksGrammar(t *testing.T) {
	info := Info()

	var parsed map[string]any
	if err := json.Unmarshal([]byte(info), &parsed); err != nil {
		t.Fatalf("Info() did not parse as JSON: %v", err)
	}

	name, ok := parsed["name"].(string)
	if !ok || name != "COBOL" {
		t.Fatalf("Info() JSON \"name\" = %v, want \"COBOL\"", parsed["name"])
	}

	if len(info) <= 100000 {
		t.Fatalf("len(Info()) = %d, want > 100000 (forest v1.9.1's placeholder is 327 bytes; this fork's grammar.json is 428,580 bytes)", len(info))
	}
}

// TestShimMissingQueryReturnsEmpty pins the edge case: an unknown query kind
// returns an empty slice and does not panic.
func TestShimMissingQueryReturnsEmpty(t *testing.T) {
	out := GetQuery("does-not-exist")
	if len(out) != 0 {
		t.Fatalf("GetQuery(\"does-not-exist\") = %q, want empty", out)
	}
}
