// Package main is the reference-rig manifest-minting helper.
//
// Mints a v1 canonical manifest from a source SQLite file (and optional
// whole-file artifacts), writes it to disk, computes the SHA-256 trust-root,
// and prints the trust-root hex on stdout so the operator can pass it to
// `tools/reference-rig/deploy.sh <trust-root>`.
//
// Pages are streamed one at a time; the full page list is never materialized
// in memory. Memory cost is O(write-buffer + SHA-256 state) ≈ 8 MiB.
//
// This is a chunk-002-side stopgap until the proper chunk-001 manifest
// generator workflow exists. The output schema is identical to chunk-001's
// frozen manifest schema (specs/002-001-delta-recovery-client-chunk-001/
// contracts/manifest.schema.json).
//
// Usage:
//
//	rig-helper mint \
//	  --sqlite <path-to-canonical-main.sqlite3> \
//	  --pocketnet-core-version <version> \
//	  --block-height <int> \
//	  --created-at <RFC3339> \
//	  --out <path-to-manifest.json> \
//	  [--whole-file <relpath>=<absolute-path>]...
package main

import (
	"bufio"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"flag"
	"fmt"
	"io"
	"iter"
	"os"
	"sort"
	"strings"

	"github.com/pocketnet-team/pocketnet-node-doctor/internal/hashutil"
)

// stringList is a flag.Value that accumulates repeated --whole-file flags.
type stringList []string

func (s *stringList) String() string     { return strings.Join(*s, ",") }
func (s *stringList) Set(v string) error { *s = append(*s, v); return nil }

// wfEntry is a resolved whole_file manifest entry.
type wfEntry struct{ relPath, hash string }

func main() {
	if len(os.Args) < 2 {
		usage()
		os.Exit(64)
	}
	switch os.Args[1] {
	case "mint":
		os.Exit(runMint(os.Args[2:]))
	case "-h", "--help", "help":
		usage()
		os.Exit(0)
	default:
		fmt.Fprintf(os.Stderr, "rig-helper: unknown subcommand %q\n", os.Args[1])
		usage()
		os.Exit(64)
	}
}

func usage() {
	fmt.Fprintln(os.Stderr, `rig-helper — mint a v1 canonical manifest for the reference rig.

Subcommands:
  mint --sqlite <path> --pocketnet-core-version <v> --block-height <n>
       --created-at <rfc3339> --out <manifest.json>
       [--whole-file <relpath>=<absolute-path>]...

Mints a manifest.json from <sqlite> (page-level entries at 4096-byte boundaries
with a change_counter from the SQLite header) plus zero-or-more whole_file
entries, serializes via the canonical-form rule (sorted keys, no insignificant
whitespace, UTF-8), computes SHA-256 of that payload, prints the trust-root
hex on stdout.`)
}

func runMint(args []string) int {
	fs := flag.NewFlagSet("mint", flag.ContinueOnError)
	var (
		sqlitePath  = fs.String("sqlite", "", "path to canonical main.sqlite3 (required)")
		coreVersion = fs.String("pocketnet-core-version", "", "pocketnet-core version string (required)")
		blockHeight = fs.Int64("block-height", 0, "canonical block height (required)")
		createdAt   = fs.String("created-at", "", "RFC 3339 / ISO-8601 timestamp (required)")
		out         = fs.String("out", "", "path to write manifest.json (required)")
		wholeFiles  stringList
	)
	fs.Var(&wholeFiles, "whole-file", "<relpath>=<absolute-path>; repeatable")
	if err := fs.Parse(args); err != nil {
		return 64
	}
	var missing []string
	if *sqlitePath == "" {
		missing = append(missing, "--sqlite")
	}
	if *coreVersion == "" {
		missing = append(missing, "--pocketnet-core-version")
	}
	if *blockHeight == 0 {
		missing = append(missing, "--block-height")
	}
	if *createdAt == "" {
		missing = append(missing, "--created-at")
	}
	if *out == "" {
		missing = append(missing, "--out")
	}
	if len(missing) > 0 {
		fmt.Fprintf(os.Stderr, "missing required flags: %s\n", strings.Join(missing, ", "))
		fs.PrintDefaults()
		return 64
	}

	// Hash whole-file entries first (small in count; hashing is O(file-size)).
	wfEntries := make([]wfEntry, 0, len(wholeFiles))
	for _, spec := range wholeFiles {
		eq := strings.IndexByte(spec, '=')
		if eq <= 0 || eq == len(spec)-1 {
			fmt.Fprintf(os.Stderr, "--whole-file %q: expected <relpath>=<absolute-path>\n", spec)
			return 1
		}
		h, err := hashutil.HashWholeFile(spec[eq+1:])
		if err != nil {
			fmt.Fprintf(os.Stderr, "hash %s: %v\n", spec[eq+1:], err)
			return 1
		}
		wfEntries = append(wfEntries, wfEntry{spec[:eq], h})
	}
	sort.Slice(wfEntries, func(i, j int) bool { return wfEntries[i].relPath < wfEntries[j].relPath })

	// Read SQLite change_counter from the 100-byte header (header-only read).
	cc, err := readChangeCounter(*sqlitePath)
	if err != nil {
		fmt.Fprintf(os.Stderr, "read change_counter: %v\n", err)
		return 1
	}

	// Open the page-hash iterator (file is opened eagerly; closed after drain).
	seq, err := hashutil.HashSQLitePages(*sqlitePath, 4096)
	if err != nil {
		fmt.Fprintf(os.Stderr, "open sqlite_pages: %v\n", err)
		return 1
	}

	// Atomic write: stream JSON to a temp file, rename to final path on success.
	tmpOut := *out + ".tmp"
	f, err := os.Create(tmpOut)
	if err != nil {
		fmt.Fprintf(os.Stderr, "create %s: %v\n", tmpOut, err)
		return 1
	}
	committed := false
	defer func() {
		f.Close()
		if !committed {
			os.Remove(tmpOut)
		}
	}()

	hasher := sha256.New()
	// 4 MiB write buffer: amortizes syscall overhead over the large output.
	bw := bufio.NewWriterSize(io.MultiWriter(f, hasher), 4<<20)

	var pageCount int64
	if err := streamManifestJSON(bw, *blockHeight, *coreVersion, *createdAt, cc, seq, wfEntries, &pageCount); err != nil {
		fmt.Fprintf(os.Stderr, "stream manifest: %v\n", err)
		return 1
	}
	if err := bw.Flush(); err != nil {
		fmt.Fprintf(os.Stderr, "flush: %v\n", err)
		return 1
	}
	if err := f.Sync(); err != nil {
		fmt.Fprintf(os.Stderr, "sync: %v\n", err)
		return 1
	}

	trustRoot := hex.EncodeToString(hasher.Sum(nil))
	f.Close()
	if err := os.Rename(tmpOut, *out); err != nil {
		fmt.Fprintf(os.Stderr, "rename to %s: %v\n", *out, err)
		return 1
	}
	committed = true

	fi, _ := os.Stat(*out)
	var size int64
	if fi != nil {
		size = fi.Size()
	}
	fmt.Fprintf(os.Stderr, "manifest written: %s (%d bytes)\n", *out, size)
	fmt.Fprintf(os.Stderr, "page entries: %d\n", pageCount)
	fmt.Fprintf(os.Stderr, "whole_file entries: %d\n", len(wfEntries))
	fmt.Fprintf(os.Stderr, "trust-root SHA-256:\n")
	fmt.Println(trustRoot)
	return 0
}

