import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import qs
import qs.launcher
import qs.services
import qs.ui

// The dock of a screen: `apps`, each by its icon, with a mark under one that
// has windows, longer under the one in focus and in the color of an error under
// one that asks to be looked at. The wheel on one goes through its windows, and
// one the dock keeps can be dragged to another place among those. It's at the bottom of the screen,
// or where Settings.dock.position says, in its middle, and windows keep out of
// its way; with Settings.dock.autoHide it's out of sight, over them, until the
// pointer rests at its edge of the screen.
PanelWindow {
	id: dock

	required property var modelData
	property var apps: []
	readonly property var own: Settings.dock
	readonly property string at: ["top", "left", "right"].includes(own.position) ? own.position : "bottom"
	readonly property bool upright: at === "left" || at === "right"
	readonly property bool hides: own.autoHide
	readonly property real size: Theme.u(own.size)
	// Across it: the icon, the mark, and the edges around them.
	readonly property real thick: Math.round(size + Theme.u(22))
	// Off the screen's edge: over the bar, if that's there and this isn't laid out
	// after it.
	readonly property real gap: hides ? Settings.inset(modelData, at) : Theme.edge
	// For Tip.
	readonly property real tipsFrom: thick + Theme.u(6)
	readonly property string tipsAt: ({ top: "below", bottom: "above", left: "right", right: "left" })[at]
	// In sight: always, unless it hides; then with the pointer at its edge or on it.
	// Its menu is open: that keeps it in sight too, and so does niri's overview.
	property bool held: false
	readonly property bool pointed: sensor.containsMouse || over.hovered || held || Niri.overview
	property bool down: true

	signal activated(var app)
	signal started(var app)
	// A step through its windows, 1 for the next.
	signal turned(var app, int by)
	// Its menu, where `along` this edge of the screen its icon has its middle.
	signal asked(var app, real along)
	// One place on among those kept, or with -1 one back.
	signal moved(var app, int by)

	// Where along its edge of the screen `item` of it has its middle: the dock is
	// in the middle of that edge.
	function alongOf(item) {
		const at = item.mapToItem(null, item.width / 2, item.height / 2);
		return upright ? (modelData.height - height) / 2 + at.y : (modelData.width - width) / 2 + at.x;
	}

	function settle() {
		coming.stop();
		going.stop();
		if (!hides)
			down = true;
		else if (pointed && !down)
			coming.start();
		else if (!pointed && down)
			going.start();
	}

	screen: modelData
	anchors {
		top: at === "top"
		bottom: at === "bottom"
		left: at === "left"
		right: at === "right"
	}
	margins {
		top: at === "top" ? gap : 0
		bottom: at === "bottom" ? gap : 0
		left: at === "left" ? gap : 0
		right: at === "right" ? gap : 0
	}
	implicitWidth: upright ? thick : Math.ceil(row.implicitWidth)
	implicitHeight: upright ? Math.ceil(row.implicitHeight) : thick
	visible: apps.length > 0
	exclusionMode: hides ? ExclusionMode.Ignore : ExclusionMode.Auto
	color: "transparent"
	WlrLayershell.namespace: "okaeri-dock"
	// Only where it shows: out of sight it's still over the windows, and the clicks
	// there are theirs.
	mask: Region {
		x: Math.round(body.x)
		y: Math.round(body.y)
		width: dock.width
		height: dock.height
	}
	BackgroundEffect.blurRegion: Theme.barBlur ? glass : null

	onHidesChanged: settle()
	onPointedChanged: settle()
	Component.onCompleted: settle()

	Timer {
		id: coming

		interval: 150
		onTriggered: dock.down = true
	}

	Timer {
		id: going

		interval: 400
		onTriggered: dock.down = false
	}

	// Its edge of the screen, as long as it is, for the pointer to bring it back.
	PanelWindow {
		screen: dock.screen
		visible: dock.hides && dock.apps.length > 0
		anchors {
			top: dock.at === "top"
			bottom: dock.at === "bottom"
			left: dock.at === "left"
			right: dock.at === "right"
		}
		implicitWidth: dock.upright ? 1 : dock.width
		implicitHeight: dock.upright ? dock.height : 1
		exclusionMode: ExclusionMode.Ignore
		color: "transparent"
		WlrLayershell.namespace: "okaeri-edge"

		MouseArea {
			id: sensor

			anchors.fill: parent
			acceptedButtons: Qt.NoButton
			hoverEnabled: true
		}
	}

	// A pixel in from the edge, as the bar's.
	Region {
		id: glass

		x: Math.round(body.x) + 1
		y: Math.round(body.y) + 1
		width: dock.width - 2
		height: dock.height - 2
		radius: Theme.cardRadius
	}

	Item {
		id: body

		// How far out of its place it is: toward its edge, until nothing of it shows.
		property real out: dock.down ? 0 : dock.thick + dock.gap

		x: dock.at === "left" ? -out : dock.at === "right" ? out : 0
		y: dock.at === "top" ? -out : dock.at === "bottom" ? out : 0
		width: parent.width
		height: parent.height
		// Under the pointer it stays, and out of sight it takes no clicks.
		enabled: dock.down

		Behavior on out {
			enabled: Theme.animate

			NumberAnimation {
				duration: Theme.ms(180)
				easing.type: Easing.OutCubic
			}
		}

		HoverHandler {
			id: over
		}

		Rectangle {
			anchors.fill: parent
			radius: Theme.cardRadius
			color: Theme.barFill
		}

		Rectangle {
			anchors.fill: parent
			radius: Theme.cardRadius
			color: "transparent"
			border.width: 1
			border.color: Theme.border
		}

		Grid {
			id: row

			columns: dock.upright ? 1 : 1000
			padding: Theme.u(6)
			spacing: Theme.u(4)

			Repeater {
				// By id: an app that stays keeps its place and what's on it.
				model: ScriptModel {
					values: dock.apps
					objectProp: "id"
				}

				Item {
					id: app

					required property var modelData
					readonly property bool running: modelData.windows.length > 0
					readonly property bool focused: modelData.windows.some(window => window.is_focused)
					readonly property bool urgent: modelData.windows.some(window => window.is_urgent)
					readonly property bool kept: dock.own.pinned.includes(modelData.id)
					readonly property string image: modelData.entry ? Apps.image(modelData.entry.icon) : Apps.imageOf(modelData.id)

					width: dock.upright ? dock.thick - Theme.u(12) : dock.size + Theme.u(4)
					height: dock.upright ? dock.size + Theme.u(4) : dock.thick - Theme.u(12)

					Rectangle {
						anchors.fill: parent
						radius: Math.max(0, Theme.cardRadius - Theme.u(4))
						color: pointer.pressed ? Theme.pressed : pointer.containsMouse ? Theme.hover : "transparent"
					}

					// Toward the screen's middle; the mark has the side by its edge.
					Item {
						x: dock.at === "left" ? parent.width - width : dock.at === "right" ? 0 : (parent.width - width) / 2
						y: dock.at === "top" ? parent.height - height : dock.at === "bottom" ? 0 : (parent.height - height) / 2
						width: dock.size
						height: dock.size

						IconImage {
							anchors.fill: parent
							visible: app.image !== ""
							source: app.image
						}

						// An app the icon theme doesn't know.
						Icon {
							anchors.centerIn: parent
							visible: app.image === ""
							name: "apps"
							size: dock.size * 0.7
						}
					}

					Rectangle {
						property real long: Theme.u(app.focused ? 14 : 4)
						readonly property real short: Theme.u(4)

						x: dock.upright ? (dock.at === "left" ? 0 : parent.width - width) : (parent.width - width) / 2
						y: dock.upright ? (parent.height - height) / 2 : (dock.at === "top" ? 0 : parent.height - height)
						width: dock.upright ? short : long
						height: dock.upright ? long : short
						radius: Theme.round(short)
						visible: app.running
						color: app.urgent ? Theme.colors.error : app.focused ? Theme.colors.accent : Theme.colors.subtext

						Behavior on long {
							enabled: Theme.animate

							NumberAnimation {
								duration: Theme.ms(140)
								easing.type: Easing.OutCubic
							}
						}
					}

					MouseArea {
						id: pointer

						anchors.fill: parent
						hoverEnabled: true
						acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
						// Where along the dock the button went down, and whether the pointer
						// went far enough from there since to be dragging the app.
						property real from: 0
						property bool dragging: false
						property int notches: 0

						function along(event) {
							const at = mapToItem(row, event.x, event.y);
							return dock.upright ? at.y : at.x;
						}

						cursorShape: dragging ? Qt.ClosedHandCursor : Qt.PointingHandCursor
						onPressed: event => {
							dragging = false;
							from = along(event);
						}
						// Into the place of the one beside it, and that one takes this
						// one's: the pointer is over its own app again.
						onPositionChanged: event => {
							if (!(pressedButtons & Qt.LeftButton) || !app.kept)
								return;
							const at = along(event);
							if (!dragging && Math.abs(at - from) < Theme.u(8))
								return;
							dragging = true;
							const long = dock.upright ? app.height : app.width;
							const middle = (dock.upright ? app.y : app.x) + long / 2;
							const reach = long / 2 + row.spacing;
							if (at > middle + reach)
								dock.moved(app.modelData, 1);
							else if (at < middle - reach)
								dock.moved(app.modelData, -1);
						}
						onReleased: letGo.restart()
						onCanceled: dragging = false
						onClicked: event => {
							if (dragging)
								return;
							if (event.button === Qt.RightButton)
								dock.asked(app.modelData, dock.alongOf(app));
							else if (event.button === Qt.MiddleButton && app.modelData.entry)
								dock.started(app.modelData);
							else if (event.button === Qt.LeftButton)
								dock.activated(app.modelData);
						}
						// 120 to a notch, down being the next window.
						onWheel: event => {
							notches += event.angleDelta.y;
							const steps = Math.trunc(notches / 120);
							if (steps === 0)
								return;
							notches -= steps * 120;
							if (app.running)
								dock.turned(app.modelData, -steps);
						}

						// The click that ends a drag comes after the release.
						Timer {
							id: letGo

							interval: 0
							onTriggered: pointer.dragging = false
						}
					}

					Tip {
						listens: false
						hovered: pointer.containsMouse && !dock.held
						pressed: pointer.pressed
						text: [app.modelData.entry?.name ?? app.modelData.id, app.modelData.windows.length > 1 ? `${app.modelData.windows.length} windows` : "", app.kept ? "kept" : ""].filter(part => part !== "").join(" · ")
					}
				}
			}
		}
	}
}
