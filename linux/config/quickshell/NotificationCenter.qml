import Quickshell
import QtQuick
import QtQml
import QtQuick.Controls.Basic as Controls

PopupWindow {
  id: popup

  required property var controller
  required property var panel
  required property var service

  anchor.window: panel
  anchor.rect.x: parentWindow.width - width - 12
  anchor.rect.y: parentWindow.height + 12
  color: "transparent"
  grabFocus: false
  implicitHeight: 548
  implicitWidth: 432
  surfaceFormat.opaque: false

  component HeaderIconButton: Item {
    id: button

    required property string iconName
    property color idleColor: popup.controller.controlPrimaryText
    property color activeColor: popup.controller.urgent
    property bool active: false
    property bool destructive: false
    signal clicked

    height: 32
    width: 32

    Rectangle {
      anchors.fill: parent
      color: button.active
        ? Qt.rgba(button.activeColor.r, button.activeColor.g, button.activeColor.b, area.containsMouse ? 0.35 : 0.18)
        : (area.containsMouse
          ? (button.destructive
            ? Qt.rgba(button.activeColor.r, button.activeColor.g, button.activeColor.b, 0.25)
            : popup.controller.controlSurface)
          : "transparent")
      radius: 8
    }

    LucideIcon {
      anchors.centerIn: parent
      color: button.active || (button.destructive && area.containsMouse) ? button.activeColor : button.idleColor
      height: 16
      source: popup.controller.icon(button.iconName)
      width: 16
    }

    MouseArea {
      id: area

      anchors.fill: parent
      cursorShape: Qt.PointingHandCursor
      hoverEnabled: true
      onClicked: button.clicked()
    }
  }

  component DismissButton: Item {
    id: button

    required property string description
    property string label: ""
    property bool emphasized: false
    signal clicked()

    width: label ? buttonLabel.implicitWidth + 20 : 28
    height: 28
    activeFocusOnTab: enabled && visible
    opacity: button.emphasized || area.containsMouse || activeFocus ? 1 : 0.45
    Accessible.role: Accessible.Button
    Accessible.name: description
    Accessible.onPressAction: { if (enabled) clicked() }
    Keys.onSpacePressed: event => { if (!event.isAutoRepeat) clicked() }
    Keys.onReturnPressed: event => { if (!event.isAutoRepeat) clicked() }
    Keys.onEnterPressed: event => { if (!event.isAutoRepeat) clicked() }
    Controls.ToolTip {
      parent: button
      x: button.width - implicitWidth
      y: -implicitHeight - 6
      visible: button.enabled && (area.containsMouse || button.activeFocus)
      delay: 500
      padding: 8
      contentItem: Text {
        text: button.description
        textFormat: Text.PlainText
        color: popup.controller.controlPrimaryText
        font.family: popup.controller.fontFamily
        font.pixelSize: 11
      }
      background: Rectangle {
        color: popup.controller.controlSurface
        border.color: popup.controller.controlSecondaryText
        radius: 7
      }
    }

    Behavior on opacity {
      NumberAnimation { duration: 120; easing.type: Easing.OutQuad }
    }

    Rectangle {
      anchors.fill: parent
      radius: 7
      color: area.containsMouse || button.activeFocus ? popup.controller.controlSliderTrack : "transparent"
      border.width: button.activeFocus ? 1 : 0
      border.color: popup.controller.controlSecondaryText
    }

    LucideIcon {
      anchors.centerIn: parent
      width: 14
      height: 14
      visible: !button.label
      source: popup.controller.icon("x")
      color: popup.controller.controlSecondaryText
    }

    Text {
      id: buttonLabel
      anchors.centerIn: parent
      text: button.label
      visible: button.label !== ""
      color: popup.controller.controlSecondaryText
      font.family: popup.controller.fontFamily
      font.pixelSize: 11
    }

    MouseArea {
      id: area
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: button.clicked()
    }
  }

  component NotificationCard: Item {
    id: card

    required property var controller
    required property var record
    required property var service

    readonly property bool isLive: Boolean(service.live[record.id])
    readonly property var icon: service.iconFor(card.record)
    readonly property string body: service.displayBody(card.record)
    readonly property real contentHeight: textColumn.height + 24

    property bool dismissing: false
    property real bellAngle: 0
    property bool groupDismissing: false
    property int groupDismissDelay: 0
    property real groupDismissOffset: 0

    transform: [
      Translate {
        id: urgentTranslate
      },
      Translate {
        x: card.groupDismissOffset
      }
    ]
    width: parent.width
    height: card.contentHeight

    Behavior on y {
      enabled: !card.dismissing && !card.groupDismissing

      YAnimator {
        duration: 180
        easing.type: Easing.OutCubic
      }
    }

    SequentialAnimation {
      id: urgentWiggle

      loops: Animation.Infinite
      running: card.isLive && card.record.urgency === "critical" && !card.dismissing

      PauseAnimation { duration: 1800 }
      ParallelAnimation {
        NumberAnimation { target: urgentTranslate; property: "x"; to: 5; duration: 70; easing.type: Easing.OutQuad }
        NumberAnimation { target: card; property: "bellAngle"; to: -12; duration: 70; easing.type: Easing.OutQuad }
      }
      ParallelAnimation {
        NumberAnimation { target: urgentTranslate; property: "x"; to: -5; duration: 110; easing.type: Easing.InOutSine }
        NumberAnimation { target: card; property: "bellAngle"; to: 10; duration: 110; easing.type: Easing.InOutSine }
      }
      ParallelAnimation {
        NumberAnimation { target: urgentTranslate; property: "x"; to: 3; duration: 90; easing.type: Easing.InOutSine }
        NumberAnimation { target: card; property: "bellAngle"; to: -6; duration: 90; easing.type: Easing.InOutSine }
      }
      ParallelAnimation {
        NumberAnimation { target: urgentTranslate; property: "x"; to: 0; duration: 100; easing.type: Easing.OutQuad }
        NumberAnimation { target: card; property: "bellAngle"; to: 0; duration: 100; easing.type: Easing.OutQuad }
      }

      onStopped: {
        urgentTranslate.x = 0
        card.bellAngle = 0
      }
    }

    HoverHandler { id: cardHover }

    // Declared first so the buttons inside the surface keep their clicks.
    MouseArea {
      anchors.fill: parent
      cursorShape: Qt.PointingHandCursor
      hoverEnabled: true
      onClicked: card.activate()
    }

    Item {
      id: surface

      height: parent.height
      width: parent.width

      Rectangle {
        anchors.fill: parent
        border.color: card.controller.darkMode ? "#33404D" : "#D7DCE3"
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
          loops: Animation.Infinite
          running: urgentBreath.visible

          NumberAnimation {
            target: urgentBreath
            property: "opacity"
            from: 0.18
            to: 0.85
            duration: 1100
            easing.type: Easing.InOutSine
          }
          PauseAnimation { duration: 150 }
          NumberAnimation {
            target: urgentBreath
            property: "opacity"
            from: 0.85
            to: 0.18
            duration: 1100
            easing.type: Easing.InOutSine
          }
          PauseAnimation { duration: 450 }
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
          height: 22
          spacing: 6
          width: parent.width

          Text {
            color: card.controller.controlSecondaryText
            elide: Text.ElideRight
            font.family: card.controller.fontFamily
            font.pixelSize: 10
            text: card.record.appName
            width: parent.width - timeLabel.width - dismissButton.width - parent.spacing * 2
          }

          Text {
            id: timeLabel

            anchors.verticalCenter: parent.verticalCenter
            color: card.controller.controlSecondaryText
            font.family: card.controller.fontFamily
            font.pixelSize: 10
            text: service.timeAgo(card.record)
          }

          DismissButton {
            id: dismissButton

            anchors.verticalCenter: parent.verticalCenter
            description: "Dismiss notification"
            emphasized: cardHover.hovered
            enabled: !card.dismissing && !card.groupDismissing
            onClicked: card.startDismiss()
          }
        }

        Text {
          color: card.controller.controlPrimaryText
          elide: Text.ElideRight
          font.family: card.controller.fontFamily
          font.pixelSize: 12
          text: card.record.summary
          width: parent.width
        }

        Text {
          color: card.controller.controlSecondaryText
          elide: Text.ElideRight
          font.family: card.controller.fontFamily
          font.pixelSize: 11
          maximumLineCount: 2
          text: card.body
          visible: card.body.length > 0
          width: parent.width
          wrapMode: Text.Wrap
        }

        Row {
          height: 26
          spacing: 8
          visible: card.isLive && card.record.actions.length > 0
          width: parent.width

          Repeater {
            model: card.record.actions

            delegate: Item {
              required property var modelData
              required property int index

              height: 26
              width: buttonLabel.implicitWidth + 20

              Rectangle {
                anchors.fill: parent
                color: card.controller.controlBackground
                radius: 8
              }

              Text {
                id: buttonLabel

                anchors.centerIn: parent
                color: card.controller.controlPrimaryText
                font.family: card.controller.fontFamily
                font.pixelSize: 11
                text: modelData.text
              }

              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: service.invokeAction(card.record.id, modelData.sourceIndex)
              }
            }
          }
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

          transform: Rotation {
            id: bellRotation

            angle: card.icon.kind === "lucide" && card.icon.source === "bell" ? card.bellAngle : 0
            origin.x: notificationIcon.width / 2
            origin.y: 0
          }
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
      if (card.dismissing)
        return
      card.service.activateRecord(card.record.id)
      card.service.dismissRecord(card.record.id)
    }

    onGroupDismissingChanged: {
      if (groupDismissing)
        groupDismissAnimation.start()
    }

    SequentialAnimation {
      id: groupDismissAnimation

      PauseAnimation { duration: Math.max(0, card.groupDismissDelay) }
      NumberAnimation {
        target: card
        property: "groupDismissOffset"
        to: card.width
        duration: 260
        easing.type: Easing.InCubic
      }
    }

    ParallelAnimation {
      id: dismissAnim

      XAnimator {
        target: surface
        to: -card.width
        duration: 260
        easing.type: Easing.OutCubic
      }
      OpacityAnimator {
        target: surface
        to: 0
        duration: 200
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

    HoverHandler { id: groupHover }

    required property var controller
    required property var group
    required property var service

    property var records: group.records
    readonly property bool grouped: recordModel.count > 1
    readonly property var icon: recordModel.count > 0 ? service.iconFor(recordModel.get(0).notification) : ({ kind: "lucide", source: "bell" })
    readonly property bool expanded: popup.expandedGroupKey === group.key
    property bool dismissing: false
    property real headerDismissOffset: 0

    ListModel {
      id: recordModel

      dynamicRoles: true
    }

    clip: true
    height: grouped ? groupHeader.height + (expanded ? cardList.height + 8 : 0) : cardList.height
    width: parent.width

    Behavior on height {
      NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
    }

    Component.onCompleted: syncRecords(notificationGroup.records)

    function syncRecords(records) {
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

    Timer {
      id: groupDismissTimer

      interval: 320 + Math.max(0, recordModel.count - 1) * 70
      onTriggered: notificationGroup.service.dismissRecords(notificationGroup.recordsForDismissal())
    }

    NumberAnimation {
      id: headerDismissAnimation

      target: notificationGroup
      property: "headerDismissOffset"
      to: notificationGroup.width
      duration: 260
      easing.type: Easing.InCubic
    }

    function startClearAllDismiss() {
      clearAllDismissAnimation.start()
    }

    OpacityAnimator {
      id: clearAllDismissAnimation

      target: notificationGroup
      to: 0
      duration: 200
      easing.type: Easing.OutCubic
    }

    Item {
      id: groupHeader

      enabled: !notificationGroup.dismissing
      height: 56
      transform: Translate { x: notificationGroup.headerDismissOffset }
      visible: notificationGroup.grouped
      width: parent.width

      MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: notificationGroup.toggleExpanded()
        z: -1
      }

      Rectangle {
        anchors.fill: parent
        border.color: notificationGroup.controller.darkMode ? "#33404D" : "#D7DCE3"
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
          width: parent.width
        }

        Text {
          color: notificationGroup.controller.controlSecondaryText
          font.family: notificationGroup.controller.fontFamily
          font.pixelSize: 10
          text: recordModel.count + " notifications"
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
        emphasized: groupHover.hovered
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
        source: notificationGroup.controller.icon("chevrons-down-up")
        width: 16
      }
    }

    Column {
      id: cardList

      enabled: !notificationGroup.dismissing
      spacing: 10
      width: parent.width - 12
      x: notificationGroup.grouped ? 12 : 0
      y: notificationGroup.grouped ? groupHeader.height + 8 : 0

      Repeater {
        id: historyCards
        model: recordModel

        delegate: NotificationCard {
          required property int index
          required property var notification

          controller: notificationGroup.controller
          groupDismissing: notificationGroup.dismissing
          groupDismissDelay: 60 + Math.max(0, index) * 70
          groupDismissOffset: 0
          opacity: !notificationGroup.grouped || notificationGroup.expanded ? 1 : 0
          record: notification
          service: notificationGroup.service
          width: cardList.width

          Behavior on opacity {
            SequentialAnimation {
              PauseAnimation { duration: notificationGroup.expanded ? Math.max(0, index) * 70 : 0 }
              NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
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
      groupDismissTimer.start()
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
  property var readingAnchor: null

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
    if (!popup.visible || clearAllAnimation.running)
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
  }

  ParallelAnimation {
    id: clearAllAnimation

    NumberAnimation {
      target: clearAllTranslate
      property: "x"
      to: popup.width
      duration: 240
      easing.type: Easing.InCubic
    }
    NumberAnimation {
      target: notificationList
      property: "opacity"
      to: 0
      duration: 180
      easing.type: Easing.InQuad
    }
    onFinished: {
      popup.service.dismissRecords(popup.clearingRecords)
      popup.clearingRecords = []
      popup.expandedGroupKey = ""
      clearAllTranslate.x = 0
      notificationList.opacity = 1
    }
  }

  function requestOpen() {
    if (popup.visible && !closeAnim.running)
      return
    popup.closePending = false
    closeAnim.stop()
    if (!popup.visible) {
      content.opacity = 0
      content.y = 10
      popup.visible = true
    }
    openAnim.start()
  }

  function requestClose() {
    if (!popup.visible || closeAnim.running)
      return
    popup.closePending = true
    openAnim.stop()
    closeAnim.start()
  }

  // Soft rise + fade: content slides up into place on open and down on close.
  ParallelAnimation {
    id: openAnim
    OpacityAnimator {
      target: content
      to: 1
      duration: 160
      easing.type: Easing.OutCubic
    }
    YAnimator {
      target: content
      to: 0
      duration: 160
      easing.type: Easing.OutCubic
    }
  }

  ParallelAnimation {
    id: closeAnim
    OpacityAnimator {
      target: content
      to: 0
      duration: 120
      easing.type: Easing.InCubic
    }
    YAnimator {
      target: content
      to: 6
      duration: 120
      easing.type: Easing.InCubic
    }
    onStopped: {
      if (popup.closePending) {
        popup.closePending = false
        popup.visible = false
      }
    }
  }

  onVisibleChanged: {
    if (popup.visible) {
      popup.syncHistory()
    } else {
      popup.readingAnchor = null
      anchorRelease.stop()
      centerModel.clear()
      openAnim.stop()
      closeAnim.stop()
      popup.closePending = false
      popup.expandedGroupKey = ""
      content.opacity = 1
      content.y = 0
    }
  }

  Item {
    id: content

    width: parent.width
    height: parent.height

    HoverHandler {
      onHoveredChanged: {
        if (hovered)
          popup.controller.cancelHoverClose()
        else
          popup.controller.requestHoverClose(1)
      }
    }

    Rectangle {
      anchors.fill: parent
      border.color: popup.controller.darkMode ? "#3A424E" : "#D8DDE4"
      border.width: 1
      color: popup.controller.controlBackground
      radius: 26
    }

    Column {
      anchors {
        fill: parent
        margins: 16
      }
      spacing: 12

      Item {
        height: 32
        width: parent.width

        Text {
          id: titleText

          anchors.verticalCenter: parent.verticalCenter
          color: popup.controller.controlPrimaryText
          font.family: popup.controller.fontFamily
          font.pixelSize: 18
          text: "Notifications"
        }

        HeaderIconButton {
          id: dndButton

          active: popup.controller.doNotDisturb
          activeColor: popup.controller.urgent
          anchors {
            right: parent.right
            verticalCenter: parent.verticalCenter
          }
          iconName: "bell"
          onClicked: popup.controller.toggleDoNotDisturb()
        }

        DismissButton {
          id: clearButton

          anchors {
            right: dndButton.left
            rightMargin: 8
            verticalCenter: parent.verticalCenter
          }
          label: "Clear all"
          description: "Clear notification history"
          emphasized: true
          enabled: !clearAllAnimation.running
          onClicked: {
            popup.clearingRecords = service.history.slice()
            popup.startClearAllDismissals()
            clearAllAnimation.start()
          }
          visible: service.history.length > 0
        }
      }

      Item {
        height: parent.height - 44
        width: parent.width

        Flickable {
          id: historyView
          anchors.fill: parent
          clip: true
          contentHeight: notificationList.height
          contentWidth: width
          boundsBehavior: Flickable.StopAtBounds
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
            width: parent.width
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
          visible: service.history.length === 0

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
