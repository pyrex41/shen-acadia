#!/usr/bin/env python3

from __future__ import annotations

import json
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
from protocol import (  # noqa: E402
    dec_u64s,
    dec_unit,
    find_fault_ids,
    get_scenario_recs,
    link_rec,
    put_fault,
)

ACADIA = Path(os.environ.get("ACADIA_BIN", Path.home() / "bin" / "acadia"))
SHEN_GO = Path(os.environ.get("SHEN_GO", ROOT.parent / "shen-go" / ".bin" / "shen-go"))
SHEN_LUA = Path(os.environ.get("SHEN_LUA", ROOT.parent / "shen-lua" / "bin" / "shen"))


def wait_socket(path: str, timeout: float = 30.0) -> None:
    deadline = time.time() + timeout
    while time.time() < deadline:
        if Path(path).exists():
            probe = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
            probe.settimeout(0.2)
            try:
                probe.connect(path)
                return
            except OSError:
                pass
            finally:
                probe.close()
        time.sleep(0.05)
    raise TimeoutError(path)


def start_acadia(sock: str) -> subprocess.Popen[bytes]:
    process = subprocess.Popen(
        [str(ACADIA), "serve", f"--socket={sock}"],
        cwd=ROOT,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    wait_socket(sock)
    return process


def shen_string(value: str) -> str:
    return json.dumps(value, ensure_ascii=False)


def shen_row(row: list[object]) -> str:
    customer, site, psi, instance, scenario, title, status, unit, ordinal = row
    return (
        f"[candidate {customer} {site} {psi} {instance} {scenario} "
        f"{shen_string(str(title))} {status} {shen_string(str(unit))} {ordinal}]"
    )


def selection_program(scope: int, rows: list[list[object]], linked: list[int]) -> str:
    row_expr = "[" + " ".join(shen_row(row) for row in rows) + "]"
    linked_expr = "[" + " ".join(str(value) for value in linked) + "]"
    return (
        f'(load "{ROOT / "load.shen"}")\n'
        f"(ac.flow-print (ac.flow {scope} {row_expr} {linked_expr}))\n"
    )


def select(port: str, scope: int, rows: list[list[object]], linked: list[int]) -> tuple[list[int], list[int]]:
    with tempfile.NamedTemporaryFile("w", suffix=".shen", encoding="utf-8") as script:
        script.write(selection_program(scope, rows, linked))
        script.flush()
        if port == "go":
            command = [str(SHEN_GO), "script", script.name]
            environment = None
        else:
            command = [str(SHEN_LUA), "--hush-load", script.name]
            environment = {**os.environ, "SHEN_FASL": "off"}
        completed = subprocess.run(
            command,
            cwd=ROOT,
            env=environment,
            capture_output=True,
            text=True,
            check=True,
        )
    ordinals: list[int] = []
    ambiguous: list[int] = []
    for line in completed.stdout.splitlines():
        if line.startswith("CANDIDATE "):
            ordinals.append(int(line.split()[1]))
        elif line.startswith("AMBIGUOUS "):
            ambiguous.append(int(line.split()[1]))
    if "FLOW-END" not in completed.stdout:
        raise RuntimeError(f"{port} flow output incomplete: {completed.stdout[-500:]}")
    return ordinals, ambiguous


def scenario_links(sock: str, scenario: int) -> list[int]:
    return dec_u64s(post(sock, get_scenario_recs(scenario)))


def run_once(sock: str, vector: dict[str, object]) -> tuple[list[list[int]], list[int]]:
    rows = vector["rows"]
    scenarios = list(dict.fromkeys(int(row[4]) for row in rows))
    linked = [scenario for scenario in scenarios if scenario_links(sock, scenario)]
    go_selection = select("go", int(vector["scope"]), rows, linked)
    lua_selection = select("lua", int(vector["scope"]), rows, linked)
    if go_selection != lua_selection:
        raise RuntimeError(f"Shen port divergence: go={go_selection} lua={lua_selection}")
    ordinals, ambiguous = go_selection
    by_ordinal = {int(row[8]): row for row in rows}
    inserted: list[list[int]] = []
    for ordinal in ordinals:
        row = by_ordinal[ordinal]
        customer, site, _, _, scenario, title, _, unit, _ = row
        if scenario_links(sock, int(scenario)):
            continue
        recommendation_ids = sorted(
            dec_u64s(post(sock, find_fault_ids(int(customer), int(site), str(unit), str(title))))
        )
        for recommendation_id in recommendation_ids:
            dec_unit(post(sock, link_rec(int(scenario), recommendation_id)))
            inserted.append([int(scenario), recommendation_id])
    return sorted(inserted), ambiguous


def run_vector(vector: dict[str, object]) -> dict[str, object]:
    with tempfile.TemporaryDirectory() as directory:
        sock = str(Path(directory) / "acadia.sock")
        process = start_acadia(sock)
        try:
            for recommendation in vector["recommendations"]:
                recommendation_id, customer, site, unit, title, text = recommendation
                dec_unit(
                    post(
                        sock,
                        put_fault(
                            int(recommendation_id),
                            int(customer),
                            int(site),
                            str(unit),
                            str(title),
                            str(text),
                        ),
                    )
                )
            for scenario, recommendation_id in vector["existing"]:
                dec_unit(post(sock, link_rec(int(scenario), int(recommendation_id))))
            inserted, ambiguous = run_once(sock, vector)
            rerun_inserted, rerun_ambiguous = run_once(sock, vector)
        finally:
            process.terminate()
            try:
                process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                process.kill()
    expected_inserted = vector["expected_inserted"]
    expected_ambiguous = vector["expected_ambiguous"]
    passed = (
        inserted == expected_inserted
        and ambiguous == expected_ambiguous
        and rerun_inserted == []
        and rerun_ambiguous == expected_ambiguous
    )
    return {
        "name": vector["name"],
        "status": "pass" if passed else "fail",
        "inserted": inserted,
        "ambiguous": ambiguous,
        "rerun_inserted": rerun_inserted,
        "expected_inserted": expected_inserted,
        "expected_ambiguous": expected_ambiguous,
    }


def main() -> None:
    if not ACADIA.is_file():
        print(json.dumps({"status": "skip", "reason": "acadia-binary-missing"}))
        raise SystemExit(77)
    if not SHEN_GO.is_file() or not SHEN_LUA.is_file():
        print(json.dumps({"status": "skip", "reason": "shen-port-missing"}))
        raise SystemExit(77)
    vectors = json.loads((ROOT / "flow" / "vectors.json").read_text(encoding="utf-8"))
    reports = [run_vector(vector) for vector in vectors]
    status = "pass" if all(report["status"] == "pass" for report in reports) else "fail"
    print(json.dumps({"status": status, "vectors": reports}, indent=2))
    raise SystemExit(0 if status == "pass" else 1)


if __name__ == "__main__":
    main()
