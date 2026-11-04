import QtQuick
import Quickshell
import qs
import qs.ui

// Every base component, to look at and poke (OKAERI_GALLERY=1, as ./try
// does). Its buttons change the theme in memory, not the theme file.
FloatingWindow {
	id: gallery

	title: "okaeri gallery"
	implicitWidth: Theme.u(640)
	implicitHeight: Theme.u(860)
	color: Theme.colors.background

	function apply(change) {
		Theme.user = Object.assign({}, Theme.user, change);
	}

	Flickable {
		anchors.fill: parent
		contentHeight: page.implicitHeight + Theme.u(40)
		boundsBehavior: Flickable.StopAtBounds

		Column {
			id: page

			x: Theme.u(20)
			y: Theme.u(20)
			width: parent.width - Theme.u(40)
			spacing: Theme.u(14)

			Card {
				width: parent.width
				title: "Theme"

				Row {
					spacing: Theme.u(8)

					Button {
						text: "Dark"
						onClicked: gallery.apply({ extends: "dark" })
					}

					Button {
						text: "Light"
						onClicked: gallery.apply({ extends: "light" })
					}

					Button {
						text: "Round"
						onClicked: gallery.apply({ radius: null })
					}

					Button {
						text: "Square"
						onClicked: gallery.apply({ radius: 0 })
					}

					Button {
						text: "Corners 8"
						onClicked: gallery.apply({ radius: 8 })
					}
				}
			}

			Card {
				width: parent.width
				title: "Buttons"

				Row {
					spacing: Theme.u(8)

					Button {
						text: "Plain"
					}

					Button {
						text: "Filled"
						filled: true
					}

					Button {
						text: "Flat"
						flat: true
					}

					Button {
						icon: "search"
						text: "With icon"
					}

					Button {
						icon: "sun"
					}

					Button {
						text: "Disabled"
						enabled: false
					}
				}
			}

			Card {
				width: parent.width
				title: "Text fields"

				TextField {
					width: parent.width
					placeholder: "Search"
					icon: "search"
				}

				TextField {
					width: parent.width
					placeholder: "Password"
					secret: true
				}

				TextField {
					width: parent.width
					placeholder: "Disabled"
					enabled: false
				}
			}

			Card {
				width: parent.width
				title: "Switch and slider"

				Toggle {
					id: toggle

					onToggled: wanted => checked = wanted
				}

				Slider {
					width: parent.width
					value: 0.6
					onMoved: wanted => value = wanted
				}
			}

			Card {
				width: parent.width
				title: "List"

				List {
					width: parent.width
					model: [
						{ text: "Plain row" },
						{ text: "With an icon", icon: "sun" },
						{ text: "With a line under it", subtext: "The second line", icon: "volume" },
						{ separator: true },
						{ text: "Checked", check: true },
						{ text: "Goes further", more: true },
						{ text: "Disabled", enabled: false }
					]
				}
			}
		}
	}
}
