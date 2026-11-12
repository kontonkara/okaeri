import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import qs
import qs.launcher
import qs.notifications
import qs.services
import qs.ui

// The dock of a screen: `apps`, each by its icon, with a mark under one that
// has windows, longer under the one in focus and in the color of an error under
// one that asks to be looked at, and with Settings.dock.count how many windows
// it has, where that's more than one. The wheel on one goes through its windows,
// and one the dock keeps can be dragged to another place among those. It's at
// the bottom of the screen, or where Settings.dock.position says, in its middle,
// and windows keep out of its way; with Settings.dock.autoHide it's out of
// sight, over them, until the pointer rests at its edge of the screen, and with
// Settings.dock.smartHide it's in sight too while its screen shows an empty
// workspace.
//
// Under the pointer the icons grow, as Settings.dock.magnify says, the nearest
// most, and those beside them make room; the dock itself keeps its size, and
// what grows stands out of it, away from the edge. With Settings.dock.bounce an
// app hops as it starts, until its window comes, and while it asks to be looked
// at.
PanelWindow {
	id: dock

	required property var modelData
	property var apps: []
	// The apps starting from it now, by their ids.
	property var launching: []
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
	// How large an icon gets under the pointer, 1 for not at all, and the room
	// that takes: across, out of the dock, and along it at each end, for those
	// that make room.
	readonly property real magnify: own.magnify >= 100 ? own.magnify / 100 : 1
	readonly property bool magnifies: magnify > 1
	readonly property real hop: own.bounce ? Theme.u(12) : 0
	readonly property real headroom: Math.ceil(size * (magnify - 1) + hop)
	readonly property real across: thick + headroom
	readonly property real ends: Math.ceil(size * (magnify - 1) * 1.2)
	// The icons one after another, the launcher's button where it goes.
	readonly property var items: own.launcher === "start" ? [launcherItem].concat(apps) : own.launcher === "end" ? apps.concat([launcherItem]) : apps
	readonly property var launcherItem: ({ id: "*launcher", launcher: true, windows: [] })
	// Where those it keeps end and the others begin, for a line between them with
	// Settings.dock.separator: the index of the first of the others, -1 for none,
	// and the room the line takes.
	readonly property int split: {
		if (!own.separator)
			return -1;
		const first = items.findIndex(item => !item.launcher && !own.pinned.includes(item.id));
		return first > 0 && items.slice(0, first).some(item => !item.launcher) ? first : -1;
	}
	readonly property real sep: Theme.u(12)
	// One icon's place along the dock, and from one to the next.
	readonly property real slot: size + Theme.u(4)
	readonly property real step: slot + row.spacing
	// Where along the row the middle of icon `index` is.
	function middleOf(index) {
		return row.padding + index * step + (split >= 0 && index >= split ? sep : 0) + slot / 2;
	}
	readonly property real length: Math.ceil(upright ? row.implicitHeight : row.implicitWidth)
	// For Tip.
	readonly property real tipsFrom: across + Theme.u(6)
	readonly property string tipsAt: ({ top: "below", bottom: "above", left: "right", right: "left" })[at]
	// In sight: always, unless it hides; then with the pointer at its edge or on it.
	// Its menu is open: that keeps it in sight too, and so does niri's overview,
	// and with smartHide a workspace with no windows.
	property bool held: false
	readonly property bool bare: {
		if (!own.smartHide)
			return false;
		const shown = Niri.on(modelData.name).find(workspace => workspace.is_active);
		return !!shown && !Niri.holds(shown);
	}
	readonly property bool pointed: sensor.containsMouse || over.hovered || held || Niri.overview || bare
	property bool down: true
	// Where along the icons the pointer is, kept as it leaves for them to settle
	// back from there, and how far they've grown toward their size under it.
	property real hoverAt: 0
	property real lift: over.hovered && magnifies && !dragging ? 1 : 0
	property bool dragging: false
	// How much longer each icon is under the pointer, and how far each moves
	// along for that: the row grows from its middle, to both ends.
	readonly property var grown: {
		const reach = step * 2;
		return items.map((item, index) => {
			const away = Math.abs(hoverAt - middleOf(index));
			const near = away < reach ? Math.pow(Math.cos(Math.PI / 2 * away / reach), 2) : 0;
			return size * (magnify - 1) * lift * near;
		});
	}
	readonly property var shifts: {
		const total = grown.reduce((sum, more) => sum + more, 0);
		let before = 0;
		return grown.map(more => {
			const shift = before + more / 2 - total / 2;
			before += more;
			return shift;
		});
	}

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
	implicitWidth: upright ? across : length + ends * 2
	implicitHeight: upright ? length + ends * 2 : across
	visible: items.length > 0
	// Its own thickness only: what grows out of it stands over the windows.
	exclusionMode: hides ? ExclusionMode.Ignore : ExclusionMode.Normal
	exclusiveZone: thick
	color: "transparent"
	WlrLayershell.namespace: "okaeri-dock"
	// Only where it shows: out of sight it's still over the windows, and the clicks
	// there are theirs, as they are around it, where the icons grow into.
	mask: Region {
		x: Math.round(body.x)
		y: Math.round(body.y)
		width: Math.round(body.width)
		height: Math.round(body.height)
	}
	BackgroundEffect.blurRegion: Theme.barBlur ? glass : null

	onHidesChanged: settle()
	onPointedChanged: settle()
	Component.onCompleted: settle()

	Connections {
		target: over

		function onPointChanged() {
			if (over.hovered)
				dock.hoverAt = dock.upright ? over.point.position.y : over.point.position.x;
		}
	}

	Behavior on lift {
		enabled: Theme.animate

		NumberAnimation {
			duration: Theme.ms(160)
			easing.type: Easing.OutCubic
		}
	}

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
		visible: dock.hides && dock.items.length > 0
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
		width: Math.round(body.width) - 2
		height: Math.round(body.height) - 2
		radius: Theme.cardRadius
	}

	Item {
		id: body

		// How far out of its place it is: toward its edge, until nothing of it shows.
		property real out: dock.down ? 0 : dock.thick + dock.gap

		// By its edge of the window, the room for what grows on its other side.
		x: dock.upright ? (dock.at === "left" ? -out : dock.width - dock.thick + out) : dock.ends
		y: dock.upright ? dock.ends : (dock.at === "top" ? -out : dock.height - dock.thick + out)
		width: dock.upright ? dock.thick : dock.length
		height: dock.upright ? dock.length : dock.thick
		// Under the pointer it stays, and out of sight it takes no clicks.
		enabled: dock.down
		opacity: 0

		// It comes into sight eased out, and goes eased in.
		Behavior on out {
			enabled: Theme.animate

			NumberAnimation {
				duration: Theme.ms(180)
				easing.type: dock.down ? Easing.OutCubic : Easing.InQuad
			}
		}

		// The first time it shows, it fades in.
		NumberAnimation on opacity {
			to: 1
			duration: Theme.animate ? Theme.ms(300) : 0
			easing.type: Easing.OutCubic
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

			// What moves, as one is dragged or another comes or goes, glides there,
			// and one that comes grows in.
			move: Transition {
				enabled: Theme.animate

				NumberAnimation {
					properties: "x,y"
					duration: Theme.ms(180)
					easing.type: Easing.OutCubic
				}
			}

			add: Transition {
				enabled: Theme.animate

				NumberAnimation {
					property: "opacity"
					from: 0
					to: 1
					duration: Theme.ms(200)
				}

				NumberAnimation {
					property: "scale"
					from: 0.5
					to: 1
					duration: Theme.ms(240)
					easing.type: Easing.OutBack
				}
			}

			Repeater {
				// By id: an app that stays keeps its place and what's on it.
				model: ScriptModel {
					values: dock.items
					objectProp: "id"
				}

				Item {
					id: app

					required property var modelData
					required property int index
					readonly property bool launcher: !!modelData.launcher
					readonly property bool running: modelData.windows.length > 0
					readonly property bool focused: modelData.windows.some(window => window.is_focused)
					readonly property bool urgent: modelData.windows.some(window => window.is_urgent)
					readonly property bool kept: dock.own.pinned.includes(modelData.id)
					readonly property string image: launcher ? "" : modelData.entry ? Apps.image(modelData.entry.icon) : Apps.imageOf(modelData.id)
					// How large it is now, and how far along it's moved, for those under
					// the pointer.
					readonly property real grow: 1 + (dock.grown[index] ?? 0) / dock.size
					readonly property real shift: dock.shifts[index] ?? 0
					// Hopping: as it starts, and while it asks to be looked at.
					readonly property bool bouncing: dock.own.bounce && (dock.launching.includes(modelData.id) || urgent)
					property real up: 0
					// The line before it, if it's the first of those not kept.
					readonly property real lead: index === dock.split ? dock.sep : 0
					// What it said that's not been seen.
					readonly property int unread: launcher || !dock.own.unread ? 0 : NotificationStore.unreadOf(modelData)

					width: dock.upright ? dock.thick - Theme.u(12) : dock.slot + lead
					height: dock.upright ? dock.slot + lead : dock.thick - Theme.u(12)
					// The larger in front.
					z: grow

					SequentialAnimation {
						running: app.bouncing && Theme.animate
						loops: Animation.Infinite
						onRunningChanged: {
							if (!running)
								app.up = 0;
						}

						NumberAnimation {
							target: app
							property: "up"
							to: 1
							duration: 220
							easing.type: Easing.OutQuad
						}

						NumberAnimation {
							target: app
							property: "up"
							to: 0
							duration: 220
							easing.type: Easing.InQuad
						}

						PauseAnimation {
							duration: 260
						}
					}

					// The line between those kept and the others, in the middle of the gap, as
					// far along as the icon after it moves.
					Rectangle {
						readonly property real middle: (app.lead - row.spacing) / 2
						readonly property real moved: app.shift - (dock.grown[app.index] ?? 0) / 2

						objectName: "separator"
						visible: app.lead > 0
						x: dock.upright ? (parent.width - width) / 2 : middle - width / 2 + moved
						y: dock.upright ? middle - height / 2 + moved : (parent.height - height) / 2
						width: dock.upright ? dock.size * 0.6 : Math.max(1, Theme.u(1.5))
						height: dock.upright ? Math.max(1, Theme.u(1.5)) : dock.size * 0.6
						color: Qt.alpha(Theme.colors.text, 0.3)
					}

					// The app's own place, past the line before the first of those not kept.
					Item {
						id: body

						x: dock.upright ? 0 : app.lead
						y: dock.upright ? app.lead : 0
						width: dock.upright ? parent.width : dock.slot
						height: dock.upright ? dock.slot : parent.height

						// Under the pointer, where icons don't grow there.
						Rectangle {
							anchors.fill: parent
							visible: !dock.magnifies
							radius: Math.max(0, Theme.cardRadius - Theme.u(4))
							color: pointer.pressed ? Theme.pressed : pointer.containsMouse ? Theme.hover : "transparent"
						}

						// Toward the screen's middle; the mark has the side by its edge. It
						// moves along as those before it grow, and away from the edge as it
						// hops, and grows from its side by the edge.
						Item {
							x: dock.at === "left" ? parent.width - width : dock.at === "right" ? 0 : (parent.width - width) / 2
							y: dock.at === "top" ? parent.height - height : dock.at === "bottom" ? 0 : (parent.height - height) / 2
							width: dock.size
							height: dock.size
							transform: Translate {
								readonly property real away: app.up * dock.hop
								x: dock.upright ? (dock.at === "left" ? away : -away) : app.shift
								y: dock.upright ? app.shift : (dock.at === "top" ? away : -away)
							}

							Item {
								anchors.fill: parent
								scale: app.grow
								transformOrigin: dock.at === "top" ? Item.Top : dock.at === "left" ? Item.Left : dock.at === "right" ? Item.Right : Item.Bottom

								IconImage {
									anchors.fill: parent
									visible: app.image !== ""
									source: app.image
								}

								// An app the icon theme doesn't know, or the launcher's button.
								Icon {
									anchors.centerIn: parent
									visible: app.image === ""
									name: app.launcher ? "search" : "apps"
									size: dock.size * (app.launcher ? 0.6 : 0.7)
								}

								// How many of its notifications are unread, in the corner across.
								Rectangle {
									objectName: "unread"
									anchors.left: parent.left
									anchors.top: parent.top
									anchors.margins: -Theme.u(3)
									visible: app.unread > 0
									width: Math.max(height, unread.implicitWidth + Theme.u(8))
									height: Math.round(Theme.u(16))
									radius: height / 2
									color: Theme.colors.error

									Text {
										id: unread

										anchors.centerIn: parent
										text: app.unread > 99 ? "99+" : app.unread
										color: Theme.colors.background
										font.family: Theme.font
										font.pixelSize: Theme.fontSize - Theme.u(4)
										font.weight: Theme.fontWeight
									}
								}

								// How many windows it has, from two on.
								Rectangle {
									anchors.right: parent.right
									anchors.top: parent.top
									anchors.margins: -Theme.u(3)
									visible: dock.own.count && app.modelData.windows.length > 1
									width: Math.max(height, count.implicitWidth + Theme.u(8))
									height: Math.round(Theme.u(16))
									radius: height / 2
									color: Theme.colors.accent

									Text {
										id: count

										anchors.centerIn: parent
										text: app.modelData.windows.length
										color: Theme.colors.background
										font.family: Theme.font
										font.pixelSize: Theme.fontSize - Theme.u(4)
										font.weight: Theme.fontWeight
									}
								}
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
							transform: Translate {
								x: dock.upright ? 0 : app.shift
								y: dock.upright ? app.shift : 0
							}

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
							acceptedButtons: app.launcher ? Qt.LeftButton : Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
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
							onDraggingChanged: dock.dragging = dragging
							onPressed: event => {
								dragging = false;
								from = along(event);
							}
							// Into the place of the one beside it, and that one takes this
							// one's: the pointer is over its own app again. By where its place
							// is, not where it's gliding to.
							onPositionChanged: event => {
								if (!(pressedButtons & Qt.LeftButton) || !app.kept)
									return;
								const at = along(event);
								if (!dragging && Math.abs(at - from) < Theme.u(8))
									return;
								dragging = true;
								const middle = dock.middleOf(app.index);
								const reach = dock.slot / 2 + row.spacing;
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
								if (app.launcher)
									Apps.launcherWanted();
								else if (event.button === Qt.RightButton)
									dock.asked(app.modelData, dock.alongOf(body));
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
							text: app.launcher ? "Apps" : [app.modelData.entry?.name ?? app.modelData.id, app.modelData.windows.length > 1 ? `${app.modelData.windows.length} windows` : "", app.kept ? "kept" : ""].filter(part => part !== "").join(" · ")
						}
					}
				}
			}
		}
	}
}
