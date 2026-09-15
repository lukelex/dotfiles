pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Services.SystemTray
import QtQuick
import QtQuick.Controls as Controls

Item {
  id: tray

  required property var controller

  readonly property var items: SystemTray.items
  readonly property bool available: items.values.length > 0
  readonly property bool menuOpen: menuAnchor.visible
  property var activeMenuCell: null
  property var activeMenuItem: null

  signal menuClosed()

  height: available ? surface.height : 0
  implicitHeight: available ? surface.height : 0
  visible: available

  function tooltipText(item) {
    const title = item.tooltipTitle || item.title
    return item.tooltipDescription ? title + "\n" + item.tooltipDescription : title
  }

  function openMenu(item, cell) {
    if (!item.hasMenu)
      return

    tray.controller.cancelHoverClose()
    if (menuAnchor.visible)
      menuAnchor.close()
    tray.activeMenuItem = item
    tray.activeMenuCell = cell
    Qt.callLater(function() {
      if (tray.activeMenuItem === item && tray.activeMenuCell === cell && !menuAnchor.visible)
        menuAnchor.open()
    })
  }

  function closeMenu() {
    if (menuAnchor.visible)
      menuAnchor.close()
    else {
      tray.activeMenuItem = null
      tray.activeMenuCell = null
    }
  }

  onVisibleChanged: {
    if (!visible)
      tray.closeMenu()
  }

  Rectangle {
    id: surface

    width: parent.width
    height: body.implicitHeight + 28
    color: tray.controller.controlSurface
    radius: 18

    Column {
      id: body

      x: 14
      y: 14
      width: parent.width - 28
      spacing: 10

      Text {
        color: tray.controller.controlPrimaryText
        font.family: tray.controller.fontFamily
        font.pixelSize: 12
        text: "Tray"
      }

      Flickable {
        id: iconScroll

        width: parent.width
        height: Math.min(124, iconGrid.implicitHeight)
        contentWidth: width
        contentHeight: iconGrid.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick

        Grid {
          id: iconGrid

          width: iconScroll.width
          columns: Math.max(1, Math.floor((width + columnSpacing) / (36 + columnSpacing)))
          columnSpacing: 8
          rowSpacing: 8

          Repeater {
            model: tray.items

            delegate: Item {
              id: cell

              required property var modelData

              width: 36
              height: 36
              opacity: modelData.status === Status.Passive ? 0.55 : 1
              Accessible.name: tray.tooltipText(modelData)
              Accessible.role: Accessible.Button

              Rectangle {
                anchors.fill: parent
                color: cell.modelData.status === Status.NeedsAttention
                  ? Qt.rgba(tray.controller.urgent.r, tray.controller.urgent.g, tray.controller.urgent.b, 0.2)
                  : mouseArea.containsMouse ? tray.controller.controlBackground : "transparent"
                radius: 10
              }

              Image {
                anchors.centerIn: parent
                asynchronous: true
                fillMode: Image.PreserveAspectFit
                height: 24
                smooth: true
                source: cell.modelData.icon
                sourceSize: Qt.size(24, 24)
                width: 24
              }

              Rectangle {
                anchors.right: parent.right
                anchors.top: parent.top
                color: tray.controller.urgent
                height: 7
                radius: 4
                visible: cell.modelData.status === Status.NeedsAttention
                width: 7
              }

              MouseArea {
                id: mouseArea

                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                cursorShape: Qt.PointingHandCursor
                hoverEnabled: true
                onClicked: function(mouse) {
                  if (mouse.button === Qt.LeftButton) {
                    if (cell.modelData.onlyMenu)
                      tray.openMenu(cell.modelData, cell)
                    else
                      cell.modelData.activate()
                  } else if (mouse.button === Qt.RightButton) {
                    tray.openMenu(cell.modelData, cell)
                  } else if (mouse.button === Qt.MiddleButton) {
                    cell.modelData.secondaryActivate()
                  }
                }
              }

              Controls.ToolTip {
                parent: cell
                visible: mouseArea.containsMouse && tray.tooltipText(cell.modelData) !== ""
                delay: 500
                padding: 8
                contentItem: Text {
                  color: tray.controller.controlPrimaryText
                  font.family: tray.controller.fontFamily
                  font.pixelSize: 11
                  textFormat: Text.PlainText
                  text: tray.tooltipText(cell.modelData)
                  width: Math.min(280, implicitWidth)
                  wrapMode: Text.Wrap
                }
                background: Rectangle {
                  color: tray.controller.controlSurface
                  border.color: tray.controller.controlSecondaryText
                  radius: 7
                }
              }
            }
          }
        }

        Controls.ScrollBar.vertical: Controls.ScrollBar {
          policy: Controls.ScrollBar.AsNeeded
        }
      }
    }
  }

  QsMenuAnchor {
    id: menuAnchor

    menu: tray.activeMenuItem ? tray.activeMenuItem.menu : null
    anchor.item: tray.activeMenuCell
    onClosed: {
      tray.activeMenuItem = null
      tray.activeMenuCell = null
      tray.menuClosed()
    }
  }
}
