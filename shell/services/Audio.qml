pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import qs

// The default output's volume, 0 to 1 or up to Settings.audio.max past it, and
// the default microphone's.
Singleton {
	id: audio

	// How far the volume goes: past 1 the sound server amplifies.
	readonly property real limit: Math.max(1, Settings.audio.max / 100)
	readonly property var sink: Pipewire.defaultAudioSink
	readonly property bool ready: !!sink && sink.ready && !!sink.audio
	readonly property real volume: ready ? sink.audio.volume : 0
	readonly property bool muted: ready && sink.audio.muted

	readonly property var source: Pipewire.defaultAudioSource
	readonly property bool micReady: !!source && source.ready && !!source.audio
	readonly property real micVolume: micReady ? source.audio.volume : 0
	readonly property bool micMuted: micReady && source.audio.muted

	// What apps are playing, each with a volume of its own: to Quickshell a stream
	// that plays is a sink too. What has no app is the sound server's own, a filter's,
	// and what plays as a notification is over as soon as it shows.
	readonly property var streams: Pipewire.nodes.values.filter(node => node.isStream)
	readonly property var nodes: streams.filter(node => node.isSink && !!node.audio && !!node.properties["application.name"] && node.properties["media.role"] !== "Notification")

	// Where sound can go: the sinks of devices, not the filters on the way to them.
	// They go by their names, as properties would take tracking each, and that's
	// not for what sits on a GPU that sleeps.
	readonly property var outputs: Pipewire.nodes.values.filter(node => node.isSink && !node.isStream && /^(alsa|bluez)_output/.test(node.name) && reaches(node))
	// Where sound can come from, the same way: devices' microphones.
	readonly property var inputs: Pipewire.nodes.values.filter(node => !node.isSink && !node.isStream && /^(alsa|bluez)_input/.test(node.name))
	// The PCI addresses of what has a screen on it, without the function.
	property var screens: []

	// What comes out of a GPU's audio goes nowhere without a screen on that GPU, and
	// one in use stays, for the list to say where the sound is.
	function reaches(node) {
		const gpu = node.name.match(/^alsa_output\.pci-(\w+)_(\w+)_(\w+)\.\d\.(hdmi|dp)/i);
		return !gpu || node === sink || screens.includes(`${gpu[1]}:${gpu[2]}:${gpu[3]}`);
	}

	// sysfs says what it last saw: this doesn't wake a GPU that sleeps.
	function checkScreens() {
		screenCheck.running = true;
	}

	// Up to the limit, or where something else put it past that.
	function change(by) {
		if (ready) {
			const level = Math.max(0, Math.min(Math.max(limit, volume), volume + by));
			Env.act(`volume ${level}`, () => sink.audio.volume = level);
			if (Settings.sounds.volumeChange && !muted && level !== volume)
				Sounds.play("audio-volume-change");
		}
	}

	function use(node) {
		if (node !== sink)
			Env.act("output", () => Pipewire.preferredDefaultAudioSink = node);
	}

	function useInput(node) {
		if (node !== source)
			Env.act("input", () => Pipewire.preferredDefaultAudioSource = node);
	}

	function toggleMute() {
		if (ready)
			Env.act(`mute ${!muted}`, () => sink.audio.muted = !muted);
	}

	function changeStream(node, level) {
		Env.act(`app volume ${level}`, () => node.audio.volume = level);
	}

	function toggleStream(node) {
		const muted = !!node.audio.muted;
		Env.act(`app mute ${!muted}`, () => node.audio.muted = !muted);
	}

	// Its app's name, without what a wrapper makes of it.
	function streamName(node) {
		const name = node.properties["application.name"] ?? node.description ?? node.name;
		return name.replace(/^\./, "").replace(/-wrapped$/, "");
	}

	function changeMic(by) {
		if (micReady) {
			const level = Math.max(0, Math.min(1, micVolume + by));
			Env.act(`mic volume ${level}`, () => source.audio.volume = level);
		}
	}

	function toggleMicMute() {
		if (micReady)
			Env.act(`mic mute ${!micMuted}`, () => source.audio.muted = !micMuted);
	}

	Component.onCompleted: checkScreens()

	Process {
		id: screenCheck

		command: ["sh", "-c", 'for status in /sys/class/drm/card*-*/status; do [ "$(cat "$status")" = connected ] && basename "$(readlink -f "${status%/*}/device/device")"; done; true']

		stdout: StdioCollector {
			onStreamFinished: audio.screens = text.trim().split("\n").map(address => address.replace(/\.\d+$/, ""))
		}
	}

	// Its properties are there only while tracked.
	PwObjectTracker {
		objects: [audio.sink, audio.source].concat(audio.streams).filter(node => !!node)
	}
}
