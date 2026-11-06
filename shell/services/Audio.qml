pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

// The default output's volume, 0 to 1, and the default microphone's.
Singleton {
	id: audio

	readonly property var sink: Pipewire.defaultAudioSink
	readonly property bool ready: !!sink && sink.ready && !!sink.audio
	readonly property real volume: ready ? sink.audio.volume : 0
	readonly property bool muted: ready && sink.audio.muted

	readonly property var source: Pipewire.defaultAudioSource
	readonly property bool micReady: !!source && source.ready && !!source.audio
	readonly property real micVolume: micReady ? source.audio.volume : 0
	readonly property bool micMuted: micReady && source.audio.muted

	// What apps are playing, each with a volume of its own: to Quickshell a stream
	// that plays is a sink too. What has no app is the sound server's own, a filter's.
	readonly property var streams: Pipewire.nodes.values.filter(node => node.isStream)
	readonly property var nodes: streams.filter(node => node.isSink && !!node.audio && !!node.properties["application.name"])

	// Where sound can go: the sinks of devices, not the filters on the way to them.
	// They go by their names, as properties would take tracking each, and that's
	// not for what sits on a GPU that sleeps.
	readonly property var outputs: Pipewire.nodes.values.filter(node => node.isSink && !node.isStream && /^(alsa|bluez)_output/.test(node.name))

	function change(by) {
		if (ready) {
			const level = Math.max(0, Math.min(1, volume + by));
			Env.act(`volume ${level}`, () => sink.audio.volume = level);
		}
	}

	function use(node) {
		if (node !== sink)
			Env.act("output", () => Pipewire.preferredDefaultAudioSink = node);
	}

	function toggleMute() {
		if (ready)
			Env.act(`mute ${!muted}`, () => sink.audio.muted = !muted);
	}

	function changeStream(node, level) {
		Env.act(`app volume ${level}`, () => node.audio.volume = level);
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

	// Its properties are there only while tracked.
	PwObjectTracker {
		objects: [audio.sink, audio.source].concat(audio.streams).filter(node => !!node)
	}
}
