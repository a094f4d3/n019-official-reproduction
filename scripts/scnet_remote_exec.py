"""Run a non-interactive command on one configured SCNet account."""

from __future__ import annotations

import argparse
import sys

from transfer_files_via_local import connect


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--host",
        required=True,
        help="SSH alias from ~/.ssh/config, e.g. scnet-a094f4d7",
    )
    parser.add_argument(
        "--command",
        help="Remote shell command. Reads stdin when omitted.",
    )
    parser.add_argument(
        "--timeout",
        type=float,
        default=60.0,
        help="Transport timeout in seconds",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    command = args.command
    if command is None:
        command = sys.stdin.read()
    command = command.strip()
    if not command:
        raise SystemExit("Remote command is empty")

    client = connect(args.host)
    try:
        _, stdout, stderr = client.exec_command(
            command,
            timeout=args.timeout,
            get_pty=False,
        )
        out = stdout.read().decode("utf-8", errors="replace")
        err = stderr.read().decode("utf-8", errors="replace")
        status = stdout.channel.recv_exit_status()
        if out:
            sys.stdout.write(out)
            if not out.endswith("\n"):
                sys.stdout.write("\n")
        if err:
            sys.stderr.write(err)
            if not err.endswith("\n"):
                sys.stderr.write("\n")
        return status
    finally:
        client.close()


if __name__ == "__main__":
    raise SystemExit(main())
