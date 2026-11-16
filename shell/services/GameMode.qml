pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs

// A mode for games, on by its tile or `okaeri game toggle`, and by itself while
// gamemode has a game, if Settings.game.follow says so: Feral's gamemoded counts
// its clients on the session bus, and says when that changes. While it's on,
// as Settings.game has each: nothing moves and nothing is blurred (`plain`),
// toasts wait as with Do Not Disturb, but for critical ones (`quiet`), and the
// machine doesn't lock, dim or sleep (`awake`).
Singleton {
	id: game

	readonly property var own: Settings.game
	// Asked for by hand; and turned off by hand while gamemode would have it on,
	// until gamemode has no game again.
	property bool asked: false
	property bool refused: false
	// How many games gamemode has now.
	property int clients: 0
	readonly property bool followed: own.follow && clients > 0 && !refused
	readonly property bool on: asked || followed
	readonly property bool plain: on && own.plain
	readonly property bool quiet: on && own.quiet
	readonly property bool awake: on && own.awake
	readonly property string bus: "busctl"

	function set(wanted) {
		asked = wanted;
		refused = !wanted && own.follow && clients > 0;
	}

	function toggle() {
		set(!on);
	}

	onClientsChanged: {
		if (clients === 0)
			refused = false;
	}

	// For tests: that it changed, and by what.
	onOnChanged: console.info("okaeri: game mode:", on ? (followed ? "on, by gamemode" : "on") : "off")

	Binding {
		target: Theme
		property: "still"
		value: game.plain
	}

	IpcHandler {
		target: "game"

		function toggle(): void {
			game.toggle();
		}

		function on(): void {
			game.set(true);
		}

		function off(): void {
			game.set(false);
		}

		// { on, gamemode }: whether it's on, and how many games gamemode has.
		function state(): string {
			return JSON.stringify({ on: game.on, gamemode: game.clients });
		}

		// For tests: as if gamemode had said how many games it has.
		function heard(count: int): void {
			game.clients = count;
		}
	}

	// "i 2", as busctl prints a number.
	Process {
		id: counting

		command: [game.bus, "--user", "get-property", "com.feralinteractive.GameMode", "/com/feralinteractive/GameMode", "com.feralinteractive.GameMode", "ClientCount"]
		stdout: StdioCollector {
			onStreamFinished: {
				const said = text.match(/^i (\d+)/);
				if (said && !Env.dry)
					game.clients = Number(said[1]);
			}
		}
	}

	// Anything gamemode says is a reason to count again; and every so often, for
	// one that says nothing.
	Process {
		running: game.own.follow && !Env.dry
		command: [game.bus, "--user", "--match", "type='signal',path='/com/feralinteractive/GameMode'", "monitor"]
		stdout: SplitParser {
			onRead: recount.restart()
		}
	}

	Timer {
		id: recount

		interval: 300
		onTriggered: counting.running = true
	}

	Timer {
		interval: 20000
		running: game.own.follow && !Env.dry
		repeat: true
		triggeredOnStart: true
		onTriggered: counting.running = true
	}
}
