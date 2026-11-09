import importlib.util
import json
import os
from pathlib import Path
import queue
import subprocess
import threading
import unittest

HELPER = Path(__file__).resolve().parents[1] / "bluetooth-agent.py"
spec = importlib.util.spec_from_file_location("bluetooth_agent", HELPER)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
D = "/org/bluez/hci0/dev_AA_BB_CC_DD_EE_FF"
A = "/org/bluez/hci0"


class AgentTests(unittest.TestCase):
  def setUp(self):
    self.calls = []
    self.events = []
    self.timers = {}
    def call(path, interface, method, signature, args, callback, timeout=15000):
      self.calls.append((path, interface, method, args, callback))
    def later(seconds, fn):
      self.timers[1] = (seconds, fn)
      return 1
    self.agent = module.Agent(call, self.events.append, later, lambda token: self.timers.pop(token, None))
    self.agent.objects = {A: {module.ADAPTER: {"Powered": True}},
                          D: {module.DEVICE: {"Adapter": A, "Paired": False}}}

  def request(self, action="pair", **extra):
    self.agent.request({"id": 1, "path": D, "action": action, **extra})

  def complete(self, method, error=""):
    call = next(call for call in reversed(self.calls) if call[2] == method)
    call[4]((), error)

  def test_pair_trust_connect_are_sequential_and_only_confirmed_at_end(self):
    self.request()
    self.assertEqual([c[2] for c in self.calls], ["Pair"])
    self.complete("Pair")
    self.assertEqual(self.calls[-1][2:4], ("Set", (module.DEVICE, "Trusted", True)))
    self.complete("Set")
    self.assertEqual(self.calls[-1][2], "Connect")
    self.assertFalse(any(e["event"] == "result" for e in self.events))
    self.complete("Connect")
    self.assertEqual(self.events[-1]["message"], "Paired, trusted and connected.")

  def test_partial_success_is_not_reported_as_complete(self):
    self.request()
    self.complete("Pair")
    self.complete("Set")
    self.complete("Connect", "Out of range")
    self.assertIn("Paired and trusted, but connection failed", self.events[-1]["error"])

  def test_failed_pair_never_trusts_or_connects(self):
    self.request()
    self.complete("Pair", "Authentication failed")
    self.assertEqual([c[2] for c in self.calls], ["Pair", "CancelPairing"])
    self.assertEqual(self.events[-1]["error"], "Authentication failed")

  def test_cancellation_invalidates_prompts_and_late_completion(self):
    replies = []
    self.request()
    self.agent.agent_request("RequestConfirmation", (D, 1234), lambda *args: replies.append(args))
    token = self.agent.prompt["token"]
    self.agent.close()
    self.complete("Pair")
    self.agent.answer({"token": token, "accept": True})
    self.assertEqual(replies, [(None, "org.bluez.Error.Canceled")])
    self.assertNotIn("Set", [c[2] for c in self.calls])

  def test_unrelated_requests_are_rejected_even_while_pairing(self):
    self.request()
    replies = []
    self.agent.agent_request("RequestAuthorization", (D + "0",), lambda *args: replies.append(args))
    self.assertEqual(replies, [(None, "org.bluez.Error.Rejected")])
    self.assertIsNone(self.agent.prompt)

  def test_cancel_then_retry_waits_for_both_bluez_replies(self):
    self.request()
    self.agent.cancel_pair()
    self.request()
    self.assertEqual(len([call for call in self.calls if call[2] == "Pair"]), 1)
    self.complete("CancelPairing")
    self.request()
    self.assertEqual(len([call for call in self.calls if call[2] == "Pair"]), 1)
    self.complete("Pair", "Canceled")
    self.request()
    self.assertEqual(len([call for call in self.calls if call[2] == "Pair"]), 2)

  def test_passkeys_validate_and_stale_tokens_cannot_answer(self):
    self.request()
    replies = []
    self.agent.agent_request("RequestPasskey", (D,), lambda *args: replies.append(args))
    token = self.agent.prompt["token"]
    for value in ("-1", "1000000", "", "abc", "１２３"):
      self.agent.answer({"token": token, "accept": True, "value": value})
    self.agent.answer({"token": token + 1, "accept": True, "value": "123456"})
    self.assertEqual(replies, [])
    self.agent.answer({"token": token, "accept": True, "value": "001234"})
    self.assertEqual(replies, [((1234,), "")])
    self.assertNotIn("001234", json.dumps(self.events))

  def test_pin_byte_limit_and_rejection(self):
    self.request()
    replies = []
    self.agent.agent_request("RequestPinCode", (D,), lambda *args: replies.append(args))
    token = self.agent.prompt["token"]
    self.agent.answer({"token": token, "accept": True, "value": "é" * 9})
    self.assertEqual(replies, [])
    self.agent.answer({"token": token, "accept": False})
    self.assertEqual(replies, [(None, "org.bluez.Error.Rejected")])

  def test_display_prompts_acknowledge_and_update_entered_count(self):
    self.request()
    replies = []
    self.agent.agent_request("DisplayPasskey", (D, 42, 0), lambda *args: replies.append(args))
    self.agent.agent_request("DisplayPasskey", (D, 42, 3), lambda *args: replies.append(args))
    self.assertEqual(replies, [((), ""), ((), "")])
    self.assertEqual(self.agent.prompt["entered"], 3)

  def test_discovery_owns_its_lease_and_has_a_sixty_second_deadline(self):
    self.agent.objects[A][module.ADAPTER]["Discovering"] = True
    self.request("scan")
    self.assertEqual(self.calls[-1][2], "StartDiscovery")
    self.assertEqual(self.timers[1][0], 60)
    self.complete("StartDiscovery")
    self.assertEqual(self.agent.seen, [])  # Cached devices are not fresh sightings.
    self.agent.changed(D, {module.DEVICE: {"Adapter": A, "RSSI": -50}})
    self.assertEqual(self.agent.seen, [D])
    self.timers[1][1]()
    self.assertFalse(self.agent.scanning)
    self.assertEqual(self.calls[-1][2], "StopDiscovery")
    self.assertEqual(self.agent.seen, [D])  # Results survive scan completion.

  def test_late_discovery_start_is_released_after_close(self):
    self.request("scan")
    self.agent.close()
    self.complete("StartDiscovery")
    self.assertEqual(self.calls[-1][2], "StopDiscovery")
    self.assertFalse(self.agent.scanning)

  def test_partial_scan_failure_keeps_working_adapter_lease(self):
    other = "/org/bluez/hci1"
    self.agent.objects[other] = {module.ADAPTER: {"Powered": True}}
    self.request("scan")
    starts = [call for call in self.calls if call[2] == "StartDiscovery"]
    starts[0][4]((), "")
    starts[1][4]((), "Permission denied")
    self.assertTrue(self.agent.scanning)
    self.assertEqual(self.agent.scan_adapters, {A})
    self.assertIn("Permission denied", self.events[-1]["error"])

  def test_rescan_waits_for_previous_discovery_calls_to_drain(self):
    self.request("scan")
    self.agent.stop_scan()
    self.request("scan")
    self.assertEqual(len([call for call in self.calls if call[2] == "StartDiscovery"]), 1)
    self.complete("StartDiscovery")
    self.request("scan")
    self.assertEqual(len([call for call in self.calls if call[2] == "StartDiscovery"]), 1)
    self.complete("StopDiscovery")
    self.request("scan")
    self.assertEqual(len([call for call in self.calls if call[2] == "StartDiscovery"]), 2)

  def test_removed_device_cannot_be_retargeted_by_late_reply(self):
    self.request()
    self.agent.removed(D, [module.DEVICE])
    self.agent.changed(D, {module.DEVICE: {"Adapter": A}})
    self.complete("Pair")
    self.assertNotIn("Set", [c[2] for c in self.calls])
    self.assertIn("disappeared", self.events[-1]["error"])

  def test_forget_uses_owning_adapter_and_removal_is_confirmation(self):
    self.request("forget")
    self.assertEqual(self.calls[0][:4], (A, module.ADAPTER, "RemoveDevice", (D,)))
    self.agent.removed(D, [module.DEVICE])
    self.complete("RemoveDevice")
    self.assertEqual(len([event for event in self.events if event["event"] == "result"]), 1)
    self.assertEqual(self.events[-1]["message"], "Device forgotten.")

  def test_competing_actions_do_not_overwrite_pending_target(self):
    self.request()
    self.agent.request({"id": 2, "action": "disconnect", "path": D})
    self.assertEqual(len(self.calls), 1)
    self.assertEqual(self.agent.pending["id"], 1)
    self.assertIn("pending", self.events[-1]["error"])


