# shen-acadia

A Shen client for [Acadia](https://acadia.engineering) 0.3.0 endpoints.

Acadia's `make --gen-haskell` emits `Backend.hs` plus `Acadia/Transaction.hs`
and `Acadia/Bytes/{Encode,Decode}.hs`. That compiler output is not in this
repo (redistribution rights are unclear). This tree re-expresses the wire
layout in portable Shen, checks it against a Python twin of the same layout,
and talks to a live `acadia serve`.

This project is not affiliated with Acadia Engineering. Acadia itself is
separate software with its own license.

## Wire format

Confirmed against generated Haskell **and** a live Unix-socket `acadia serve`.
Elm's `Acadia.Transaction.attempt` POSTs the encoder:

```
POST /_endpoints
Content-Type: application/octet-stream
Accept: application/octet-stream
```

`Accept: */*` also works. `Accept: application/json` returns **406**. Unix
sockets work (`acadia serve --socket=PATH`).

Request body:

```
u32BE moduleId | u32BE endpointId | args
```

| Arg | Encoding |
|---|---|
| `String` | `u32BE byte count` + UTF-8 bytes |
| `UInt64` newtype | `u32BE 8` + `u64BE` |

Responses:

| Type | Encoding |
|---|---|
| `()` | `i32BE 0` |
| `String` | `i32BE n` (`n >= 0`) + `n` UTF-8 bytes |
| `[a]` / `Rows` | repeated `u32LE count` + `count` items, ended by `u32LE 0` |

Acadia 0.3.0's generated Haskell names the string-size helper with
`Text.length`, but the live server rejects non-ASCII requests unless the prefix
is the UTF-8 byte count. The codec follows the live wire behavior and keeps a
non-ASCII round-trip in the live test.

This tree's `src/Backend.db` is Acadia's public **foods** example (`01-foods`):

| Endpoint | Request |
|---|---|
| `addFood` | module 0, endpoint 0, one string |
| `getFoods` | module 0, endpoint 1, no args → list of strings |

`ac.find-fault` and `ac.link-rec` encode a second generated `Backend.hs` that
uses length-prefixed `UInt64` arguments (same framing, different args). They
are codec-tested against goldens only; they are not served from this
`Backend.db`.

`acadia serve` without `acadia publish` is an in-memory database. Restarting
the server drops rows.

## Layout

```
src/Backend.db           foods module (live serve target)
src/PingCx.db            test-only PingCx recommendation/link module
acadia.json              Acadia project file
shen/ac-bytes.shen       encode / decode
shen/ac-backend.shen     addFood, getFoods, find-fault, link-rec
host/protocol.py         Python twin of the Haskell codec (oracle + bench)
host/post.py             Unix-socket POST
bench/run.py             Acadia vs shen-rel vs Shen encode
bench/rel-bench.shen     in-process foods algebra (needs sibling shen-rel)
bench/codec-bench.shen   encode-only timing
run-tests.shen           codec goldens
load.shen                kernel load list
Makefile
bifrost.suite.json       cross-port agreement
```

`acadia-stuff/` (compiler cache) and `.shen-kernel-cache.*` are gitignored.

## Run

Codec tests need a Shen 42.0 launcher. Defaults assume a sibling checkout:

| Variable | Default |
|---|---|
| `SHEN_LUA` | `../shen-lua/bin/shen` |
| `SHEN_GO` | `../shen-go/.bin/shen-go` |
| `BIFROST` | `bifrost` on `PATH` |
| `ACADIA_BIN` | `~/bin/acadia` |
| `BENCH_N` | `200` |

```bash
make test                 # Shen codec goldens (shen-lua)
make test-go              # same on shen-go
make bifrost              # shen-lua / shen-go agree
make exotic-agree EXOTIC1_ROOT=/path/to/exotic-1
make flow                 # complete recommendation flow vectors
make gates                # compiler + both ports + Bifrost + live flow
make bench                # optional Acadia serve + shen-rel comparison
BENCH_N=1000 make bench
```

`make test` is self-contained given `SHEN_LUA`. `make bench` additionally
wants:

- **Acadia 0.3.0** at `$ACADIA_BIN`. If the binary is missing, the Acadia
  server rows are skipped; codec identity and shen-rel still run.
- **shen-rel** as a sibling directory (`../shen-rel/shen/rel.shen`). That
  project is not published with this repo; without it the in-process algebra
  comparison fails.

The bench starts `acadia serve` on a temp Unix socket, round-trips
`apple`/`bread` with both the Python client and Shen encode/decode, then times
N inserts + one `getFoods` on that same server. Row counts include the two
e2e foods (N+2). It does not write generated Haskell into the tree.

`make exotic-agree` co-loads exotic-1's typed scoring kernel and this endpoint
codec on both Shen-Go and Shen-Lua. It deliberately does not add database I/O
to exotic-1's engine worker; a stored-procedure extraction worker should reuse
the Shen modules without changing the test-engine protocol.

`src/PingCx.db` uses unrestricted security and helper endpoints that exist only
to prove lookup, Unicode payload, typed ID, and link round-trips. It is not the
production tenant model or a replacement for the complete stored procedure.

`make flow` executes the extracted recommendation flow over normalized candidate
rows. Shen-Go and Shen-Lua must select the same scenarios; Acadia performs exact
recommendation lookup and link persistence; every vector reruns to prove
idempotency. The remaining production boundary is construction of normalized
candidates from the legacy join graph and atomic concurrency handling.

## One run (2026-08-19, macOS, `BENCH_N=1000`)

| impl | add 1000 | get | µs/add |
|---|---:|---:|---:|
| Acadia serve + Python client (Unix socket) | 0.044 s | 0.0005 s | 44 |
| shen-rel in-process | 0.033 s | 0.002 s | 33 |
| Shen encode only | 0.0035 s | — | 3.5 |

Acadia is HTTP plus the vendor engine. shen-rel is the same `addFood` /
`getFoods` algebra with no process boundary. The Shen codec is not the
bottleneck. These numbers are one machine; `make bench` reprints them.

## License

Apache-2.0. That covers this Shen/Python tree only, not Acadia.
