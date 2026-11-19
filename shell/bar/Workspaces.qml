import QtQuick
import Quickshell
import Quickshell.Widgets
import qs
import qs.services
import qs.ui

// niri's workspaces on `output`: a click goes to one, the wheel to the next, and
// one with a window wanting attention stands out. As Settings.workspaces has it,
// those with windows look apart from the empty ones, which can be left out, and a
// pill says its number or name, and has the icons of the apps on it: a click on
// one of those goes to its window, and dragged onto another pill it goes to that
// workspace. A click on one that wants attention goes to the window that does. The
// pointer on one says what it shows. On a bar at a side they stand one under
// another, each as tall as it was long.
Grid {
	id: workspaces

	required property string output
	readonly property var own: Settings.workspaces
	readonly property var shown: own.empty ? Niri.on(output) : Niri.busyOn(output)
	readonly property bool labeled: own.labels !== "none"
	// Numbers as Settings.workspaces.numerals writes them: "roman", "kanji",
	// "circled", or as they are.
	function numeral(number) {
		if (own.numerals === "roman" && number > 0 && number < 40)
			return ["X", "IX", "V", "IV", "I"].reduce((state, letter, at) => {
				const worth = [10, 9, 5, 4, 1][at];
				while (state.left >= worth) {
					state.text += letter;
					state.left -= worth;
				}
				return state;
			}, { text: "", left: number }).text;
		if (own.numerals === "kanji" && number > 0 && number <= 10)
			return String.fromCodePoint([0x4e00, 0x4e8c, 0x4e09, 0x56db, 0x4e94, 0x516d, 0x4e03, 0x516b, 0x4e5d, 0x5341][number - 1]);
		if (own.numerals === "circled" && number > 0 && number <= 20)
			return String.fromCodePoint(0x2460 + number - 1);
		return `${number}`;
	}
	readonly property bool upright: Settings.barSide
	// As many icons to a pill, and a count of the rest.
	readonly property int most: 4
	property int wheel: 0
	// The window whose icon is dragged to another workspace, and the workspace it's
	// over.
	property var dragging: undefined
	property var over: null

	// By `delta` of the wheel, 120 to a notch, up being the one before.
	function turn(delta) {
		wheel += delta;
		const steps = Math.trunc(wheel / 120);
		if (steps === 0)
			return;
		wheel -= steps * 120;
		Niri.turn(shown, own.reverse ? -steps : steps);
	}

	// The workspace whose pill is at `point`, null between them.
	function pillAt(point) {
		return childAt(point.x, point.y)?.modelData ?? null;
	}

	// The apps with windows on `workspace`, by name, from its left, once each.
	function appsOn(workspace) {
		const apps = [];
		Niri.windowsOn(workspace).forEach(window => {
			if (!apps.includes(window.app_id || ""))
				apps.push(window.app_id || "");
		});
		return apps;
	}

	// The window of `app` to go to on `workspace`: the one it shows, if that's
	// the app's, or its first.
	function windowOf(workspace, app) {
		const own = Niri.windowsOn(workspace).filter(window => (window.app_id || "") === app);
		return (own.find(window => window.id === workspace.active_window_id) ?? own[0])?.id;
	}

	// The icon of `app`, "" for one the icon theme lacks. The entries load after
	// the first lookup: `values` has this come back when they're there.
	function icon(app) {
		const known = DesktopEntries.applications.values.length > 0;
		const name = (known && app ? DesktopEntries.heuristicLookup(app)?.icon : "") || app.toLowerCase();
		return !name ? "" : name.startsWith("/") ? Settings.url(name) : Quickshell.iconPath(name, true);
	}

	columns: upright ? 1 : 1000
	horizontalItemAlignment: Grid.AlignHCenter
	verticalItemAlignment: Grid.AlignVCenter
	spacing: Theme.u(6)

	Repeater {
		// By id, as each change makes them all anew: a pill that's made anew has
		// nothing to animate from.
		model: ScriptModel {
			values: workspaces.shown
			objectProp: "id"
		}

		Rectangle {
			id: pill

			required property var modelData
			readonly property string name: modelData.name || `${modelData.idx}`
			readonly property bool lit: modelData.is_active || modelData.is_urgent
			readonly property color ink: lit ? Theme.colors.background : Theme.colors.text
			readonly property var apps: workspaces.own.apps ? workspaces.appsOn(modelData) : []
			readonly property bool holding: apps.length > 0

			// How far along the bar it reaches, and how far across it.
			property real along: holding ? Math.ceil((workspaces.upright ? inside.implicitHeight : inside.implicitWidth) + Theme.u(10))
				: workspaces.labeled ? Math.max(Theme.u(modelData.is_active ? 28 : 18), Math.ceil((workspaces.upright ? label.implicitHeight : label.implicitWidth) + Theme.u(workspaces.upright ? 6 : 12)))
				: Theme.u(modelData.is_active ? 28 : 12)
			readonly property real across: Theme.u(holding ? 22 : workspaces.labeled ? 18 : 12)

			width: workspaces.upright ? across : along
			height: workspaces.upright ? along : across
			// Round, or square with Settings.workspaces.shape.
			radius: workspaces.own.shape === "square" ? Math.min(Theme.round(across), Theme.u(3)) : Theme.round(across)
			border.width: landing.containsDrag || (workspaces.over?.id === modelData.id && workspaces.dragging !== undefined) ? Theme.u(2) : 0
			border.color: Theme.colors.text
			// With those with windows marked, the empty ones fade, in case the
			// accent is pale too. One with icons is a place for them.
			color: modelData.is_active ? Theme.colors.accent
				: modelData.is_urgent ? Theme.colors.error
				: holding ? Qt.alpha(Theme.colors.text, 0.12)
				: !workspaces.own.occupied ? Theme.colors.dim
				: Niri.holds(modelData) ? Qt.alpha(Theme.colors.accent, 0.6)
				: Qt.alpha(Theme.colors.text, 0.25)

			Behavior on along {
				enabled: Theme.animate

				NumberAnimation {
					duration: Theme.ms(180)
					easing.type: Easing.OutCubic
				}
			}

			Grid {
				id: inside

				anchors.centerIn: parent
				columns: workspaces.upright ? 1 : 1000
				horizontalItemAlignment: Grid.AlignHCenter
				verticalItemAlignment: Grid.AlignVCenter
				spacing: Theme.u(4)

				Text {
					id: label

					visible: workspaces.labeled
					// A long name would take the bar.
					text: (workspaces.own.labels === "name" && pill.modelData.name ? pill.modelData.name : workspaces.numeral(pill.modelData.idx)).slice(0, 12)
					textFormat: Text.PlainText
					color: pill.ink
					font.family: Theme.font
					font.pixelSize: Theme.u(11)
					font.weight: Font.Bold
				}

				Repeater {
					// By name: a window's title changes often, and its app's icon
					// stays as it is.
					model: ScriptModel {
						values: pill.apps.slice(0, workspaces.most)
					}

					Item {
						required property string modelData
						readonly property string app: modelData
						readonly property string picture: workspaces.icon(modelData)

						width: Theme.u(16)
						height: width

						IconImage {
							anchors.fill: parent
							visible: parent.picture !== ""
							source: parent.picture
						}

						// An app the icon theme doesn't know.
						Icon {
							anchors.centerIn: parent
							visible: parent.picture === ""
							name: "apps"
							size: Theme.u(14)
							color: pill.ink
						}
					}
				}

				Text {
					visible: pill.apps.length > workspaces.most
					text: `+${pill.apps.length - workspaces.most}`
					color: pill.ink
					font.family: Theme.font
					font.pixelSize: Theme.u(11)
					font.weight: Font.Bold
				}
			}

			// A window carried here from the dock goes to this workspace.
			DropArea {
				id: landing

				anchors.fill: parent
				anchors.margins: -Theme.u(4)
				keys: ["text/x-okaeri-window"]
				onDropped: drop => {
					const window = Number(drop.getDataAsString("text/x-okaeri-window"));
					if (window > 0)
						Niri.moveWindow(window, pill.modelData.id);
					drop.accept(Qt.MoveAction);
				}
			}

			MouseArea {
				anchors.fill: parent
				// Out to the bar's edges, across it, and halfway to the next along it.
				anchors.leftMargin: workspaces.upright ? -(Theme.barHeight - parent.width) / 2 + Theme.u(2) : -Theme.u(3)
				anchors.rightMargin: anchors.leftMargin
				anchors.topMargin: workspaces.upright ? -Theme.u(3) : -(Theme.barHeight - parent.height) / 2 + Theme.u(2)
				anchors.bottomMargin: anchors.topMargin
				// The window of the icon pressed, and where: { window, x, y }.
				property var held: null
				property bool moved: false

				// The window of the app whose icon is at `x`, `y`, if there's one.
				function windowAt(x, y) {
					const at = mapToItem(inside, x, y);
					const app = inside.childAt(at.x, at.y)?.app;
					return app === undefined ? undefined : workspaces.windowOf(pill.modelData, app);
				}

				hoverEnabled: true
				cursorShape: workspaces.dragging !== undefined ? Qt.ClosedHandCursor : Qt.PointingHandCursor
				onPressed: event => {
					const window = windowAt(event.x, event.y);
					held = window === undefined ? null : { window, x: event.x, y: event.y };
					moved = false;
				}
				onPositionChanged: event => {
					if (!held)
						return;
					if (workspaces.dragging === undefined && Math.hypot(event.x - held.x, event.y - held.y) > Theme.u(8))
						workspaces.dragging = held.window;
					if (workspaces.dragging !== undefined)
						workspaces.over = workspaces.pillAt(mapToItem(workspaces, event.x, event.y));
				}
				onReleased: {
					if (workspaces.dragging !== undefined) {
						if (workspaces.over && workspaces.over.id !== pill.modelData.id)
							Niri.moveWindow(workspaces.dragging, workspaces.over.id);
						moved = true;
					}
					workspaces.dragging = undefined;
					workspaces.over = null;
					held = null;
				}
				onCanceled: {
					workspaces.dragging = undefined;
					workspaces.over = null;
					held = null;
				}
				onClicked: event => {
					if (moved)
						return;
					// On an app's icon it's that app's window, and on a workspace that
					// wants attention, the window that does.
					const window = windowAt(event.x, event.y) ?? (pill.modelData.is_urgent ? Niri.windowsOn(pill.modelData).find(one => one.is_urgent)?.id : undefined);
					if (window !== undefined)
						Niri.focusWindow(window);
					else
						Niri.focus(pill.modelData.id);
				}
				onWheel: event => workspaces.turn(event.angleDelta.y)

				Tip {
					listens: false
					hovered: parent.containsMouse
					pressed: parent.pressed
					text: [pill.name, Niri.titleOn(pill.modelData)].filter(part => part !== "").join(" · ")
				}
			}
		}
	}
}
