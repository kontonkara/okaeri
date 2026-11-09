pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs

// What's listening and watching: the apps that record from a microphone, and
// those that have a camera, by PipeWire's streams and, for apps that open a
// camera themselves, by who has a /dev/video* open. Recording what plays, as a
// visualizer does, isn't listening. The cameras are looked at every few seconds
// while something `uses` it, and only where there are any.
Singleton {
	id: privacy

	// What shows it.
	property int users: 0
	readonly property var microphone: names((Audio.streams ?? []).filter(node => !node.isSink && node.properties["media.class"] === "Stream/Input/Audio" && node.properties["stream.capture.sink"] !== "true"))
	readonly property var camera: names((Audio.streams ?? []).filter(node => node.properties["media.class"] === "Stream/Input/Video")).concat(opened.filter(name => !["pipewire", "wireplumber"].includes(name))).filter((name, index, all) => all.indexOf(name) === index)
	// The names of the processes that have a camera open.
	property var opened: []

	function names(nodes) {
		return nodes.map(node => Audio.streamName(node)).filter((name, index, all) => all.indexOf(name) === index);
	}

	Timer {
		running: privacy.users > 0
		interval: 3000
		repeat: true
		triggeredOnStart: true
		onTriggered: looking.running = true
	}

	Process {
		id: looking

		command: ["sh", "-c", 'ls /dev/video* >/dev/null 2>&1 || exit 0; for fd in $(find /proc/[0-9]*/fd -maxdepth 1 -lname "/dev/video*" 2>/dev/null); do pid=${fd#/proc/}; cat "/proc/${pid%%/*}/comm" 2>/dev/null; done | sort -u']

		stdout: StdioCollector {
			onStreamFinished: privacy.opened = text.split("\n").filter(name => name !== "")
		}
	}
}
