#!/usr/bin/env python3
"""Minimal QMP helper for headless Axyl test VMs.

test.sh copies this file into the VM directory (~/axyl-qemu) and prints the
socket path. Examples:

    python3 ~/axyl-qemu/qmp.py ~/axyl-qemu/qmp-arch-bios.sock status
    python3 ~/axyl-qemu/qmp.py ~/axyl-qemu/qmp-arch-bios.sock shot desktop.ppm
    python3 ~/axyl-qemu/qmp.py ~/axyl-qemu/qmp-arch-bios.sock key meta_l-ret
    python3 ~/axyl-qemu/qmp.py ~/axyl-qemu/qmp-arch-bios.sock type "themes.py set glacier"
    python3 ~/axyl-qemu/qmp.py ~/axyl-qemu/qmp-arch-bios.sock quit

Screendumps are written by QEMU, so paths must be visible to the QEMU process.
"""
from __future__ import annotations

import argparse
import json
import socket
import sys
import time
from pathlib import Path


class QMPError(RuntimeError):
    pass


# HMP sendkey names for characters that are not simply their own key name.
CHAR_KEYS = {
    " ": "spc", "-": "minus", "_": "shift-minus", "/": "slash", ".": "dot",
    ",": "comma", ":": "shift-semicolon", ";": "semicolon", "=": "equal",
    "+": "shift-equal", "'": "apostrophe", '"': "shift-apostrophe",
    "(": "shift-9", ")": "shift-0", "|": "shift-backslash", "\\": "backslash",
    "*": "shift-8", "&": "shift-7", "$": "shift-4", "#": "shift-3",
    "@": "shift-2", "!": "shift-1", "?": "shift-slash", "~": "shift-grave",
    "%": "shift-5", "^": "shift-6",
    "`": "grave", "<": "shift-comma", ">": "shift-dot",
    "{": "shift-bracket_left", "}": "shift-bracket_right",
    "[": "bracket_left", "]": "bracket_right",
}


def key_combo(char: str) -> str:
    if char in CHAR_KEYS:
        return CHAR_KEYS[char]
    if char.isalpha():
        return char.lower() if char.islower() else f"shift-{char.lower()}"
    if char.isdigit():
        return char
    raise ValueError(f"cannot type {char!r}")


class QMP:
    def __init__(self, socket_path: str, timeout: float = 15.0) -> None:
        self.sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        self.sock.settimeout(timeout)
        try:
            self.sock.connect(socket_path)
        except OSError as error:
            raise QMPError(f"cannot connect to {socket_path}: {error}") from error
        self.stream = self.sock.makefile("rwb", buffering=0)
        greeting = self._read()
        if "QMP" not in greeting:
            raise QMPError(f"unexpected greeting: {greeting}")
        self.execute("qmp_capabilities")

    def _read(self) -> dict:
        line = self.stream.readline()
        if not line:
            raise QMPError("QEMU closed the QMP connection")
        return json.loads(line.decode())

    def execute(self, command: str, arguments: dict | None = None):
        payload: dict = {"execute": command}
        if arguments:
            payload["arguments"] = arguments
        self.stream.write((json.dumps(payload) + "\n").encode())
        while True:
            message = self._read()
            if "event" in message:
                continue
            if "error" in message:
                error = message["error"]
                raise QMPError(error.get("desc") or str(error))
            return message.get("return")

    def hmp(self, command: str):
        return self.execute("human-monitor-command", {"command-line": command})

    def close(self) -> None:
        try:
            self.stream.close()
        finally:
            self.sock.close()


def main() -> int:
    parser = argparse.ArgumentParser(description="Control a headless Axyl QEMU VM")
    parser.add_argument("socket", help="QMP unix socket path")
    parser.add_argument(
        "command",
        nargs="?",
        default="status",
        choices=["status", "shot", "key", "type", "quit"],
    )
    parser.add_argument("argument", nargs="?", help="screenshot path or key combo")
    parser.add_argument(
        "--delay",
        type=float,
        default=0.0,
        help="seconds to wait before taking a screenshot",
    )
    args = parser.parse_args()

    try:
        qmp = QMP(args.socket)
        if args.command == "status":
            print(json.dumps(qmp.execute("query-status"), indent=2))
        elif args.command == "shot":
            target = args.argument or f"shot-{time.strftime('%Y%m%d-%H%M%S')}.ppm"
            if args.delay:
                time.sleep(args.delay)
            qmp.execute("screendump", {"filename": str(Path(target).resolve())})
            print(target)
        elif args.command == "key":
            if not args.argument:
                parser.error("key requires a combo, for example meta_l-ret")
            qmp.hmp(f"sendkey {args.argument}")
        elif args.command == "type":
            if not args.argument:
                parser.error("type requires text to type")
            if args.delay:
                time.sleep(args.delay)
            for char in args.argument:
                qmp.hmp(f"sendkey {key_combo(char)}")
                time.sleep(0.03)
        elif args.command == "quit":
            qmp.execute("quit")
        qmp.close()
    except (OSError, QMPError, json.JSONDecodeError) as error:
        print(f"qmp: {error}", file=sys.stderr)
        return 1

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
