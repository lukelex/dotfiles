pragma ComponentBehavior: Bound

import Quickshell
import QtQuick

PopupWindow {
  id: popup

  required property var controller
  required property var panel
  required property var service
  required property var prs
  property var expanded: ({})

  readonly property var reviews: service.history.filter(service.isGithubReview)
  readonly property var stacks: prs.prs.length > 0 ? prs.prs : popup.groupReviews(popup.reviews)

  anchor.window: panel
  anchor.rect.x: Math.max(0, panel.width - width - 12)
  anchor.rect.y: panel.height + 12
  color: "transparent"
  grabFocus: false
  implicitHeight: Math.min(640, panel.screen.height - panel.height - 24)
  implicitWidth: Math.min(560, panel.screen.width - 24)
  surfaceFormat.opaque: false

  onVisibleChanged: popup.controller.githubReviewCenterOpen = visible

  function requestOpen() { prs.refresh(true); popup.visible = true }
  function requestClose() { popup.visible = false }

  function groupReviews(records) {
    const groups = []
    for (const record of records) {
      const key = record.githubReviewUrl
      let group = groups.find(entry => entry.key === key)
      if (!group) {
        group = {
          key: key,
          repository: record.githubRepository,
          number: record.githubNumber,
          title: record.githubTitle,
          status: record.githubStatus,
          url: record.githubReviewUrl,
          reviews: []
        }
        groups.push(group)
      }
      group.reviews.push(record)
    }
    return groups
  }

  function toggleStack(key) {
    const next = Object.assign({}, popup.expanded)
    next[key] = !next[key]
    popup.expanded = next
  }

  function hasNew(stack) {
    return stack.reviews.some(review => !popup.service.isGithubReviewSeen(review))
  }

  function actionLabel(action) {
    return ({
      "review-needed": "Review requested",
      "changes-requested": "Changes requested",
      "ready-to-merge": "Ready to merge",
      "awaiting-review": "Awaiting review",
      "involved": "Following"
    })[action] || action
  }

  function relativeTime(value) {
    const date = new Date(value)
    if (Number.isNaN(date.getTime()))
      return ""
    const minutes = Math.max(0, Math.floor((Date.now() - date.getTime()) / 60000))
    if (minutes < 1)
      return "just now"
    if (minutes < 60)
      return minutes + "m ago"
    if (minutes < 1440)
      return Math.floor(minutes / 60) + "h ago"
    return Math.floor(minutes / 1440) + "d ago"
  }

  component ReviewEvent: Item {
    id: event
    required property var review
    height: eventText.implicitHeight + 12
    width: parent.width

    Rectangle {
      color: popup.controller.controlSliderTrack
      height: parent.height - 4
      radius: 2
      width: 2
    }

    Column {
      id: eventText
      x: 12
      y: 4
      width: parent.width - 12
      spacing: 2

      Text {
        color: popup.controller.controlPrimaryText
        elide: Text.ElideRight
        font.family: popup.controller.fontFamily
        font.pixelSize: 11
        text: "Reviewed by " + (event.review.githubAuthor || event.review.author || "someone") + " · " + (event.review.githubReviewState || event.review.state || "submitted")
        width: parent.width
      }

      Text {
        color: popup.controller.controlSecondaryText
        elide: Text.ElideRight
        font.family: popup.controller.fontFamily
        font.pixelSize: 10
        text: (event.review.body || popup.service.displayBody(event.review) || "No review comment")
        textFormat: Text.PlainText
        width: parent.width
        wrapMode: Text.Wrap
      }

      Row {
        spacing: 6

        Text {
          color: popup.controller.controlSecondaryText
          font.family: popup.controller.fontFamily
          font.pixelSize: 10
          text: event.review.submittedAt ? new Date(event.review.submittedAt).toLocaleString() : popup.service.timeAgo(event.review)
        }

        Text {
          color: popup.controller.controlActiveIcon
          font.family: popup.controller.fontFamily
          font.pixelSize: 10
          text: "Mark seen"
          visible: !!event.review.id && popup.service.isGithubReview(event.review) && !popup.service.isGithubReviewSeen(event.review)

          MouseArea {
            anchors.fill: parent
            anchors.margins: -5
            cursorShape: Qt.PointingHandCursor
            onClicked: popup.service.markGithubReviewSeen(event.review.id)
          }
        }
      }
    }
  }

  component ReviewStack: Item {
    id: stackCard
    required property var stack
    readonly property var stackData: stack || ({ reviews: [] })
    readonly property bool open: !!popup.expanded[stackCard.stackData.url || stackCard.stackData.key]
    height: stackColumn.implicitHeight + 32
    width: reviewList.width

    Rectangle {
      anchors.fill: parent
      border.color: popup.controller.darkMode ? "#33404D" : "#D7DCE3"
      border.width: 1
      color: popup.controller.controlSurface
      radius: 18
    }

    Column {
      id: stackColumn
      x: 16
      y: 16
      spacing: 10
      width: parent.width - 32

      Row {
        width: parent.width
        spacing: 8

        LucideIcon {
          anchors.verticalCenter: parent.verticalCenter
          color: popup.controller.controlActiveIcon
          height: 18
          source: popup.controller.icon("message-square-quote")
          width: 18
        }

        Column {
          width: parent.width - 28

          Text {
            color: popup.controller.controlPrimaryText
            elide: Text.ElideRight
            font.family: popup.controller.fontFamily
            font.pixelSize: 11
            text: stackCard.stackData.repository + "#" + stackCard.stackData.number
            width: parent.width
          }

          Text {
            color: popup.controller.controlPrimaryText
            elide: Text.ElideRight
            font.family: popup.controller.fontFamily
            font.pixelSize: 14
            maximumLineCount: 2
            text: stackCard.stackData.title
            width: parent.width
            wrapMode: Text.Wrap
          }
        }
      }

      Rectangle {
        color: popup.controller.controlActive
        height: 26
        radius: 8
        width: actionLabel.implicitWidth + 18

        Text {
          id: actionLabel
          anchors.centerIn: parent
          color: popup.controller.controlPrimaryText
          font.family: popup.controller.fontFamily
          font.pixelSize: 10
          text: popup.actionLabel(stackCard.stackData.action || stackCard.stackData.status)
        }
      }

      Text {
        color: popup.controller.controlSecondaryText
        font.family: popup.controller.fontFamily
        font.pixelSize: 11
        text: stackCard.stackData.event + " · " + popup.relativeTime(stackCard.stackData.updatedAt)
        visible: !!stackCard.stackData.event
      }

      Row {
        spacing: 8

        Rectangle {
          color: updatesArea.containsMouse ? popup.controller.controlActive : popup.controller.controlSliderTrack
          height: 30
          radius: 8
          width: updatesLabel.implicitWidth + 20

          Text {
            id: updatesLabel
            anchors.centerIn: parent
            color: popup.controller.controlPrimaryText
            font.family: popup.controller.fontFamily
            font.pixelSize: 10
            text: stackCard.open ? "Hide updates" : "Updates · " + stackCard.stackData.reviews.length
          }

          MouseArea {
            id: updatesArea
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: popup.toggleStack(stackCard.stackData.url || stackCard.stackData.key)
          }
        }

        Rectangle {
          color: browserArea.containsMouse ? popup.controller.controlActive : popup.controller.controlSliderTrack
          height: 30
          radius: 8
          width: browserLabel.implicitWidth + 20

          Text {
            id: browserLabel
            anchors.centerIn: parent
            color: popup.controller.controlPrimaryText
            font.family: popup.controller.fontFamily
            font.pixelSize: 10
            text: "Open in browser"
          }

          MouseArea {
            id: browserArea
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: popup.prs.prs.length > 0 ? popup.prs.open(stackCard.stackData.url) : popup.service.openGithubReview(stackCard.stackData.reviews[0])
          }
        }
      }

      Column {
        spacing: 8
        visible: stackCard.open
        width: parent.width

        Repeater {
          model: stackCard.stackData.reviews.slice().reverse()
          delegate: ReviewEvent {
            required property var modelData
            review: modelData
          }
        }
      }
    }

    MouseArea {
      anchors.fill: parent
      z: -1
      onClicked: popup.toggleStack(stackCard.stackData.url || stackCard.stackData.key)
    }
  }

  Rectangle {
    anchors.fill: parent
    border.color: popup.controller.darkMode ? "#3A424E" : "#D8DDE4"
    border.width: 1
    color: popup.controller.controlBackground
    radius: 26
  }

  HoverHandler {
    onHoveredChanged: {
      if (hovered)
        popup.controller.cancelHoverClose()
      else
        popup.controller.requestHoverClose(3, 500)
    }
  }

  Column {
    anchors.fill: parent
    anchors.margins: 16
    spacing: 12

    Item {
      height: 32
      width: parent.width

      Text {
        anchors.verticalCenter: parent.verticalCenter
        color: popup.controller.controlPrimaryText
        font.family: popup.controller.fontFamily
        font.pixelSize: 18
        text: "GitHub pull requests"
      }

      Text {
        anchors.right: closeButton.left
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        color: popup.controller.controlSecondaryText
        font.family: popup.controller.fontFamily
        font.pixelSize: 11
        text: popup.stacks.length + (popup.stacks.length === 1 ? " PR" : " PRs")
      }

      Text {
        id: closeButton
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        color: popup.controller.controlSecondaryText
        font.pixelSize: 18
        text: "×"

        MouseArea {
          anchors.fill: parent
          anchors.margins: -8
          cursorShape: Qt.PointingHandCursor
          onClicked: popup.requestClose()
        }
      }
    }

    Flickable {
      clip: true
      contentHeight: reviewList.height
      height: parent.height - 44
      width: parent.width

      Column {
        id: reviewList
        spacing: 10
        width: parent.width

        Repeater {
          model: popup.stacks
          delegate: ReviewStack {
            required property var modelData
            stack: modelData
          }
        }

        Text {
          color: popup.controller.controlSecondaryText
          font.family: popup.controller.fontFamily
          font.pixelSize: 12
          text: "No GitHub reviews"
          visible: popup.stacks.length === 0
        }
      }
    }
  }
}