class PrivateBusTests(unittest.TestCase):
  def test_real_agent_transport_on_isolated_dbus(self):
    """Exercise Gio export, async calls and stdin protocol without real BlueZ."""
    try:
      from gi.repository import Gio, GLib
    except ImportError:
      self.skipTest("python-gobject is not installed")
    test_bus = Gio.TestDBus.new(Gio.TestDBusFlags.NONE)
    test_bus.up()
    connection = Gio.DBusConnection.new_for_address_sync(test_bus.get_bus_address(),
      Gio.DBusConnectionFlags.AUTHENTICATION_CLIENT | Gio.DBusConnectionFlags.MESSAGE_BUS_CONNECTION, None, None)
    connection.call_sync("org.freedesktop.DBus", "/org/freedesktop/DBus", "org.freedesktop.DBus", "RequestName",
                         GLib.Variant("(su)", ("org.bluez", 0)), None, Gio.DBusCallFlags.NONE, 5000, None)
    methods = []
    registration = {}
    prompt_methods = iter([("RequestConfirmation", "(ou)", (D, 1234)),
                           ("RequestPinCode", "(o)", (D,)),
                           ("RequestPasskey", "(o)", (D,)),
                           ("RequestConfirmation", "(ou)", (D, 5678))])
    answers = []
    xml = """<node>
      <interface name="org.freedesktop.DBus.ObjectManager"><method name="GetManagedObjects"><arg type="a{oa{sa{sv}}}" direction="out"/></method></interface>
      <interface name="org.bluez.AgentManager1"><method name="RegisterAgent"><arg type="o" direction="in"/><arg type="s" direction="in"/></method><method name="UnregisterAgent"><arg type="o" direction="in"/></method></interface>
      <interface name="org.bluez.Device1"><method name="Pair"/><method name="Connect"/><method name="CancelPairing"/></interface>
      <interface name="org.freedesktop.DBus.Properties"><method name="Set"><arg type="s" direction="in"/><arg type="s" direction="in"/><arg type="v" direction="in"/></method></interface>
      </node>"""
    errors = []

    def method(bus, sender, path, interface, name, parameters, invocation):
      methods.append(name)
      if name == "GetManagedObjects":
        objects = {A: {module.ADAPTER: {"Powered": GLib.Variant("b", True)}},
                   D: {module.DEVICE: {"Adapter": GLib.Variant("o", A), "Paired": GLib.Variant("b", False)}}}
        invocation.return_value(GLib.Variant("(a{oa{sa{sv}}})", (objects,)))
      elif name == "RegisterAgent":
        registration["sender"] = sender
        invocation.return_value(GLib.Variant("()", ()))
      elif name == "Pair":
        if sender != registration["sender"]:
          errors.append("Pair did not use the registered agent's D-Bus connection")
        def confirmed(bus, result):
          try:
            answers.append(bus.call_finish(result).unpack())
            invocation.return_value(GLib.Variant("()", ()))
          except GLib.Error as error:
            errors.append(str(error))
            invocation.return_dbus_error("org.bluez.Error.AuthenticationRejected", "Rejected")
        prompt_method, signature, args = next(prompt_methods)
        connection.call(sender, module.AGENT, "org.bluez.Agent1", prompt_method,
                        GLib.Variant(signature, args), None, Gio.DBusCallFlags.NONE, 5000, None, confirmed)
      else:
        invocation.return_value(GLib.Variant("()", ()))

    for interface in Gio.DBusNodeInfo.new_for_xml(xml).interfaces:
      path = "/" if interface.name.endswith("ObjectManager") else "/org/bluez" if interface.name.endswith("AgentManager1") else D
      connection.register_object(path, interface, method, None, None)
    loop = GLib.MainLoop()
    thread = threading.Thread(target=loop.run, daemon=True)
    thread.start()
    env = dict(os.environ, DBUS_SYSTEM_BUS_ADDRESS=test_bus.get_bus_address())
    process = subprocess.Popen(["python3", "-B", str(HELPER)], stdin=subprocess.PIPE,
                               stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, env=env)
    events = queue.Queue()
    reader = threading.Thread(target=lambda: [events.put(json.loads(line)) for line in process.stdout], daemon=True)
    reader.start()
    def receive(kind):
      for _ in range(20):
        event = events.get(timeout=8)
        self.assertNotEqual(event["event"], "fatal", event)
        if event["event"] == kind:
          return event
      self.fail("Expected event " + kind)
    def send(request):
      process.stdin.write(json.dumps(request) + "\n")
      process.stdin.flush()
    try:
      receive("ready")
      send({"id": 1, "action": "pair", "path": D})
      prompt = receive("prompt")
      if prompt["prompt"] is None:
        prompt = receive("prompt")
      self.assertEqual(prompt["prompt"]["value"], 1234)
      send({"action": "reply", "token": prompt["prompt"]["token"], "accept": True})
      result = receive("result")
      self.assertEqual(result["error"], "")
      self.assertEqual(methods[-2:], ["Set", "Connect"])
      self.assertEqual(errors, [])
      for serial, value in [(2, "synthetic-pin"), (3, "000042")]:
        send({"id": serial, "action": "pair", "path": D})
        prompt = receive("prompt")
        while prompt["prompt"] is None:
          prompt = receive("prompt")
        send({"action": "reply", "token": prompt["prompt"]["token"], "accept": True, "value": value})
        self.assertEqual(receive("result")["error"], "")
      self.assertEqual(answers, [(), ("synthetic-pin",), (42,)])
      send({"id": 4, "action": "pair", "path": D})
      prompt = receive("prompt")
      while prompt["prompt"] is None:
        prompt = receive("prompt")
      # EOF models the settings process exiting/reloading during a pending prompt.
      process.stdin.close()
      self.assertEqual(process.wait(timeout=5), 0)
      self.assertIn("CancelPairing", methods)
      self.assertIn("UnregisterAgent", methods)
      self.assertEqual(process.stderr.read(), "")
    finally:
      if process.poll() is None:
        process.kill()
        process.wait(timeout=5)
      process.stdin.close()
      process.stdout.close()
      process.stderr.close()
      loop.quit()
      thread.join(timeout=2)
      connection.close_sync(None)
      test_bus.down()


if __name__ == "__main__":
  unittest.main()
