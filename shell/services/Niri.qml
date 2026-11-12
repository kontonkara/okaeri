pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs

// niri's workspaces, windows and keyboard layouts, kept up to date from its event
// stream, and the rules the shell needs of it.
Singleton {
	id: niri

	property var workspaces: []
	property var windows: []
	readonly property var focusedWindow: windows.find(w => w.is_focused) ?? null
	// The one that gets the focus back: a panel takes it from any.
	property int lastFocused: -1
	readonly property var lastWindow: windows.find(w => w.id === lastFocused) ?? null
	// What's showing the screen or a window, as niri has it.
	property var casts: []
	// Whether niri's overview is open.
	property bool overview: false
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

	// Those on the output with a window, and the active one.
	function busyOn(output) {
		return on(output).filter(w => w.is_active || holds(w));
	}

	// Whether a window is on `workspace`.
	function holds(workspace) {
		return windows.some(w => w.workspace_id === workspace.id);
	}

	// The windows on `workspace`, from its left and down each column, those that
	// float after them.
	function windowsOn(workspace) {
		const place = w => {
			const at = w.layout?.pos_in_scrolling_layout;
			return at ? at[0] * 1000 + at[1] : Infinity;
		};
		return windows.filter(w => w.workspace_id === workspace.id).sort((a, b) => (place(a) - place(b)) || a.id - b.id);
	}

	// The title of the window `workspace` shows, or "".
	function titleOn(workspace) {
		return windows.find(w => w.id === workspace.active_window_id)?.title ?? "";
	}

	// `steps` along `workspaces` from the active one, up being the one before. It
	// stops at the ends.
	function turn(workspaces, steps) {
		const at = workspaces.findIndex(w => w.is_active);
		const to = Math.max(0, Math.min(workspaces.length - 1, at - steps));
		if (to !== at)
			focus(workspaces[to].id);
	}

	// The screen with the focused workspace, the first one if niri has none of
	// them (a test's).
	readonly property var focusedScreen: {
		const output = (workspaces.find(w => w.is_focused) || {}).output;
		return Quickshell.screens.find(s => s.name === output) || Quickshell.screens[0];
	}

	// What the shell needs of niri's config, in a file of its own, for that to take
	// with `include optional=true "~/.local/state/okaeri/niri.kdl"`: niri reads it
	// again as it changes. Without it the shell runs all the same: blur only has the
	// wallpaper, the overview no backdrop, and screencasts show the toasts.
	readonly property string rules: `// Written by okaeri: it won't stay if it's changed here.
layer-rule {
	match namespace="^okaeri-backdrop$"
	place-within-backdrop true
}

layer-rule {
	match namespace="^okaeri-toasts$"
	block-out-from "screencast"
}

window-rule {
	match app-id="^org[.]quickshell$" title="^Settings$"
	open-floating true
}
${Theme.realBlur ? `
layer-rule {
	match namespace="^okaeri-panel$"
	match namespace="^okaeri-toasts$"
	match namespace="^okaeri-osd$"
	background-effect {
		xray false
	}
}

window-rule {
	match app-id="^org[.]quickshell$" title="^Settings$"
	background-effect {
		xray false
	}
}
` : ""}`

	onFocusedWindowChanged: {
		if (focusedWindow)
			lastFocused = focusedWindow.id;
	}

	onRulesChanged: writeRules()
	Component.onCompleted: writeRules()

	// Not before the theme is read, and only what's new: each write has niri read its
	// whole config again. ./try has a niri of its own, and this is the real one's.
	function writeRules() {
		if (Theme.ready && !Env.guest && rulesFile.text() !== rules)
			rulesFile.setText(rules);
	}

	Connections {
		target: Theme

		function onReadyChanged() {
			niri.writeRules();
		}
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

	function closeWindow(id) {
		act({ CloseWindow: { id } });
	}

	// To the workspace in focus, and the focus with it.
	function bringWindow(id) {
		const here = workspaces.find(w => w.is_focused);
		if (here)
			act({ MoveWindowToWorkspace: { window_id: id, reference: { Id: here.id }, focus: true } });
	}

	// To workspace `workspace`, by its id, the focus staying where it is.
	function moveWindow(id, workspace) {
		act({ MoveWindowToWorkspace: { window_id: id, reference: { Id: workspace }, focus: false } });
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

	function previousLayout() {
		act({ SwitchLayout: { layout: "Prev" } });
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
		} else if (event.WindowUrgencyChanged) {
			const change = event.WindowUrgencyChanged;
			windows = windows.map(w => w.id === change.id ? Object.assign({}, w, { is_urgent: change.urgent }) : w);
		} else if (event.WindowLayoutsChanged) {
			// Where each is in its workspace now: [[id, layout], ...].
			const layouts = {};
			event.WindowLayoutsChanged.changes.forEach(change => layouts[change[0]] = change[1]);
			windows = windows.map(w => layouts[w.id] ? Object.assign({}, w, { layout: layouts[w.id] }) : w);
		}
		if (event.CastsChanged) {
			casts = event.CastsChanged.casts;
		} else if (event.CastStartedOrChanged) {
			const cast = event.CastStartedOrChanged.cast;
			casts = casts.filter(c => c.stream_id !== cast.stream_id).concat([cast]);
		} else if (event.CastStopped) {
			casts = casts.filter(c => c.stream_id !== event.CastStopped.stream_id);
		}
		if (event.OverviewOpenedOrClosed)
			overview = event.OverviewOpenedOrClosed.is_open;
		if (event.WorkspaceActiveWindowChanged) {
			const change = event.WorkspaceActiveWindowChanged;
			workspaces = workspaces.map(w => w.id === change.workspace_id ? Object.assign({}, w, { active_window_id: change.active_window_id }) : w);
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

	FileView {
		id: rulesFile

		path: `${Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state"}/okaeri/niri.kdl`
		blockLoading: true
		// Two writes in a row come out in order.
		blockWrites: true
		printErrors: false
	}
}
