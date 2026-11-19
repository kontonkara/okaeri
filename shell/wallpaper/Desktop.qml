import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import qs
import qs.services
import qs.ui

// What's on the desktop of each screen, over the wallpaper and under the
// windows, as Settings.desktop has it: the clock, the weather, what plays and
// what the calendars have coming, one under another at a corner or in the
// middle. Only those cards take the pointer; the rest of the desktop is the
// wallpaper's.
Scope {
	id: desktop

	readonly property var own: Settings.desktop
	readonly property bool wanted: own.clock || (own.weather && Weather.on) || (own.media && !!Media.player) || (own.events && Events.on)

	Variants {
		model: desktop.wanted ? Quickshell.screens : []

		PanelWindow {
			id: window

			required property var modelData
			readonly property string at: desktop.own.position
			readonly property real gap: Theme.u(32)
			// A bar that keeps no room of its own, over the windows, is kept clear of by hand.
			readonly property bool barOver: Settings.barOn(modelData) && !(Settings.bar.reserve && !Settings.bar.autoHide)

			function from(side) {
				return gap + (barOver && Settings.barAt === side ? Theme.below : 0);
			}

			screen: modelData
			anchors {
				top: true
				bottom: true
				left: true
				right: true
			}
			color: "transparent"
			// Out of the way of what keeps room for itself: the bar and the dock.
			exclusionMode: ExclusionMode.Normal
			WlrLayershell.layer: WlrLayer.Bottom
			WlrLayershell.namespace: "okaeri-desktop"
			WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
			mask: Region {
				item: stack
			}

			SystemClock {
				id: clock

				precision: desktop.own.seconds ? SystemClock.Seconds : SystemClock.Minutes
			}

			Column {
				id: stack

				x: window.at.endsWith("left") ? window.from("left") : window.at.endsWith("right") ? parent.width - width - window.from("right") : (parent.width - width) / 2
				y: window.at.startsWith("top") ? window.from("top") : window.at.startsWith("bottom") ? parent.height - height - window.from("bottom") : (parent.height - height) / 2
				width: Theme.u(320)
				spacing: Theme.u(12)

				// The time, large, and the day under it.
				Card {
					objectName: "desktop-clock"
					width: parent.width
					visible: desktop.own.clock
					color: Theme.panel

					Text {
						width: parent.width
						text: Qt.formatDateTime(clock.date, (Settings.clock.hours12 ? "h:mm" : Tr.t("HH:mm")) + (desktop.own.seconds ? ":ss" : "") + (Settings.clock.hours12 ? " AP" : ""))
						color: Theme.colors.text
						font.family: Theme.font
						font.pixelSize: Theme.fontSize * 4
						font.weight: Theme.fontWeight
						font.features: {
							"tnum": 1
						}
					}

					Text {
						width: parent.width
						text: Qt.formatDateTime(clock.date, "dddd, d MMMM")
						color: Theme.colors.subtext
						font.family: Theme.font
						font.pixelSize: Theme.fontSize + Theme.u(2)
					}
				}

				Card {
					objectName: "desktop-weather"
					width: parent.width
					visible: desktop.own.weather && Weather.on && !!Weather.current
					color: Theme.panel

					Row {
						spacing: Theme.u(12)

						Icon {
							anchors.verticalCenter: parent.verticalCenter
							name: Weather.current ? Weather.icon(Weather.current.code, Weather.current.day) : "cloud"
							size: Theme.u(32)
						}

						Column {
							anchors.verticalCenter: parent.verticalCenter

							Text {
								text: Weather.current ? `${Weather.current.temperature}°` : ""
								color: Theme.colors.text
								font.family: Theme.font
								font.pixelSize: Theme.fontSize * 2
								font.weight: Theme.fontWeight
							}

							Text {
								text: Weather.current ? [Weather.about(Weather.current.code), Weather.days[0] ? `${Weather.days[0].high}° / ${Weather.days[0].low}°` : ""].filter(part => part !== "").join(" · ") : ""
								color: Theme.colors.subtext
								font.family: Theme.font
								font.pixelSize: Theme.fontSize
							}
						}
					}
				}

				// What plays, with the buttons for it.
				Card {
					objectName: "desktop-media"
					width: parent.width
					visible: desktop.own.media && !!Media.player
					color: Theme.panel

					Text {
						width: parent.width
						text: Media.player?.trackTitle || Media.player?.identity || ""
						textFormat: Text.PlainText
						elide: Text.ElideRight
						color: Theme.colors.text
						font.family: Theme.font
						font.pixelSize: Theme.fontSize + Theme.u(1)
						font.weight: Theme.fontWeight
					}

					Text {
						width: parent.width
						visible: text !== ""
						text: Media.player?.trackArtist ?? ""
						textFormat: Text.PlainText
						elide: Text.ElideRight
						color: Theme.colors.subtext
						font.family: Theme.font
						font.pixelSize: Theme.fontSize
					}

					Row {
						spacing: Theme.u(4)

						Button {
							height: Theme.u(30)
							flat: true
							icon: "previous"
							enabled: !!Media.player?.canGoPrevious
							onClicked: Media.previous()
						}

						Button {
							height: Theme.u(30)
							flat: true
							icon: Media.player?.isPlaying ? "pause" : "play"
							enabled: !!Media.player?.canTogglePlaying
							onClicked: Media.toggle()
						}

						Button {
							height: Theme.u(30)
							flat: true
							icon: "next"
							enabled: !!Media.player?.canGoNext
							onClicked: Media.next()
						}
					}
				}

				// What's on today and tomorrow, the next few of it.
				Card {
					id: events

					readonly property var coming: {
						const today = new Date(clock.date.getFullYear(), clock.date.getMonth(), clock.date.getDate());
						const tomorrow = new Date(today.getFullYear(), today.getMonth(), today.getDate() + 1);
						return Events.happening(today).filter(one => one.allDay || one.end > clock.date).map(one => Object.assign({ day: "" }, one)).concat(Events.happening(tomorrow).map(one => Object.assign({ day: "Tomorrow" }, one))).slice(0, 4);
					}

					objectName: "desktop-events"
					width: parent.width
					visible: desktop.own.events && Events.on
					color: Theme.panel

					Text {
						width: parent.width
						visible: events.coming.length === 0
						text: Tr.t("Nothing more today or tomorrow")
						color: Theme.colors.subtext
						font.family: Theme.font
						font.pixelSize: Theme.fontSize
					}

					Repeater {
						model: events.coming

						Item {
							required property var modelData

							width: parent.width
							height: Theme.u(24)

							Text {
								id: when

								anchors.left: parent.left
								anchors.verticalCenter: parent.verticalCenter
								width: Theme.u(90)
								text: [parent.modelData.day, parent.modelData.allDay ? Tr.t("All day") : Qt.formatTime(parent.modelData.start, Settings.clock.hours12 ? "h:mm AP" : Tr.t("HH:mm"))].filter(part => part !== "").join(" ")
								elide: Text.ElideRight
								color: Theme.colors.subtext
								font.family: Theme.font
								font.pixelSize: Theme.fontSize - Theme.u(1)
								font.features: {
									"tnum": 1
								}
							}

							Text {
								anchors.left: when.right
								anchors.right: parent.right
								anchors.verticalCenter: parent.verticalCenter
								text: parent.modelData.summary
								textFormat: Text.PlainText
								elide: Text.ElideRight
								color: Theme.colors.text
								font.family: Theme.font
								font.pixelSize: Theme.fontSize
							}
						}
					}
				}
			}
		}
	}
}
