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
// one of those goes to its window. The pointer on one says what it shows.
Row {
	id: workspaces

	required property string output
	readonly property var own: Settings.workspaces
	readonly property var shown: own.empty ? Niri.on(output) : Niri.busyOn(output)
	readonly property bool labeled: own.labels !== "none"
	// As many icons to a pill, and a count of the rest.
	readonly property int most: 4
	property int wheel: 0

	// By `delta` of the wheel, 120 to a notch, up being the one before.
	function turn(delta) {
		wheel += delta;
		const steps = Math.trunc(wheel / 120);
		if (steps === 0)
			return;
		wheel -= steps * 120;
		Niri.turn(shown, own.reverse ? -steps : steps);
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

			anchors.verticalCenter: parent.verticalCenter
			width: holding ? Math.ceil(inside.implicitWidth + Theme.u(10))
				: workspaces.labeled ? Math.max(Theme.u(modelData.is_active ? 28 : 18), Math.ceil(label.implicitWidth + Theme.u(12)))
				: Theme.u(modelData.is_active ? 28 : 12)
			height: Theme.u(holding ? 22 : workspaces.labeled ? 18 : 12)
			radius: Theme.round(height)
			// With those with windows marked, the empty ones fade, in case the
			// accent is pale too. One with icons is a place for them.
			color: modelData.is_active ? Theme.colors.accent
				: modelData.is_urgent ? Theme.colors.error
				: holding ? Qt.alpha(Theme.colors.text, 0.12)
				: !workspaces.own.occupied ? Theme.colors.dim
				: Niri.holds(modelData) ? Qt.alpha(Theme.colors.accent, 0.6)
				: Qt.alpha(Theme.colors.text, 0.25)

			Behavior on width {
				enabled: Theme.animate

				NumberAnimation {
					duration: 180
					easing.type: Easing.OutCubic
				}
			}

			Row {
				id: inside

				anchors.centerIn: parent
				spacing: Theme.u(4)

				Text {
					id: label

					anchors.verticalCenter: parent.verticalCenter
					visible: workspaces.labeled
					// A long name would take the bar.
					text: (workspaces.own.labels === "name" ? pill.name : `${pill.modelData.idx}`).slice(0, 12)
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

						anchors.verticalCenter: parent.verticalCenter
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
					anchors.verticalCenter: parent.verticalCenter
					visible: pill.apps.length > workspaces.most
					text: `+${pill.apps.length - workspaces.most}`
					color: pill.ink
					font.family: Theme.font
					font.pixelSize: Theme.u(11)
					font.weight: Font.Bold
				}
			}

			MouseArea {
				anchors.fill: parent
				anchors.leftMargin: -Theme.u(3)
				anchors.rightMargin: -Theme.u(3)
				anchors.topMargin: -(Theme.barHeight - parent.height) / 2 + Theme.u(2)
				anchors.bottomMargin: -(Theme.barHeight - parent.height) / 2 + Theme.u(2)
				hoverEnabled: true
				cursorShape: Qt.PointingHandCursor
				onClicked: event => {
					// On an app's icon it's that app's window.
					const at = mapToItem(inside, event.x, event.y);
					const app = inside.childAt(at.x, at.y)?.app;
					const window = app === undefined ? undefined : workspaces.windowOf(pill.modelData, app);
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
