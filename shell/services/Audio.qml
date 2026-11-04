pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

// The default output's volume, 0 to 1.
Singleton {
	id: audio

	readonly property var sink: Pipewire.defaultAudioSink
	readonly property bool ready: !!sink && sink.ready && !!sink.audio
	readonly property real volume: ready ? sink.audio.volume : 0
	readonly property bool muted: ready && sink.audio.muted

	function change(by) {
		if (ready) {
			const level = Math.max(0, Math.min(1, volume + by));
			Env.act(`volume ${level}`, () => sink.audio.volume = level);
		}
	}

	function toggleMute() {
		if (ready)
			Env.act(`mute ${!muted}`, () => sink.audio.muted = !muted);
	}

	// Its properties are there only while tracked.
	PwObjectTracker {
		objects: audio.sink ? [audio.sink] : []
	}
}
