pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import qs

// The default output's volume, 0 to 1 or up to Settings.audio.max past it, the
// default microphone's, and the sound cards with the ways each can work: a
// headset as one to listen to or one to talk through, a card's plugs.
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
	// What apps are listening to a microphone, each with a volume of its own: a
	// stream that records is a source.
	readonly property var listeners: streams.filter(node => !node.isSink && !!node.audio && !!node.properties["application.name"])

	// Where sound can go: the sinks of devices, not the filters on the way to them.
	// They go by their names, as properties would take tracking each, and that's
	// not for what sits on a GPU that sleeps.
	readonly property var outputs: Pipewire.nodes.values.filter(node => node.isSink && !node.isStream && /^(alsa|bluez)_output/.test(node.name) && reaches(node))
	// Where sound can come from, the same way: devices' microphones.
	readonly property var inputs: Pipewire.nodes.values.filter(node => !node.isSink && !node.isStream && /^(alsa|bluez)_input/.test(node.name))
	// The PCI addresses of what has a screen on it, without the function.
	property var screens: []
	// The sound cards that can work in more ways than one: { id, name, profiles:
	// [{ index, text }], profile }, `profile` the index of the one that's on. Read
	// with lookCards(), from what `dump` prints, which a test has its own of.
	property var cards: []
	readonly property string dump: "pw-dump"

	// change() or changeMic() left the level where it was, at an end of it: the
	// key that asked still gets an answer.
	signal stayed
	signal micStayed

	// What comes out of a GPU's audio goes nowhere without a screen on that GPU, and
	// one in use stays, for the list to say where the sound is.
	function reaches(node) {
		const gpu = node.name.match(/^alsa_output\.pci-(\w+)_(\w+)_(\w+)\.\d\.(hdmi|dp)/i);
		return !gpu || node === sink || screens.includes(`${gpu[1]}:${gpu[2]}:${gpu[3]}`);
	}

	function lookCards() {
		cardLook.running = true;
	}

	// A way that can't be now isn't one, and off is no way to work: the card's
	// outputs would go, and with them the row to bring it back by.
	function readCards(text) {
		let all = [];
		try {
			all = JSON.parse(text || "[]");
		} catch (error) {
			return;
		}
		cards = all.filter(object => object.type === "PipeWire:Interface:Device" && object.info?.props?.["media.class"] === "Audio/Device").map(object => ({
			id: object.id,
			name: object.info.props["device.description"] || object.info.props["device.name"] || "",
			profile: object.info.params?.Profile?.[0]?.index ?? -1,
			profiles: (object.info.params?.EnumProfile ?? []).filter(profile => profile.available !== "no" && profile.name !== "off").map(profile => ({ index: profile.index, text: profile.description || profile.name }))
		})).filter(card => card.profiles.length > 1);
	}

	// The way of `card.profiles` by that `index`, kept for the next time too.
	function setProfile(card, index) {
		Env.act(`card profile ${index}`, () => {
			Quickshell.execDetached(["pw-cli", "set-param", String(card.id), "Profile", `{ index: ${index}, save: true }`]);
			cardSoon.restart();
		});
	}

	// sysfs says what it last saw: this doesn't wake a GPU that sleeps.
	function checkScreens() {
		screenCheck.running = true;
	}

	// Up to the limit, or where something else put it past that. Up is to be
	// heard: that takes the mute off.
	function change(by) {
		if (ready) {
			const level = Math.max(0, Math.min(Math.max(limit, volume), volume + by));
			if (by > 0 && muted)
				Env.act("mute false", () => sink.audio.muted = false);
			if (level === volume)
				stayed();
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
			if (level === micVolume)
				micStayed();
			Env.act(`mic volume ${level}`, () => source.audio.volume = level);
		}
	}

	function toggleMicMute() {
		if (micReady)
			Env.act(`mic mute ${!micMuted}`, () => source.audio.muted = !micMuted);
	}

	Component.onCompleted: checkScreens()

	Process {
		id: cardLook

		command: [audio.dump]
		stdout: StdioCollector {
			onStreamFinished: audio.readCards(text)
		}
	}

	// A card takes a moment to work another way.
	Timer {
		id: cardSoon

		interval: 700
		onTriggered: audio.lookCards()
	}

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
