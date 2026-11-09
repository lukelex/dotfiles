SettingsStatus {
  required property var preferences
  required property var keys
  failed: preferences.error !== "" && keys.some(key => preferences.errorKeys.includes(key))
  readonly property bool pending: preferences.busy && keys.some(key => preferences.activeKeys.includes(key))
  text: failed ? preferences.error : pending ? "Applying changes…" : ""
}
