"""Opt-in real GTK/Hyprland smoke tests; briefly opens and closes picker windows."""

import json
import os
from pathlib import Path
import subprocess
import sys
import unittest
import uuid
import tempfile


PICKER = Path(__file__).resolve().parents[1] / "share-picker.py"
DRIVER = r'''
import importlib.util, sys
import gi
gi.require_version("Gtk", "4.0")
from gi.repository import Gtk, GLib
spec = importlib.util.spec_from_file_location("picker", sys.argv[1])
picker = importlib.util.module_from_spec(spec)
spec.loader.exec_module(picker)
mode = sys.argv[2]
buttons = []
original_connect = Gtk.Button.connect
def connect(button, name, callback, *args):
    if name == "clicked" and callback.__name__ == "select":
        buttons.append(button)
    return original_connect(button, name, callback, *args)
Gtk.Button.connect = connect
original_present = Gtk.ApplicationWindow.present
def present(window):
    original_present(window)
    def finish():
        if mode in ("select", "unavailable"):
            if mode == "unavailable":
                def labels(widget):
                    if isinstance(widget, Gtk.Label):
                        yield widget.get_label()
                    child = widget.get_first_child()
                    while child:
                        yield from labels(child)
                        child = child.get_next_sibling()
                assert "Preview unavailable" in list(labels(window))
            buttons[0].emit("clicked")
        else:
            window.close()
        return False
    GLib.timeout_add(1200, finish)
Gtk.ApplicationWindow.present = present
sys.exit(picker.main())
'''


@unittest.skipUnless(os.environ.get("SHARE_PICKER_GUI_TESTS") == "1", "requires a live Hyprland desktop")
class SharePickerGuiTest(unittest.TestCase):
    def test_failed_previews_do_not_prevent_selection(self):
        clients = json.loads(subprocess.check_output(["hyprctl", "clients", "-j"]))
        client = next(c for c in clients if c.get("stableId") and c.get("mapped"))
        with tempfile.TemporaryDirectory() as directory:
            grim = Path(directory) / "grim"
            grim.write_text(f"#!{sys.executable}\nraise SystemExit(1)\n")
            grim.chmod(0o755)
            env = os.environ.copy()
            env["PATH"] = directory + os.pathsep + env["PATH"]
            env["XDPH_WINDOW_SHARING_LIST"] = f'123[HC>]{client["class"]}[HT>]Integration test[HE>]{int(client["address"], 16)}[HA>]'
            env["XDPH_OUTPUT_SHARING_LIST"] = ""
            result = subprocess.run([sys.executable, "-c", DRIVER, str(PICKER), "unavailable"], env=env, capture_output=True, timeout=12)
            self.assertEqual(result.returncode, 0, result.stderr.decode())
            self.assertEqual(result.stdout, b"[SELECTION]r/window:123\n")
            self.assertIn(b'"outcome": "unavailable"', result.stderr)

    def test_real_portal_cancellation(self):
        import gi
        from gi.repository import Gio, GLib

        bus = Gio.bus_get_sync(Gio.BusType.SESSION, None)
        destination = "org.freedesktop.portal.Desktop"
        interface = "org.freedesktop.portal.ScreenCast"
        root = "/org/freedesktop/portal/desktop"
        previous = {c["address"] for c in json.loads(subprocess.check_output(["hyprctl", "clients", "-j"]))}
        closed = []

        def request(method, signature, arguments):
            loop = GLib.MainLoop()
            responses = []
            expected = []
            def response(_bus, _sender, path, _interface, _signal, parameters, _data):
                if expected and path == expected[0]:
                    responses.append(parameters.unpack())
                    loop.quit()
            subscription = bus.signal_subscribe(destination, "org.freedesktop.portal.Request", "Response", None, None, Gio.DBusSignalFlags.NONE, response, None)
            def close_picker():
                clients = json.loads(subprocess.check_output(["hyprctl", "clients", "-j"]))
                for client in clients:
                    if client["address"] not in previous and client["class"] == "dev.dotfiles.hypr-share-picker":
                        subprocess.run(["hyprctl", "eval", f'hl.dispatch(hl.dsp.window.close({{window="address:{client["address"]}"}}))'], check=True, stdout=subprocess.DEVNULL)
                        previous.add(client["address"])
                        closed.append(True)
                return True
            timer = GLib.timeout_add(100, close_picker)
            timeout = GLib.timeout_add_seconds(12, lambda: loop.quit() or True)
            try:
                result = bus.call_sync(destination, root, interface, method, GLib.Variant(signature, arguments), GLib.VariantType.new("(o)"), Gio.DBusCallFlags.NONE, 5000, None)
                expected.append(result.unpack()[0])
                loop.run()
                self.assertTrue(responses, f"{method} timed out")
                return responses[0]
            finally:
                bus.signal_unsubscribe(subscription)
                GLib.source_remove(timer)
                GLib.source_remove(timeout)

        token = "test" + uuid.uuid4().hex
        code, result = request("CreateSession", "(a{sv})", ({"session_handle_token": GLib.Variant("s", token)},))
        self.assertEqual(code, 0)
        session = result["session_handle"]
        try:
            code, _ = request("SelectSources", "(oa{sv})", (session, {"types": GLib.Variant("u", 3)}))
            if code == 0:
                code, _ = request("Start", "(osa{sv})", (session, "", {}))
            self.assertEqual(code, 1, "Closing the picker must cancel the portal request")
            self.assertTrue(closed, "The custom picker must have opened through the real portal")
        finally:
            try:
                bus.call_sync(destination, session, "org.freedesktop.portal.Session", "Close", None, None, Gio.DBusCallFlags.NONE, 3000, None)
            except GLib.Error:
                pass  # Cancellation can already have closed the session.

    def test_real_capture_selection_and_concurrent_cancellation(self):
        clients = json.loads(subprocess.check_output(["hyprctl", "clients", "-j"]))
        client = next(c for c in clients if c.get("stableId") and c.get("mapped") and c["class"] != "xwaylandvideobridge")
        env = os.environ.copy()
        env["XDPH_WINDOW_SHARING_LIST"] = f'123[HC>]{client["class"]}[HT>]Integration test[HE>]{int(client["address"], 16)}[HA>]'
        env["XDPH_OUTPUT_SHARING_LIST"] = ""
        children = [subprocess.Popen([sys.executable, "-c", DRIVER, str(PICKER), mode], env=env, stdout=subprocess.PIPE, stderr=subprocess.PIPE) for mode in ("select", "cancel")]
        try:
            for child, expected in zip(children, (b"[SELECTION]r/window:123\n", b"")):
                stdout, stderr = child.communicate(timeout=12)
                self.assertEqual(child.returncode, 0, stderr.decode())
                self.assertEqual(stdout, expected)
                self.assertIn(b'"outcome": "ok"', stderr)
                self.assertNotIn(b"Traceback", stderr)
        finally:
            for child in children:
                if child.poll() is None:
                    child.kill()
                child.communicate()
