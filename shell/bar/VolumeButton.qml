import QtQuick
import qs
import qs.control
import qs.services
import qs.ui

// The volume on the bar: whether there's sound to hear, and how loud beside it
// if Settings.audio.label says so, with headphones for Bluetooth and headphones.
// The pointer on it says where the sound goes. A click opens the control center
// at the sound, the middle button or a right click mutes it, and the wheel turns
// it by Settings.audio.step percent.
BarButton {
	readonly property bool wanted: Audio.ready
	readonly property string percent: `${Math.round(Audio.volume * 100)}%`
	readonly property string output: Audio.sink?.description || Audio.sink?.nickname || ""
	// Bluetooth, or what calls itself headphones or a headset.
	readonly property bool worn: {
		const sink = Audio.sink;
		if (!sink)
			return false;
		const form = sink.properties?.["device.form-factor"] ?? "";
		return (sink.name ?? "").startsWith("bluez_output") || form === "headphone" || form === "headset" || /head(phone|set)/i.test(output);
	}

	visible: wanted
	takesWheel: true
	icon: Audio.muted || Audio.volume === 0 ? "volumeOff" : worn && "headphones" in Theme.icons ? "headphones" : "volume"
	text: Settings.audio.label === "percent" ? percent : ""
	ink: Audio.muted ? Theme.colors.subtext : Theme.colors.text
	tip: [output, Audio.muted ? `Muted, at ${percent}` : percent].filter(part => part !== "").join(" · ")
	onClicked: {
		Control.unfolded = "sound";
		Control.toggle();
	}
	onMiddleClicked: Audio.toggleMute()
	onRightClicked: Audio.toggleMute()
	onScrolled: steps => Audio.change(steps * Settings.audio.step / 100)
}
