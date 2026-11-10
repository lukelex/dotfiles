#!/usr/bin/env python3
"""Visual source chooser and crash supervisor for XDPH."""

import json
import os
import re
import subprocess
import sys
import threading
import shutil
import signal
import time
from concurrent.futures import ThreadPoolExecutor


WINDOW = re.compile(r"(\d+)\[HC>\](.*?)\[HT>\](.*?)\[HE>\](\d+)\[HA>\]", re.DOTALL)


def windows_from_portal(value):
    return [
        {"id": int(identifier), "class": window_class, "title": title, "address": int(address)}
        for identifier, window_class, title, address in WINDOW.findall(value)
    ]


def outputs_from_portal(value):
    value = value.encode("utf-8")
    outputs = []
    while value:
        length, separator, rest = value.partition(b":")
        if not separator or not length.isdigit():
            break
        name_length = int(length)
        name, rest = rest[:name_length], rest[name_length:]
        match = re.match(rb"^:(-?\d+):(-?\d+):(\d+):(\d+);", rest)
        if not name or not match:
            break
        outputs.append(name.decode("utf-8"))
        value = rest[match.end():]
    return outputs


def portal_selection(kind, identifier):
    # XDPH's 'r' flag asks it to return a restore token when the app supports it.
    return f"[SELECTION]r/{kind}:{identifier}"


def hyprctl(*args):
    try:
        return json.loads(subprocess.check_output(["hyprctl", "-j", *args], timeout=3))
    except (OSError, subprocess.CalledProcessError, subprocess.TimeoutExpired, ValueError):
        raise RuntimeError("Hyprland IPC unavailable") from None


def log(event, **fields):
    print(json.dumps({"component": "share-picker", "event": event, **fields}), file=sys.stderr, flush=True)


def window_available(window, clients):
    client = clients.get(window["address"])
    return bool(client and client.get("mapped", True) and
                window.get("stableId") and client.get("stableId") == window["stableId"])


