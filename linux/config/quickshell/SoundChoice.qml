pragma ComponentBehavior: Bound

import QtQuick

SettingsChoice {
  id: choice
  required property bool keyboardEnabled
  required property var choices
  required property string selected
  required property string label
  signal chosen(var option)
  signal interacted()
  width: parent.width
  model: choices
  textRole: "description"
  currentIndex: choices.findIndex(option => option.name === selected)
  displayText: currentIndex < 0 ? label + ": unavailable" : label + ": " + choices[currentIndex].description
  focusPolicy: keyboardEnabled ? Qt.StrongFocus : Qt.NoFocus
  Accessible.name: label
  onPressedChanged: { if (pressed) interacted() }
  onActivated: index => chosen(choices[index])
}