// jsonStr returns the JSON-encoded form of s including surrounding double quotes.
func jsonStr(s string) string {
	b, _ := json.Marshal(s)
	return string(b)
}

// streamManifestJSON writes canonical-form manifest JSON to w, streaming page
// hashes from seq one at a time without materializing the full page list.
//
// Key ordering follows canonform (alphabetical at every level):
//
//	outer:              canonical_identity, entries, format_version, trust_anchors
//	canonical_identity: block_height, created_at, pocketnet_core_version
//	sqlite_pages entry: change_counter, entry_kind, pages, path
//	page entry:         hash, offset
//	whole_file entry:   entry_kind, hash, path
func streamManifestJSON(
	w io.Writer,
	blockHeight int64,
	coreVersion, createdAt string,
	cc int64,
	seq iter.Seq2[hashutil.PageHash, error],
	wfEntries []wfEntry,
	pageCount *int64,
) error {
	ws := func(s string) error {
		_, err := io.WriteString(w, s)
		return err
	}

	// Outer object opener + canonical_identity (keys: block_height, created_at, pocketnet_core_version).
	if _, err := fmt.Fprintf(w,
		`{"canonical_identity":{"block_height":%d,"created_at":%s,"pocketnet_core_version":%s},"entries":[`,
		blockHeight, jsonStr(createdAt), jsonStr(coreVersion)); err != nil {
		return err
	}

	// sqlite_pages entry header (keys in order: change_counter, entry_kind, pages).
	if _, err := fmt.Fprintf(w, `{"change_counter":%d,"entry_kind":"sqlite_pages","pages":[`, cc); err != nil {
		return err
	}

	// Stream pages one at a time; each page: keys hash, offset.
	first := true
	var iterErr error
	seq(func(ph hashutil.PageHash, err error) bool {
		if err != nil {
			iterErr = fmt.Errorf("page hash: %w", err)
			return false
		}
		if !first {
			if _, werr := io.WriteString(w, ","); werr != nil {
				iterErr = werr
				return false
			}
		}
		if _, werr := fmt.Fprintf(w, `{"hash":"%s","offset":%d}`, ph.Hash, ph.Offset); werr != nil {
			iterErr = werr
			return false
		}
		first = false
		*pageCount++
		return true
	})
	if iterErr != nil {
		return iterErr
	}

	// Close pages array; add path field (completing the sqlite_pages entry).
	if err := ws(`],"path":"pocketdb/main.sqlite3"}`); err != nil {
		return err
	}

	// Append whole_file entries (already sorted by relPath).
	// Keys in canonical order: entry_kind, hash, path.
	for _, wfe := range wfEntries {
		if _, err := fmt.Fprintf(w, `,{"entry_kind":"whole_file","hash":"%s","path":%s}`,
			wfe.hash, jsonStr(wfe.relPath)); err != nil {
			return err
		}
	}

	// Close entries array; add format_version and trust_anchors; close outer object.
	return ws(`],"format_version":1,"trust_anchors":[]}`)
}

func readChangeCounter(path string) (int64, error) {
	f, err := os.Open(path)
	if err != nil {
		return 0, err
	}
	defer f.Close()
	var hdr [100]byte
	if _, err := io.ReadFull(f, hdr[:]); err != nil {
		return 0, err
	}
	const magic = "SQLite format 3\x00"
	if string(hdr[0:16]) != magic {
		return 0, fmt.Errorf("not a SQLite-3 file: magic mismatch")
	}
	cc := int64(uint32(hdr[24])<<24 | uint32(hdr[25])<<16 | uint32(hdr[26])<<8 | uint32(hdr[27]))
	return cc, nil
}
