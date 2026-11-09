"""Small LSP fixture: cache an unopened file, updating only on watched-file events."""
import json
from pathlib import Path
import sys

root = Path(sys.argv[1])
opened = {}


def read_state():
  return (root / "state.txt").read_text().strip()


cached = read_state()


def send(message):
  body = json.dumps(dict(jsonrpc="2.0", **message)).encode()
  sys.stdout.buffer.write(f"Content-Length: {len(body)}\r\n\r\n".encode() + body)
  sys.stdout.buffer.flush()


while True:
  headers = {}
  while line := sys.stdin.buffer.readline():
    if line == b"\r\n":
      break
    key, value = line.decode().split(":", 1)
    headers[key.lower()] = value.strip()
  if not headers:
    break
  message = json.loads(sys.stdin.buffer.read(int(headers["content-length"])))
  method = message.get("method")
  params = message.get("params", {})
  if method == "initialize":
    send({"id": message["id"], "result": {"capabilities": {"hoverProvider": True, "textDocumentSync": 1}}})
  elif method == "initialized":
    send({"id": "watch", "method": "client/registerCapability", "params": {"registrations": [{
      "id": "state", "method": "workspace/didChangeWatchedFiles",
      "registerOptions": {"watchers": [{"globPattern": "**/state.txt"}]},
    }]}})
  elif method == "workspace/didChangeWatchedFiles":
    cached = read_state()
  elif method == "textDocument/didOpen":
    doc = params["textDocument"]
    opened[doc["uri"]] = doc["text"]
  elif method == "textDocument/didChange":
    opened[params["textDocument"]["uri"]] = params["contentChanges"][-1]["text"]
  elif method == "textDocument/hover":
    send({"id": message["id"], "result": {"contents": cached + "|" + opened[params["textDocument"]["uri"]]}})
  elif method == "shutdown":
    send({"id": message["id"], "result": None})
  elif method == "exit":
    break
