import QtQuick
import Quickshell
import Quickshell.Io

// What a plugin runs with the shell, for what has no place of its own: here a
// call, `okaeri hello ping`.
Scope {
	IpcHandler {
		target: "hello"

		function ping(): string {
			return "pong";
		}
	}
}
