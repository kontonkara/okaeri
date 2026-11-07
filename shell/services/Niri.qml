pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// niri's workspaces, windows and keyboard layouts, kept up to date from its event
// stream.
Singleton {
	id: niri

	property var workspaces: []
	property var windows: []
	readonly property var focusedWindow: windows.find(w => w.is_focused) ?? null
	// What's showing the screen or a window, as niri has it.
	property var casts: []
	// The keyboard layouts by name, and which is on.
	property var layouts: []
	property int layout: 0
	// The one that's on, for short: its name's first letters.
	readonly property string layoutLabel: (layouts[layout] ?? "").slice(0, 2).toUpperCase()

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
		waiting.push(JSON.stringify({ Action: action }));
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

	function focusWindow(id) {
		act({ FocusWindow: { id } });
	}

	// To a window of the app that goes by one of `names`, if it has one.
	function focusApp(names) {
		const wanted = names.filter(name => !!name).map(name => name.toLowerCase());
		const window = windows.find(w => wanted.some(name => (w.app_id || "").toLowerCase().includes(name)));
		if (window)
			focusWindow(window.id);
	}

	function nextLayout() {
		act({ SwitchLayout: { layout: "Next" } });
	}

	function stopCast(session) {
		act({ StopCast: { session_id: session } });
	}

	function quit() {
		act({ Quit: { skip_confirmation: true } });
	}

	function handle(event) {
		if (event.KeyboardLayoutsChanged) {
			layouts = event.KeyboardLayoutsChanged.keyboard_layouts.names;
			layout = event.KeyboardLayoutsChanged.keyboard_layouts.current_idx;
		} else if (event.KeyboardLayoutSwitched) {
			layout = event.KeyboardLayoutSwitched.idx;
		}
		if (event.WindowsChanged) {
			windows = event.WindowsChanged.windows;
		} else if (event.WindowOpenedOrChanged) {
			const window = event.WindowOpenedOrChanged.window;
			const others = windows.filter(w => w.id !== window.id);
			// One that comes with the focus takes it from the rest.
			windows = (window.is_focused ? others.map(w => Object.assign({}, w, { is_focused: false })) : others).concat([window]);
		} else if (event.WindowClosed) {
			windows = windows.filter(w => w.id !== event.WindowClosed.id);
		} else if (event.WindowFocusChanged) {
			const id = event.WindowFocusChanged.id;
			windows = windows.map(w => Object.assign({}, w, { is_focused: w.id === id }));
		}
		if (event.CastsChanged) {
			casts = event.CastsChanged.casts;
		} else if (event.CastStartedOrChanged) {
			const cast = event.CastStartedOrChanged.cast;
			casts = casts.filter(c => c.stream_id !== cast.stream_id).concat([cast]);
		} else if (event.CastStopped) {
			casts = casts.filter(c => c.stream_id !== event.CastStopped.stream_id);
		}
		if (event.WorkspaceUrgencyChanged) {
			const change = event.WorkspaceUrgencyChanged;
			workspaces = workspaces.map(w => w.id === change.id ? Object.assign({}, w, { is_urgent: change.urgent }) : w);
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

	property var waiting: []

	// One request a connection, closed at the reply, and the next on a new one.
	Socket {
		id: requests

		path: Quickshell.env("NIRI_SOCKET")

		onConnectedChanged: {
			if (connected) {
				write(niri.waiting.shift() + "\n");
				flush();
			} else if (niri.waiting.length) {
				connected = true;
			}
		}

		parser: SplitParser {
			onRead: requests.connected = false
		}
	}
}
