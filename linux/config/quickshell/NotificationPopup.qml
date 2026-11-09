pragma ComponentBehavior: Bound

import Quickshell
import QtQuick
import "DesignTokens.js" as Design
import QtQml
import QtQuick.Controls.Basic as Controls

PopupWindow {
  id: popup

  required property var controller
  required property var panel
  required property var service

  readonly property int viewportMargin: 6
  readonly property bool leftAligned: service.popupCorner.endsWith("left")
  readonly property bool bottomAligned: service.popupCorner.startsWith("bottom")
  readonly property bool selectedScreen: {
    const focused = controller.focusedPanel()
    return service.popupScreenMatches(panel.screen.name, Quickshell.screens, focused ? focused.screen.name : "")
  }
  property var popupStacks: null
  property var readingAnchor: null
  readonly property bool reducedMotion: service.reduceMotion

  function readingEntries() {
    let entries = []
    for (let index = 0; popup.popupStacks && index < popup.popupStacks.count; index++) {
      const stack = popup.popupStacks.itemAt(index)
      if (stack)
        entries = entries.concat(stack.readingEntries())
    }
    return entries.sort((a, b) => a.y - b.y)
  }

  function preserveReadingPosition(excludedIds = []) {
    if (!popup.visible || popupView.moving || popupScrollBar.pressed)
      return
    const entries = popup.readingEntries().filter(entry => !excludedIds.includes(entry.id))
    if (popup.readingAnchor && entries.some(entry => entry.id === popup.readingAnchor.id))
      return
    const anchor = entries.find(entry => entry.y + entry.height > popupView.contentY) || entries[entries.length - 1]
    popup.readingAnchor = anchor ? { id: anchor.id, offset: anchor.y - popupView.contentY } : null
    anchorRelease.restart()
  }

  function restoreReadingPosition() {
    if (popupView.moving || popupScrollBar.pressed) {
      popup.readingAnchor = null
      return
    }
    const entry = popup.readingAnchor && popup.readingEntries().find(entry => entry.id === popup.readingAnchor.id)
    if (entry)
      popupView.contentY = Math.max(0, Math.min(entry.y - popup.readingAnchor.offset, popupView.contentHeight - popupView.height))
  }

  Timer {
    id: anchorRelease
    interval: 300
    onTriggered: {
      popup.restoreReadingPosition()
      popup.readingAnchor = null
    }
  }
  readonly property var emptyRecord: ({
    id: "",
    appName: "",
    summary: "",
    body: "",
    urgency: "normal",
    value: -1,
    actions: []
  })

  anchor.window: panel
  anchor.rect.x: leftAligned ? 12 - viewportMargin : Math.max(0, panel.width - width - 12 + viewportMargin)
  anchor.rect.y: bottomAligned ? Math.max(panel.height + 12, panel.screen.height - height - 12) : panel.height + 12
  color: "transparent"
  implicitWidth: Math.min(Design.notification.width, panel.screen.width - Design.panel.gap * 2) + viewportMargin * 2
  implicitHeight: Math.min(column.height, Math.max(1, panel.screen.height - panel.height - Design.panel.gap * 2))
  surfaceFormat.opaque: false

  visible: popupGroupModel.count > 0 && !controller.notificationCenterOpen && selectedScreen

  ListModel {
    id: popupGroupModel

    dynamicRoles: true
  }

  function addPopupRecord(record) {
    popup.preserveReadingPosition()
    for (let index = 0; popup.popupStacks && index < popup.popupStacks.count; index++) {
      const stack = popup.popupStacks.itemAt(index)
      if (stack && stack.updateRecord(record))
        return
    }
    const lastStack = popup.popupStacks ? popup.popupStacks.itemAt(popup.popupStacks.count - 1) : null
    if (lastStack && lastStack.canAddRecord(record)) {
      lastStack.addRecord(record)
      return
    }

    popupGroupModel.append({ popupGroup: { records: [record] } })
  }

  function removePopupRecord(id) {
    if (!popup.popupStacks)
      return

    for (let index = 0; index < popup.popupStacks.count; index++) {
      const stack = popup.popupStacks.itemAt(index)
      if (stack && stack.expireRecord(id))
        return
    }
  }

  function removeStack(stack) {
    popup.preserveReadingPosition(stack.records.map(record => record.id))
    for (let index = 0; popup.popupStacks && index < popup.popupStacks.count; index++) {
      if (popup.popupStacks.itemAt(index) === stack) {
        popupGroupModel.remove(index)
        return
      }
    }
  }

  Component.onCompleted: {
    for (const group of service.popupGroups)
      popupGroupModel.append({ popupGroup: group })
  }

  Connections {
    target: popup.service

    function onPopupRecordAdded(record) {
      popup.addPopupRecord(record)
    }

    function onPopupRecordRemoved(id) {
      popup.removePopupRecord(id)
    }

    function onPopupRecordsCleared() {
      popup.readingAnchor = null
      popupGroupModel.clear()
    }
  }

  component NotificationToast: Item {
    id: toast

    required property var controller
    required property var record
    required property var service

    property string countLabel: ""
    property bool dismissing: false
    property var dismissingRecordId: null
    property bool interactive: true
    property bool animateReflow: false
    property bool urgentAttention: false
    property var dismissHandler: null
    property real reflowOffset: 0
    property real unfoldOffset: 0
    property bool enterFromRight: false
    property real presentationOpacity: 1
    property real dismissalOpacity: 1
    property var displayedRecordId: null

    opacity: presentationOpacity * dismissalOpacity
    onRecordChanged: {
      if (toast.record && toast.record.id !== toast.displayedRecordId) {
        const replacing = toast.displayedRecordId !== null
        toast.displayedRecordId = toast.record.id
        if (replacing)
          toast.resetDismissal()
      }
    }

    function resetDismissal() {
      dismissAnimation.stop()
      toast.dismissing = false
      toast.dismissingRecordId = null
      dismissTranslate.x = 0
      toast.dismissalOpacity = 1
    }

    readonly property var displayRecord: service.popupDisplayRecord(toast.record)
    readonly property var icon: service.iconFor(toast.displayRecord)
    readonly property string body: service.displayBody(toast.displayRecord)
    readonly property bool canActivate: service.canActivate(toast.record)
    readonly property bool activationPending: service.activationPendingId === toast.record.id

    transform: [
      Translate {
        id: dismissTranslate
      },
      Translate {
        id: entryTranslate
      },
      Translate {
        y: toast.reflowOffset
      },
      Translate {
        y: toast.unfoldOffset
      }
    ]
    width: parent ? parent.width : 0

    Behavior on y {
      enabled: toast.animateReflow

      YAnimator {
        duration: popup.reducedMotion ? 0 : 180
        easing.type: Easing.OutCubic
      }
    }

    function activate() {
      if (toast.dismissing || !toast.canActivate || toast.service.activationPendingId !== null)
        return
      toast.service.activateRecord(toast.record.id)
    }

    function startDismiss() {
      if (toast.dismissing)
        return
      toast.dismissing = true
      toast.dismissingRecordId = toast.record.id
      dismissAnimation.start()
    }

    ParallelAnimation {
      id: dismissAnimation

      NumberAnimation {
        target: dismissTranslate
        property: "x"
        to: popup.leftAligned ? -popup.width : popup.width
        duration: popup.reducedMotion ? 0 : 240
        easing.type: Easing.InCubic
      }
      NumberAnimation {
        target: toast
        property: "dismissalOpacity"
        to: 0
        duration: popup.reducedMotion ? 0 : 180
        easing.type: Easing.InQuad
      }
      onFinished: {
        if (toast.dismissHandler)
          toast.dismissHandler(toast.dismissingRecordId)
        else
          toast.service.dismissRecord(toast.dismissingRecordId)
      }
    }

    NumberAnimation {
      id: reflowAnimation

      target: toast
      property: "reflowOffset"
      to: 0
      duration: popup.reducedMotion ? 0 : 180
      easing.type: Easing.OutCubic
    }

    function moveFrom(previousY) {
      reflowAnimation.stop()
      toast.reflowOffset = previousY - toast.y
      reflowAnimation.restart()
    }

    function playEntry() {
      entryTranslate.x = popup.leftAligned ? -popup.width : popup.width
      entryAnimation.restart()
    }

    Component.onCompleted: {
      if (toast.enterFromRight)
        toast.playEntry()
    }

    NumberAnimation {
      id: entryAnimation

      target: entryTranslate
      property: "x"
      to: 0
      duration: popup.reducedMotion ? 0 : 280
      easing.type: Easing.OutCubic
    }

    Rectangle {
      id: background

      anchors.fill: parent
      border.color: toast.controller.controlSurfaceBorder
      border.width: 1
      color: toast.controller.controlSurface
      radius: Design.notification.radius
    }

    Rectangle {
      id: urgentBreath

      anchors.fill: parent
      color: Qt.rgba(toast.controller.urgent.r, toast.controller.urgent.g, toast.controller.urgent.b, 0.12)
      opacity: 0.18
      radius: Design.notification.radius
      visible: toast.record.urgency === "critical" || toast.urgentAttention

      SequentialAnimation {
        loops: 1
        running: urgentBreath.visible && !popup.reducedMotion

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

    Rectangle {
      anchors {
        left: parent.left
        leftMargin: 12
        top: parent.top
        topMargin: 12
      }
      color: toast.record.urgency === "critical" ? toast.controller.urgent : toast.controller.controlActive
      height: 40
      radius: 12
      width: 40

      Image {
        anchors.fill: parent
        anchors.margins: 8
        fillMode: Image.PreserveAspectFit
        source: toast.icon.kind === "image" ? toast.icon.source : ""
        visible: toast.icon.kind === "image"
      }

      LucideIcon {
        id: notificationIcon

        anchors.centerIn: parent
        color: toast.controller.controlPrimaryText
        height: 20
        source: toast.icon.kind === "lucide" ? toast.controller.icon(toast.icon.source) : ""
        visible: toast.icon.kind === "lucide"
        width: 20
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
        height: 28
        spacing: 4
        width: parent.width

        Text {
          anchors.verticalCenter: parent.verticalCenter
          color: toast.controller.controlSecondaryText
          elide: Text.ElideRight
          font.family: toast.controller.fontFamily
          font.pixelSize: 10
          text: (toast.record.urgency === "critical" ? "Critical · " : "") + toast.record.appName
          textFormat: Text.PlainText
          width: Math.max(0, parent.width - timeLabel.width - countLabelText.width - dismissButton.width - parent.spacing * 3)
        }

        Text {
          id: countLabelText
          anchors.verticalCenter: parent.verticalCenter

          color: toast.controller.controlSecondaryText
          font.family: toast.controller.fontFamily
          font.pixelSize: 10
          text: toast.countLabel
          visible: toast.countLabel.length > 0
          width: visible ? contentWidth : 0
        }

        Text {
          id: timeLabel
          anchors.verticalCenter: parent.verticalCenter

          color: toast.controller.controlSecondaryText
          font.family: toast.controller.fontFamily
          font.pixelSize: 10
          text: popup.service.timeAgo(toast.record)
        }

        NotificationButton {
          id: dismissButton
          controller: toast.controller
          iconName: "x"
          description: "Dismiss notification"
          keyboardEnabled: false
          enabled: toast.interactive && !toast.dismissing
          onClicked: toast.startDismiss()
        }
      }

      Text {
        color: toast.controller.controlPrimaryText
        elide: Text.ElideRight
        font.family: toast.controller.fontFamily
        font.pixelSize: 12
        text: toast.displayRecord.summary
        textFormat: Text.PlainText
        width: parent.width
      }

      Text {
        color: toast.controller.controlSecondaryText
        elide: Text.ElideRight
        font.family: toast.controller.fontFamily
        font.pixelSize: 11
        maximumLineCount: 2
        text: toast.body
        textFormat: Text.PlainText
        visible: toast.body.length > 0
        width: parent.width
        wrapMode: Text.Wrap
      }

      Text {
        width: parent.width
        visible: text.length > 0
        text: toast.service.activationPendingId === toast.record.id ? "Opening…"
          : toast.service.activationErrorId === toast.record.id ? toast.service.activationError : ""
        textFormat: Text.PlainText
        wrapMode: Text.Wrap
        color: toast.service.activationPendingId === toast.record.id
          ? toast.controller.controlSecondaryText : toast.controller.urgent
        font.family: toast.controller.fontFamily
        font.pixelSize: 11
      }

      Rectangle {
        color: toast.controller.controlSliderFill
        height: 4
        radius: 2
        visible: toast.displayRecord.value >= 0
        width: parent.width * Math.min(1, Math.max(0, toast.displayRecord.value / 100))
      }

      Flow {
        spacing: 8
        visible: toast.displayRecord.actions.length > 0
        enabled: toast.interactive && !toast.dismissing
        width: parent.width

        Repeater {
          model: toast.displayRecord.actions

          delegate: NotificationButton {
            id: actionDelegate

            required property var modelData
            required property int index

            controller: toast.controller
            maximumWidth: textColumn.width
            text: actionDelegate.modelData.text
            keyboardEnabled: false
            enabled: toast.service.activationPendingId === null
            onClicked: popup.service.invokeAction(toast.record.id, actionDelegate.modelData.sourceIndex)
          }
        }
      }
    }

    height: Math.max(textColumn.height + 24, 64)

    MouseArea {
      anchors.fill: parent
      acceptedButtons: Qt.LeftButton | Qt.RightButton
      cursorShape: toast.activationPending ? Qt.BusyCursor : toast.canActivate ? Qt.PointingHandCursor : Qt.ArrowCursor
      enabled: toast.interactive
      hoverEnabled: true
      onClicked: mouse => {
        if (mouse.button === Qt.RightButton) {
          toast.startDismiss()
        } else {
          toast.activate()
        }
      }
      z: -1
    }
  }

  component PopupStack: Item {
    id: stack

    required property var controller
    required property var popupGroup
    required property var service

    property var records: popupGroup.records
    property var removeHandler: null
    readonly property int maxCollapsedCards: 3
    readonly property int visibleCollapsedCardCount: Math.min(records.length, maxCollapsedCards)
    readonly property int layerCount: Math.max(0, visibleCollapsedCardCount - 1)
    readonly property int collapsedLayerInset: 6
    readonly property int collapsedLayerOffset: 12
    readonly property var latestRecord: records[records.length - 1]
    readonly property bool grouped: records.length > 1
    readonly property bool showingExpanded: expanded && records.length > 0
    readonly property bool hasCritical: records.some(record => record.urgency === "critical")
    readonly property bool hoverProtected: stackHover.hovered || (popupView.interactive && viewportHover.hovered)
    property bool expanded: false
    property bool expiring: false
    property int expiringLayerIndex: -1
    property var expiringStackRecordId: ""
    property var pendingStackExpiryIds: []
    property real expandedHeight: 0
    property bool reflowing: false
    property var reflowPositions: null

    function readingEntries() {
      return stack.records.slice().reverse().map((record, index) => {
        const item = stack.showingExpanded ? expandedCards.itemAt(index) : latestToast
        return { id: record.id, y: item ? item.mapToItem(column, 0, 0).y : stack.y, height: item ? item.height : stack.height }
      })
    }

    onHeightChanged: Qt.callLater(popup.restoreReadingPosition)
    onYChanged: Qt.callLater(popup.restoreReadingPosition)

    ListModel {
      id: recordModel

      dynamicRoles: true
    }

    transform: [
      Translate {
        id: entryTranslate
      },
      Translate {
        id: expiryTranslate
      }
    ]
    clip: !reflowing
    height: records.length === 0 ? 0 : (showingExpanded ? expandedHeight : latestToast.height + layerCount * collapsedLayerOffset)
    visible: records.length > 0
    width: parent ? parent.width : 0

    Behavior on height {
      NumberAnimation { duration: popup.reducedMotion ? 0 : 240; easing.type: Easing.OutCubic }
    }

    Behavior on y {
      NumberAnimation {
        duration: popup.reducedMotion ? 0 : 180
        easing.type: Easing.OutCubic
      }
    }

    Component.onCompleted: {
      for (const record of stack.records.slice().reverse())
        recordModel.append({ notification: record })
      entryAnimation.start()
    }

    NumberAnimation {
      id: entryAnimation

      target: entryTranslate
      property: "x"
      from: popup.leftAligned ? -popup.width : popup.width
      to: 0
      duration: popup.reducedMotion ? 0 : 280
      easing.type: Easing.OutCubic
    }

    ParallelAnimation {
      id: expiryAnimation

      NumberAnimation { target: expiryTranslate; property: "x"; to: popup.leftAligned ? -popup.width : popup.width; duration: popup.reducedMotion ? 0 : 240; easing.type: Easing.InCubic }
      OpacityAnimator { target: stack; to: 0; duration: popup.reducedMotion ? 0 : 180; easing.type: Easing.InQuad }
      onFinished: {
        if (stack.expiring && stack.removeHandler)
          stack.removeHandler(stack)
      }
    }

    Timer {
      id: collapseTimer

      interval: 250
      onTriggered: {
        popup.preserveReadingPosition()
        stack.expanded = false
        stack.expandedHeight = 0
      }
    }

    Timer {
      id: reflowTimer

      interval: popup.reducedMotion ? 0 : 180
      onTriggered: stack.reflowing = false
    }

    Timer {
      id: stackedExpiryTimer

      interval: popup.reducedMotion ? 0 : 180
      onTriggered: stack.finishStackExpiry()
    }

    onHoverProtectedChanged: {
      stack.service.setRecordsHovered(stack.records, stack.hoverProtected)
      if (stack.hoverProtected)
        collapseTimer.stop()
      else
        collapseTimer.restart()
    }

    HoverHandler {
      id: stackHover
      onHoveredChanged: {
        if (hovered && !stack.expanded && stack.grouped) {
          popup.preserveReadingPosition()
          stack.expandedHeight = expandedColumn.contentHeight
          stack.expanded = true
        }
      }
    }

    Repeater {
      model: stack.layerCount

      delegate: Rectangle {
        required property int index

        border.color: stack.controller.controlSurfaceBorder
        border.width: 1
        color: stack.controller.controlSurface
        height: latestToast.height
        opacity: stack.expanded || index === stack.expiringLayerIndex ? 0 : 0.72 + index * 0.12
        radius: Design.notification.radius
        scale: index === stack.expiringLayerIndex ? 0.9 : 1
        transformOrigin: Item.Center
        visible: stack.records.length > 0
        width: stack.width - (stack.layerCount - index) * stack.collapsedLayerInset * 2
        x: (stack.layerCount - index) * stack.collapsedLayerInset
        y: index * stack.collapsedLayerOffset - (index === stack.expiringLayerIndex ? 6 : 0)

        Behavior on opacity {
          NumberAnimation { duration: popup.reducedMotion ? 0 : 180; easing.type: Easing.OutCubic }
        }

        Behavior on scale {
          NumberAnimation { duration: popup.reducedMotion ? 0 : 180; easing.type: Easing.InQuad }
        }

        Behavior on y {
          YAnimator { duration: popup.reducedMotion ? 0 : 180; easing.type: Easing.InQuad }
        }
      }
    }

    NotificationToast {
      id: latestToast

      controller: stack.controller
      countLabel: stack.records.length > 1 ? "+" + (stack.records.length - 1) : ""
      interactive: !stack.showingExpanded
      record: stack.latestRecord || popup.emptyRecord
      service: stack.service
      urgentAttention: stack.hasCritical
      presentationOpacity: stack.showingExpanded ? 0 : 1
      dismissHandler: id => stack.dismissRecord(id)
      visible: stack.records.length > 0
      y: stack.layerCount * stack.collapsedLayerOffset
      z: 3

      Behavior on presentationOpacity {
        NumberAnimation { duration: popup.reducedMotion ? 0 : 180; easing.type: Easing.OutCubic }
      }
    }

    Item {
      id: expandedColumn

      property real spacing: 8
      property real contentHeight: {
        let height = 0
        for (let index = 0; index < expandedCards.count; index++) {
          const card = expandedCards.itemAt(index)
          if (card)
            height += card.height
        }
        return height + Math.max(0, expandedCards.count - 1) * expandedColumn.spacing
      }

      function cardY(index, cardHeight) {
        let y = expandedColumn.height - cardHeight
        for (let previousIndex = 0; previousIndex < index; previousIndex++) {
          const previousCard = expandedCards.itemAt(previousIndex)
          if (previousCard)
            y -= previousCard.height + expandedColumn.spacing
        }
        return y
      }

      height: stack.showingExpanded ? stack.expandedHeight : contentHeight
      enabled: stack.showingExpanded
      visible: stack.records.length > 0
      width: parent.width
      z: 4

      Repeater {
        id: expandedCards

        model: recordModel

        delegate: NotificationToast {
          id: expandedCard

          required property int index
          required property var notification

          controller: stack.controller
          enterFromRight: notification && notification.entering === true
          interactive: stack.showingExpanded
          presentationOpacity: stack.showingExpanded ? 1 : 0
          dismissHandler: id => stack.dismissRecord(id)
          record: notification || popup.emptyRecord
          service: stack.service
          urgentAttention: notification && notification.urgency === "critical"
          unfoldOffset: stack.expanded ? 0 : 16 + expandedCard.index * 3
          y: expandedColumn.cardY(expandedCard.index, height)
          onHeightChanged: {
            if (stack.showingExpanded)
              Qt.callLater(stack.updateExpandedHeight)
          }
          onYChanged: Qt.callLater(popup.restoreReadingPosition)
          onReflowOffsetChanged: Qt.callLater(popup.restoreReadingPosition)

          Behavior on unfoldOffset {
            NumberAnimation {
              duration: popup.reducedMotion ? 0 : 240
              easing.type: Easing.OutCubic
            }
          }

          Behavior on presentationOpacity {
            SequentialAnimation {
              PauseAnimation { duration: stack.expanded && !popup.reducedMotion ? Math.min(100, Math.max(0, expandedCard.index) * 25) : 0 }
              NumberAnimation { duration: popup.reducedMotion ? 0 : 180; easing.type: Easing.OutCubic }
            }
          }
        }
      }
    }

    function dismissRecord(id) {
      const service = stack.service
      stack.removeRecords([id])
      service.dismissRecord(id)
    }

    function removeRecords(ids) {
      if (!stack.records.some(record => ids.includes(record.id)))
        return
      popup.preserveReadingPosition(ids)
      if (stack.showingExpanded && !stack.reflowPositions) {
        const positions = {}
        for (let index = 0; index < expandedCards.count; index++) {
          const card = expandedCards.itemAt(index)
          if (card)
            positions[card.record.id] = card.y + card.reflowOffset
        }
        stack.reflowPositions = positions
        stack.reflowing = true
      }
      for (let index = recordModel.count - 1; index >= 0; index--) {
        if (ids.includes(recordModel.get(index).notification.id))
          recordModel.remove(index)
      }
      stack.records = stack.records.filter(record => !ids.includes(record.id))
      if (stack.records.length === 0)
        stack.removeHandler(stack)
      else
        Qt.callLater(stack.finishReflow)
    }

    function finishReflow() {
      if (stack.showingExpanded) {
        stack.updateExpandedHeight()
        for (let index = 0; index < expandedCards.count; index++) {
          const card = expandedCards.itemAt(index)
          if (card && stack.reflowPositions && stack.reflowPositions[card.record.id] !== undefined)
            card.moveFrom(stack.reflowPositions[card.record.id])
        }
      }
      stack.reflowPositions = null
      reflowTimer.restart()
    }

    function updateRecord(record) {
      const index = stack.records.findIndex(entry => entry.id === record.id)
      if (index < 0)
        return false
      if (stack.expiring) {
        stack.expiring = false
        expiryAnimation.stop()
        expiryTranslate.x = 0
        stack.opacity = 1
      }
      stack.pendingStackExpiryIds = stack.pendingStackExpiryIds.filter(id => id !== record.id)
      if (stack.expiringStackRecordId === record.id) {
        stack.expiringStackRecordId = stack.pendingStackExpiryIds[0] || ""
        stack.pendingStackExpiryIds = stack.pendingStackExpiryIds.slice(1)
        if (stack.expiringStackRecordId === "") {
          stackedExpiryTimer.stop()
          stack.expiringLayerIndex = -1
        }
      }
      stack.records = stack.records.map(entry => entry.id === record.id ? record : entry)
      recordModel.setProperty(recordModel.count - index - 1, "notification", record)
      if (stack.hoverProtected)
        stack.service.setHovered(record.id, true)
      if (stack.showingExpanded)
        Qt.callLater(stack.updateExpandedHeight)
      return true
    }

    function canAddRecord(record) {
      const latestRecord = stack.records[stack.records.length - 1]
      const firstRecord = stack.records[0]
      return !stack.expiring && !latestToast.dismissing && latestRecord
        && stack.service.appKey(record) === stack.service.appKey(latestRecord)
        && record.urgency === latestRecord.urgency
        && record.time - latestRecord.time <= stack.service.popupGroupWindow
        && Math.abs(record.time - firstRecord.time) <= stack.service.notificationGroupWindow
    }

    function addRecord(record) {
      if (!stack.canAddRecord(record))
        return

      stack.records = stack.records.concat([record])
      if (stack.hoverProtected)
        stack.service.setHovered(record.id, true)
      recordModel.insert(0, { notification: Object.assign({}, record, { entering: true }) })

      if (stack.showingExpanded) {
        Qt.callLater(stack.updateExpandedHeight)
      } else {
        Qt.callLater(latestToast.playEntry)
      }
    }

    function updateExpandedHeight() {
      stack.expandedHeight = expandedColumn.contentHeight
    }

    function expireRecord(id) {
      const index = stack.records.findIndex(record => record.id === id)
      if (index < 0)
        return false

      if (stack.records.length === 1) {
        stack.expiring = true
        expiryAnimation.start()
        return true
      }

      if (!stack.showingExpanded) {
        if (stack.expiringStackRecordId !== "") {
          if (!stack.pendingStackExpiryIds.includes(id))
            stack.pendingStackExpiryIds = stack.pendingStackExpiryIds.concat([id])
          return true
        }

        stack.expiringStackRecordId = id
        stack.expiringLayerIndex = Math.min(index, stack.layerCount - 1)
        stackedExpiryTimer.restart()
        return true
      }

      stack.removeRecords([id])

      return true
    }

    function finishStackExpiry() {
      // One exit animation covers a burst; do not build a serial removal backlog.
      const ids = stack.pendingStackExpiryIds.concat([stack.expiringStackRecordId])
      stack.expiringLayerIndex = -1
      stack.expiringStackRecordId = ""
      stack.pendingStackExpiryIds = []
      stack.removeRecords(ids)
    }

  }

  Flickable {
    id: popupView

    anchors.fill: parent
    contentHeight: column.height
    contentWidth: width
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    flickableDirection: Flickable.VerticalFlick
    interactive: contentHeight > height
    onMovementStarted: popup.readingAnchor = null
    onContentHeightChanged: {
      if (popup.readingAnchor) {
        Qt.callLater(popup.restoreReadingPosition)
        anchorRelease.restart()
      } else {
        contentY = Math.max(0, Math.min(contentY, contentHeight - height))
      }
    }
    HoverHandler { id: viewportHover }
    Controls.ScrollBar.vertical: Controls.ScrollBar {
      id: popupScrollBar
      width: popup.viewportMargin
      policy: Controls.ScrollBar.AsNeeded
      active: popupView.interactive
      onPressedChanged: { if (pressed) popup.readingAnchor = null }
    }

    Column {
      id: column

      anchors {
        horizontalCenter: parent.horizontalCenter
        top: parent.top
      }
      spacing: 10
      width: popupView.width - popup.viewportMargin * 2
      onPositioningComplete: popup.restoreReadingPosition()

      Component.onCompleted: popup.popupStacks = stackRepeater

      Repeater {
        id: stackRepeater

        model: popupGroupModel

        delegate: PopupStack {
          controller: popup.controller
          removeHandler: stack => popup.removeStack(stack)
          service: popup.service
        }
      }
    }
  }
}
