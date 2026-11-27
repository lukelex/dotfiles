import Quickshell.Io

// Publish once, after both the exit status and the full output are available.
Process {
  id: probe
  required property list<string> probeCommand
  signal sampled(string output)
  command: ["timeout", "--kill-after=1s", "4s", ...probeCommand]
  stdout: StdioCollector { id: output }
  onExited: (code, status) => probe.sampled(code === 0 && status === 0 ? output.text : "")
}
