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

    def run(self, args):
        with self.lock:
            if self.stopped.is_set():
                return None
            process = subprocess.Popen(["grim", *args, "-s", "0.25", "-"], stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
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


def thumbnail(*args, stopped=None, captures=None):
    started = time.monotonic()
    for attempt in range(2):
        if stopped is not None and stopped.is_set():
            return None
        try:
            data = captures.run(args) if captures else subprocess.check_output(["grim", *args, "-s", "0.25", "-"], stderr=subprocess.DEVNULL, timeout=3)
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
        dialog = Gtk.ApplicationWindow(application=application, title="Select what to share")
        active_dialog.append(dialog)
        dialog.set_default_size(760, 795)
        dialog.connect("close-request", lambda *_: application.quit() or False)
        layout = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=12)
        layout.set_margin_top(18)
        layout.set_margin_bottom(18)
        layout.set_margin_start(18)
        layout.set_margin_end(18)
        dialog.set_child(layout)
        heading = Gtk.Label(label="Select what to share", xalign=0)
        heading.add_css_class("title-2")
        layout.append(heading)
        layout.append(Gtk.Label(label="Click a preview to start sharing. Close this window to cancel.", xalign=0))
        notice = Gtk.Label(label="New windows require reopening the share dialog.", xalign=0)
        layout.append(notice)
        tabs = Gtk.Notebook()
        tabs.set_vexpand(True)
        layout.append(tabs)
        refresh = Gtk.Button(label="Refresh previews")
        layout.append(refresh)
        tiles = []
        generation = 0
        pending = 0

        def add_tab(label, entries):
            scroll = Gtk.ScrolledWindow()
            grid = Gtk.FlowBox()
            grid.set_selection_mode(Gtk.SelectionMode.NONE)
            grid.set_max_children_per_line(3)
            grid.set_column_spacing(12)
            grid.set_row_spacing(12)
            grid.set_margin_top(12)
            grid.set_margin_bottom(12)
            scroll.set_child(grid)
            tabs.append_page(scroll, Gtk.Label(label=label))
            if not entries:
                grid.append(Gtk.Label(label=f"No {label.lower()} available"))
            return grid

        def add_tile(grid, kind, identifier, title, capture_args, icon, window=None):
            button = Gtk.Button()
            button.set_tooltip_text(title)
            content = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
            content.set_size_request(210, 150)
            preview = Gtk.Stack()
            preview.set_size_request(210, 120)
            if not Gtk.IconTheme.get_for_display(Gdk.Display.get_default()).has_icon(icon):
                icon = "application-x-executable"
            image = Gtk.Image.new_from_icon_name(icon)
            image.set_pixel_size(72)
            preview.add_named(image, "icon")
            picture = Gtk.Picture()
            picture.set_content_fit(Gtk.ContentFit.CONTAIN)
            preview.add_named(picture, "snapshot")
            content.append(preview)
            status = Gtk.Label(label="Loading preview…" if capture_args else "Preview unavailable")
            status.add_css_class("dim-label")
            content.append(status)
            text = Gtk.Label(label=title, max_width_chars=27, ellipsize=3)
            content.append(text)
            details = Gtk.Label(label=window["class"] if window else "Screen", max_width_chars=27, ellipsize=3)
            content.append(details)
            button.set_child(content)

            def select(*_):
                try:
                    if window:
                        current = {int(c["address"], 16): c for c in hyprctl("clients")}
                        valid = window_available(window, current)
                    else:
                        valid = identifier in {m["name"] for m in hyprctl("monitors")}
                except RuntimeError:
                    notice.set_label("Cannot verify this source. Retry or use the standard picker.")
                    return
                if not valid:
                    button.set_sensitive(False)
                    status.set_label("Source closed or disconnected")
                    return
                print(portal_selection(kind, identifier), flush=True)
                application.quit()

            button.connect("clicked", select)
            grid.append(button)
            tiles.append((capture_args, preview, picture, status))
            sources.append((window, identifier, button, text, details, status))

        def load_previews(*_):
            nonlocal generation, pending
            generation += 1
            current_generation = generation
            pending = sum(args is not None for args, *_ in tiles)
            refresh.set_sensitive(pending == 0)

            def deliver(future, preview, picture, status):
                nonlocal pending
                if stopped.is_set() or current_generation != generation:
                    return False
                try:
                    data = future.result()
                except Exception:
                    log("capture-worker-error")
                    data = None
                if data:
                    try:
                        picture.set_paintable(Gdk.Texture.new_from_bytes(GLib.Bytes.new(data)))
                        preview.set_visible_child_name("snapshot")
                        status.set_label("")
                    except GLib.Error:
                        data = None
                if not data:
                    picture.set_paintable(None)
                    preview.set_visible_child_name("icon")
                    status.set_label("Preview unavailable")
                pending -= 1
                refresh.set_sensitive(pending == 0)
                return False

            for args, preview, picture, status in tiles:
                if args is None:
                    continue
                status.set_label("Loading preview…")
                future = executor.submit(thumbnail, *args, stopped=stopped, captures=captures)
                future.add_done_callback(
                    lambda result, p=preview, pic=picture, s=status:
                    GLib.idle_add(deliver, result, p, pic, s) if not stopped.is_set() else None
                )

        sources = []
        screen_grid = add_tab("Screens", outputs)
        for name in outputs:
            monitor = monitors.get(name, {})
            title = monitor.get("description") or name
            add_tile(screen_grid, "screen", name, title, ("-o", name), "video-display")

        window_grid = add_tab("Windows", windows)
        for window in windows:
            add_tile(window_grid, "window", window["id"], window["title"] or window["class"], window_capture_args(window, clients), window["class"].lower() or "application-x-executable", window)

        lifecycle_busy = False
        def update_sources(future):
            nonlocal lifecycle_busy
            lifecycle_busy = False
            if stopped.is_set():
                return False
            try:
                current, screens = future.result()
            except Exception:
                notice.set_label("Hyprland unavailable. Retry or use the standard picker.")
                return False
            notice.set_label("New windows require reopening the share dialog.")
            for window, identifier, button, text, details, status in sources:
                valid = window_available(window, current) if window else identifier in screens
                button.set_sensitive(valid)
                if not valid:
                    status.set_label("Source closed or disconnected")
                elif window:
                    client = current[window["address"]]
                    text.set_label(client.get("title") or window["class"])
                    button.set_tooltip_text(client.get("title") or window["class"])
                    workspace = client.get("workspace", {}).get("name", "?")
                    details.set_label(f'{window["class"]} · Workspace {workspace}')
            return False

        def poll_sources():
            nonlocal lifecycle_busy
            if stopped.is_set():
                return False
            if not lifecycle_busy:
                lifecycle_busy = True
                future = executor.submit(lambda: (
                    {int(c["address"], 16): c for c in hyprctl("clients")},
                    {m["name"] for m in hyprctl("monitors")},
                ))
                future.add_done_callback(lambda result: GLib.idle_add(update_sources, result) if not stopped.is_set() else None)
            return True

        standard = Gtk.Button(label="Use standard picker")
        standard.connect("clicked", lambda *_: failed.append(True) or application.quit())
        layout.append(standard)
        GLib.timeout_add_seconds(2, poll_sources)
        poll_sources()

        if not outputs and windows:
            tabs.set_current_page(1)
        dialog.present()
        refresh.connect("clicked", load_previews)
        load_previews()

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
