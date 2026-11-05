pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// niri's workspaces and windows, kept up to date from its event stream.
Singleton {
	id: niri

	property var workspaces: []
	property var windows: []

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

	// Started by niri, in a scope of its own: what the shell starts goes when a
	// service of it restarts.
	function spawn(command) {
		act({ Spawn: { command } });
	}

	// To a window of the app that goes by one of `names`, if it has one.
	function focusApp(names) {
		const wanted = names.filter(name => !!name).map(name => name.toLowerCase());
		const window = windows.find(w => wanted.some(name => (w.app_id || "").toLowerCase().includes(name)));
		if (window)
			act({ FocusWindow: { id: window.id } });
	}

	function quit() {
		act({ Quit: { skip_confirmation: true } });
	}

	function handle(event) {
		if (event.WindowsChanged) {
			windows = event.WindowsChanged.windows;
		} else if (event.WindowOpenedOrChanged) {
			const window = event.WindowOpenedOrChanged.window;
			windows = windows.filter(w => w.id !== window.id).concat([window]);
		} else if (event.WindowClosed) {
			windows = windows.filter(w => w.id !== event.WindowClosed.id);
		}
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
