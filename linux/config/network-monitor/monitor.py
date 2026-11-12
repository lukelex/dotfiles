#!/usr/bin/env python3
"""Record connectivity probes and bounded diagnostic snapshots without root."""

import argparse
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timezone
import fcntl
import json
import logging
from logging.handlers import TimedRotatingFileHandler
import os
from pathlib import Path
import subprocess
import time


def run(command, timeout=3):
  start = time.monotonic()
  try:
    result = subprocess.run(command, capture_output=True, text=True, timeout=timeout)
    return {
      "ok": result.returncode == 0,
      "exit_code": result.returncode,
      "ms": round((time.monotonic() - start) * 1000),
      "output": (result.stdout + result.stderr).strip()[:24000],
    }
  except (OSError, subprocess.TimeoutExpired) as error:
    return {"ok": False, "ms": round((time.monotonic() - start) * 1000),
            "output": str(error)}


def route():
  result = run(["ip", "-j", "-4", "route", "get", "1.1.1.1"])
  try:
    entry = json.loads(result["output"])[0]
    return entry.get("dev"), entry.get("gateway"), result
  except (ValueError, IndexError, KeyError, TypeError):
    return None, None, result


def interface_state(interface):
  state = {}
  if interface:
    base = Path("/sys/class/net") / interface
    for name in ("carrier", "operstate", "speed", "carrier_changes",
                 "statistics/rx_errors", "statistics/tx_errors",
                 "statistics/rx_dropped", "statistics/tx_dropped"):
      try:
        state[name] = (base / name).read_text().strip()
      except OSError:
        state[name] = None
  return state


def snapshot(interface, pool):
  commands = {
    "addresses": ["ip", "-brief", "address"],
    "routes": ["ip", "route", "show", "table", "all"],
    "neighbours": ["ip", "neigh"],
    "networkmanager": ["journalctl", "-b", "-u", "NetworkManager",
                       "--since", "2 minutes ago", "-n", "150", "--no-pager"],
    "kernel": ["journalctl", "-b", "-k", "--since", "2 minutes ago",
               "-n", "100", "--no-pager"],
    "dns_config": ["cat", "/etc/resolv.conf"],
  }
  if interface:
    commands["device"] = ["nmcli", "device", "show", interface]
    commands["link"] = ["ip", "-s", "link", "show", "dev", interface]
  futures = {name: pool.submit(run, command) for name, command in commands.items()}
  return {name: future.result() for name, future in futures.items()}


def main():
  parser = argparse.ArgumentParser(description=__doc__)
  parser.add_argument("--once", action="store_true", help="Capture one sample and exit")
  parser.add_argument("--https-target", action="append", default=[],
                      help="Public HTTPS URL to check every 30 seconds (repeatable)")
  parser.add_argument("--state-dir", type=Path,
                      default=Path(os.environ.get("XDG_STATE_HOME", Path.home() / ".local/state"))
                      / "network-monitor")
  args = parser.parse_args()
  os.umask(0o077)
  args.state_dir.mkdir(parents=True, exist_ok=True)
  lock = (args.state_dir / "lock").open("w")
  try:
    fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
  except BlockingIOError:
    parser.exit(1, "Network monitor is already running in this state directory.\n")

  logger = logging.getLogger("network-monitor")
  logger.setLevel(logging.INFO)
  handler = TimedRotatingFileHandler(args.state_dir / "monitor.jsonl",
                                   when="midnight", backupCount=7, utc=True)
  handler.setFormatter(logging.Formatter("%(message)s"))
  logger.addHandler(handler)

  def record(kind, **fields):
    logger.info(json.dumps({"time": datetime.now(timezone.utc).isoformat(),
                            "kind": kind, **fields}))

  previous = None
  pending_snapshot = False
  last_snapshot = float("-inf")
  last_targets = float("-inf")
  previous_targets = None
  with ThreadPoolExecutor(max_workers=8) as pool:
    while True:
      start = time.monotonic()
      interface, gateway, route_result = route()
      link = interface_state(interface)
      commands = {
        "internet_cloudflare": ["ping", "-n", "-c", "1", "-W", "2", "1.1.1.1"],
        "internet_google": ["ping", "-n", "-c", "1", "-W", "2", "8.8.8.8"],
        "dns": ["getent", "ahostsv4", "example.com"],
        "https": ["curl", "--noproxy", "*", "-4", "-sS", "-f", "-o", "/dev/null",
                  "--connect-timeout", "2", "--max-time", "3",
                  "-w", "%{http_code} %{time_total}", "https://example.com/"],
      }
      if gateway:
        commands["gateway"] = ["ping", "-n", "-c", "1", "-W", "2", gateway]
      futures = {name: pool.submit(run, command, 4) for name, command in commands.items()}
      probes = {name: future.result() for name, future in futures.items()}
      if not gateway:
        probes["gateway"] = {"ok": False, "ms": 0, "output": "No IPv4 gateway on selected route"}
      record("sample", interface=interface, gateway=gateway, link=link, probes=probes,
             route=route_result)
      state = {"interface": interface, "gateway_address": gateway, "carrier": link.get("carrier"),
               **{name: probe["ok"] for name, probe in probes.items()}}
      if state != previous:
        record("transition", before=previous, after=state)
        print(json.dumps({"time": datetime.now(timezone.utc).isoformat(), **state}), flush=True)
        previous = state
        pending_snapshot = True
      if args.https_target and start - last_targets >= 30:
        # Use curl's normal address-family selection, unlike the IPv4 baseline.
        # Public endpoints only: no browser cookies or account credentials.
        futures = {
          url: pool.submit(run, ["curl", "--noproxy", "*", "-sS", "-f",
                                 "-o", "/dev/null", "--connect-timeout", "2",
                                 "--max-time", "3", "-w",
                                 "http=%{http_code} ip=%{remote_ip} dns=%{time_namelookup} "
                                 "connect=%{time_connect} tls=%{time_appconnect} "
                                 "total=%{time_total} version=%{http_version}", url], 4)
          for url in args.https_target
        }
        targets = {url: future.result() for url, future in futures.items()}
        record("target_sample", probes=targets)
        target_state = {url: probe["ok"] for url, probe in targets.items()}
        if target_state != previous_targets:
          record("target_transition", before=previous_targets, after=target_state)
          print(json.dumps({"targets": targets}), flush=True)
          previous_targets = target_state
          pending_snapshot = True
        last_targets = start
      # Coalesce flapping transitions so diagnostics cannot flood the log.
      if pending_snapshot and start - last_snapshot >= 60:
        record("snapshot", diagnostics=snapshot(interface, pool))
        last_snapshot = start
        pending_snapshot = False
      if args.once:
        break
      time.sleep(max(0, 5 - (time.monotonic() - start)))


if __name__ == "__main__":
  main()
