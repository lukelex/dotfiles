SettingsStatus {
  required property var service
  required property var actions
  failed: service.error !== ""
  text: actions.includes(service.action) ? service.error || (service.busy ? "Applying changes…" : "") : ""
}
