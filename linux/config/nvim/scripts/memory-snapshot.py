"""Linux process-tree memory snapshot for :NvimMemory. All quantities are KiB."""
import json
import os
from pathlib import Path
import sys

METRICS = {"rss_kib": "Rss", "pss_kib": "Pss", "swap_kib": "SwapPss"}


def identity(directory):
  stat = (directory / "stat").read_text()
  tail = stat.rsplit(")", 1)[1].split()
  return {"ppid": int(tail[1]), "name": stat.split("(", 1)[1].rsplit(")", 1)[0],
          "started": tail[19]}


def label(directory, name):
  try:
    args = (directory / "cmdline").read_bytes().decode(errors="replace").strip("\0").split("\0")
    executable = Path(args[0]).name
    if executable in {"sh", "bash"} and "-c" in args[1:]:
      return name
    if executable in {"node", "nodejs", "ruby", "python", "python3", "sh", "bash"}:
      script = next((arg for arg in args[1:] if not arg.startswith("-")), "")
      # Never display shell command strings or arbitrary arguments (which may contain secrets).
      if script.startswith("/") and "\n" not in script:
        suffix = ""
        if "/node_modules/" in script:
          workspace = script.split("/node_modules/", 1)[0]
          suffix = " [" + workspace.replace(str(Path.home()), "~", 1) + "]"
        return executable + " / " + Path(script).name + suffix
    return name
  except (OSError, IndexError):
    return name


def snapshot(editor_pid, proc=Path("/proc"), excluded_pid=None):
  processes = {}
  for directory in proc.iterdir():
    if not directory.name.isdigit():
      continue
    try:
      if directory.stat().st_uid == os.getuid():
        processes[int(directory.name)] = identity(directory)
    except (OSError, ValueError, IndexError):
      continue
  if editor_pid not in processes:
    raise RuntimeError("Neovim exited or its process metadata is unavailable")
  root = editor_pid
  # Neovim's TUI and embedded editor are separate processes; include both.
  while processes[root]["ppid"] in processes:
    parent = processes[root]["ppid"]
    if processes[parent]["name"] != "nvim":
      break
    root = parent
  children = {}
  for pid, info in processes.items():
    children.setdefault(info["ppid"], []).append(pid)
  rows = []

  def visit(pid, depth):
    if pid == excluded_pid:
      return
    info = processes[pid]
    directory = proc / str(pid)
    row = {"pid": pid, "depth": depth, "label": label(directory, info["name"])}
    try:
      values = {}
      for line in (directory / "smaps_rollup").read_text().splitlines():
        parts = line.split()
        if len(parts) >= 2 and parts[1].isdigit():
          values[parts[0].rstrip(":")] = int(parts[1])
      if identity(directory)["started"] != info["started"]:
        raise RuntimeError("process identity changed during snapshot")
      for key, field in METRICS.items():
        row[key] = values.get(field)
      row["private_kib"] = (values["Private_Clean"] + values["Private_Dirty"]
                            + values.get("Private_Hugetlb", 0))
    except (OSError, ValueError, IndexError, KeyError, RuntimeError) as error:
      row["error"] = type(error).__name__
    rows.append(row)
    for child in sorted(children.get(pid, [])):
      visit(child, depth + 1)

  visit(root, 0)
  totals, missing = {}, {}
  for key in (*METRICS, "private_kib"):
    totals[key] = sum(row.get(key) or 0 for row in rows)
    missing[key] = sum(row.get(key) is None for row in rows)
  return {"root_pid": root, "editor_pid": editor_pid, "processes": rows,
          "totals": totals, "missing": missing}


if __name__ == "__main__":
  request = json.load(sys.stdin)
  print(json.dumps(snapshot(int(request["pid"]), excluded_pid=os.getpid())))
