import importlib.util
from pathlib import Path
import tempfile
import unittest

spec = importlib.util.spec_from_file_location("memory", Path(__file__).resolve().parents[1] / "scripts/memory-snapshot.py")
memory = importlib.util.module_from_spec(spec)
spec.loader.exec_module(memory)


class SnapshotTest(unittest.TestCase):
  def setUp(self):
    self.temp = tempfile.TemporaryDirectory()
    self.addCleanup(self.temp.cleanup)
    self.proc = Path(self.temp.name)

  def process(self, pid, parent, name, pss=10):
    directory = self.proc / str(pid)
    directory.mkdir()
    fields = ["S", str(parent), *(["0"] * 17), "123"]
    (directory / "stat").write_text(f"{pid} ({name}) " + " ".join(fields))
    (directory / "cmdline").write_bytes(name.encode() + b"\0")
    (directory / "smaps_rollup").write_text(
      f"Rss: 200 kB\nPss: {pss} kB\nPrivate_Clean: 2 kB\nPrivate_Dirty: 3 kB\nSwapPss: 4 kB\n")
    return directory

  def test_tree_and_proportional_totals(self):
    self.process(10, 1, "nvim", 10)
    self.process(11, 10, "nvim", 20)
    self.process(12, 11, "node", 30)
    self.process(13, 12, "node", 40)
    self.process(14, 11, "python3", 999)  # Snapshot helper is not editor usage.
    self.process(15, 14, "helper-child", 999)
    self.process(20, 1, "nvim", 999)  # Another editor is not part of this session.
    result = memory.snapshot(11, self.proc, excluded_pid=14)
    self.assertEqual([row["pid"] for row in result["processes"]], [10, 11, 12, 13])
    self.assertEqual([row["depth"] for row in result["processes"]], [0, 1, 2, 3])
    self.assertEqual(result["totals"]["pss_kib"], 100)
    self.assertEqual(result["totals"]["rss_kib"], 800)
    self.assertEqual(result["totals"]["swap_kib"], 16)

  def test_missing_measurements_are_partial_not_zero(self):
    self.process(10, 1, "nvim")
    child = self.process(11, 10, "node")
    (child / "smaps_rollup").unlink()
    result = memory.snapshot(10, self.proc)
    self.assertEqual(result["missing"]["pss_kib"], 1)
    self.assertNotIn("pss_kib", result["processes"][1])
    self.assertIn("error", result["processes"][1])

  def test_label_does_not_disclose_shell_arguments(self):
    child = self.process(10, 1, "sh")
    (child / "cmdline").write_bytes(b"/usr/bin/sh\0-c\0/usr/bin/tool --token secret\0")
    self.assertEqual(memory.snapshot(10, self.proc)["processes"][0]["label"], "sh")


if __name__ == "__main__":
  unittest.main()
