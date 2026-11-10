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
import importlib.util, sys, io, contextlib
import gi
gi.require_version("Gtk", "4.0")
gi.require_version("Gdk", "4.0")
from gi.repository import Gtk, GLib, Gdk
from pathlib import Path
sys.path.insert(0, str(Path(sys.argv[1]).parent))
from share_picker_ui import Picker
spec = importlib.util.spec_from_file_location("picker", sys.argv[1])
picker = importlib.util.module_from_spec(spec)
spec.loader.exec_module(picker)
mode = sys.argv[2]
output = io.StringIO()
original_present = Picker.present
def present(ui):
    original_present(ui)
    def finish():
        assert ui.kind == "window"
        assert not ui.share.get_sensitive()
        source = next(s for s in ui.sources if s.visible)
        if mode == "lifecycle":
            ui.select(source)
            original_ipc = ui.api.hyprctl
            def without_source(command):
                values = original_ipc(command)
                return [c for c in values if int(c["address"], 16) != source.window["address"]] if command == "clients" else values
            ui.api.hyprctl = without_source
            ui.poll_sources()
            def check_closed():
                assert ui.selected is None
                assert not ui.share.get_sensitive()
                assert not source.cell.get_visible()
                assert "closed" in ui.notice.get_label()
                assert output.getvalue() == ""
                ui.quit()
                return False
            GLib.timeout_add(400, check_closed)
        elif mode in ("select", "unavailable", "ux"):
            if mode == "unavailable":
                assert source.status.get_label() == "Preview unavailable"
            source.button.emit("clicked")
            assert ui.selected is source and ui.share.get_sensitive()
            assert output.getvalue() == "", "Selecting a tile must not share"
            if mode == "ux":
                ui.open_detail()
                assert ui.pages.get_visible_child_name() == "detail"
                ui.escape()
                assert ui.pages.get_visible_child_name() == "browse"
                ui.search.set_text("not-a-real-source-94182")
                ui.filter_sources()
                assert ui.selected is None and not ui.share.get_sensitive()
                ui.escape()
                assert not ui.search.get_text()
                ui.search.grab_focus()
                ui.key_pressed(None, Gdk.KEY_Return, 0, Gdk.ModifierType(0))
                assert ui.selected is source and ui.armed
                assert output.getvalue() == ""
                ui.key_pressed(None, Gdk.KEY_Down, 0, Gdk.ModifierType(0))
                assert not ui.armed
                ui.key_pressed(None, Gdk.KEY_Return, 0, Gdk.ModifierType(0))
                assert ui.armed and output.getvalue() == ""
                ui.key_pressed(None, Gdk.KEY_Return, 0, Gdk.ModifierType(0))
            else:
                ui.share.emit("clicked")
        else:
            source.button.emit("clicked")
            assert output.getvalue() == ""
            ui.window.close()
        return False
    GLib.timeout_add(1200, finish)
Picker.present = present
with contextlib.redirect_stdout(output):
    result = picker.main()
sys.stdout.write(output.getvalue())
sys.exit(result)
'''


@unittest.skipUnless(os.environ.get("SHARE_PICKER_GUI_TESTS") == "1", "requires a live Hyprland desktop")
class SharePickerGuiTest(unittest.TestCase):
    def test_closed_selection_is_removed_without_sharing(self):
        clients = json.loads(subprocess.check_output(["hyprctl", "clients", "-j"]))
        client = next(c for c in clients if c.get("stableId") and c.get("mapped"))
        env = os.environ.copy()
        env["XDPH_WINDOW_SHARING_LIST"] = f'123[HC>]{client["class"]}[HT>]Integration test[HE>]{int(client["address"], 16)}[HA>]'
        env["XDPH_OUTPUT_SHARING_LIST"] = ""
        result = subprocess.run([sys.executable, "-c", DRIVER, str(PICKER), "lifecycle"], env=env, capture_output=True, timeout=12)
        self.assertEqual(result.returncode, 0, result.stderr.decode())
        self.assertEqual(result.stdout, b"")

    def test_search_confirmation_and_expanded_preview(self):
        clients = json.loads(subprocess.check_output(["hyprctl", "clients", "-j"]))
        client = next(c for c in clients if c.get("stableId") and c.get("mapped") and c["class"] != "xwaylandvideobridge")
        env = os.environ.copy()
        env["XDPH_WINDOW_SHARING_LIST"] = f'123[HC>]{client["class"]}[HT>]Integration test[HE>]{int(client["address"], 16)}[HA>]'
        env["XDPH_OUTPUT_SHARING_LIST"] = ""
        result = subprocess.run([sys.executable, "-c", DRIVER, str(PICKER), "ux"], env=env, capture_output=True, timeout=12)
        self.assertEqual(result.returncode, 0, result.stderr.decode())
        self.assertEqual(result.stdout, b"[SELECTION]r/window:123\n")

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
