#!/usr/bin/env python3
"""
stub-server.py — minimal HTTP stub server for Chunk 001 contract verification.

Serves a synthetic chunk store rooted at SERVE_ROOT, honoring:
  - chunk-url-grammar.md path scheme: /canonicals/<block_height>/{manifest.json,
    trust-root.sha256, files/<path>, files/<path>/pages/<offset>}
  - http-encoding.md: chunk URLs require Accept-Encoding offering zstd or gzip;
    server selects pre-compressed `.zst` (preferred) or `.gz` from on-disk
    siblings; HTTP 406 with body 'Supported encodings: zstd, gzip\n' otherwise.
  - manifest URL and trust-root sidecar served identity-encoded as plain JSON /
    plain text regardless of Accept-Encoding.

The on-disk layout under SERVE_ROOT mirrors the URL space:
  SERVE_ROOT/manifest.json
  SERVE_ROOT/trust-root.sha256
  SERVE_ROOT/files/<path>           (whole-file chunk; .zst and .gz siblings)
  SERVE_ROOT/files/<path>/pages/<offset>  (sqlite-page chunk; .zst and .gz siblings)

(URL path /canonicals/<block_height>/ is the publisher's per-canonical prefix;
the stub strips that prefix when present so a single SERVE_ROOT can be served
under any block-height. Pass --strip-canonical-prefix to opt out.)

Usage:
    python3 stub-server.py SERVE_ROOT [--port 8080] [--bind 127.0.0.1]
                                       [--no-strip-canonical-prefix]

Exit codes: never returns; Ctrl-C to stop.
"""

from __future__ import annotations

import argparse
import http.server
import os
import re
import sys
from pathlib import Path

SUPPORTED_ENCODINGS = ("zstd", "gzip")
ENCODING_BODY_406 = b"Supported encodings: zstd, gzip\n"

# Paths considered chunk URLs (subject to encoding negotiation):
#   /files/<anything>
# Paths NOT subject to encoding negotiation:
#   /manifest.json
#   /trust-root.sha256
CHUNK_PATH_RE = re.compile(r"^/files/.+")
MANIFEST_PATH_RE = re.compile(r"^/manifest\.json$")
TRUST_ROOT_PATH_RE = re.compile(r"^/trust-root\.sha256$")
CANONICAL_PREFIX_RE = re.compile(r"^/canonicals/[0-9]+(/.*)$")


def parse_accept_encoding(header_value: str | None) -> set[str]:
    if not header_value:
        return set()
    tokens: set[str] = set()
    for token in header_value.split(","):
        # token may be "zstd;q=0.5"
        name = token.strip().split(";")[0].strip().lower()
        if name:
            tokens.add(name)
    return tokens


def select_encoding(offered: set[str]) -> str | None:
    # Prefer zstd over gzip per http-encoding.md.
    for enc in SUPPORTED_ENCODINGS:
        if enc in offered:
            return enc
    return None


class StubHandler(http.server.BaseHTTPRequestHandler):
    serve_root: Path
    strip_canonical_prefix: bool

    def log_message(self, format: str, *args) -> None:  # noqa: A002
        sys.stderr.write("[stub-server] " + (format % args) + "\n")

    def _send(
        self,
        status: int,
        body: bytes,
        content_type: str,
        content_encoding: str | None = None,
        vary: bool = False,
    ) -> None:
        self.send_response(status)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(body)))
        if content_encoding is not None:
            self.send_header("Content-Encoding", content_encoding)
        if vary:
            self.send_header("Vary", "Accept-Encoding")
        self.end_headers()
        self.wfile.write(body)

    def _normalize_path(self, raw_path: str) -> str:
        # Strip query string (we don't honor any).
        path = raw_path.split("?", 1)[0]
        if self.strip_canonical_prefix:
            m = CANONICAL_PREFIX_RE.match(path)
            if m is not None:
                return m.group(1)
        return path

    def _resolve_in_root(self, url_path: str) -> Path | None:
        # url_path begins with "/"; map to a path under serve_root.
        # Reject any traversal; the chunk-url-grammar already forbids "..".
        if "/../" in url_path or url_path.endswith("/.."):
            return None
        rel = url_path.lstrip("/")
        candidate = (self.serve_root / rel).resolve()
        try:
            candidate.relative_to(self.serve_root.resolve())
        except ValueError:
            return None
        return candidate

    def do_GET(self) -> None:  # noqa: N802
        url_path = self._normalize_path(self.path)

        if MANIFEST_PATH_RE.match(url_path) or TRUST_ROOT_PATH_RE.match(url_path):
            target = self._resolve_in_root(url_path)
            if target is None or not target.is_file():
                self._send(404, b"not found\n", "text/plain; charset=utf-8")
                return
            content_type = (
                "application/json; charset=utf-8"
                if url_path.endswith(".json")
                else "text/plain; charset=utf-8"
            )
            with target.open("rb") as fh:
                body = fh.read()
            self._send(200, body, content_type)
            return

        if CHUNK_PATH_RE.match(url_path):
            offered = parse_accept_encoding(self.headers.get("Accept-Encoding"))
            chosen = select_encoding(offered)
            if chosen is None:
                self._send(
                    406,
                    ENCODING_BODY_406,
                    "text/plain; charset=utf-8",
                    vary=True,
                )
                return
            target = self._resolve_in_root(url_path)
            if target is None:
                self._send(404, b"not found\n", "text/plain; charset=utf-8")
                return
            ext = ".zst" if chosen == "zstd" else ".gz"
            variant = target.with_name(target.name + ext)
            if not variant.is_file():
                self._send(
                    404,
                    f"missing pre-compressed variant: {variant.name}\n".encode(),
                    "text/plain; charset=utf-8",
                )
                return
            with variant.open("rb") as fh:
                body = fh.read()
            self._send(
                200,
                body,
                "application/octet-stream",
                content_encoding=chosen,
                vary=True,
            )
            return

        self._send(404, b"not found\n", "text/plain; charset=utf-8")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("serve_root", help="directory to serve")
    ap.add_argument("--bind", default="127.0.0.1")
    ap.add_argument("--port", type=int, default=8080)
    ap.add_argument(
        "--no-strip-canonical-prefix",
        dest="strip_canonical_prefix",
        action="store_false",
        default=True,
        help="do NOT strip /canonicals/<block_height>/ prefix from request URLs",
    )
    args = ap.parse_args()

    serve_root = Path(args.serve_root).resolve()
    if not serve_root.is_dir():
        print(f"error: serve_root '{serve_root}' is not a directory", file=sys.stderr)
        return 2

    StubHandler.serve_root = serve_root
    StubHandler.strip_canonical_prefix = args.strip_canonical_prefix

    httpd = http.server.ThreadingHTTPServer((args.bind, args.port), StubHandler)
    sys.stderr.write(
        f"[stub-server] serving {serve_root} on http://{args.bind}:{args.port}/ "
        f"(strip_canonical_prefix={args.strip_canonical_prefix})\n"
    )
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        sys.stderr.write("[stub-server] interrupted; exiting\n")
    finally:
        httpd.server_close()
    return 0


if __name__ == "__main__":
    sys.exit(main())
