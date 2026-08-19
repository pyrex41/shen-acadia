#!/usr/bin/env python3
"""Benchmark Acadia serve (Haskell-shaped client) against shen-rel."""

from __future__ import annotations

import os
import socket
import subprocess
import sys
import tempfile
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "host"))

from post import post  # noqa: E402
from protocol import add_food, dec_strings, dec_unit, find_fault, get_foods, link_rec  # noqa: E402

SHEN_LUA = Path(os.environ.get("SHEN_LUA", ROOT.parent / "shen-lua" / "bin" / "shen"))
SHEN_REL = ROOT.parent / "shen-rel"
ACADIA = Path(os.environ.get("ACADIA_BIN", Path.home() / "bin" / "acadia"))
N = int(os.environ.get("BENCH_N", "200"))


def shen(*exprs: str, load: str | None = None) -> str:
    cmd = [str(SHEN_LUA), "--hush-load"]
    env = os.environ.copy()
    env["SHEN_FASL"] = "off"
    if load:
        cmd += ["-e", f'(load "{load}")']
    for e in exprs:
        cmd += ["-e", e]
    r = subprocess.run(cmd, cwd=ROOT, capture_output=True, text=True, env=env, check=True)
    return r.stdout


def wait_socket(path: str, timeout: float = 30.0) -> None:
    deadline = time.time() + timeout
    while time.time() < deadline:
        if Path(path).exists():
            try:
                s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
                s.settimeout(0.2)
                s.connect(path)
                s.close()
                return
            except OSError:
                pass
        time.sleep(0.05)
    raise TimeoutError(path)


def start_acadia(sock: str) -> subprocess.Popen:
    env = os.environ.copy()
    proc = subprocess.Popen(
        [str(ACADIA), "serve", f"--socket={sock}"],
        cwd=ROOT,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        env=env,
    )
    wait_socket(sock)
    return proc


def goldens() -> None:
    want = {
        "add-food-apple": add_food("apple").hex(),
        "get-foods": get_foods().hex(),
        "find-fault": find_fault(1, 10, "AHU", "Overheat").hex(),
        "link-rec": link_rec(30, 90).hex(),
    }
    out = shen(
        '(output (cn "add-food-apple " (cn (ac.hex (ac.add-food "apple")) "~%")))',
        '(output (cn "get-foods " (cn (ac.hex (ac.get-foods)) "~%")))',
        '(output (cn "find-fault " (cn (ac.hex (ac.find-fault 1 10 "AHU" "Overheat")) "~%")))',
        '(output (cn "link-rec " (cn (ac.hex (ac.link-rec 30 90)) "~%")))',
        load="load.shen",
    )
    got = {}
    for line in out.splitlines():
        if " " in line:
            k, _, v = line.partition(" ")
            got[k] = v
    bad = [k for k, v in want.items() if got.get(k) != v]
    if bad:
        raise SystemExit(f"codec mismatch {bad}\nwant {want}\ngot {got}")
    print("codec python == shen: PASS")


def e2e(sock: str) -> None:
    dec_unit(post(sock, add_food("apple")))
    dec_unit(post(sock, add_food("bread")))
    names = dec_strings(post(sock, get_foods()))
    if "apple" not in names or "bread" not in names:
        raise SystemExit(f"e2e getFoods missing rows: {names}")
    print(f"acadia e2e getFoods: {len(names)} rows (contains apple, bread)")
    with tempfile.TemporaryDirectory() as td:
        req = Path(td) / "req.bin"
        res = Path(td) / "res.bin"
        shen(
            f'(ac.write-bin "{req}" (ac.get-foods))',
            load="load.shen",
        )
        res.write_bytes(post(sock, req.read_bytes()))
        out = shen(
            f'(let D (ac.dec-strings (ac.read-bin "{res}")) (output (cn "shen-client-names " (cn (str (length (hd (tl D)))) "~%"))))',
            load="load.shen",
        )
        if "shen-client-names " not in out:
            raise SystemExit(f"shen client decode failed:\n{out}")
        print("shen client getFoods decode:", out.strip())


def bench_acadia(sock: str, n: int) -> dict[str, float | int]:
    t0 = time.perf_counter()
    for i in range(n):
        dec_unit(post(sock, add_food(f"f{i}")))
    t1 = time.perf_counter()
    names = dec_strings(post(sock, get_foods()))
    t2 = time.perf_counter()
    return {"add_sec": t1 - t0, "get_sec": t2 - t1, "names": len(names)}


def bench_rel(n: int) -> dict[str, float | int]:
    out = shen(f"(rel-bench {n})", load="bench/rel-bench.shen")
    rec: dict[str, float | int] = {}
    for line in out.splitlines():
        if line.startswith("rel-add-sec "):
            rec["add_sec"] = float(line.split()[1])
        elif line.startswith("rel-get-sec "):
            rec["get_sec"] = float(line.split()[1])
        elif line.startswith("rel-names "):
            rec["names"] = int(line.split()[1])
    if "add_sec" not in rec:
        raise SystemExit(f"rel-bench parse failed:\n{out}")
    return rec


def bench_codec(n: int) -> dict[str, float]:
    out = shen(f"(codec-bench {n})", load="bench/codec-bench.shen")
    rec: dict[str, float] = {}
    for line in out.splitlines():
        if line.startswith("codec-add-sec "):
            rec["add_sec"] = float(line.split()[1])
    if "add_sec" not in rec:
        raise SystemExit(f"codec-bench parse failed:\n{out}")
    return rec


def main() -> None:
    if not SHEN_LUA.is_file():
        raise SystemExit(f"no shen-lua at {SHEN_LUA}")
    if not (SHEN_REL / "shen" / "rel.shen").is_file():
        raise SystemExit(f"no shen-rel at {SHEN_REL}")
    goldens()
    codec = bench_codec(N)
    print(f"shen-client encode {N} addFood: {codec['add_sec']:.4f}s")

    if not ACADIA.is_file():
        print(f"SKIP acadia serve: {ACADIA} missing")
        rel = bench_rel(N)
        print(f"shen-rel add {N}: {rel['add_sec']:.4f}s  get: {rel['get_sec']:.4f}s  names={rel['names']}")
        return

    with tempfile.TemporaryDirectory() as td:
        sock = str(Path(td) / "acadia.sock")
        proc = start_acadia(sock)
        try:
            e2e(sock)
            ac = bench_acadia(sock, N)
        finally:
            proc.terminate()
            try:
                proc.wait(timeout=5)
            except subprocess.TimeoutExpired:
                proc.kill()
    rel = bench_rel(N)
    print()
    print(f"n={N}")
    print(f"{'impl':<28} {'add_s':>10} {'get_s':>10} {'us/add':>10} {'rows':>8}")
    rows = [
        ("acadia serve + python client", ac["add_sec"], ac["get_sec"], ac["names"]),
        ("shen-rel in-process", rel["add_sec"], rel["get_sec"], rel["names"]),
        ("shen-acadia encode only", codec["add_sec"], 0.0, N),
    ]
    for name, add_s, get_s, names in rows:
        us = (add_s / N) * 1e6 if N else 0
        print(f"{name:<28} {add_s:10.4f} {get_s:10.4f} {us:10.1f} {names:8}")


if __name__ == "__main__":
    main()
