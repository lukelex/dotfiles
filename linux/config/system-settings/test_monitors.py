import json
import multiprocessing
import os
from pathlib import Path
import tempfile
import time
import unittest
from unittest.mock import patch, Mock

import monitors as m


def output(name='DP-1', identity='edid:aabb', **changes):
  value = dict(m.base_output(name), identity=identity, enabled=True,
    modes=[{'mode': '1920x1080', 'rate': 60}, {'mode': '2560x1440', 'rate': 60}])
  value.update(changes)
  return value


class MonitorTests(unittest.TestCase):
  def setUp(self):
    self.temp = tempfile.TemporaryDirectory(prefix='monitor-tests-')
    self.addCleanup(self.temp.cleanup)
    self.root = Path(self.temp.name)
    self.enterContext(patch.object(m, 'RUNTIME', self.root / 'runtime'))
    self.enterContext(patch.object(m, 'STORE', self.root / 'profiles.json'))
    self.enterContext(patch.object(m, 'SESSION', 'x11'))
    self.enterContext(patch.dict(os.environ, XDG_CONFIG_HOME=str(self.root / 'config')))
    m.write_json(m.STORE, {'version': 1, 'automatic': True, 'profiles': []})

  def test_rejects_unsafe_or_malformed_layouts(self):
    for changes in [dict(enabled=False), dict(rate=0), dict(scale=float('nan')),
      dict(x=-1), dict(y=1.2), dict(connector='DP-1;evil'), dict(rotation='flip'), dict(identity='bad\nvalue')]:
      with self.subTest(changes=changes), self.assertRaises(ValueError):
        m.validate_outputs([output(**changes)])
    with self.assertRaises(ValueError):
      m.validate_outputs([output(), output()])

  def test_color_depth_validation_and_legacy_profiles(self):
    for depth in [True, 12, '10', None]:
      with self.assertRaises(ValueError):
        m.validate_outputs([output(bitDepth=depth)])
    with patch.object(m, 'SESSION', 'wayland'):
      current = output(bitDepth=10, tenBitAvailable=True)
      self.assertEqual(m.resolve([output()], [current])[0]['bitDepth'], 10)
      self.assertEqual(m.clean([current])[0]['bitDepth'], 10)
      self.assertNotIn('tenBitAvailable', m.clean([current])[0])
      for current in [output(bitDepth=8, tenBitAvailable=False), output()]:
        with self.assertRaises(ValueError):
          m.resolve([output(bitDepth=10)], [current])
    with self.assertRaisesRegex(ValueError, 'Hyprland'):
      m.resolve([output(bitDepth=10)], [output()])

  def test_ten_bit_capability_requires_edid_or_observed_ten_bit(self):
    connector = self.root / 'card1-DP-1'
    connector.mkdir()
    edid = bytearray(128)
    edid[:8] = bytes.fromhex('00ffffffffffff00')
    edid[18:21] = bytes([1, 4, 0xb0])
    edid[127] = -sum(edid[:127]) % 256
    (connector / 'edid').write_bytes(edid)
    with patch.object(m.Path, 'glob', return_value=[connector]):
      self.assertTrue(m.color_capability('DP-1', 8)['tenBitAvailable'])
      self.assertFalse(m.color_capability('DP-1', None)['tenBitAvailable'])
      edid[20] = 0xa0
      edid[127] = -sum(edid[:127]) % 256
      (connector / 'edid').write_bytes(edid)
      self.assertFalse(m.color_capability('DP-1', 8)['tenBitAvailable'])
    with patch.object(m.Path, 'glob', return_value=[]):
      self.assertFalse(m.color_capability('DP-1', 8)['tenBitAvailable'])
      self.assertTrue(m.color_capability('DP-1', 10)['tenBitAvailable'])
    self.assertIsNone(m.format_depth('unknown'))
    self.assertEqual(m.format_depth('XRGB2101010'), 10)
    self.assertEqual(m.format_depth('XRGB8888'), 8)

  def test_hdmi_deep_color_flag_and_checksum(self):
    edid = bytearray(256)
    edid[:8] = bytes.fromhex('00ffffffffffff00')
    edid[128:132] = bytes([2, 3, 11, 0])
    edid[132:139] = bytes([0x66, 3, 12, 0, 0, 0, 0x10])
    edid[255] = -sum(edid[128:255]) % 256
    self.assertTrue(m.edid_details(edid)['tenBit'])
    edid[138] = 0
    self.assertIsNone(m.edid_details(edid)['tenBit'])
    edid[255] = -sum(edid[128:255]) % 256
    self.assertFalse(m.edid_details(edid)['tenBit'])

  def test_hyprland_applies_depth_and_rejects_silent_eight_bit_fallback_on_keep(self):
    self.enterContext(patch.object(m, 'SESSION', 'wayland'))
    with patch.object(m, 'command', return_value='ok\n') as command:
      m.apply_layout([output(bitDepth=10)])
      self.assertEqual(command.call_args.args[0][:2], ['hyprctl', 'eval'])
      self.assertIn('bitdepth = 10', command.call_args.args[0][-1])
    before, after = output(bitDepth=8), output(bitDepth=10)
    pending = dict(token='color', monotonicDeadline=time.monotonic() + 20,
      before=m.clean([before]), after=m.clean([after]), topology=m.topology([before]))
    m.write_json(m.RUNTIME / 'pending', pending)
    with patch.object(m, 'discover', return_value=[before]), patch.object(m, 'apply_layout') as apply:
      with self.assertRaisesRegex(ValueError, 'did not match'):
        m.confirm('color', True)
      self.assertEqual(apply.call_args.args[0][0]['bitDepth'], 8)
    self.assertFalse(m.layout_equal([after], [before]))

  def test_kanshi_color_hook_restores_saved_depth_and_respects_trials(self):
    self.enterContext(patch.object(m, 'SESSION', 'wayland'))
    profile = dict(name='Desk color', session='wayland', preferred=True,
      outputs=m.clean([output(bitDepth=10)]))
    m.save_profile(profile)
    self.assertIn("profile-color 'Desk color'", m.kanshi_config([profile]))
    with patch.object(m, 'discover', return_value=[output(bitDepth=8, tenBitAvailable=True)]), patch.object(m, 'apply_layout') as apply:
      m.profile_color('Desk color')
      self.assertEqual(apply.call_args.args[0][0]['bitDepth'], 10)
      apply.reset_mock()
      m.write_json(m.RUNTIME / 'pending', {'token': 'trial'})
      m.profile_color('Desk color')
      apply.assert_not_called()

  def test_lua_monitor_adapter_enables_before_disabling_and_rejects_ipc_errors(self):
    self.enterContext(patch.object(m, 'SESSION', 'wayland'))
    outputs = [output(name='eDP-1', identity='', enabled=False),
      output(bitDepth=10, mode='2560x1440', rate=59.94, x=100, y=200, scale=1.25, rotation='left')]
    with patch.object(m, 'command', return_value='ok\n') as command:
      m.apply_layout(outputs)
      self.assertEqual(command.call_args.args[0], ['hyprctl', 'eval',
        'hl.monitor({output = "DP-1", mode = "2560x1440@59.94", position = "100x200", scale = 1.25, transform = 1, bitdepth = 10}); '
        'hl.monitor({output = "eDP-1", disabled = true})'])
    for response in ['unknown request', 'Lua error: invalid monitor', '']:
      with patch.object(m, 'command', return_value=response), self.assertRaises(RuntimeError):
        m.apply_layout(outputs)

  def test_identity_matches_a_new_connector_and_rejects_missing_or_extra_hardware(self):
    saved = [output()]
    connected = [output(name='DP-3')]
    self.assertEqual(m.resolve(saved, connected)[0]['connector'], 'DP-3')
    for connected in [[], [output(identity='edid:different')], [output(), output(name='HDMI-1', identity='edid:bb')]]:
      with self.assertRaises(ValueError):
        m.resolve(saved, connected)

  def test_duplicate_edids_require_connector_disambiguation(self):
    connected = [output(), output(name='DP-2')]
    self.assertEqual(len(m.resolve([output(), output(name='DP-2')], connected)), 2)
    with self.assertRaises(ValueError):
      m.resolve([output(name='DP-3')], connected)

  def test_rejects_unsupported_modes_but_tolerates_reported_refresh_rounding(self):
    self.assertEqual(m.resolve([output(rate=59.94)], [output()])[0]['rate'], 59.94)
    with self.assertRaises(ValueError):
      m.resolve([output(rate=120)], [output()])
    with self.assertRaises(ValueError):
      m.resolve([output(mode='8000x4000')], [output()])

  def test_autorandr_import_preserves_rotation_primary_and_uniform_scaling(self):
    parsed = m.parse_autorandr('output DP-1\nmode 1920x1080\nrate 59.94\npos 200x0\nrotate left\nprimary\ntransform 0.8,0,0,0,0.8,0,0,0,1\noutput HDMI-1\noff\n', 'DP-1 aabb\nHDMI-1 ccdd\n')
    self.assertEqual(parsed[0]['scale'], 1.25)
    self.assertEqual(parsed[0]['rotation'], 'left')
    self.assertEqual(parsed[0]['x'], 200)
    self.assertTrue(parsed[0]['primary'])
    self.assertFalse(parsed[1]['enabled'])
    self.assertIn('transform 0.800000,0,0,0,0.800000,0,0,0,1', m.autorandr_config(parsed))

  def test_nonuniform_transforms_are_not_silently_lost(self):
    with self.assertRaises(ValueError):
      m.parse_autorandr('output DP-1\nmode 1920x1080\ntransform 1,0.2,0,0,1,0,0,0,1\n', 'DP-1 aabb\n')

  def test_kanshi_uses_native_rotation_names_and_quotes_descriptions(self):
    text = m.kanshi_config([dict(outputs=[output(identity='description:Acme 4K Panel 123', rotation='left'),
      output(name='eDP-1', identity='', enabled=False)])])
    self.assertIn('output "Acme 4K Panel 123" enable mode 1920x1080@60Hz position 0,0 scale 1 transform 90', text)
    self.assertIn('output "eDP-1" disable', text)

  def test_profile_crud_preference_and_atomic_rejection(self):
    first = dict(name='Desk', session='x11', preferred=True, outputs=m.clean([output()]))
    second = dict(first, name='Desk compact')
    m.save_profile(first)
    m.save_profile(second)
    store = m.load()
    self.assertFalse(store['profiles'][0]['preferred'])
    self.assertEqual(m.preferred_profiles(store, 'x11')[0]['name'], 'Desk compact')
    before = m.STORE.read_bytes()
    with self.assertRaises(ValueError):
      m.save_profile(dict(second, name='Desk'))
    self.assertEqual(before, m.STORE.read_bytes())
    with self.assertRaises(ValueError):
      m.save_profile(dict(second, name='../escape'))
    self.assertEqual(before, m.STORE.read_bytes())

  def test_restore_after_unplug_enables_the_remaining_panel(self):
    before = [output(), output(name='eDP-1', identity='edid:ccdd', enabled=False)]
    connected = [output(name='eDP-1', identity='edid:ccdd', enabled=False)]
    with patch.object(m, 'discover', return_value=connected), patch.object(m, 'apply_layout') as apply:
      m.write_json(m.RUNTIME / 'pending', {})
      m.restore({'before': m.clean(before)})
      restored = apply.call_args.args[0]
      self.assertEqual(restored[0]['connector'], 'eDP-1')
      self.assertTrue(restored[0]['enabled'])
      self.assertFalse((m.RUNTIME / 'pending').exists())

  def test_restore_retries_with_safe_mode_when_previous_mode_fails(self):
    with patch.object(m, 'discover', return_value=[output()]), patch.object(m, 'apply_layout', side_effect=[RuntimeError('mode rejected'), None]) as apply:
      m.restore({'before': m.clean([output(mode='2560x1440')])})
      self.assertEqual(apply.call_count, 2)
      self.assertEqual(apply.call_args.args[0][0]['mode'], '1920x1080')

  def test_failed_trial_rolls_back_with_guard_armed_before_applying(self):
    before = [output()]
    def spawn(args, **kwargs):
      self.assertTrue((m.RUNTIME / 'pending').exists())
      self.assertTrue(kwargs['start_new_session'])
      m.write_json(m.RUNTIME / 'guard-ready', args[-1])
      return Mock(poll=lambda: None)
    with patch.object(m, 'discover', return_value=before), patch.object(m.subprocess, 'Popen', side_effect=spawn), patch.object(m, 'apply_layout', side_effect=[RuntimeError('partial failure'), None]) as apply:
      with self.assertRaisesRegex(RuntimeError, 'partial failure'):
        m.trial([output(mode='2560x1440')])
      self.assertEqual(apply.call_count, 2)
      self.assertEqual(apply.call_args.args[0][0]['mode'], '1920x1080')
      self.assertFalse((m.RUNTIME / 'pending').exists())

  def test_keep_cancels_guard_without_saving_a_profile(self):
    pending = dict(token='abc', monotonicDeadline=time.monotonic() + 20, before=m.clean([output()]), after=m.clean([output()]), topology=m.topology([output()]))
    m.write_json(m.RUNTIME / 'pending', pending)
    with patch.object(m, 'discover', return_value=[output()]), patch.object(m, 'apply_layout') as apply:
      m.confirm('abc', True)
      apply.assert_not_called()
    self.assertEqual(m.read_state('hold'), pending['topology'])
    self.assertEqual(m.load()['profiles'], [])
    with self.assertRaises(ValueError):
      m.confirm('abc', True)

  def test_late_keep_and_hotplug_are_reverted(self):
    for expiry, hardware in [(time.monotonic() - 1, [output()]), (time.monotonic() + 20, [output(name='HDMI-1', identity='edid:ccdd')])]:
      pending = dict(token='abc', monotonicDeadline=expiry, before=m.clean([output()]), topology=m.topology([output()]))
      m.write_json(m.RUNTIME / 'pending', pending)
      with patch.object(m, 'discover', return_value=hardware), patch.object(m, 'apply_layout') as apply:
        with self.assertRaisesRegex(ValueError, 'restored'):
          m.confirm('abc', True)
        apply.assert_called_once()

  def test_independent_guard_restores_without_a_ui_process(self):
    pending = dict(token='guard-test', monotonicDeadline=time.monotonic() - 1, before=m.clean([output()]))
    m.write_json(m.RUNTIME / 'pending', pending)
    restored_file = self.root / 'restored.json'
    with patch.object(m, 'discover', return_value=[output(mode='2560x1440')]), patch.object(m, 'apply_layout', side_effect=lambda outputs: m.write_json(restored_file, outputs)):
      process = multiprocessing.get_context('fork').Process(target=m.guard, args=('guard-test',))
      process.start()
      process.join(5)
      if process.is_alive():
        process.terminate()
        process.join()
        self.fail('rollback guard did not finish')
    self.assertEqual(process.exitcode, 0)
    self.assertEqual(json.loads(restored_file.read_text())[0]['mode'], '1920x1080')
    self.assertFalse((m.RUNTIME / 'pending').exists())

  def test_existing_autorandr_hook_is_preserved(self):
    target = self.root / 'config/autorandr/block'
    target.parent.mkdir(parents=True)
    target.write_text('custom hook')
    with self.assertRaises(ValueError):
      m.ensure_autorandr_block()
    self.assertEqual(target.read_text(), 'custom hook')

  def test_edid_hdmi_limits_are_distinct_from_current_usage(self):
    edid = bytearray(256)
    edid[:8] = bytes.fromhex('00ffffffffffff00')
    edid[128:132] = bytes([2, 3, 20, 0])
    edid[132:140] = bytes([0x67, 3, 12, 0, 0, 0, 0, 60])
    edid[140:146] = bytes([0x65, 0xd8, 0x5d, 0xc4, 1, 120])
    details = m.edid_details(edid)
    self.assertEqual(details['maxTmdsMHz'], 600)
    self.assertNotIn('negotiatedGbps', details)
    self.assertIsNone(m.edid_details(b'bad')['maxTmdsMHz'])

  def test_link_estimate_uses_pixel_clock_and_does_not_claim_max_bpc_is_active(self):
    verbose = 'DP-1 connected\n\tmax bpc: 12\n\tsubconnector: HDMI\n  3840x2160 (0x1) 529.200MHz *current\nHDMI-1 disconnected\n'
    with patch.object(m, 'command', return_value=verbose), patch.object(m.Path, 'glob', return_value=[]):
      details = m.link_details('DP-1')
    self.assertEqual(details['maxBpc'], '12')
    self.assertIsNone(details['activeBpc'])
    self.assertIsNone(details['negotiatedGbps'])
    self.assertAlmostEqual(details['estimated8BitRgbGbps'], 12.7008)

  def watcher_context(self):
    self.enterContext(patch.dict(os.environ, XDG_SESSION_ID=''))
    self.enterContext(patch.object(m.atexit, 'register'))
    self.enterContext(patch.object(m.signal, 'signal'))
    self.enterContext(patch.object(m, 'stop_kanshi'))
    self.enterContext(patch.object(m, 'postswitch'))
    self.enterContext(patch.object(m.time, 'sleep', side_effect=[None, None, KeyboardInterrupt]))

  def test_watcher_applies_once_and_avoids_native_queries_when_hardware_is_unchanged(self):
    self.watcher_context()
    m.save_profile(dict(name='Desk', session='x11', preferred=True, outputs=m.clean([output(mode='2560x1440')])))
    with patch.object(m, 'hardware_probe', return_value=['unchanged']), patch.object(m, 'discover', return_value=[output()]) as discover, patch.object(m, 'apply_layout') as apply:
      with self.assertRaises(KeyboardInterrupt):
        m.watch()
      self.assertEqual(discover.call_count, 1)
      self.assertEqual(apply.call_count, 1)
      self.assertEqual(apply.call_args.args[0][0]['mode'], '2560x1440')

  def test_kept_manual_layout_is_held_until_hardware_changes(self):
    self.watcher_context()
    other = output(identity='edid:ccdd')
    m.save_profile(dict(name='Other dock', session='x11', preferred=True, outputs=m.clean([dict(other, mode='2560x1440')])))
    with patch.object(m, 'hardware_probe', side_effect=['first', 'second', 'second']), patch.object(m, 'discover', side_effect=[[output()], [output()], [other], [other]]), patch.object(m, 'apply_layout') as apply:
      with self.assertRaises(KeyboardInterrupt):
        m.watch(defer=True)
      self.assertEqual(apply.call_count, 1)
      self.assertEqual(apply.call_args.args[0][0]['identity'], 'edid:ccdd')
      self.assertFalse((m.RUNTIME / 'hold').exists())

  def test_disabled_automatic_switching_never_queries_or_applies_layouts(self):
    self.watcher_context()
    m.write_json(m.STORE, dict(version=1, automatic=False, profiles=[]))
    with patch.object(m, 'discover') as discover, patch.object(m, 'apply_layout') as apply:
      with self.assertRaises(KeyboardInterrupt):
        m.watch()
      discover.assert_not_called()
      apply.assert_not_called()

  def test_watcher_recovers_an_expired_trial_after_a_guard_crash(self):
    self.watcher_context()
    m.write_json(m.RUNTIME / 'pending', dict(token='stale', monotonicDeadline=time.monotonic() - 1,
      before=m.clean([output()])))
    with patch.object(m, 'hardware_probe', return_value=['same']), patch.object(m, 'discover', return_value=[output(mode='2560x1440')]), patch.object(m, 'apply_layout') as apply:
      with self.assertRaises(KeyboardInterrupt):
        m.watch()
      apply.assert_called_once()
      self.assertEqual(apply.call_args.args[0][0]['mode'], '1920x1080')
      self.assertFalse((m.RUNTIME / 'pending').exists())


if __name__ == '__main__':
  unittest.main()
