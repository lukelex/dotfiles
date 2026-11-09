#!/usr/bin/env python3
"""Page-scoped BlueZ agent. JSON lines on stdin/stdout; never log pairing data.

The same D-Bus connection registers Agent1 and calls Pair so BlueZ routes prompts
to this agent. We do not request default-agent status and reject unsolicited
requests even if BlueZ elects us default. Native Quickshell owns UI observations.
"""

import json
import os
import signal
import sys

DEVICE = "org.bluez.Device1"
ADAPTER = "org.bluez.Adapter1"
PROPERTIES = "org.freedesktop.DBus.Properties"
AGENT = "/org/quickshell/BluetoothAgent"


class Agent:
  """Transport-independent request lifecycle, also exercised by isolated tests."""

  def __init__(self, call, emit, later, cancel_timer):
    self.call = call
    self.emit = emit
    self.later = later
    self.cancel_timer = cancel_timer
    self.objects = {}
    self.pending = None
    self.pair_request = None
    self.cancel_pending = 0
    self.prompt = None
    self.prompt_serial = 0
    self.scanning = False
    self.scan_generation = 0
    self.scan_timer = None
    self.scan_adapters = set()
    self.scan_pending = 0
    self.seen = []
    self.closed = False

  def result(self, request, error="", message=""):
    self.emit({"event": "result", "id": request.get("id"),
               "path": request.get("path", ""), "error": error, "message": message})

  def finish(self, request, error="", message=""):
    if self.pending is not request:
      return
    self.clear_prompt()
    self.pending = None
    self.result(request, error, message)

  def clear_prompt(self):
    if self.prompt and self.prompt.get("reply"):
      self.prompt["reply"](None, "org.bluez.Error.Canceled")
    self.prompt = None
    self.emit({"event": "prompt", "prompt": None})

  def cancel_pair(self):
    request = self.pending
    if not request or request["action"] != "pair":
      return
    # Invalidate first: completion racing cancellation cannot trust/connect.
    self.finish(request, "Pairing canceled.")
    self.cancel_device(request["path"])

  def cancel_device(self, path):
    self.cancel_pending += 1
    def canceled(value, error):
      self.cancel_pending -= 1
    self.call(path, DEVICE, "CancelPairing", None, (), canceled, 5000)

  def request(self, request):
    if self.closed or not isinstance(request, dict):
      return
    action = request.get("action")
    if action == "reply":
      self.answer(request)
      return
    if action == "cancel":
      self.cancel_pair()
      return
    if action == "stopScan":
      self.stop_scan()
      return
    if action == "scan":
      self.start_scan(request)
      return
    if action not in ("pair", "connect", "disconnect", "forget"):
      self.result(request, "Unsupported Bluetooth action.")
      return
    if self.pending or self.pair_request or self.cancel_pending:
      self.result(request, "Another device action is still pending.")
      return
    path = request.get("path")
    if not isinstance(path, str):
      self.result(request, "Invalid device identity.")
      return
    device = self.objects.get(path, {}).get(DEVICE)
    if not device:
      self.result(request, "Device is no longer available.")
      return
    self.pending = request
    if action == "pair":
      if device.get("Paired"):
        self.finish(request, "Device is already paired. Use Connect instead.")
        return
      self.pair_request = request
      self.call(path, DEVICE, "Pair", None, (),
                lambda value, error: self.paired(request, error), 90000)
    elif action == "forget":
      self.call(device["Adapter"], ADAPTER, "RemoveDevice", "(o)", (path,),
                lambda value, error: self.finish(request, error, "Device forgotten."), 15000)
    else:
      self.call(path, DEVICE, "Connect" if action == "connect" else "Disconnect", None, (),
                lambda value, error: self.finish(request, error,
                  "Connected." if action == "connect" else "Disconnected."), 30000)

  def paired(self, request, error):
    if self.pair_request is request:
      self.pair_request = None
    if self.pending is not request:
      return
    if error:
      self.cancel_device(request["path"])
      self.finish(request, error)
      return
    self.clear_prompt()
    self.call(request["path"], PROPERTIES, "Set", "(ssv)", (DEVICE, "Trusted", True),
              lambda value, failure: self.trusted(request, failure), 10000)

  def trusted(self, request, error):
    if self.pending is not request:
      return
    if error:
      self.finish(request, "Paired, but could not enable automatic reconnection: " + error)
      return
    self.call(request["path"], DEVICE, "Connect", None, (),
              lambda value, failure: self.finish(request,
                "Paired and trusted, but connection failed: " + failure if failure else "",
                "Paired, trusted and connected."), 30000)

  def agent_request(self, method, args, reply):
    if method in ("Cancel", "Release"):
      self.clear_prompt()
      reply((), "")
      if method == "Release":
        self.cancel_pair()
      return
    path = args[0] if args else ""
    if self.closed or not self.pending or self.pending["action"] != "pair" or self.pending["path"] != path:
      reply(None, "org.bluez.Error.Rejected")
      return
    supported = ("RequestPinCode", "RequestPasskey", "DisplayPinCode", "DisplayPasskey",
                 "RequestConfirmation", "RequestAuthorization", "AuthorizeService")
    if method not in supported:
      reply(None, "org.bluez.Error.Rejected")
      return
    display = method.startswith("Display")
    if display and self.prompt and self.prompt["kind"] == method and self.prompt["path"] == path:
      self.prompt.update(value=args[1], entered=args[2] if len(args) > 2 else 0)
      self.emit({"event": "prompt", "prompt": {key: value for key, value in self.prompt.items() if key != "reply"}})
      reply((), "")
      return
    self.clear_prompt()
    self.prompt_serial += 1
    self.prompt = {"token": self.prompt_serial, "path": path, "kind": method,
                   "value": args[1] if len(args) > 1 else "",
                   "entered": args[2] if len(args) > 2 else 0,
                   "reply": None if display else reply}
    self.emit({"event": "prompt", "prompt": {key: value for key, value in self.prompt.items() if key != "reply"}})
    if display:
      reply((), "")

  def answer(self, request):
    prompt = self.prompt
    if not prompt or request.get("token") != prompt["token"] or not prompt["reply"]:
      return
    value = request.get("value", "")
    accepted = request.get("accept") is True
    if accepted and prompt["kind"] == "RequestPinCode":
      if not isinstance(value, str) or not 1 <= len(value.encode("utf-8")) <= 16 or "\x00" in value:
        return
      result = (value,)
    elif accepted and prompt["kind"] == "RequestPasskey":
      if not isinstance(value, str) or not value.isascii() or not value.isdigit() or len(value) > 6:
        return
      result = (int(value),)
    else:
      result = ()
    self.prompt = None
    prompt["reply"](result if accepted else None, "" if accepted else "org.bluez.Error.Rejected")
    self.emit({"event": "prompt", "prompt": None})

  def scan_state(self):
    self.emit({"event": "scan", "active": self.scanning, "seen": self.seen})

  def start_scan(self, request):
    if self.scanning or self.scan_pending:
      self.result(request, "Discovery is still starting or stopping. Try again shortly.")
      self.scan_state()
      return
    adapters = [path for path, interfaces in self.objects.items() if interfaces.get(ADAPTER, {}).get("Powered")]
    if not adapters:
      self.result(request, "No powered Bluetooth adapters are available.")
      self.scan_state()
      return
    self.scanning = True
    self.scan_generation += 1
    generation = self.scan_generation
    self.seen = []
    self.scan_state()
    self.scan_timer = self.later(60, self.stop_scan)
    remaining = set(adapters)
    errors = []

    def started(path, error):
      self.scan_pending -= 1
      if generation != self.scan_generation or not self.scanning:
        if not error:
          self.release_scan(path)
        return
      if error:
        errors.append(path.rsplit("/", 1)[-1] + ": " + error)
      else:
        self.scan_adapters.add(path)
      remaining.discard(path)
      if not remaining:
        self.result(request, "; ".join(errors))
        if not self.scan_adapters:
          self.stop_scan()

    for path in adapters:
      # Acquire our own session even when another client is already discovering.
      self.scan_pending += 1
      self.call(path, ADAPTER, "StartDiscovery", None, (),
                lambda value, error, path=path: started(path, error), 15000)

  def release_scan(self, path):
    self.scan_pending += 1
    def released(value, error):
      self.scan_pending -= 1
      if error and not self.closed:
        self.emit({"event": "scanError", "error": "Could not stop discovery: " + error + ". Close Bluetooth settings to release its discovery session."})
    self.call(path, ADAPTER, "StopDiscovery", None, (), released, 5000)

  def stop_scan(self):
    if self.scan_timer:
      self.cancel_timer(self.scan_timer)
      self.scan_timer = None
    self.scanning = False
    self.scan_generation += 1
    for path in self.scan_adapters:
      self.release_scan(path)
    self.scan_adapters.clear()
    self.scan_state()
    return False

  def changed(self, path, interfaces):
    self.objects.setdefault(path, {}).update(interfaces)
    if self.scanning and DEVICE in interfaces and path not in self.seen:
      self.seen.append(path)
      self.scan_state()

  def removed(self, path, interfaces):
    for interface in interfaces:
      self.objects.get(path, {}).pop(interface, None)
    if path in self.seen:
      self.seen.remove(path)
      self.scan_state()
    if self.pending and self.pending["path"] == path and DEVICE in interfaces:
      if self.pending["action"] == "forget":
        self.finish(self.pending, message="Device forgotten.")
      else:
        self.finish(self.pending, "Device disappeared during the operation.")
    if ADAPTER in interfaces:
      self.scan_adapters.discard(path)

  def close(self):
    self.closed = True
    self.cancel_pair()
    self.clear_prompt()
    self.stop_scan()


