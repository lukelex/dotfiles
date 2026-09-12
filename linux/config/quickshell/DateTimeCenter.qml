import Quickshell
import QtQuick

PopupWindow {
  id: popup

  required property var controller
  required property var panel

  readonly property date today: controller.currentDate
  readonly property int firstWeekday: (new Date(today.getFullYear(), today.getMonth(), 1).getDay() + 6) % 7
  readonly property int daysInMonth: new Date(today.getFullYear(), today.getMonth() + 1, 0).getDate()

  anchor.window: panel
  anchor.rect.x: (parentWindow.width - width) / 2
  anchor.rect.y: parentWindow.height + 12
  color: "transparent"
  grabFocus: true
  implicitHeight: 430
  implicitWidth: 584
  surfaceFormat.opaque: false

  component Surface: Rectangle {
    required property var controller

    border.color: controller.darkMode ? "#33404D" : "#D7DCE3"
    border.width: 1
    color: controller.controlSurface
    radius: 18
  }

  component WeatherMetric: Item {
    required property var controller
    required property string title
    required property string value

    height: 29

    Column {
      anchors.fill: parent
      spacing: 2

      Text {
        color: controller.controlSecondaryText
        font.family: controller.fontFamily
        font.letterSpacing: 0.8
        font.pixelSize: 9
        text: title.toUpperCase()
      }

      Text {
        color: controller.controlPrimaryText
        font.family: controller.fontFamily
        font.pixelSize: 12
        text: value
      }
    }
  }

  Item {
    anchors.fill: parent

    HoverHandler {
      onHoveredChanged: {
        if (hovered)
          popup.controller.cancelHoverClose()
        else
          popup.controller.requestHoverClose(3, 600)
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

      Surface {
        controller: popup.controller
        height: 64
        width: parent.width

        Row {
          anchors {
            fill: parent
            margins: 10
          }
          spacing: 12

          Item {
            height: parent.height
            width: parent.width - dateSummary.width - parent.spacing

            Rectangle {
              anchors {
                left: parent.left
                verticalCenter: parent.verticalCenter
              }
              color: popup.controller.controlActive
              clip: true
              height: 44
              radius: 22
              width: 44

              Image {
                id: profileImage

                anchors.fill: parent
                anchors.margins: 1
                asynchronous: true
                fillMode: Image.PreserveAspectCrop
                source: popup.controller.profileImage
                visible: status === Image.Ready
              }

              LucideIcon {
                anchors.centerIn: parent
                color: popup.controller.controlPrimaryText
                height: 20
                source: popup.controller.icon("user")
                visible: !profileImage.visible
                width: 20
              }
            }

            Column {
              anchors {
                left: parent.left
                leftMargin: 56
                right: parent.right
                verticalCenter: parent.verticalCenter
              }
              spacing: 2

              Text {
                color: popup.controller.controlPrimaryText
                elide: Text.ElideRight
                font.family: popup.controller.fontFamily
                font.pixelSize: 14
                text: popup.controller.profileName
                width: parent.width
              }

              Text {
                color: popup.controller.controlSecondaryText
                font.family: popup.controller.fontFamily
                font.pixelSize: 10
                text: "Current user"
              }
            }
          }

          Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            color: popup.controller.darkMode ? "#3C4653" : "#D4DAE1"
            height: 34
            width: 1
          }

          Column {
            id: dateSummary

            anchors.verticalCenter: parent.verticalCenter
            spacing: 2
            width: 186

            Text {
              color: popup.controller.controlSecondaryText
              font.family: popup.controller.fontFamily
              font.pixelSize: 10
              text: Qt.formatDate(popup.today, "dddd") + "  ·  " + Qt.formatTime(popup.today, "HH:mm")
            }

            Text {
              color: popup.controller.controlPrimaryText
              font.family: popup.controller.fontFamily
              font.pixelSize: 15
              text: Qt.formatDate(popup.today, "d MMMM yyyy")
            }
          }
        }
      }

      Row {
        height: 322
        spacing: 12
        width: parent.width

        Surface {
          controller: popup.controller
          height: parent.height
          width: 304

          Column {
            anchors {
              fill: parent
              margins: 16
            }
            spacing: 14

            Text {
              color: popup.controller.controlPrimaryText
              font.family: popup.controller.fontFamily
              font.pixelSize: 15
              text: Qt.formatDate(popup.today, "MMMM yyyy")
            }

            Row {
              spacing: 0
              width: parent.width

              Repeater {
                model: ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

                delegate: Text {
                  required property string modelData

                  color: popup.controller.controlSecondaryText
                  font.family: popup.controller.fontFamily
                  font.pixelSize: 10
                  horizontalAlignment: Text.AlignHCenter
                  text: modelData
                  width: parent.width / 7
                }
              }
            }

            Grid {
              columns: 7
              rowSpacing: 6
              width: parent.width

              Repeater {
                model: 42

                delegate: Item {
                  required property int index

                  readonly property int day: index - popup.firstWeekday + 1
                  height: 29
                  opacity: day > 0 && day <= popup.daysInMonth ? 1 : 0
                  width: parent.width / 7

                  Rectangle {
                    anchors.centerIn: parent
                    color: parent.day === popup.today.getDate() ? popup.controller.controlActive : "transparent"
                    height: 27
                    radius: 14
                    width: 27
                  }

                  Text {
                    anchors.centerIn: parent
                    color: parent.day === popup.today.getDate() ? popup.controller.controlPrimaryText : popup.controller.controlSecondaryText
                    font.family: popup.controller.fontFamily
                    font.pixelSize: 12
                    text: parent.day
                  }
                }
              }
            }
          }
        }

        Column {
          height: parent.height
          spacing: 12
          width: parent.width - 316

          Surface {
            controller: popup.controller
            height: 178
            width: parent.width

            Column {
              anchors {
                fill: parent
                margins: 16
              }
              spacing: 10

              Row {
                height: 48
                spacing: 10

                Rectangle {
                  color: popup.controller.controlActive
                  height: 44
                  radius: 22
                  width: 44

                  LucideIcon {
                    anchors.centerIn: parent
                    color: popup.controller.controlPrimaryText
                    height: 22
                    source: popup.controller.icon("cloud-sun")
                    width: 21
                  }
                }

                Column {
                  anchors.verticalCenter: parent.verticalCenter
                  spacing: 2

                  Text {
                    color: popup.controller.controlPrimaryText
                    font.family: popup.controller.fontFamily
                    font.pixelSize: 23
                    text: popup.controller.weatherAvailable ? popup.controller.weatherTemperature + "°C" : "--°C"
                  }

                  Text {
                    color: popup.controller.controlSecondaryText
                    elide: Text.ElideRight
                    font.family: popup.controller.fontFamily
                    font.pixelSize: 11
                    text: popup.controller.weatherAvailable ? popup.controller.weatherDescription : "Weather unavailable"
                    width: 148
                  }

                  Text {
                    color: popup.controller.controlSecondaryText
                    elide: Text.ElideRight
                    font.family: popup.controller.fontFamily
                    font.pixelSize: 10
                    text: popup.controller.weatherAvailable ? popup.controller.weatherCity + ", " + popup.controller.weatherCountry : "Check your connection"
                    width: 148
                  }
                }
              }

              Rectangle {
                color: popup.controller.darkMode ? "#27303A" : "#DDE2E8"
                height: 1
                width: parent.width
              }

              Grid {
                columnSpacing: 12
                columns: 2
                rowSpacing: 9
                width: parent.width

                WeatherMetric {
                  controller: popup.controller
                  title: "Feels like"
                  value: popup.controller.weatherAvailable ? popup.controller.weatherFeelsLike + "°C" : "--"
                  width: (parent.width - parent.columnSpacing) / 2
                }

                WeatherMetric {
                  controller: popup.controller
                  title: "Humidity"
                  value: popup.controller.weatherAvailable ? popup.controller.weatherHumidity + "%" : "--"
                  width: (parent.width - parent.columnSpacing) / 2
                }

                WeatherMetric {
                  controller: popup.controller
                  title: "Range"
                  value: popup.controller.weatherAvailable ? popup.controller.weatherLow + "° - " + popup.controller.weatherHigh + "°" : "--"
                  width: (parent.width - parent.columnSpacing) / 2
                }

                WeatherMetric {
                  controller: popup.controller
                  title: "Wind"
                  value: popup.controller.weatherAvailable ? popup.controller.weatherWind + " m/s" : "--"
                  width: (parent.width - parent.columnSpacing) / 2
                }
              }
            }
          }

          Surface {
            controller: popup.controller
            height: 132
            width: parent.width

            Column {
              anchors {
                fill: parent
                margins: 16
              }
              spacing: 10

              Text {
                color: popup.controller.controlPrimaryText
                font.family: popup.controller.fontFamily
                font.pixelSize: 13
                text: "Next 3 days"
              }

              Row {
                spacing: 0
                width: parent.width

                Repeater {
                  model: popup.controller.weatherForecast

                  delegate: Column {
                    required property var modelData

                    spacing: 4
                    width: parent.width / 3

                    Text {
                      color: popup.controller.controlSecondaryText
                      font.family: popup.controller.fontFamily
                      font.pixelSize: 10
                      horizontalAlignment: Text.AlignHCenter
                      text: modelData.day
                      width: parent.width
                    }

                    LucideIcon {
                      anchors.horizontalCenter: parent.horizontalCenter
                      color: popup.controller.controlActiveIcon
                      height: 18
                      source: popup.controller.icon("cloud-sun")
                      width: 18
                    }

                    Text {
                      color: popup.controller.controlPrimaryText
                      font.family: popup.controller.fontFamily
                      font.pixelSize: 12
                      horizontalAlignment: Text.AlignHCenter
                      text: modelData.temperature + "°"
                      width: parent.width
                    }

                    Text {
                      color: popup.controller.controlSecondaryText
                      elide: Text.ElideRight
                      font.family: popup.controller.fontFamily
                      font.pixelSize: 9
                      horizontalAlignment: Text.AlignHCenter
                      text: modelData.condition
                      width: parent.width
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
  }

  onVisibleChanged: {
    if (visible)
      controller.refreshDateTimeStatus()
  }
}
