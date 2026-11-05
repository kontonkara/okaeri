pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// niri's workspaces, kept up to date from its event stream.
Singleton {
	id: niri

	property var workspaces: []

	// Those on the output, in order. A screen niri doesn't know (a test's
	// headless one) gets them all.
	function on(output) {
		const own = workspaces.filter(w => w.output === output);
		return (own.length ? own : workspaces.slice()).sort((a, b) => a.idx - b.idx);
	}

	// The screen with the focused workspace, the first one if niri has none of
	// them (a test's).
	readonly property var focusedScreen: {
		const output = (workspaces.find(w => w.is_focused) || {}).output;
		return Quickshell.screens.find(s => s.name === output) || Quickshell.screens[0];
	}

	function act(action) {
		request = JSON.stringify({ Action: action });
		requests.connected = true;
	}

	function focus(id) {
		act({ FocusWorkspace: { reference: { Id: id } } });
	}

	function quit() {
		act({ Quit: { skip_confirmation: true } });
	}

	function handle(event) {
		if (event.WorkspacesChanged) {
			workspaces = event.WorkspacesChanged.workspaces;
		} else if (event.WorkspaceActivated) {
			const id = event.WorkspaceActivated.id;
			const focused = event.WorkspaceActivated.focused;
			const output = workspaces.find(w => w.id === id)?.output;
			workspaces = workspaces.map(w => Object.assign({}, w, {
				is_active: w.output === output ? w.id === id : w.is_active,
				is_focused: focused ? w.id === id : w.is_focused
			}));
		}
	}

	Socket {
		path: Quickshell.env("NIRI_SOCKET")
		connected: true

		onConnectedChanged: {
			if (connected) {
				write('"EventStream"\n');
				flush();
			}
		}

		parser: SplitParser {
			onRead: line => niri.handle(JSON.parse(line))
		}
	}

	property string request: ""

	// One request a connection, closed at the reply.
	Socket {
		id: requests

		path: Quickshell.env("NIRI_SOCKET")

		onConnectedChanged: {
			if (connected) {
				write(niri.request + "\n");
				flush();
			}
		}

		parser: SplitParser {
			onRead: requests.connected = false
		}
	}
}
