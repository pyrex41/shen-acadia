"""Acadia 0.3.0 endpoint codec, transcribed from generated Haskell.

Not a copy of compiler output: same layout as Backend.hs / Acadia.Bytes.*.
"""

from __future__ import annotations

import struct


def u32be(n: int) -> bytes:
    return struct.pack(">I", n)


def u32le(n: int) -> bytes:
    return struct.pack("<I", n)


def u64be(n: int) -> bytes:
    return struct.pack(">Q", n)


def enc_string(s: str) -> bytes:
    # getSizeString = Text.length (chars), then UTF-8 bytes.
    return u32be(len(s)) + s.encode("utf-8")


def enc_u64(n: int) -> bytes:
    return u32be(8) + u64be(n)


def hdr(module: int, endpoint: int) -> bytes:
    return u32be(module) + u32be(endpoint)


def add_food(name: str) -> bytes:
    return hdr(0, 0) + enc_string(name)


def get_foods() -> bytes:
    return hdr(0, 1)


def find_fault(customer_id: int, client_site_id: int, unit: str, title: str) -> bytes:
    return hdr(0, 0) + enc_u64(customer_id) + enc_u64(client_site_id) + enc_string(unit) + enc_string(title)


def link_rec(scenario_id: int, recommendation_id: int) -> bytes:
    return hdr(0, 1) + enc_u64(scenario_id) + enc_u64(recommendation_id)


def dec_i32be(buf: bytes, i: int) -> tuple[int, int]:
    return struct.unpack_from(">i", buf, i)[0], i + 4


def dec_u32le(buf: bytes, i: int) -> tuple[int, int]:
    return struct.unpack_from("<I", buf, i)[0], i + 4


def dec_unit(buf: bytes) -> None:
    n, i = dec_i32be(buf, 0)
    if n != 0 or i != len(buf):
        raise ValueError(f"unit: {buf!r}")


def dec_string_at(buf: bytes, i: int) -> tuple[str, int]:
    n, i = dec_i32be(buf, i)
    if n < 0:
        raise ValueError("string: negative length")
    s = buf[i : i + n].decode("utf-8")
    return s, i + n


def dec_strings(buf: bytes) -> list[str]:
    i = 0
    out: list[str] = []
    while True:
        n, i = dec_u32le(buf, i)
        if n == 0:
            return out
        for _ in range(n):
            s, i = dec_string_at(buf, i)
            out.append(s)
