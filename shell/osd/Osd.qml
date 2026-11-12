import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs
import qs.notifications
import qs.services
import qs.ui

// What the volume, the microphone, the brightness, the keyboard layout, a lock
// key, the keyboard's light, the power profile, the night light, keeping awake or
// Do Not Disturb just became, or what plays after a key of the player's, for a
// moment, on the screen in focus: at its bottom, its top or in its middle, as
// Settings.osd says, which also says for how long, whether the level is in
// numbers too and what has no card. The power profile, the night light, keeping
// awake and Do Not Disturb only show with no panel open: there they change in
// sight. Clicks and keys go to what's under it.
PanelWindow {
	id: osd

	readonly property var icons: ({
		volume: "volume",
		mute: "volumeOff",
		brightness: "sun",
		mic: "mic",
		micMute: "micOff",
		layout: "keyboard",
		caps: "capsLock",
		num: "numLock",
		profile: "bolt",
		night: "sunset",
		awake: "coffee",
		dnd: "bellOff",
		keys: "keyboard",
		media: "music"
	})
	// The kinds by what the settings turn off.
	readonly property var groups: ({
		volume: "volume",
		mute: "volume",
		brightness: "brightness",
		mic: "mic",
		micMute: "mic",
		layout: "layout",
		caps: "locks",
		num: "locks",
		profile: "profile",
		night: "night",
		awake: "awake",
		dnd: "dnd",
		keys: "keys",
		media: "media"
	})
	readonly property real rise: Theme.u(8)
	readonly property string position: Settings.osd.position
	readonly property bool fromTop: position === "top"
	property string kind: "volume"
	property real level: 0
	// What the slider shows: a volume is full at its limit.
	readonly property real filled: groups[kind] === "volume" ? level / Audio.limit : level
	readonly property bool lock: kind === "caps" || kind === "num"
	// Those that are on or off, and say it in words.
	readonly property var switches: ({
		night: "Night light",
		awake: "Keep awake",
		dnd: "Do Not Disturb"
	})
	readonly property bool off: kind === "mute" || kind === "micMute" || ((lock || kind in switches) && level === 0)
	// What plays, as its title and who by; the icon says whether it does.
	readonly property var player: Media.player
	readonly property string track: player ? [player.trackTitle, player.trackArtist].filter(part => part).join(" \u2014 ") || player.identity : ""
	// What it says in words, if that's what it shows and not a level.
	// A layout by its whole name: two of one language would say the same in two
	// letters.
	readonly property string label: kind === "layout" ? Niri.layouts[Niri.layout] || Niri.layoutLabel
		: lock ? `${kind === "caps" ? "Caps Lock" : "Num Lock"} ${off ? "off" : "on"}`
		: kind in switches ? `${switches[kind]} ${off ? "off" : "on"}`
		: kind === "profile" ? Power.profileName
		: kind === "media" ? track
		: ""
	property bool shown: false

	function show(kind, level) {
		if (!Object.keys(icons).includes(kind)) {
			console.info(`okaeri: no osd "${kind}", it's one of ${Object.keys(icons).join(", ")}`);
			return;
		}
		if (kind === "media" && !player)
			return;
		osd.kind = kind;
		osd.level = level;
		screen = Niri.focusedScreen;
		shown = true;
		visible = true;
		hold.restart();
	}

	// For what changes in sight in a panel: only with none open.
	function tell(kind, level) {
		if (wants(groups[kind]) && Panels.open.length === 0)
			show(kind, level);
	}

	// Whether a change of `group` gets a card: a call by IPC always does.
	function wants(group) {
		return !Settings.osd.hidden.includes(group);
	}

	function showMic() {
		show(Audio.micMuted ? "micMute" : "mic", Audio.micVolume);
	}

	function showLayout() {
		show("layout", 0);
	}

	function showVolume() {
		show(Audio.muted ? "mute" : "volume", Audio.volume);
	}

	anchors.bottom: position === "bottom"
	anchors.top: fromTop
	// Clear of a bar that's down there.
	margins.bottom: Math.max(Theme.u(48), Settings.bottom(screen) + Theme.u(16)) - rise
	margins.top: Settings.top(screen) + Theme.u(16) - rise
	implicitWidth: card.width
	implicitHeight: Math.ceil(card.height + rise)
	visible: false
	color: "transparent"
	exclusionMode: ExclusionMode.Ignore
	mask: Region {}
	WlrLayershell.layer: WlrLayer.Overlay
	WlrLayershell.namespace: "okaeri-osd"
	BackgroundEffect.blurRegion: Theme.blur && shown ? glass : null
	WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

	// quickshell ipc call -- osd show volume 0.5, the kind one of `icons`.
	// Without the --, `show` is a command of quickshell's own.
	IpcHandler {
		target: "osd"

		function show(kind: string, level: real): void {
			osd.show(kind, level);
		}
	}

	// The player's keys: what plays, kept up while the track changes.
	Connections {
		target: Media

		function onKeyed() {
			if (osd.wants("media"))
				osd.show("media", 1);
		}
	}

	Connections {
		target: osd.kind === "media" && osd.shown ? osd.player : null

		function onTrackTitleChanged() {
			hold.restart();
		}
	}

	// A key at the end of what it changes moves nothing, and still gets its card.
	Connections {
		target: Audio

		function onStayed() {
			if (osd.wants("volume"))
				osd.showVolume();
		}

		function onMicStayed() {
			if (osd.wants("mic"))
				osd.showMic();
		}
	}

	Connections {
		target: Brightness

		function onStayed() {
			if (osd.wants("brightness"))
				osd.show("brightness", Brightness.level);
		}
	}

	// An external screen's, by the keys.
	Connections {
		target: Ddc

		function onStepped(level) {
			if (osd.wants("brightness"))
				osd.show("brightness", level);
		}
	}

	Watch {
		value: KeyboardLight.level
		ready: KeyboardLight.available
		device: KeyboardLight.device
		onMoved: osd.wants("keys") && osd.show("keys", KeyboardLight.level)
	}

	Watch {
		value: Audio.volume
		ready: Audio.ready
		device: Audio.sink
		onMoved: osd.wants("volume") && osd.showVolume()
	}

	Watch {
		value: Audio.muted
		ready: Audio.ready
		device: Audio.sink
		onMoved: osd.wants("volume") && osd.showVolume()
	}

	Watch {
		value: Brightness.level
		ready: Brightness.available
		device: Brightness.device
		onMoved: osd.wants("brightness") && osd.show("brightness", Brightness.level)
	}

	Watch {
		value: Audio.micVolume
		ready: Audio.micReady
		device: Audio.source
		onMoved: osd.wants("mic") && osd.showMic()
	}

	Watch {
		value: Audio.micMuted
		ready: Audio.micReady
		device: Audio.source
		onMoved: osd.wants("mic") && osd.showMic()
	}

	Watch {
		value: Niri.layout
		ready: Niri.layouts.length > 1
		device: Niri.layouts.join()
		onMoved: osd.wants("layout") && osd.showLayout()
	}

	Watch {
		value: Locks.caps
		ready: Locks.ready
		device: Locks.device
		onMoved: osd.wants("locks") && osd.show("caps", Locks.caps ? 1 : 0)
	}

	Watch {
		value: Locks.num
		ready: Locks.ready
		device: Locks.device
		onMoved: osd.wants("locks") && osd.show("num", Locks.num ? 1 : 0)
	}

	Watch {
		value: Power.profile
		ready: Power.choices.length > 1
		onMoved: osd.tell("profile", 1)
	}

	Watch {
		value: NightLight.on
		ready: NightLight.available
		onMoved: osd.tell("night", NightLight.on ? 1 : 0)
	}

	Watch {
		value: Awake.on
		ready: true
		onMoved: osd.tell("awake", Awake.on ? 1 : 0)
	}

	Watch {
		value: NotificationStore.dnd
		ready: true
		onMoved: osd.tell("dnd", NotificationStore.dnd ? 1 : 0)
	}

	Timer {
		id: hold

		interval: Settings.osd.duration * 1000
		onTriggered: osd.shown = false
	}

	// What the card covers, a pixel in from its edge, for the blur behind it.
	Region {
		id: glass

		x: 1
		y: Math.round(card.y + slide.y) + 1
		width: card.width - 2
		height: card.height - 2
		radius: card.radius
	}

	Card {
		id: card

		y: osd.fromTop ? osd.rise : 0
		// As a panel is: see-through and blurred, where the theme has that.
		color: Theme.panel
		opacity: osd.shown ? 1 : 0
		transform: Translate {
			id: slide

			y: osd.shown ? 0 : osd.fromTop ? -osd.rise : osd.rise

			Behavior on y {
				enabled: Theme.animate

				NumberAnimation {
					duration: Theme.ms(160)
					easing.type: Easing.OutCubic
				}
			}
		}

		Behavior on opacity {
			enabled: Theme.animate

			NumberAnimation {
				duration: Theme.ms(160)
				easing.type: Easing.OutCubic
			}
		}

		onOpacityChanged: {
			if (opacity === 0)
				osd.visible = false;
		}

		Row {
			spacing: Theme.u(10)

			Icon {
				anchors.verticalCenter: parent.verticalCenter
				name: osd.kind === "media" ? (osd.player?.isPlaying ? "play" : "pause") : osd.icons[osd.kind]
				color: osd.off ? Theme.colors.subtext : Theme.colors.text
			}

			Text {
				anchors.verticalCenter: parent.verticalCenter
				visible: osd.label !== ""
				// A long name is cut, so the card stays about as wide as one with a
				// level: in even pixels, as the card is centred.
				width: Math.min(Math.ceil(implicitWidth / 2) * 2, Math.round(Theme.u(240) / 2) * 2)
				text: osd.label
				textFormat: Text.PlainText
				elide: Text.ElideRight
				color: Theme.colors.text
				font.family: Theme.font
				font.pixelSize: Theme.fontSize
				font.weight: Theme.fontWeight
			}

			Slider {
				anchors.verticalCenter: parent.verticalCenter
				value: osd.filled
				interactive: false
				visible: osd.label === ""
				enabled: !osd.off

				Behavior on value {
					enabled: Theme.animate && osd.shown

					NumberAnimation {
						duration: Theme.ms(120)
						easing.type: Easing.OutCubic
					}
				}
			}

			Text {
				anchors.verticalCenter: parent.verticalCenter
				visible: Settings.osd.percent && osd.label === ""
				// As wide as it gets, so that the card keeps its size.
				width: Theme.u(40)
				horizontalAlignment: Text.AlignRight
				text: `${Math.round(osd.level * 100)}%`
				color: osd.off ? Theme.colors.subtext : Theme.colors.text
				font.family: Theme.font
				font.pixelSize: Theme.fontSize
				font.features: {
					"tnum": 1
				}
			}
		}
	}
}
