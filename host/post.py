"""POST application/octet-stream to Acadia serve (/_endpoints)."""

from __future__ import annotations

import argparse
import socket
from pathlib import Path


def post(sock_path: str, body: bytes, timeout: float = 30.0) -> bytes:
    req = (
        b"POST /_endpoints HTTP/1.1\r\n"
        b"Host: localhost\r\n"
        b"Content-Type: application/octet-stream\r\n"
        b"Accept: application/octet-stream\r\n"
        b"Content-Length: "
        + str(len(body)).encode()
        + b"\r\n"
        b"Connection: close\r\n"
        b"\r\n"
        + body
    )
    s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    s.settimeout(timeout)
    s.connect(sock_path)
    try:
        s.sendall(req)
        data = b""
        while True:
            chunk = s.recv(65536)
            if not chunk:
                break
            data += chunk
    finally:
        s.close()
    if b"\r\n\r\n" not in data:
        raise RuntimeError(f"no HTTP body: {data[:200]!r}")
    head, _, rest = data.partition(b"\r\n\r\n")
    status = head.split(b"\r\n", 1)[0]
    if not status.endswith(b"200 OK"):
        raise RuntimeError(f"HTTP {status!r} {rest[:200]!r}")
    return rest


def main() -> None:
    p = argparse.ArgumentParser()
    p.add_argument("--socket", required=True)
    p.add_argument("--in", dest="inp", required=True)
    p.add_argument("--out", required=True)
    args = p.parse_args()
    body = Path(args.inp).read_bytes()
    Path(args.out).write_bytes(post(args.socket, body))


if __name__ == "__main__":
    main()
