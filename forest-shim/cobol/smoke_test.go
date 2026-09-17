//go:build !plugin

package cobol

import (
	"bytes"
	"encoding/json"
	"os"
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

// TestShimEmbedsIDMSQuery pins the published IDMS query in both supported
// GetQuery forms and checks the query still names every public statement class
// plus its graph-bearing capture roles.
func TestShimEmbedsIDMSQuery(t *testing.T) {
	idms := GetQuery("idms")
	idmsScm := GetQuery("idms.scm")
	if len(idms) == 0 {
		t.Fatal("GetQuery(\"idms\") returned empty, want the published IDMS query")
	}
	if !bytes.Equal(idmsScm, idms) {
		t.Fatal("GetQuery(\"idms.scm\") differs from GetQuery(\"idms\")")
	}
	if sourcePath := os.Getenv("IDMS_SOURCE_QUERY"); sourcePath != "" {
		source, err := os.ReadFile(sourcePath)
		if err != nil {
			t.Fatalf("read source IDMS query: %v", err)
		}
		if !bytes.Equal(idms, source) {
			t.Fatal("embedded IDMS query differs from IDMS_SOURCE_QUERY")
		}
	}
	for _, contract := range [][]byte{
		[]byte("idms_navigation_statement"),
		[]byte("idms_update_statement"),
		[]byte("idms_session_statement"),
		[]byte("idms_accept_statement"),
		[]byte("@verb"),
		[]byte("@record"),
		[]byte("@set"),
	} {
		if !bytes.Contains(idms, contract) {
			t.Fatalf("embedded IDMS query is missing contract fragment %q", contract)
		}
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
