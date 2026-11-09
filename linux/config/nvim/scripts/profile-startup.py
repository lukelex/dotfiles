#!/usr/bin/env python3
"""Profile a real Neovim TUI and restored session without overwriting the session."""

import argparse
import errno
import fcntl
import json
import os
from pathlib import Path
import pty
import re
import select
import shutil
import signal
import struct
import subprocess
import tempfile
import termios
import time
from urllib.parse import quote


QUERY = re.compile(rb"\x1b(?:\]11;\?(?:\x07|\x1b\\)|\[5n|\[c|\[\?(\d+)\$p|\[\?u|\[6n)")


def reply_queries(master, pending):
  """Answer basic terminal probes so the synthetic PTY does not add DSR timeouts."""
  end = 0
  for match in QUERY.finditer(pending):
    query = match.group()
    if query.startswith(b"\x1b]11;"):
      reply = b"\x1b]11;rgb:0000/0000/0000\x1b\\"
    elif match.group(1):
      reply = b"\x1b[?" + match.group(1) + b";0$y"
    else:
      reply = {b"\x1b[5n": b"\x1b[0n", b"\x1b[c": b"\x1b[?1;2c",
               b"\x1b[?u": b"\x1b[?0u", b"\x1b[6n": b"\x1b[1;1R"}[query]
    os.write(master, reply)
    end = match.end()
  return pending[end:][-64:]


def main():
  parser = argparse.ArgumentParser(description=__doc__)
  parser.add_argument("project", type=Path)
  parser.add_argument("--seconds", type=int, default=20)
  parser.add_argument("--treesitter", choices=("configured", "async"), default="configured")
  parser.add_argument("--session", type=Path, help="Override the saved auto-session file")
  parser.add_argument("--output", type=Path, help="New output directory (defaults to a temporary directory)")
  args = parser.parse_args()
  if args.seconds < 1:
    parser.error("--seconds must be positive")
  project = args.project.expanduser().resolve(strict=True)
  config = Path(__file__).resolve().parent.parent
  data = Path(os.environ.get("XDG_DATA_HOME", Path.home() / ".local/share")) / "nvim"
  session = args.session or data / "sessions" / (quote(str(project), safe="") + ".vim")
  if not session.is_file():
    parser.error(f"No saved session at {session}; use --session to specify one")
  if args.output:
    output = args.output.expanduser().resolve()
    output.mkdir(parents=True, exist_ok=False)
  else:
    preferred = Path("/tmp/opencode")
    parent = preferred if os.access(preferred, os.W_OK) else None
    output = Path(tempfile.mkdtemp(prefix="nvim-profile-", dir=parent))
  copies = output / "sessions"
  copies.mkdir()
  shutil.copy2(session, copies / session.name)
  # auto-session may have saved companion data next to the Vim session.
  for companion in session.parent.glob(session.stem + ".*"):
    if companion.is_file() and companion != session:
      shutil.copy2(companion, copies / companion.name)
  env = dict(os.environ, TERM="xterm-256color", NVIM_PROFILE_OUTPUT=str(output),
             NVIM_PROFILE_SECONDS=str(args.seconds), NVIM_PROFILE_TS=args.treesitter)
  command = ["nvim", "-u", str(config / "init.lua"), "-i", "NONE", "-n",
             "--startuptime", str(output / "startup.log"),
             "--cmd", "lua dofile(" + json.dumps(str(config / "scripts/profile-startup.lua")) + ")"]
  master, slave = pty.openpty()
  fcntl.ioctl(slave, termios.TIOCSWINSZ, struct.pack("HHHH", 50, 180, 0, 0))
  process = subprocess.Popen(command, cwd=project, env=env, stdin=slave, stdout=slave,
                             stderr=slave, start_new_session=True)
  os.close(slave)
  deadline = time.monotonic() + args.seconds + 60
  pending = b""
  try:
    with (output / "terminal.log").open("wb") as log:
      while process.poll() is None:
        if time.monotonic() > deadline:
          raise TimeoutError(f"Neovim did not finish; inspect {output}")
        readable, _, _ = select.select([master], [], [], 0.1)
        if readable:
          try:
            chunk = os.read(master, 65536)
          except OSError as error:
            if error.errno != errno.EIO:
              raise
            break
          if not chunk:
            break
          log.write(chunk)
          pending = reply_queries(master, pending + chunk)
    process.wait(timeout=10)
  finally:
    if process.poll() is None:
      os.killpg(process.pid, signal.SIGTERM)
      try:
        process.wait(timeout=5)
      except subprocess.TimeoutExpired:
        os.killpg(process.pid, signal.SIGKILL)
        process.wait()
    os.close(master)
  result_path = output / "result.json"
  if process.returncode or not result_path.exists():
    raise RuntimeError(f"Profiling failed (exit {process.returncode}); inspect {output}")
  result = json.loads(result_path.read_text())
  for line in (output / "startup.log").read_text().splitlines():
    if "--- NVIM STARTED ---" in line:
      result["startup_ms"] = float(line.split()[0])
  result_path.write_text(json.dumps(result, indent=2) + "\n")
  if not result.get("session_restored"):
    raise RuntimeError(f"The saved session was not restored; inspect {output}")
  print(json.dumps(result, indent=2))
  print(f"Profile files: {output}")


if __name__ == "__main__":
  main()
