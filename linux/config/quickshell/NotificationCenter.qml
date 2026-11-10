pragma ComponentBehavior: Bound

import Quickshell
import QtQuick
import "DesignTokens.js" as Design
import QtQml
import QtQuick.Controls.Basic as Controls

Scope {
  id: popup

  required property var controller
  required property var panel
  required property var service

  readonly property real height: Math.min(548, panel.screen.height - panel.height - 24)
  readonly property real width: Math.min(Design.panel.width, panel.screen.width - Design.panel.gap * 2)
  readonly property bool visible: preview.visible || pinnedPopup.visible
  readonly property bool reducedMotion: service.reduceMotion
  property bool pinned: false
  property bool promotionPending: false
  property var promotionSnapshot: null
  property var promotionWindow: null
  property int pinRequest: 0
  property var activationReturn: null
  property var restoreAfterOpen: null
  readonly property bool compactHeader: width < 400
  property bool overflowRequested: false

  function activateFromCenter(id, actionIndex = null) {
    if (popup.service.activationPendingId !== null)
      return
    const entry = popup.readingEntries().find(entry => entry.id === id)
    const position = { id: id, contentY: historyView.contentY, expandedGroupKey: popup.expandedGroupKey,
      offset: entry ? entry.y - historyView.contentY : null }
    popup.requestClose(true)
    popup.activationReturn = position
    if (actionIndex === null)
      popup.service.activateRecord(id)
    else
      popup.service.invokeAction(id, actionIndex)
    popup.checkActivationReturn()
  }

  function checkActivationReturn() {
    const position = popup.activationReturn
    if (!position)
      return
    const failed = popup.service.activationErrorId === position.id && popup.service.activationError !== ""
    if (!failed && popup.service.activationPendingId === position.id)
      return
    popup.activationReturn = null
    if (failed && popup.service.history.some(record => record.id === position.id)) {
      popup.restoreAfterOpen = position
      popup.requestOpen(true)
    }
  }

  function restoreActivationPosition() {
    const position = popup.restoreAfterOpen
    if (!position || !popup.visible)
      return
    popup.restoreAfterOpen = null
    popup.expandedGroupKey = position.expandedGroupKey
    notificationList.forceLayout()
    popup.readingAnchor = position.offset === null ? null : { id: position.id, offset: position.offset }
    historyView.contentY = Math.max(0, Math.min(position.contentY, historyView.contentHeight - historyView.height))
    popup.restoreReadingPosition()
    anchorRelease.restart()
  }

  function clearAll() {
    if (clearAllAnimation.running || groupDismissTimer.running || popup.service.history.length === 0)
      return
    popup.clearingRecords = popup.service.history.slice()
    popup.startClearAllDismissals()
    clearAllAnimation.start()
  }

  function openOverflow() {
    popup.overflowRequested = true
    popup.requestOpen(true)
    if (pinnedPopup.visible) {
      popup.overflowRequested = false
      headerMenu.open()
    }
  }

  component Hint: Controls.ToolTip {
    id: hint
    delay: 500
    padding: 8
    implicitWidth: Math.min(300, popup.width - 32, contentItem.implicitWidth + 16)
    contentItem: Text {
      text: hint.text
      textFormat: Text.PlainText
      wrapMode: Text.Wrap
      color: popup.controller.controlPrimaryText
      font.family: popup.controller.fontFamily
      font.pixelSize: 11
    }
    background: Rectangle {
      color: popup.controller.controlSurface
      border.color: popup.controller.controlSurfaceBorder
      radius: 7
    }
  }

  component HeaderIconButton: NotificationButton {
    id: button

    property color idleColor: popup.controller.controlPrimaryText
    property color activeColor: popup.controller.controlActiveIcon
    property bool active: false
    property bool destructive: false
    controller: popup.controller
    keyboardEnabled: popup.pinned
    iconSize: 16
    foregroundColor: button.active || (button.destructive && button.hovered) ? button.activeColor : button.idleColor
    height: 32
    width: 32

    background: Rectangle {
      color: button.active
        ? Qt.rgba(button.activeColor.r, button.activeColor.g, button.activeColor.b, button.hovered ? 0.35 : 0.18)
        : (button.hovered
          ? (button.destructive
            ? Qt.rgba(button.activeColor.r, button.activeColor.g, button.activeColor.b, 0.25)
            : popup.controller.controlHover)
          : "transparent")
      radius: 8
      border.width: button.activeFocus ? 1 : 0
      border.color: popup.controller.controlActiveIcon
    }
  }

  component DismissButton: NotificationButton {
    id: button

    property string label: ""
    controller: popup.controller
    text: label
    iconName: label ? "" : "x"
    keyboardEnabled: popup.pinned
  }

  component NotificationCard: Item {
    id: card

    required property var controller
    required property var record
    required property var service

    readonly property bool isLive: { service.liveRevision; return Boolean(service.live[record.id]) }
    readonly property var icon: service.iconFor(card.record)
    readonly property string body: service.displayBody(card.record)
    readonly property real contentHeight: textColumn.height + 24

    property bool dismissing: false
    property bool expanded: false
    property bool copied: false
    readonly property bool canExpand: expanded || summaryLabel.truncated || bodyLabel.truncated
    property bool groupDismissing: false
    property int groupDismissDelay: 0
    property real groupDismissOffset: 0

    transform: Translate { x: card.groupDismissOffset }
    width: parent.width
    height: card.contentHeight

    Behavior on height {
      NumberAnimation { duration: popup.reducedMotion ? 0 : 180; easing.type: Easing.OutCubic }
    }

    Behavior on y {
      enabled: !card.dismissing && !card.groupDismissing

      YAnimator {
        duration: popup.reducedMotion ? 0 : 180
        easing.type: Easing.OutCubic
      }
    }

    // Declared first so the buttons inside the surface keep their clicks.
    MouseArea {
      anchors.fill: parent
      acceptedButtons: Qt.LeftButton | Qt.RightButton
      cursorShape: card.canExpand ? Qt.PointingHandCursor : Qt.ArrowCursor
      hoverEnabled: true
      onClicked: mouse => {
        if (mouse.button === Qt.RightButton)
          card.startDismiss()
        else if (card.canExpand)
          card.expanded = !card.expanded
      }
    }

    Item {
      id: surface

      clip: true
      height: parent.height
      width: parent.width

      Rectangle {
        anchors.fill: parent
        border.color: card.controller.controlSurfaceBorder
        border.width: 1
        color: card.controller.controlSurface
        radius: 18
      }

      Rectangle {
        id: urgentBreath

        anchors.fill: parent
        color: Qt.rgba(card.controller.urgent.r, card.controller.urgent.g, card.controller.urgent.b, 0.12)
        opacity: 0.18
        radius: 18
        visible: card.isLive && card.record.urgency === "critical"

        SequentialAnimation {
          loops: 1
          running: popup.visible && urgentBreath.visible && !popup.reducedMotion

          NumberAnimation {
            target: urgentBreath
            property: "opacity"
            from: 0.18
            to: 0.85
            duration: 180
            easing.type: Easing.InOutSine
          }
          NumberAnimation {
            target: urgentBreath
            property: "opacity"
            from: 0.85
            to: 0.18
            duration: 420
            easing.type: Easing.InOutSine
          }
        }
      }

      Column {
        id: textColumn

        anchors {
          left: parent.left
          leftMargin: 64
          right: parent.right
          rightMargin: 14
          top: parent.top
          topMargin: 12
        }
        spacing: 3

        Row {
          height: Math.max(dismissButton.height, summaryLabel.height)
          spacing: 6
          width: parent.width

          Text {
            id: summaryLabel
            anchors.verticalCenter: parent.verticalCenter
            color: card.controller.controlPrimaryText
            elide: Text.ElideRight
            font.family: card.controller.fontFamily
            font.pixelSize: 12
            text: (card.record.urgency === "critical" ? "Critical · " : "") + card.record.summary
            textFormat: Text.PlainText
            wrapMode: Text.Wrap
            maximumLineCount: card.expanded ? 2147483647 : 1
            width: Math.max(0, parent.width - timeLabel.width - dismissButton.width - parent.spacing * 2)
          }

          Text {
            id: timeLabel

            anchors.baseline: summaryLabel.baseline
            color: card.controller.controlSecondaryText
            font.family: card.controller.fontFamily
            font.pixelSize: 10
            text: popup.service.timeAgo(card.record)
            width: Math.max(28, implicitWidth)
            horizontalAlignment: Text.AlignRight
            Accessible.name: popup.service.exactTime(card.record)
            HoverHandler { id: timeHover }
            Hint {
              parent: timeLabel
              x: timeLabel.width - implicitWidth
              y: -implicitHeight - 6
              text: popup.service.exactTime(card.record)
              visible: timeHover.hovered || timeLabel.activeFocus
            }
          }

          DismissButton {
            id: dismissButton

            anchors.verticalCenter: parent.verticalCenter
            description: "Dismiss notification"
            enabled: !card.dismissing && !card.groupDismissing
            onClicked: card.startDismiss()
          }
        }

        Text {
          id: bodyLabel
          color: card.controller.controlSecondaryText
          elide: Text.ElideRight
          font.family: card.controller.fontFamily
          font.pixelSize: 11
          maximumLineCount: card.expanded ? 2147483647 : 2
          text: card.body
          textFormat: Text.PlainText
          visible: card.body.length > 0
          width: parent.width
          wrapMode: Text.Wrap
        }

        Controls.AbstractButton {
          id: disclosure

          visible: card.canExpand
          enabled: !card.dismissing && !card.groupDismissing
          width: Math.min(parent.width, disclosureLabel.implicitWidth + 34)
          height: 28
          focusPolicy: popup.pinned ? Qt.TabFocus : Qt.NoFocus
          hoverEnabled: true
          Accessible.name: card.expanded ? "Collapse notification text" : "Read full notification"
          Keys.onReturnPressed: event => { if (!event.isAutoRepeat) clicked() }
          Keys.onEnterPressed: event => { if (!event.isAutoRepeat) clicked() }
          onClicked: card.expanded = !card.expanded

          background: Rectangle {
            radius: 7
            color: disclosure.down ? card.controller.controlSliderTrack
              : disclosure.hovered ? card.controller.controlHover : "transparent"
            border.width: disclosure.activeFocus ? 1 : 0
            border.color: card.controller.controlActiveIcon
          }

          contentItem: Item {
            LucideIcon {
              anchors.left: parent.left
              anchors.leftMargin: 4
              anchors.verticalCenter: parent.verticalCenter
              width: 14
              height: 14
              source: card.controller.icon("chevron-right")
              rotation: card.expanded ? 270 : 90
              Behavior on rotation {
                RotationAnimation { duration: popup.reducedMotion ? 0 : 180; direction: RotationAnimation.Shortest; easing.type: Easing.OutCubic }
              }
              color: card.controller.controlSecondaryText
            }

            Text {
              id: disclosureLabel
              anchors.left: parent.left
              anchors.leftMargin: 24
              anchors.right: parent.right
              anchors.rightMargin: 6
              anchors.verticalCenter: parent.verticalCenter
              text: card.expanded ? "Show less" : "Show more"
              elide: Text.ElideRight
              color: card.controller.controlSecondaryText
              font.family: card.controller.fontFamily
              font.pixelSize: 11
            }
          }

          HoverHandler {
            cursorShape: Qt.PointingHandCursor
          }
        }

        Flow {
          width: parent.width
          spacing: 6
          topPadding: 7

          DismissButton {
            label: card.copied ? "Copied" : "Copy"
            description: "Copy notification text"
            onClicked: {
              Quickshell.clipboardText = card.record.summary + (card.body ? "\n" + card.body : "")
              card.copied = true
              copyFeedback.restart()
            }
          }

          DismissButton {
            label: card.service.activationPendingId === card.record.id ? "Opening…" : "Open"
            description: "Open notification in its application"
            visible: card.service.canActivate(card.record)
            enabled: card.service.activationPendingId === null && !card.dismissing
            onClicked: card.activate()
          }

          Repeater {
            model: card.isLive ? card.record.actions : []

            delegate: DismissButton {
              id: actionDelegate

              required property var modelData
              required property int index

              label: modelData.text
              description: modelData.text
              maximumWidth: textColumn.width
              enabled: !card.dismissing && !card.groupDismissing && card.service.activationPendingId === null
              onClicked: {
                const id = card.record.id
                const index = actionDelegate.modelData.sourceIndex
                popup.activateFromCenter(id, index)
              }
            }
          }
        }

        Text {
          width: parent.width
          visible: card.service.activationErrorId === card.record.id && text.length > 0
          text: card.service.activationError
          textFormat: Text.PlainText
          wrapMode: Text.Wrap
          color: card.controller.urgent
          font.family: card.controller.fontFamily
          font.pixelSize: 11
        }
      }

      Rectangle {
        anchors {
          left: parent.left
          leftMargin: 12
          top: parent.top
          topMargin: 12
        }
        color: card.record.urgency === "critical" ? card.controller.urgent : card.controller.controlActive
        height: 40
        radius: 12
        width: 40

        Image {
          anchors.fill: parent
          anchors.margins: 8
          fillMode: Image.PreserveAspectFit
          source: card.icon.kind === "image" ? card.icon.source : ""
          visible: card.icon.kind === "image"
        }

        LucideIcon {
          id: notificationIcon

          anchors.centerIn: parent
          color: card.controller.controlPrimaryText
          height: 20
          source: card.icon.kind === "lucide" ? card.controller.icon(card.icon.source) : ""
          visible: card.icon.kind === "lucide"
          width: 20
        }
      }
    }

    function startDismiss() {
      if (card.dismissing)
        return
      card.dismissing = true
      dismissAnim.start()
    }

    function activate() {
      if (card.dismissing || card.groupDismissing || card.service.activationPendingId !== null)
        return
      const id = card.record.id
      popup.activateFromCenter(id)
    }

    Timer {
      id: copyFeedback
      interval: 1500
      onTriggered: card.copied = false
    }

    onGroupDismissingChanged: {
      if (groupDismissing)
        groupDismissAnimation.start()
      else {
        groupDismissAnimation.stop()
        card.groupDismissOffset = 0
        surface.opacity = 1
      }
    }

    SequentialAnimation {
      id: groupDismissAnimation

      PauseAnimation { duration: popup.reducedMotion ? 0 : Math.max(0, card.groupDismissDelay) }
      ParallelAnimation {
        NumberAnimation {
          target: card
          property: "groupDismissOffset"
          to: card.width
          duration: popup.reducedMotion ? 0 : 260
          easing.type: Easing.InCubic
        }
        OpacityAnimator {
          target: surface
          to: 0
          duration: popup.reducedMotion ? 0 : 200
          easing.type: Easing.OutCubic
        }
      }
    }

    ParallelAnimation {
      id: dismissAnim

      XAnimator {
        target: surface
        to: card.width
        duration: popup.reducedMotion ? 0 : 260
        easing.type: Easing.InCubic
      }
      OpacityAnimator {
        target: surface
        to: 0
        duration: popup.reducedMotion ? 0 : 200
        easing.type: Easing.OutCubic
      }
      onStopped: {
        if (card.dismissing)
          card.service.dismissRecord(card.record.id)
      }
    }
  }

  component NotificationGroup: Item {
    id: notificationGroup

    required property var controller
    required property var group
    required property var service

    property var records: group.records
    readonly property bool grouped: recordModel.count > 1
    readonly property var icon: recordModel.count > 0 ? service.iconFor(recordModel.get(0).notification) : ({ kind: "lucide", source: "bell" })
    readonly property var latest: recordModel.count > 0 ? recordModel.get(0).notification : null
    readonly property bool expanded: popup.expandedGroupKey === group.key
    property real revealProgress: expanded ? 1 : 0
    property bool dismissing: false
    property real headerDismissOffset: 0

    ListModel {
      id: recordModel

      dynamicRoles: true
    }

    clip: true
    height: grouped ? groupHeader.height + (cardList.height + 8) * revealProgress : cardList.height
    width: parent.width

    Behavior on revealProgress {
      NumberAnimation { duration: popup.reducedMotion ? 0 : 180; easing.type: Easing.OutCubic }
    }

    Component.onCompleted: syncRecords(notificationGroup.records)

    function syncRecords(records) {
      if (notificationGroup.dismissing && !groupDismissTimer.running) {
        notificationGroup.dismissing = false
        notificationGroup.headerDismissOffset = 0
        groupHeader.opacity = 1
      }
      popup.reconcileModel(recordModel, records, "notification", "id")
    }

    function readingEntries() {
      const entries = []
      for (let index = 0; index < recordModel.count; index++) {
        const item = notificationGroup.grouped && !notificationGroup.expanded
          ? notificationGroup : historyCards.itemAt(index)
        if (item)
          entries.push({ id: recordModel.get(index).notification.id,
            y: item.mapToItem(notificationList, 0, 0).y, height: item.height })
      }
      return entries
    }

    ParallelAnimation {
      id: headerDismissAnimation

      NumberAnimation {
        target: notificationGroup
        property: "headerDismissOffset"
        to: notificationGroup.width
        duration: popup.reducedMotion ? 0 : 260
        easing.type: Easing.InCubic
      }
      OpacityAnimator {
        target: groupHeader
        to: 0
        duration: popup.reducedMotion ? 0 : 200
        easing.type: Easing.OutCubic
      }
    }

    function startClearAllDismiss() {
      clearAllDismissAnimation.start()
    }

    OpacityAnimator {
      id: clearAllDismissAnimation

      target: notificationGroup
      to: 0
      duration: popup.reducedMotion ? 0 : 200
      easing.type: Easing.OutCubic
    }

    Item {
      id: groupHeader

      enabled: !notificationGroup.dismissing
      activeFocusOnTab: popup.pinned && notificationGroup.grouped && enabled
      Accessible.role: Accessible.Button
      Accessible.name: (notificationGroup.latest ? notificationGroup.latest.appName : "") + "; "
        + recordModel.count + " notifications; " + (notificationGroup.expanded ? "collapse" : "expand")
      Accessible.onPressAction: notificationGroup.toggleExpanded()
      Keys.onSpacePressed: event => { if (!event.isAutoRepeat) notificationGroup.toggleExpanded() }
      Keys.onReturnPressed: event => { if (!event.isAutoRepeat) notificationGroup.toggleExpanded() }
      Keys.onEnterPressed: event => { if (!event.isAutoRepeat) notificationGroup.toggleExpanded() }
      height: Math.max(78, groupText.implicitHeight + 24)
      transform: Translate { x: notificationGroup.headerDismissOffset }
      visible: notificationGroup.grouped
      width: parent.width

      MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: mouse => {
          if (mouse.button === Qt.RightButton)
            notificationGroup.dismissGroup()
          else
            notificationGroup.toggleExpanded()
        }
        z: -1
      }

      Rectangle {
        anchors.fill: parent
        border.color: groupHeader.activeFocus ? notificationGroup.controller.controlActiveIcon : notificationGroup.controller.controlSurfaceBorder
        border.width: 1
        color: notificationGroup.controller.controlSurface
        radius: 16
      }

      Rectangle {
        anchors {
          left: parent.left
          leftMargin: 10
          verticalCenter: parent.verticalCenter
        }
        color: notificationGroup.controller.controlActive
        height: 36
        radius: 10
        width: 36

        Image {
          anchors.fill: parent
          anchors.margins: 7
          fillMode: Image.PreserveAspectFit
          source: notificationGroup.icon.kind === "image" ? notificationGroup.icon.source : ""
          visible: notificationGroup.icon.kind === "image"
        }

        LucideIcon {
          anchors.centerIn: parent
          color: notificationGroup.controller.controlPrimaryText
          height: 18
          source: notificationGroup.icon.kind === "lucide" ? notificationGroup.controller.icon(notificationGroup.icon.source) : ""
          visible: notificationGroup.icon.kind === "lucide"
          width: 18
        }
      }

      Column {
        id: groupText
        anchors {
          left: parent.left
          leftMargin: 58
          right: clearGroupButton.left
          rightMargin: 10
          verticalCenter: parent.verticalCenter
        }
        spacing: 2

        Text {
          color: notificationGroup.controller.controlPrimaryText
          elide: Text.ElideRight
          font.family: notificationGroup.controller.fontFamily
          font.pixelSize: 12
          text: recordModel.count > 0 ? recordModel.get(0).notification.appName : ""
          textFormat: Text.PlainText
          width: parent.width
        }

        Text {
          color: notificationGroup.controller.controlSecondaryText
          elide: Text.ElideRight
          font.family: notificationGroup.controller.fontFamily
          font.pixelSize: 11
          text: notificationGroup.latest ? (notificationGroup.latest.summary || notificationGroup.service.displayBody(notificationGroup.latest)) : ""
          textFormat: Text.PlainText
          width: parent.width
        }

        Text {
          id: groupStatus
          color: notificationGroup.controller.controlSecondaryText
          font.family: notificationGroup.controller.fontFamily
          font.pixelSize: 10
          width: parent.width
          elide: Text.ElideRight
          wrapMode: Text.Wrap
          maximumLineCount: 2
          textFormat: Text.PlainText
          text: (notificationGroup.latest && notificationGroup.latest.urgency === "critical" ? "Critical · " : "")
            + recordModel.count + " notifications · " + popup.service.timeAgo(notificationGroup.latest)
          Accessible.name: text + "; " + popup.service.exactTime(notificationGroup.latest)
        }
      }

      DismissButton {
        id: clearGroupButton

        anchors {
          right: expandIcon.left
          rightMargin: 6
          verticalCenter: parent.verticalCenter
        }
        description: "Dismiss group"
        enabled: !notificationGroup.dismissing
        onClicked: notificationGroup.dismissGroup()
      }

      LucideIcon {
        id: expandIcon

        anchors {
          right: parent.right
          rightMargin: 14
          verticalCenter: parent.verticalCenter
        }
        color: notificationGroup.controller.controlSecondaryText
        height: 16
        source: notificationGroup.controller.icon("chevron-right")
        rotation: notificationGroup.expanded ? 90 : 0
        Behavior on rotation {
          RotationAnimation { duration: popup.reducedMotion ? 0 : 180; direction: RotationAnimation.Shortest; easing.type: Easing.OutCubic }
        }
        width: 16
      }
    }

    Column {
      id: cardList

      enabled: !notificationGroup.dismissing
      spacing: 10
      width: parent.width - x
      x: notificationGroup.grouped ? 12 : 0
      y: notificationGroup.grouped ? groupHeader.height + 8 : 0

      Repeater {
        id: historyCards
        model: recordModel

        delegate: NotificationCard {
          id: historyCard

          required property int index
          required property var notification

          controller: notificationGroup.controller
          groupDismissing: notificationGroup.dismissing
          groupDismissDelay: 60 + Math.min(140, Math.max(0, historyCard.index) * 35)
          groupDismissOffset: 0
          opacity: !notificationGroup.grouped || notificationGroup.expanded ? 1 : 0
          record: notification
          service: notificationGroup.service
          width: cardList.width

          Behavior on opacity {
            SequentialAnimation {
              PauseAnimation { duration: notificationGroup.expanded && !popup.reducedMotion ? Math.min(140, Math.max(0, historyCard.index) * 35) : 0 }
              NumberAnimation { duration: popup.reducedMotion ? 0 : 160; easing.type: Easing.OutCubic }
            }
          }

        }
      }
    }

    function dismissGroup() {
      if (notificationGroup.dismissing)
        return
      notificationGroup.dismissing = true
      headerDismissAnimation.start()
      popup.queueGroupDismiss(notificationGroup.recordsForDismissal())
    }

    function toggleExpanded() {
      if (!notificationGroup.grouped)
        return
      popup.expandedGroupKey = notificationGroup.expanded ? "" : notificationGroup.group.key
    }

    function recordsForDismissal() {
      const currentRecords = []
      for (let index = 0; index < recordModel.count; index++)
        currentRecords.push(recordModel.get(index).notification)
      return currentRecords
    }

  }

  property bool closePending: false
  property string expandedGroupKey: ""
  property var clearingRecords: []
  property var groupDismissRecords: []
  property var readingAnchor: null

  function queueGroupDismiss(records) {
    popup.groupDismissRecords = popup.groupDismissRecords.concat(records)
    groupDismissTimer.restart()
  }

  // Owned by the panel so closing it cannot cancel an accepted dismissal.
  Timer {
    id: groupDismissTimer
    interval: popup.reducedMotion ? 0 : 480
    onTriggered: {
      const records = popup.groupDismissRecords
      popup.groupDismissRecords = []
      popup.service.dismissRecords(records)
      popup.syncHistory()
    }
  }

  ListModel {
    id: centerModel
    dynamicRoles: true
  }

  function reconcileModel(model, values, role, key) {
    for (let index = 0; index < values.length; index++) {
      let existing = index
      while (existing < model.count && model.get(existing)[role][key] !== values[index][key])
        existing++
      if (existing === model.count) {
        const row = {}
        row[role] = values[index]
        model.insert(index, row)
      } else {
        if (existing !== index)
          model.move(existing, index, 1)
        model.setProperty(index, role, values[index])
      }
    }
    if (model.count > values.length)
      model.remove(values.length, model.count - values.length)
  }

  function readingEntries() {
    let entries = []
    for (let index = 0; index < historyGroups.count; index++) {
      const group = historyGroups.itemAt(index)
      if (group)
        entries = entries.concat(group.readingEntries())
    }
    return entries
  }

  function syncHistory() {
    if (!popup.visible || clearAllAnimation.running || groupDismissTimer.running)
      return
    const groups = service.historyGroups
    const survivingIds = new Set()
    for (const group of groups) {
      for (const record of group.records)
        survivingIds.add(record.id)
    }
    const entries = popup.readingEntries().filter(entry => survivingIds.has(entry.id))
    const anchor = entries.find(entry => entry.y + entry.height > historyView.contentY)
      || entries[entries.length - 1]
    if (!popup.readingAnchor || !survivingIds.has(popup.readingAnchor.id))
      popup.readingAnchor = anchor ? { id: anchor.id, offset: anchor.y - historyView.contentY } : null

    for (let index = 0; index < centerModel.count; index++) {
      const previous = centerModel.get(index).historyGroup
      if (previous.key === popup.expandedGroupKey) {
        const next = groups.find(group => group.records.some(record =>
          previous.records.some(entry => entry.id === record.id)))
        popup.expandedGroupKey = next ? next.key : ""
        break
      }
    }
    popup.reconcileModel(centerModel, groups, "historyGroup", "key")
    for (let index = 0; index < historyGroups.count; index++)
      historyGroups.itemAt(index).syncRecords(groups[index].records)
    notificationList.forceLayout()
    Qt.callLater(popup.restoreReadingPosition)
    anchorRelease.restart()
  }

  function restoreReadingPosition() {
    if (!popup.readingAnchor)
      return
    const entry = popup.readingEntries().find(entry => entry.id === popup.readingAnchor.id)
    if (entry)
      historyView.contentY = Math.max(0, Math.min(entry.y - popup.readingAnchor.offset,
        historyView.contentHeight - historyView.height))
  }

  function startClearAllDismissals() {
    for (let index = 0; index < historyGroups.count; index++) {
      const group = historyGroups.itemAt(index)
      if (group)
        group.startClearAllDismiss()
    }
  }

  // Keep the same card in place through height animations, but never fight scrolling.
  Timer {
    id: anchorRelease
    interval: 220
    onTriggered: {
      popup.restoreReadingPosition()
      popup.readingAnchor = null
    }
  }

  Connections {
    target: popup.service
    function onHistoryGroupsChanged() { popup.syncHistory() }
    function onActivationErrorChanged() { Qt.callLater(popup.checkActivationReturn) }
    function onActivationPendingIdChanged() { Qt.callLater(popup.checkActivationReturn) }
  }

  ParallelAnimation {
    id: clearAllAnimation

    NumberAnimation {
      target: clearAllTranslate
      property: "x"
      to: popup.width
      duration: popup.reducedMotion ? 0 : 260
      easing.type: Easing.InCubic
    }
    onFinished: {
      popup.service.clearHistoryWithUndo(popup.clearingRecords)
      popup.clearingRecords = []
      popup.expandedGroupKey = ""
      clearAllTranslate.x = 0
      // All rendered rows belong to the snapshot; newer arrivals were deferred.
      centerModel.clear()
      Qt.callLater(popup.syncHistory)
    }
  }

  function openPinned(request) {
    if (request !== popup.pinRequest)
      return
    if (popup.pinned && !popup.closePending)
      pinnedPopup.open()
    popup.promotionPending = false
  }

  function requestOpen(pin = false) {
    popup.activationReturn = null
    if (!pin && popup.closePending && popup.pinned)
      return
    hoverCloseTimer.stop()
    popup.closePending = false
    closeAnim.stop()
    if (!popup.visible && !popup.promotionPending) {
      content.opacity = 0
      content.y = popup.reducedMotion ? 0 : 10
    }
    if (pin || popup.pinned) {
      popup.pinned = true
      if (pinnedPopup.visible || popup.promotionPending)
        return
      popup.promotionPending = true
      const request = ++popup.pinRequest
      if (preview.visible) {
        const captured = content.grabToImage(result => {
          if (request !== popup.pinRequest || !popup.pinned || popup.closePending)
            return
          popup.promotionSnapshot = result
        })
        if (!captured) {
          popup.promotionPending = false
          popup.pinned = false
        }
      } else {
        Qt.callLater(popup.openPinned, request)
      }
    } else {
      preview.visible = true
      if (content.opacity < 1 && !openAnim.running)
        openAnim.start()
    }
  }

  function requestClose(immediate = false) {
    popup.activationReturn = null
    popup.restoreAfterOpen = null
    popup.overflowRequested = false
    headerMenu.close()
    popup.pinRequest++
    popup.promotionPending = false
    popup.promotionSnapshot = null
    popup.promotionWindow = null
    hoverCloseTimer.stop()
    popup.closePending = true
    openAnim.stop()
    if (pinnedPopup.visible)
      pinnedPopup.close()
    else
      popup.pinned = false
    if (immediate) {
      closeAnim.stop()
      preview.visible = false
    } else if (preview.visible && !closeAnim.running) {
      closeAnim.start()
    }
  }

  // Soft rise + fade: content slides up into place on open and down on close.
  function requestHoverClose() {
    if (!popup.pinned)
      hoverCloseTimer.restart()
  }

  Timer {
    id: hoverCloseTimer
    interval: 250
    onTriggered: { if (!popup.pinned) popup.requestClose() }
  }

  PopupWindow {
    id: preview
    anchor.window: popup.panel
    anchor.rect.x: Math.max(0, popup.panel.width - popup.width - 12)
    anchor.rect.y: popup.panel.height + 12
    implicitWidth: popup.width
    implicitHeight: popup.height
    color: "transparent"
    surfaceFormat.opaque: false
    grabFocus: false

    Image {
      anchors.fill: parent
      source: popup.promotionSnapshot ? popup.promotionSnapshot.url : ""
      visible: popup.promotionSnapshot !== null
      z: 1
      onStatusChanged: {
        if (status === Image.Ready)
          Qt.callLater(popup.openPinned, popup.pinRequest)
      }
    }
  }

  Connections {
    target: popup.promotionWindow
    function onFrameSwapped() {
      if (pinnedPopup.visible && popup.promotionSnapshot) {
        preview.visible = false
        popup.promotionSnapshot = null
        popup.promotionWindow = null
      }
    }
  }

  PopupWindow {
    id: pinnedPopup
    anchor.window: popup.panel
    anchor.rect.x: Math.max(0, popup.panel.width - popup.width - 12)
    anchor.rect.y: popup.panel.height + 12
    implicitWidth: popup.width
    implicitHeight: popup.height
    color: "transparent"
    surfaceFormat.opaque: false
    grabFocus: true

    function open() {
      pinnedPopup.visible = true
      if (popup.promotionSnapshot) {
        popup.promotionWindow = content.nativeWindow
        preview.contentItem.Window.window.raise()
      }
      content.forceActiveFocus()
      Qt.callLater(popup.restoreActivationPosition)
      if (popup.overflowRequested) {
        popup.overflowRequested = false
        headerMenu.open()
      }
      if (content.opacity < 1 && !openAnim.running)
        openAnim.start()
    }

    function close() {
      popup.pinned = false
      pinnedPopup.visible = false
      preview.visible = false
      popup.promotionSnapshot = null
      popup.promotionWindow = null
    }
    onVisibleChanged: {
      if (!visible && popup.pinned)
        popup.requestClose(true)
    }
  }

  ParallelAnimation {
    id: openAnim
    OpacityAnimator {
      target: content
      to: 1
      duration: popup.reducedMotion ? 0 : Design.motion.enter
      easing.type: Easing.OutCubic
    }
    YAnimator {
      target: content
      to: 0
      duration: popup.reducedMotion ? 0 : Design.motion.enter
      easing.type: Easing.OutCubic
    }
  }

  ParallelAnimation {
    id: closeAnim
    OpacityAnimator {
      target: content
      to: 0
      duration: popup.reducedMotion ? 0 : Design.motion.exit
      easing.type: Easing.InCubic
    }
    YAnimator {
      target: content
      to: 6
      duration: popup.reducedMotion ? 0 : Design.motion.exit
      easing.type: Easing.InCubic
    }
    onFinished: preview.visible = false
  }

  onVisibleChanged: {
    if (popup.visible) {
      popup.syncHistory()
    } else {
      popup.pinned = false
      popup.pinRequest++
      popup.promotionPending = false
      popup.promotionSnapshot = null
      popup.promotionWindow = null
      popup.readingAnchor = null
      anchorRelease.stop()
      centerModel.clear()
      openAnim.stop()
      closeAnim.stop()
      popup.closePending = false
      popup.expandedGroupKey = ""
      content.opacity = 0
      content.y = 0
    }
  }

  FocusScope {
    id: content

    readonly property var nativeWindow: Window.window
    parent: pinnedPopup.visible ? pinnedPopup.contentItem : preview.contentItem
    width: popup.width
    height: popup.height
    focus: popup.pinned
    Keys.onEscapePressed: popup.requestClose()

    Controls.Menu {
      id: headerMenu
      x: Math.max(0, content.width - width - Design.panel.padding)
      y: Design.panel.padding + 40
      width: Math.min(280, popup.width - Design.panel.padding * 2)
      padding: 6
      background: Rectangle {
        color: popup.controller.controlSurface
        border.color: popup.controller.controlSurfaceBorder
        radius: 10
      }
      delegate: Controls.MenuItem {
        id: menuItem
        implicitHeight: Math.max(36, contentItem.implicitHeight + 16)
        contentItem: Text {
          text: menuItem.text
          textFormat: Text.PlainText
          wrapMode: Text.Wrap
          color: menuItem.enabled ? popup.controller.controlPrimaryText : popup.controller.controlSecondaryText
          font.family: popup.controller.fontFamily
          font.pixelSize: 12
        }
        background: Rectangle {
          radius: 7
          color: menuItem.highlighted ? popup.controller.controlHover : "transparent"
          border.width: menuItem.activeFocus ? 1 : 0
          border.color: popup.controller.controlActiveIcon
        }
      }
      Controls.Action {
        text: "Do Not Disturb: " + (popup.controller.doNotDisturb ? "on" : "off")
        onTriggered: popup.controller.toggleDoNotDisturb()
      }
      Controls.Action {
        text: "Notification sounds: " + (popup.service.notificationSoundsMuted ? "muted" : "on")
        onTriggered: popup.service.setNotificationSoundsMuted(!popup.service.notificationSoundsMuted)
      }
      Controls.Action {
        text: "Notification settings"
        onTriggered: popup.controller.openSystemSettings(popup.panel.screen, "notifications")
      }
      Controls.Action {
        text: "Clear all notifications"
        enabled: popup.service.history.length > 0 && !clearAllAnimation.running && !groupDismissTimer.running
        onTriggered: popup.clearAll()
      }
    }

    HoverHandler {
      onHoveredChanged: {
        if (hovered)
          hoverCloseTimer.stop()
        else
          popup.requestHoverClose()
      }
    }

    PanelSurface {
      anchors.fill: parent
      controller: popup.controller
    }

    Column {
      anchors {
        fill: parent
        margins: Design.panel.padding
      }
      spacing: 12

      Item {
        height: 32
        width: parent.width

        Text {
          id: titleText

          anchors.verticalCenter: parent.verticalCenter
          anchors.left: parent.left
          anchors.right: popup.compactHeader ? overflowButton.left : clearButton.visible ? clearButton.left : settingsButton.left
          anchors.rightMargin: 8
          color: popup.controller.controlPrimaryText
          font.family: popup.controller.fontFamily
          font.pixelSize: Design.typography.heading
          elide: Text.ElideRight
          text: "Notifications"
        }

        HeaderIconButton {
          id: modeButton
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          iconName: popup.pinned ? "x" : "keyboard"
          description: popup.pinned ? "Close notifications" : "Pin notifications for keyboard interaction"
          onClicked: popup.pinned ? popup.requestClose() : popup.requestOpen(true)
        }

        HeaderIconButton {
          id: overflowButton
          visible: popup.compactHeader
          anchors.right: modeButton.left
          anchors.rightMargin: 8
          anchors.verticalCenter: parent.verticalCenter
          text: "…"
          description: "More notification controls"
          onClicked: popup.openOverflow()
        }

        HeaderIconButton {
          id: dndButton
          visible: !popup.compactHeader

          active: popup.controller.doNotDisturb
          activeColor: popup.controller.controlActiveIcon
          anchors {
            right: modeButton.left
            rightMargin: 8
            verticalCenter: parent.verticalCenter
          }
          iconName: popup.controller.doNotDisturb ? "bell-off" : "bell"
          description: popup.controller.doNotDisturb
            ? "Do Not Disturb on: " + (popup.service.allowCriticalDuringDnd
              ? "critical alerts may interrupt; " : "popups and sounds muted; ")
              + "notifications still saved. Click to turn off."
            : "Do Not Disturb off: popups enabled; sounds "
              + (popup.service.notificationSoundsMuted ? "muted" : "enabled") + ". Click to turn on."
          Accessible.role: Accessible.CheckBox
          Accessible.name: "Do Not Disturb"
          Accessible.checkable: true
          Accessible.checked: popup.controller.doNotDisturb
          onClicked: popup.controller.toggleDoNotDisturb()
        }

        HeaderIconButton {
          id: soundButton
          visible: !popup.compactHeader

          active: popup.service.notificationSoundsMuted
          activeColor: popup.controller.controlActiveIcon
          anchors {
            right: dndButton.left
            rightMargin: 8
            verticalCenter: parent.verticalCenter
          }
          iconName: popup.service.notificationSoundsMuted ? "volume-x" : "volume-2"
          description: popup.service.notificationSoundsMuted
            ? "Notification sounds muted; popups still follow Do Not Disturb. Click to unmute."
            : "Notification sounds enabled, subject to app preferences and Do Not Disturb exceptions. Click to mute sounds only."
          Accessible.role: Accessible.CheckBox
          Accessible.name: "Mute notification sounds"
          Accessible.checkable: true
          Accessible.checked: popup.service.notificationSoundsMuted
          onClicked: popup.service.setNotificationSoundsMuted(!popup.service.notificationSoundsMuted)
        }

        HeaderIconButton {
          id: settingsButton
          visible: !popup.compactHeader
          anchors.right: soundButton.left
          anchors.rightMargin: 8
          anchors.verticalCenter: parent.verticalCenter
          iconName: "settings"
          description: "Notification settings"
          Accessible.role: Accessible.Button
          Accessible.name: description
          onClicked: popup.controller.openSystemSettings(popup.panel.screen, "notifications")
        }

        DismissButton {
          id: clearButton

          anchors {
            right: settingsButton.left
            rightMargin: 8
            verticalCenter: parent.verticalCenter
          }
          label: "Clear all"
          description: "Clear notification history"
          enabled: !clearAllAnimation.running && !groupDismissTimer.running
          onClicked: popup.clearAll()
          visible: !popup.compactHeader && popup.service.history.length > 0
        }
      }

      Item {
        id: undoBanner
        width: parent.width
        visible: popup.service.clearedHistory.length > 0
        height: visible ? Math.max(undoLabel.implicitHeight, undoButton.height) : 0
        Text {
          id: undoLabel
          width: Math.max(1, parent.width - undoButton.width - 12)
          anchors.verticalCenter: parent.verticalCenter
          text: popup.service.clearedHistory.length + " notifications cleared.\nUndo restores history only, not app actions."
          textFormat: Text.PlainText
          wrapMode: Text.Wrap
          color: popup.controller.controlSecondaryText
          font.family: popup.controller.fontFamily
          font.pixelSize: 11
        }
        NotificationButton {
          id: undoButton
          controller: popup.controller
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          keyboardEnabled: popup.pinned
          text: "Undo"
          description: "Restore cleared notification history"
          onClicked: popup.service.undoClearHistory()
        }
      }

      Item {
        height: Math.max(0, parent.height - 44 - (undoBanner.visible ? undoBanner.height + 12 : 0))
        width: parent.width

        Flickable {
          id: historyView
          anchors.fill: parent
          clip: true
          contentHeight: notificationList.height
          contentWidth: width
          boundsBehavior: Flickable.StopAtBounds
          Controls.ScrollBar.vertical: Controls.ScrollBar {
            policy: Controls.ScrollBar.AsNeeded
          }
          onMovementStarted: popup.readingAnchor = null
          onContentHeightChanged: {
            if (popup.readingAnchor) {
              Qt.callLater(popup.restoreReadingPosition)
              anchorRelease.restart()
            }
          }

          Column {
            id: notificationList

            enabled: !clearAllAnimation.running
            transform: Translate { id: clearAllTranslate }
            spacing: 10
            width: historyView.width - (historyView.contentHeight > historyView.height ? 12 : 0)
            onPositioningComplete: popup.restoreReadingPosition()

            Repeater {
              id: historyGroups
              model: centerModel

              delegate: NotificationGroup {
                required property var historyGroup

                controller: popup.controller
                group: historyGroup
                service: popup.service
                width: notificationList.width
              }
            }
          }
        }

        Column {
          anchors.centerIn: parent
          spacing: 8
          visible: popup.service.history.length === 0

          Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            color: popup.controller.controlSurface
            height: 48
            radius: 24
            width: 48

            LucideIcon {
              anchors.centerIn: parent
              color: popup.controller.controlSecondaryText
              height: 22
              source: popup.controller.icon("bell")
              width: 22
            }
          }

          Text {
            color: popup.controller.controlPrimaryText
            font.family: popup.controller.fontFamily
            font.pixelSize: 13
            horizontalAlignment: Text.AlignHCenter
            text: "No notifications"
            width: 180
          }

          Text {
            color: popup.controller.controlSecondaryText
            font.family: popup.controller.fontFamily
            font.pixelSize: 11
            horizontalAlignment: Text.AlignHCenter
            text: "You are all caught up"
            width: 180
          }
        }
      }
    }
  }
}