AGENT_XML = """<node><interface name="org.bluez.Agent1">
<method name="Release"/><method name="Cancel"/>
<method name="RequestPinCode"><arg type="o" direction="in"/><arg type="s" direction="out"/></method>
<method name="DisplayPinCode"><arg type="o" direction="in"/><arg type="s" direction="in"/></method>
<method name="RequestPasskey"><arg type="o" direction="in"/><arg type="u" direction="out"/></method>
<method name="DisplayPasskey"><arg type="o" direction="in"/><arg type="u" direction="in"/><arg type="q" direction="in"/></method>
<method name="RequestConfirmation"><arg type="o" direction="in"/><arg type="u" direction="in"/></method>
<method name="RequestAuthorization"><arg type="o" direction="in"/></method>
<method name="AuthorizeService"><arg type="o" direction="in"/><arg type="s" direction="in"/></method>
</interface></node>"""


def main():
  from gi.repository import Gio, GLib, GLibUnix

  loop = GLib.MainLoop()
  bus = Gio.bus_get_sync(Gio.BusType.SYSTEM, None)
  bluez_owner = bus.call_sync("org.freedesktop.DBus", "/org/freedesktop/DBus", "org.freedesktop.DBus",
                             "GetNameOwner", GLib.Variant("(s)", ("org.bluez",)),
                             None, Gio.DBusCallFlags.NONE, 5000, None).unpack()[0]
  closing = False

  def emit(event):
    try:
      print(json.dumps(event), flush=True)
    except BrokenPipeError:
      shutdown()

  def call(path, interface, method, signature, args, callback, timeout=15000):
    if signature == "(ssv)":
      args = (args[0], args[1], GLib.Variant("b", args[2]))
    parameters = GLib.Variant(signature, args) if signature else None

    def completed(connection, result):
      try:
        value = connection.call_finish(result)
      except GLib.Error as error:
        # BlueZ errors contain no credentials. Strip remote wrapper, keep reason.
        Gio.DBusError.strip_remote_error(error)
        callback(None, error.message)
      else:
        callback(value.unpack() if value else (), "")

    bus.call("org.bluez", path, interface, method, parameters, None,
             Gio.DBusCallFlags.NONE, timeout, None, completed)

  agent = Agent(call, emit, lambda seconds, fn: GLib.timeout_add_seconds(seconds, fn), GLib.source_remove)

  def shutdown():
    nonlocal closing
    if closing:
      return False
    closing = True
    agent.close()
    call("/org/bluez", "org.bluez.AgentManager1", "UnregisterAgent", "(o)", (AGENT,), lambda *_: None, 1000)
    # Allow CancelPairing/StopDiscovery replies to drain; disconnect also releases
    # discovery leases and the agent if BlueZ or the bus is unavailable.
    GLib.timeout_add(250, lambda: (loop.quit(), False)[1])
    return False

  def agent_method(connection, sender, path, interface, method, parameters, invocation):
    if sender != bluez_owner:
      invocation.return_dbus_error("org.bluez.Error.Rejected", "Only BlueZ may invoke the pairing agent.")
      return
    def reply(value, error):
      if error:
        invocation.return_dbus_error(error, "Pairing request rejected or canceled.")
      else:
        signature = "(s)" if method == "RequestPinCode" else "(u)" if method == "RequestPasskey" else "()"
        invocation.return_value(GLib.Variant(signature, value))
    agent.agent_request(method, parameters.unpack(), reply)

  bus.register_object(AGENT, Gio.DBusNodeInfo.new_for_xml(AGENT_XML).interfaces[0], agent_method, None, None)

  def signal_received(connection, sender, path, interface, name, parameters):
    values = parameters.unpack()
    if name == "InterfacesAdded":
      agent.changed(values[0], values[1])
    elif name == "InterfacesRemoved":
      agent.removed(values[0], values[1])
    elif name == "PropertiesChanged":
      iface, changed, invalid = values
      properties = agent.objects.setdefault(path, {}).setdefault(iface, {})
      properties.update(changed)
      for key in invalid:
        properties.pop(key, None)
      # A fresh RSSI/advertisement observation, not an old cached device entry.
      if iface == DEVICE and any(key in changed for key in ("RSSI", "ManufacturerData", "ServiceData")):
        agent.changed(path, {DEVICE: properties})
      if iface == ADAPTER and changed.get("Powered") is False:
        agent.scan_adapters.discard(path)
        if not any(interfaces.get(ADAPTER, {}).get("Powered") for interfaces in agent.objects.values()):
          agent.stop_scan()
        if agent.pending:
          device = agent.objects.get(agent.pending["path"], {}).get(DEVICE, {})
          if device.get("Adapter") == path:
            agent.cancel_pair()

  bus.signal_subscribe("org.bluez", None, None, None, None, Gio.DBusSignalFlags.NONE, signal_received)

  def owner_changed(connection, sender, path, interface, name, parameters):
    _, old, new = parameters.unpack()
    if old and old != new:
      emit({"event": "fatal", "error": "Bluetooth service restarted. Reopen Bluetooth settings to reconnect."})
      shutdown()

  bus.signal_subscribe("org.freedesktop.DBus", "org.freedesktop.DBus", "NameOwnerChanged",
                       "/org/freedesktop/DBus", "org.bluez", Gio.DBusSignalFlags.NONE, owner_changed)

  def registered(value, error):
    if error:
      emit({"event": "fatal", "error": "Could not start Bluetooth pairing agent: " + error})
      shutdown()
    elif not closing:
      emit({"event": "ready"})

  def loaded(value, error):
    if error:
      emit({"event": "fatal", "error": "Bluetooth service unavailable: " + error})
      shutdown()
    elif not closing:
      agent.objects = value[0]
      call("/org/bluez", "org.bluez.AgentManager1", "RegisterAgent", "(os)", (AGENT, "KeyboardDisplay"), registered)

  call("/", "org.freedesktop.DBus.ObjectManager", "GetManagedObjects", None, (), loaded)
  buffer = bytearray()
  os.set_blocking(sys.stdin.fileno(), False)

  def read_input(fd, condition):
    try:
      chunk = os.read(fd, 8192)
    except BlockingIOError:
      return True
    if not chunk:
      shutdown()
      return False
    buffer.extend(chunk)
    if len(buffer) > 65536:
      shutdown()
      return False
    while b"\n" in buffer:
      line, _, rest = buffer.partition(b"\n")
      buffer[:] = rest
      try:
        request = json.loads(line)
      except (ValueError, UnicodeDecodeError):
        continue
      if isinstance(request, dict) and request.get("action") == "shutdown":
        shutdown()
        return False
      agent.request(request)
    return True

  GLib.io_add_watch(sys.stdin.fileno(), GLib.IO_IN | GLib.IO_HUP | GLib.IO_ERR, read_input)
  GLibUnix.signal_add(GLib.PRIORITY_DEFAULT, signal.SIGTERM, shutdown)
  GLibUnix.signal_add(GLib.PRIORITY_DEFAULT, signal.SIGINT, shutdown)
  loop.run()
  bus.close_sync(None)


if __name__ == "__main__":
  try:
    main()
  except Exception:
    # No traceback: incoming agent parameters may include a pairing secret.
    print(json.dumps({"event": "fatal", "error": "Bluetooth helper unavailable. Check BlueZ and python-gobject."}), flush=True)
    sys.exit(1)
