import QtQuick
import Quickshell.Io
import Quickshell.Services.UPower
import qs
import qs.services
import qs.ui

// The battery, with the way to the settings and the session menu; the volume,
// the brightness and the microphone; and tiles for Wi-Fi, Bluetooth, the night
// light, keeping awake, the power profile, airplane mode and VPN. An arrow on a
// tile or a level opens its page in the panel's place: the networks, the
// devices, the VPNs, where the sound goes and what plays, the microphones.
// Escape there goes back, and a closing panel too. What's in it is there only
// while it shows, so what's typed in it goes with it.
Panel {
	id: controlCenter

	align: Settings.corner("control")
	escapes: () => {
		if (Control.unfolded === "")
			return false;
		Control.unfolded = "";
		return true;
	}
	onShownChanged: Control.open = shown
	onPanelClosed: Control.unfolded = ""
	// A reload takes it away without closing it, and what's scanning would go
	// on with nobody left to stop it.
	Component.onDestruction: Control.open = false

	Connections {
		target: Control

		function onToggled() {
			controlCenter.toggle();
		}

		function onAsked(page) {
			Control.unfolded = page;
			if (!controlCenter.shown)
				controlCenter.show();
		}
	}

	IpcHandler {
		target: "control"

		function toggle(): void {
			controlCenter.toggle();
		}

		// Open at a page: wifi, bluetooth, vpn, sound or mic.
		function page(name: string): void {
			Control.show(name);
		}
	}

	Loader {
		width: parent.width
		active: controlCenter.visible

		// Scrolled, where it's more than the screen has room for.
		sourceComponent: Flickable {
			id: view

			height: Math.min(column.height, controlCenter.room)
			contentHeight: column.height
			interactive: contentHeight > height
			// While a page comes in sideways, nothing of it shows past the panel.
			clip: true
			boundsBehavior: Flickable.StopAtBounds

			// The panel grows and shrinks to what's in it, not at once.
			Behavior on height {
				enabled: Theme.animate

				NumberAnimation {
					duration: 200
					easing.type: Easing.OutCubic
				}
			}

			Column {
				id: column

				// A page in the place of the rest.
				readonly property bool paging: [wifi, bluetooth, vpn, sound, mic].some(page => page.visible)

				width: view.width
				spacing: Math.round(Theme.u(10))
				transform: Translate {
					id: sliding
				}

				// A page comes in from the side the panel is on, and the tiles from
				// the other as it goes.
				Connections {
					target: Control

					function onUnfoldedChanged() {
						if (!Theme.animate || !controlCenter.shown)
							return;
						const side = controlCenter.align === "top-left" ? -1 : 1;
						sliding.x = (Control.unfolded !== "" ? side : -side) * Theme.u(32);
						column.opacity = 0;
						arriving.restart();
					}
				}

				ParallelAnimation {
					id: arriving

					NumberAnimation {
						target: sliding
						property: "x"
						to: 0
						duration: 220
						easing.type: Easing.OutCubic
					}

					NumberAnimation {
						target: column
						property: "opacity"
						to: 1
						duration: 180
						easing.type: Easing.OutCubic
					}
				}

				Item {
					width: parent.width
					height: Theme.u(34)
					visible: !column.paging

					Text {
						anchors.left: parent.left
						anchors.leftMargin: Theme.u(6)
						anchors.right: buttons.left
						anchors.rightMargin: Theme.u(8)
						anchors.verticalCenter: parent.verticalCenter
						text: Power.present ? [`${Power.charge}%`, Power.batteryLine].filter(part => part !== "").join(" · ") : ""
						color: Theme.colors.subtext
						elide: Text.ElideRight
						font.family: Theme.font
						font.pixelSize: Theme.fontSize - Theme.u(1)
					}

					Row {
						id: buttons

						anchors.right: parent.right
						anchors.verticalCenter: parent.verticalCenter
						spacing: Theme.u(4)

						Button {
							height: Theme.u(32)
							flat: true
							icon: "gear"
							tip: "Settings"
							onClicked: {
								controlCenter.hide();
								Settings.asked();
							}
						}

						Button {
							height: Theme.u(32)
							flat: true
							icon: "power"
							tip: "Session"
							onClicked: {
								controlCenter.hide();
								Session.menuWanted();
							}
						}
					}
				}

				Levels {
					visible: !column.paging
				}

				// The tiles in their order, two to a row but for a wide one and one left
				// alone in its row.
				Flow {
					id: tiles

					// Those that apply here, and aren't left out.
					readonly property var shown: Control.order.filter(name => !Settings.control.hidden.includes(name) && wanted(name))
					readonly property var whole: Control.whole(shown)

					function wanted(name) {
						return name === "wifi" ? !!Wifi.device : name === "bluetooth" ? !!Bt.adapter : name === "vpn" ? Vpn.connections.length > 0 : name === "airplane" ? Airplane.possible : name === "power" ? Power.choices.length > 1 : true;
					}

					width: parent.width
					visible: !column.paging
					spacing: Theme.u(8)

					Repeater {
						model: tiles.shown

						Loader {
							required property string modelData

							width: tiles.whole[modelData] ? tiles.width : (tiles.width - tiles.spacing) / 2
							sourceComponent: ({
									wifi: wifiTile,
									bluetooth: bluetoothTile,
									vpn: vpnTile,
									airplane: airplaneTile,
									night: nightTile,
									awake: awakeTile,
									power: powerTile
								})[modelData]
						}
					}

					Component {
						id: wifiTile

						Tile {
							name: "wifi"
							wanted: !!Wifi.device
							icon: Wifi.enabled ? "wifi" : "wifiOff"
							title: "Wi-Fi"
							summary: wifi.summary
							checked: Wifi.enabled
							canSwitch: !Wifi.blocked
							opens: "wifi"
							onToggled: wanted => Wifi.setEnabled(wanted)
						}
					}

					Component {
						id: bluetoothTile

						Tile {
							name: "bluetooth"
							wanted: !!Bt.adapter
							icon: Bt.enabled ? "bluetooth" : "bluetoothOff"
							title: "Bluetooth"
							summary: bluetooth.summary
							checked: Bt.enabled
							canSwitch: !Bt.blocked
							opens: "bluetooth"
							onToggled: wanted => Bt.setEnabled(wanted)
						}
					}

					Component {
						id: vpnTile

						Tile {
							name: "vpn"
							wanted: Vpn.connections.length > 0
							icon: "shield"
							title: "VPN"
							summary: vpn.summary
							checked: Vpn.up.length > 0
							opens: "vpn"
							onToggled: wanted => Vpn.setEnabled(wanted)
						}
					}

					Component {
						id: airplaneTile

						Tile {
							name: "airplane"
							wanted: Airplane.possible
							icon: "plane"
							title: "Airplane mode"
							summary: Airplane.on ? "Radios off" : "Off"
							checked: Airplane.on
							onToggled: wanted => Airplane.set(wanted)
						}
					}

					Component {
						id: nightTile

						Tile {
							name: "night"
							icon: "sunset"
							title: "Night light"
							summary: !NightLight.available ? "It needs wlsunset" : NightLight.on ? NightLight.summary : "Off"
							checked: NightLight.on && NightLight.available
							canSwitch: NightLight.available
							takesWheel: true
							onToggled: wanted => NightLight.set(wanted)
							onScrolled: steps => NightLight.step(-steps)
						}
					}

					Component {
						id: awakeTile

						Tile {
							name: "awake"
							icon: "coffee"
							title: "Keep awake"
							summary: !Awake.on ? "Off" : Awake.label || "It won't lock or dim"
							checked: Awake.on
							takesWheel: true
							onToggled: wanted => Awake.set(wanted, 0)
							onScrolled: steps => Awake.step(steps)
						}
					}

					Component {
						id: powerTile

						Tile {
							readonly property int at: Power.choices.findIndex(choice => choice.profile === Power.profile)

							// Along the profiles, round to the first again.
							function turn(steps) {
								const count = Power.choices.length;
								Power.set(Power.choices[((at + steps) % count + count) % count].profile);
							}

							name: "power"
							wanted: Power.choices.length > 1
							icon: "bolt"
							title: "Power"
							summary: Power.choices[at]?.text ?? ""
							checked: Power.profile !== PowerProfile.Balanced
							switches: false
							takesWheel: true
							onClicked: turn(1)
							onScrolled: steps => turn(-steps)
						}
					}
				}

				WifiSection {
					id: wifi

					room: controlCenter.room
				}

				BluetoothSection {
					id: bluetooth

					room: controlCenter.room
				}

				VpnSection {
					id: vpn

					room: controlCenter.room
				}

				SoundSection {
					id: sound

					room: controlCenter.room
				}

				MicSection {
					id: mic

					room: controlCenter.room
				}
			}
		}
	}
}
