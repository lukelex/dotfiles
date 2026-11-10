import importlib.util
from pathlib import Path
import unittest
from unittest.mock import patch
import subprocess
import threading
import tempfile
import os
import time
import sys
from concurrent.futures import ThreadPoolExecutor
from unittest.mock import Mock


PICKER = Path(__file__).resolve().parents[1] / "share-picker.py"
spec = importlib.util.spec_from_file_location("hypr_share_picker", PICKER)
picker = importlib.util.module_from_spec(spec)
spec.loader.exec_module(picker)


class SharePickerTest(unittest.TestCase):
    def test_real_supervisor_executes_fallback_when_ipc_fails(self):
        with tempfile.TemporaryDirectory() as directory:
            for name, code in (
                ("hyprctl", "raise SystemExit(1)"),
                ("hyprland-share-picker", "print('[SELECTION]r/window:123')"),
            ):
                path = Path(directory) / name
                path.write_text(f"#!{sys.executable}\n{code}\n")
                path.chmod(0o755)
            env = os.environ.copy()
            env["PATH"] = directory + os.pathsep + env["PATH"]
            result = subprocess.run([sys.executable, str(PICKER)], env=env, capture_output=True, timeout=5)
            self.assertEqual(result.returncode, 0, result.stderr.decode())
            self.assertEqual(result.stdout, b"[SELECTION]r/window:123\n")
            self.assertIn(b'"event": "fallback"', result.stderr)

    def test_address_reuse_and_missing_identity_cannot_select_another_window(self):
        window = {"id": 123, "address": 456, "stableId": "a"}
        self.assertTrue(picker.window_available(window, {456: {"stableId": "a"}}))
        self.assertFalse(picker.window_available(window, {456: {"stableId": "b"}}))
        self.assertFalse(picker.window_available(window, {}))
        self.assertFalse(picker.window_available({"address": 456}, {456: {"stableId": "a"}}))
        self.assertFalse(picker.window_available(window, {456: {"stableId": "a", "mapped": False}}))

    def test_unicode_output_lengths_are_bytes_and_geometry_is_not_used_for_capture(self):
        self.assertEqual(picker.outputs_from_portal("5:écran:-1920:-100:1920:1080;"), [])
        self.assertEqual(picker.outputs_from_portal("6:écran:-1920:-100:1920:1080;"), ["écran"])
        for scale in (1, 1.25, 2):
            self.assertEqual(picker.window_capture_args({"address": 1}, {1: {"stableId": "abc", "scale": scale, "at": [-100, 50]}}), ("-T", "abc"))

    def test_supervisor_selection_cancel_crash_and_invalid_response(self):
        env = {"XDPH_WINDOW_SHARING_LIST": "123[HC>]app[HT>]title[HE>]456[HA>]"}
        for code, output, fallback, expected in (
            (0, b"[SELECTION]r/window:123\n", False, "[SELECTION]r/window:123"),
            (0, b"", False, None),
            (1, b"", True, None),
            (-11, b"", True, None),
            (0, b"[SELECTION]r/window:456", True, None),
            (0, b"debug\n[SELECTION]r/window:123", True, None),
        ):
            child = Mock(returncode=code)
            child.communicate.return_value = (output, None)
            with self.subTest(code=code, output=output), patch.dict(os.environ, env, clear=True), patch.object(picker.subprocess, "Popen", return_value=child), patch.object(picker.signal, "signal"), patch.object(picker.os, "execvp") as execute, patch("builtins.print") as emit:
                picker.supervise()
                self.assertEqual(execute.called, fallback)
                if expected:
                    emit.assert_called_once_with(expected, flush=True)
                elif not fallback:
                    emit.assert_not_called()

    def test_real_hung_capture_is_killed_on_close_and_requests_are_independent(self):
        with tempfile.TemporaryDirectory() as directory:
            grim = Path(directory) / "grim"
            grim.write_text("#!/usr/bin/env python3\nimport time\ntime.sleep(60)\n")
            grim.chmod(0o755)
            first, second = picker.Captures(), picker.Captures()
            with patch.dict(os.environ, {"PATH": directory + os.pathsep + os.environ["PATH"]}), ThreadPoolExecutor(max_workers=2) as executor:
                one = executor.submit(first.run, ("-T", "one"))
                two = executor.submit(second.run, ("-T", "two"))
                try:
                    deadline = time.monotonic() + 2
                    while time.monotonic() < deadline:
                        with first.lock, second.lock:
                            if first.processes and second.processes:
                                break
                        time.sleep(0.01)
                    started = time.monotonic()
                    first.close()
                    self.assertIsNone(one.result(timeout=1))
                    self.assertLess(time.monotonic() - started, 1)
                    self.assertFalse(two.done())
                    self.assertIsNone(first.run(("-T", "queued")))
                finally:
                    first.close()
                    second.close()
                self.assertIsNone(two.result(timeout=1))

    def test_capture_uses_stable_id_even_on_another_workspace(self):
        window = {"id": 123, "address": 456}
        clients = {456: {"stableId": "1800000a", "workspace": {"id": 99}}}
        self.assertEqual(picker.window_capture_args(window, clients), ("-T", "1800000a"))
        self.assertEqual(picker.portal_selection("window", window["id"]), "[SELECTION]r/window:123")
        self.assertIsNone(picker.window_capture_args(window, {}))
        self.assertIsNone(picker.window_capture_args(window, {456: {}}))

    def test_transient_capture_failure_is_retried(self):
        with patch.object(picker.subprocess, "check_output", side_effect=[subprocess.TimeoutExpired("grim", 3), b"image"]) as capture:
            self.assertEqual(picker.thumbnail("-T", "1800000a"), b"image")
            self.assertEqual(capture.call_count, 2)
            self.assertEqual(capture.call_args.args[0], ["grim", "-T", "1800000a", "-s", "0.25", "-"])

    def test_persistent_failure_is_bounded_and_shutdown_skips_capture(self):
        with patch.object(picker.subprocess, "check_output", side_effect=OSError) as capture:
            self.assertIsNone(picker.thumbnail("-T", "gone"))
            self.assertEqual(capture.call_count, 2)
            stopped = threading.Event()
            stopped.set()
            self.assertIsNone(picker.thumbnail("-T", "gone", stopped=stopped))
            self.assertEqual(capture.call_count, 2)

    def test_window_ids_are_portal_handles_not_hyprland_addresses(self):
        data = "123[HC>]kitty[HT>]Editor[HE>]456[HA>]789[HC>]Chrome[HT>]Call[HE>]0[HA>]"
        self.assertEqual(
            picker.windows_from_portal(data),
            [
                {"id": 123, "class": "kitty", "title": "Editor", "address": 456},
                {"id": 789, "class": "Chrome", "title": "Call", "address": 0},
            ],
        )
        self.assertEqual(picker.portal_selection("window", 123), "[SELECTION]r/window:123")

    def test_output_names_are_length_prefixed(self):
        self.assertEqual(
            picker.outputs_from_portal("8:HDMI-A-1:0:0:1920:1080;6:DP-1 A:-100:0:100:200;"),
            ["HDMI-A-1", "DP-1 A"],
        )
        self.assertEqual(picker.portal_selection("screen", "HDMI-A-1"), "[SELECTION]r/screen:HDMI-A-1")

    def test_incomplete_output_list_does_not_create_invalid_choices(self):
        self.assertEqual(picker.outputs_from_portal("8:HDMI-A-1:0:0:1920"), [])


if __name__ == "__main__":
    unittest.main()
