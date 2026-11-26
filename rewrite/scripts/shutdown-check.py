#!/usr/bin/env python3
"""Check real Windows process exits, including failures after passing test output."""

import argparse
import os
import subprocess
from pathlib import Path


def main() -> int:
    root = Path(__file__).resolve().parents[2]
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", required=True, type=Path, help="Windows Godot executable")
    parser.add_argument("--runs", type=int, default=3, help="runs per mode (startup, idle, active)")
    parser.add_argument("--timeout", type=float, default=45, help="seconds per process")
    parser.add_argument("--output", type=Path, default=root / "build/shutdown-check")
    args = parser.parse_args()
    if os.name != "nt":
        parser.error("this regression targets Windows shutdown and isolates profiles with APPDATA")
    if args.runs < 1 or args.timeout <= 0:
        parser.error("runs and timeout must be positive")
    godot = args.godot.resolve()
    if godot.name.endswith("_console.exe"):
        # Launch the actual process, so timeout handling cannot orphan its child.
        godot = godot.with_name(godot.name.replace("_console.exe", ".exe"))
    if not godot.is_file():
        parser.error(f"Godot executable not found: {godot}")
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    failed = False
    for mode in ("startup", "idle", "active"):
        for run in range(1, args.runs + 1):
            label = f"{mode}-{run}"
            profile = output / f"{label}-profile"
            profile.mkdir(exist_ok=True)
            environment = os.environ.copy()
            environment["APPDATA"] = str(profile)
            command = [str(godot), "--headless", "--path", str(root / "rewrite/godot")]
            if mode == "startup":
                command += ["--quit-after", "2"]
            else:
                command += ["-s", "res://tools/shutdown_probe.gd"]
                if mode == "active":
                    command += ["--", "--probe-audio-playing"]
            log_path = output / f"{label}.log"
            timed_out = False
            with log_path.open("w", encoding="utf-8") as log:
                try:
                    result = subprocess.run(
                        command,
                        cwd=root,
                        env=environment,
                        stdout=log,
                        stderr=subprocess.STDOUT,
                        timeout=args.timeout,
                        check=False,
                    )
                    code = result.returncode
                except subprocess.TimeoutExpired:
                    code = -1
                    timed_out = True
            text = log_path.read_text(encoding="utf-8", errors="replace")
            errors = any(
                line.startswith(("ERROR:", "SCRIPT ERROR:"))
                or "were leaked at exit" in line
                or "resources still in use" in line
                for line in text.splitlines()
            )
            complete = mode == "startup" or "SHUTDOWN_PROBE_READY" in text
            passed = code == 0 and not errors and complete and not timed_out
            failed |= not passed
            print(
                f"{'PASS' if passed else 'FAIL'} {label}: exit={code} "
                f"(0x{code & 0xFFFFFFFF:08x}) timeout={timed_out} log={log_path}",
                flush=True,
            )
    return int(failed)


if __name__ == "__main__":
    raise SystemExit(main())