class Captures:
    """Own child processes so cancellation also interrupts communicate()."""

    def __init__(self):
        self.lock = threading.Lock()
        self.processes = set()
        self.stopped = threading.Event()

    def run(self, args, scale=0.25):
        with self.lock:
            if self.stopped.is_set():
                return None
            process = subprocess.Popen(["grim", *args, "-s", str(scale), "-"], stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
            self.processes.add(process)
        try:
            data, _ = process.communicate(timeout=3)
            return data if process.returncode == 0 else None
        except subprocess.TimeoutExpired:
            process.kill()
            process.communicate()
            raise
        finally:
            with self.lock:
                self.processes.discard(process)

    def close(self):
        with self.lock:
            self.stopped.set()
            for process in self.processes:
                try:
                    process.kill()
                except ProcessLookupError:
                    pass


def window_capture_args(window, clients):
    # XDPH's selection handle, Hyprland address, and ext-toplevel ID differ.
    stable_id = clients.get(window["address"], {}).get("stableId")
    return ("-T", stable_id) if stable_id else None


def thumbnail(*args, stopped=None, captures=None, scale=0.25):
    started = time.monotonic()
    for attempt in range(2):
        if stopped is not None and stopped.is_set():
            return None
        try:
            data = captures.run(args, scale) if captures else subprocess.check_output(["grim", *args, "-s", str(scale), "-"], stderr=subprocess.DEVNULL, timeout=3)
            if data:
                log("capture", outcome="ok", attempt=attempt + 1, milliseconds=round((time.monotonic() - started) * 1000))
                return data
        except (OSError, subprocess.CalledProcessError, subprocess.TimeoutExpired):
            pass
    log("capture", outcome="unavailable", milliseconds=round((time.monotonic() - started) * 1000))
    return None


def main():
    import gi

    gi.require_version("Gtk", "4.0")
    gi.require_version("Gdk", "4.0")
    from gi.repository import Gdk, Gio, GLib, Gtk
    Gtk.init()
    if not Gdk.Display.get_default() or not hasattr(Gtk.Picture, "set_content_fit"):
        raise RuntimeError("GTK display unavailable")

    windows = windows_from_portal(os.environ.get("XDPH_WINDOW_SHARING_LIST", ""))
    outputs = outputs_from_portal(os.environ.get("XDPH_OUTPUT_SHARING_LIST", ""))
    clients = {int(client["address"], 16): client for client in hyprctl("clients")}
    for window in windows:
        window["stableId"] = clients.get(window["address"], {}).get("stableId")
    monitors = {monitor["name"]: monitor for monitor in hyprctl("monitors")}
    # Keep instances independent so simultaneous portal requests each get a reply.
    app = Gtk.Application(application_id="dev.dotfiles.hypr-share-picker", flags=Gio.ApplicationFlags.NON_UNIQUE)
    executor = ThreadPoolExecutor(max_workers=3)
    captures = Captures()
    stopped = captures.stopped
    # GTK callback exceptions otherwise leave a broken UI running indefinitely.
    failed = []
    active_dialog = []
    def callback_error(*_):
        failed.append(True)
        log("ui-error")
        app.quit()
    sys.excepthook = callback_error
    app.connect("shutdown", lambda *_: captures.close())
    for signum in (signal.SIGTERM, signal.SIGINT):
        GLib.unix_signal_add(GLib.PRIORITY_DEFAULT, signum, lambda: app.quit() or False)

    def activate(application):
        # Resolve alongside the real script even when launched through ~/.local/bin.
        sys.dont_write_bytecode = True
        sys.path.insert(0, os.path.dirname(os.path.realpath(__file__)))
        from types import SimpleNamespace
        from share_picker_ui import Picker
        api = SimpleNamespace(hyprctl=hyprctl, thumbnail=thumbnail, log=log,
                              window_available=window_available,
                              window_capture_args=window_capture_args,
                              portal_selection=portal_selection)
        picker = Picker(application, windows, outputs, clients, monitors, executor,
                        captures, api, lambda: failed.append(True))
        active_dialog.append(picker)
        picker.present()

    app.connect("activate", activate)
    try:
        # GTK initialization can fail before activate; the supervisor must fall back.
        app.run([])
    finally:
        captures.close()
        executor.shutdown(wait=True, cancel_futures=True)
    return 1 if failed or not active_dialog else 0


def check_dependencies():
    installed = shutil.which("u_hypr-share-picker.py")
    if not installed or os.path.realpath(installed) != os.path.realpath(__file__):
        raise RuntimeError("Configured picker link is missing or points elsewhere")
    config_home = os.environ.get("XDG_CONFIG_HOME", os.path.expanduser("~/.config"))
    with open(os.path.join(config_home, "hypr", "xdph.conf"), encoding="utf-8") as config:
        if not re.search(r"^\s*custom_picker_binary\s*=\s*u_hypr-share-picker\.py\s*$", config.read(), re.MULTILINE):
            raise RuntimeError("xdph.conf does not select this picker")
    for name in ("hyprctl", "grim", "hyprland-share-picker"):
        if not shutil.which(name):
            raise RuntimeError(f"Missing command: {name}")
    import gi
    gi.require_version("Gtk", "4.0")
    gi.require_version("Gdk", "4.0")
    from gi.repository import Gtk, Gdk
    Gtk.init()
    if not hasattr(Gtk.Picture, "set_content_fit") or not Gdk.Display.get_default():
        raise RuntimeError("GTK 4.8+ and a graphical session are required")
    directory = os.path.dirname(os.path.realpath(__file__))
    for filename in ("share_picker_ui.py", "share-picker.css"):
        if not os.access(os.path.join(directory, filename), os.R_OK):
            raise RuntimeError(f"Missing presentation file: {filename}")
    result = subprocess.run(["grim", "-h"], capture_output=True, timeout=3)
    if b"-T" not in result.stdout + result.stderr:
        raise RuntimeError("grim lacks direct window capture (-T)")
    hyprctl("clients")
    # Probe capture support without saving screen content or opening a portal.
    monitors = hyprctl("monitors")
    if not monitors or thumbnail("-o", monitors[0]["name"]) is None:
        raise RuntimeError("Monitor capture unavailable")
    clients = hyprctl("clients")
    identifiers = [c.get("stableId") for c in clients if c.get("stableId")]
    if identifiers and not any(thumbnail("-T", ident) for ident in identifiers[:2]):
        raise RuntimeError("Window capture unavailable")


def supervise():
    """Isolate GTK/native crashes; publish only a validated portal response."""
    child = subprocess.Popen([sys.executable, os.path.realpath(__file__), "--picker"], stdout=subprocess.PIPE)
    cancelled = False
    def cancel(*_):
        nonlocal cancelled
        cancelled = True
        child.terminate()
    for signum in (signal.SIGTERM, signal.SIGINT):
        signal.signal(signum, cancel)
    while True:
        try:
            output, _ = child.communicate(timeout=0.2)
            break
        except subprocess.TimeoutExpired:
            if cancelled:
                child.kill()
                child.communicate()
                return 0
    if cancelled:
        return 0
    allowed = {portal_selection("window", w["id"]) for w in windows_from_portal(os.environ.get("XDPH_WINDOW_SHARING_LIST", ""))}
    allowed.update(portal_selection("screen", name) for name in outputs_from_portal(os.environ.get("XDPH_OUTPUT_SHARING_LIST", "")))
    response = output.decode("utf-8", errors="replace").strip()
    if child.returncode == 0 and not response:
        return 0  # Intentional cancellation is never a fallback.
    if child.returncode == 0 and response in allowed:
        print(response, flush=True)
        return 0
    log("fallback", reason="picker-failed", exit_code=child.returncode)
    os.execvp("hyprland-share-picker", ["hyprland-share-picker", "--allow-token"])


if __name__ == "__main__":
    try:
        if "--check" in sys.argv:
            check_dependencies()
            log("check", outcome="ok")
            sys.exit(0)
        sys.exit(main() if "--picker" in sys.argv else supervise())
    except Exception as error:
        if "--check" in sys.argv:
            log("check", outcome="failed", reason=str(error))
        else:
            log("fatal", error_type=type(error).__name__)
        sys.exit(1)
