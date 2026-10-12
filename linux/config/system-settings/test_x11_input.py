import unittest
from unittest.mock import patch

import x11_input


MOUSE = '''
  Device Node (123): "/dev/input/event4"
  libinput Send Events Modes Available (124): 1, 0
  libinput Natural Scrolling Enabled (125): 0
  libinput Accel Speed (126): 0.0
  libinput Accel Profiles Available (127): 1, 1, 1
  libinput Accel Profile Enabled (128): 1, 0, 0
'''
TRACKPAD = MOUSE + '''
  libinput Tapping Enabled (129): 0
  libinput Disable While Typing Enabled (130): 1
'''


class InputTests(unittest.TestCase):
  def command(self, *args):
    if args == ('list', '--short'):
      return 'Mouse id=10 [slave pointer (2)]\nTrackpad id=11 [slave pointer (2)]\nKeyboard id=12 [slave keyboard (3)]'
    if args == ('list-props', '10'):
      return MOUSE
    if args == ('list-props', '11'):
      return TRACKPAD
    return ''

  def test_distinct_scrolling_and_supported_properties(self):
    with patch.object(x11_input, 'command', side_effect=self.command) as command:
      x11_input.apply(dict(naturalScroll=False, touchpadNaturalScroll=True,
        tapToClick=True, disableWhileTyping=False, sensitivity=0.25, acceleration='flat'))
    calls = [call.args for call in command.call_args_list if call.args[0] == 'set-prop']
    self.assertIn(('set-prop', '10', 'libinput Natural Scrolling Enabled', '0'), calls)
    self.assertIn(('set-prop', '11', 'libinput Natural Scrolling Enabled', '1'), calls)
    self.assertIn(('set-prop', '11', 'libinput Tapping Enabled', '1'), calls)
    self.assertIn(('set-prop', '11', 'libinput Disable While Typing Enabled', '0'), calls)
    self.assertIn(('set-prop', '10', 'libinput Accel Profile Enabled', '0', '1', '0'), calls)
    self.assertFalse(any(call[1] == '12' for call in calls))
    self.assertFalse(any(call[1:3] == ('10', 'libinput Tapping Enabled') for call in calls))

  def test_missing_dependency_and_disappearing_devices(self):
    with patch.object(x11_input, 'command', side_effect=FileNotFoundError):
      self.assertIn('xorg-xinput', x11_input.describe()['error'])
    def disconnected(*args):
      if args[0] == 'list-props':
        raise RuntimeError('device disappeared')
      return self.command(*args)
    with patch.object(x11_input, 'command', side_effect=disconnected):
      self.assertEqual(x11_input.describe()['keys'], [])

  def test_write_errors_are_not_reported_as_success(self):
    def failing(*args):
      if args[0] == 'set-prop':
        raise RuntimeError('write failed')
      return self.command(*args)
    with patch.object(x11_input, 'command', side_effect=failing):
      with self.assertRaisesRegex(RuntimeError, 'write failed'):
        x11_input.apply(dict(naturalScroll=True))


if __name__ == '__main__':
  unittest.main()
