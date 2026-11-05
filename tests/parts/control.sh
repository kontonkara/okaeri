# The control center, sourced by part.sh. First on what's really here, which
# only gets read: everything it asks for ends in the log, and so must leave
# names out. Then on made-up networks and devices, to reach what the machine
# doesn't show right now. Those come in through Probe, a file only this test
# has, put into the shell's copy, which Quickshell then reloads.

seen() {
	log | grep -cF "$1" || true
}

# `when TEXT COMMAND...`: the command makes one more line with TEXT in the log.
when() {
	text=$1
	shift
	before=$(seen "$text")
	"$@"
	for _ in $(seq 30); do
		[ "$(seen "$text")" -gt "$before" ] && return 0
		sleep 0.1
	done
	echo "control: nothing new with \"$text\" after: $*" >&2
	return 1
}

# `never TEXT COMMAND...`: the command makes no line with TEXT in the log.
never() {
	text=$1
	shift
	before=$(seen "$text")
	"$@"
	sleep 0.3
	[ "$(seen "$text")" -eq "$before" ] || {
		echo "control: \"$text\" after: $*" >&2
		return 1
	}
}

at() {
	move "$1" "$2"
	click
}

toggle() {
	ipc control toggle
	sleep 0.4
}

# Where things are with both sliders there. The panel's right edge is 10 px in
# from the screen's, its top under the bar.
volume_y=76
brightness_y=110
mute_x=1045
slider_left=1068
slider_width=250
wifi_y=172
switch_x=1344
fold_x=1150
# Wi-Fi's rows, under its header, and Bluetooth's header when Wi-Fi is folded,
# and under the six made-up networks.
row_y=213
row_step=38
bt_y=238
bt_low_y=466

row() {
	echo $((row_y + $1 * row_step))
}

# An empty place of the screen, and how a strip of the bottom of the panel's
# column looks with no panel in it.
outside_x=400
outside_y=500
strip() {
	magick "$1" -crop 380x8+1010+892 +repage -format '%k' info:
}

# How much two pictures differ in a part of them, 0 for not at all: letters
# drawn anew can be a shade off, and that doesn't count. That part is a row, or
# the lower line of one.
differ() {
	magick "$out/$1.png" "$out/$2.png" -crop "$3" +repage -fuzz 5% -metric AE -compare -format '%[distortion]' info:
}
whole_row() {
	echo "250x34+1060+$(($(row "$1") - 17))"
}
lower_line() {
	echo "250x12+1060+$(($(row "$1") + 5))"
}

# Whether Wi-Fi's card has a color in it, red far from green. The themes are
# black and white and the edges of letters reach 0.3: more than that is the
# error color, or a color that came from somewhere else.
color_in_wifi() {
	magick "$out/$1.png" -crop 370x300+1015+150 +repage -channel RG -separate +channel \
		-compose difference -composite -format '%[fx:maxima]' info: |
		awk '{ print ($1 > 0.4 ? "yes" : "no") }'
}

# On what's here ---------------------------------------------------------

when 'dry: wifi scan true' toggle
wait_log 'dry: bluetooth discovery true'
sleep 0.8
shot real

at $((slider_left + slider_width / 2)) $volume_y
wait_log 'dry: volume 0.'
log | grep -E 'dry: volume 0\.(49|5)' >/dev/null
when 'dry: volume' wheel 1
when 'dry: mute' at $mute_x $volume_y
when 'dry: brightness' at $((slider_left + slider_width / 4)) $brightness_y

when 'dry: wifi false' at $switch_x $wifi_y
# Folded, and Bluetooth's switch comes up to where the test expects it.
at $fold_x $wifi_y
sleep 0.4
shot real-folded
when 'dry: bluetooth false' at $switch_x $bt_y
at $fold_x $bt_y
sleep 0.4
shot real-bluetooth

# Closing takes back what opening started: a key, then a click elsewhere.
when 'dry: wifi scan false' key Escape
wait_log 'dry: bluetooth discovery false'
when 'dry: wifi scan true' toggle
when 'dry: wifi scan false' at $outside_x $outside_y
sleep 0.4

# Made up ----------------------------------------------------------------

cat >"$work/shell/control/Probe.qml" <<'QML'
import QtQuick
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Io
import Quickshell.Networking
import qs
import qs.services

Scope {
	id: probe

	component FakeNetwork: QtObject {
		property string name
		property bool connected: false
		property bool known: false
		property real signalStrength: 0.5
		property int security: WifiSecurityType.Wpa2Psk
		property int state: connected ? ConnectionState.Connected : ConnectionState.Disconnected
		property bool stateChanging: false

		signal connectionFailed(int reason)
	}

	component FakeDevice: QtObject {
		property string name
		property string deviceName: name
		property bool connected: false
		property bool paired: false
		property bool pairing: false
		property bool trusted: false
		property bool batteryAvailable: false
		property real battery: 0
		property int state: connected ? BluetoothDeviceState.Connected : BluetoothDeviceState.Disconnected
	}

	property var networks: [
		home, office, neighbour, cafe, campus, weak
	]

	FakeNetwork { id: home; name: "Home"; connected: true; known: true; signalStrength: 0.7 }
	FakeNetwork { id: office; name: "Office"; known: true; signalStrength: 0.4 }
	FakeNetwork { id: neighbour; name: "Neighbour"; signalStrength: 0.9 }
	FakeNetwork { id: cafe; name: "Cafe"; signalStrength: 0.8; security: WifiSecurityType.Open }
	FakeNetwork { id: campus; name: "Campus"; signalStrength: 0.6; security: WifiSecurityType.Wpa2Eap }
	FakeNetwork { id: weak; name: "A very long network name that has to be cut somewhere in its row"; signalStrength: 0.2; security: WifiSecurityType.Sae }

	QtObject {
		id: wifiCard

		readonly property int type: DeviceType.Wifi
		property bool scannerEnabled: false
		readonly property QtObject networks: QtObject {
			property var values: probe.networks
		}
	}

	FakeDevice { id: buds; name: "Buds"; connected: true; paired: true; batteryAvailable: true; battery: 0.6 }
	FakeDevice { id: keyboard; name: "Keyboard"; paired: true }
	FakeDevice { id: speaker; name: "Speaker" }
	FakeDevice { id: watch; name: "Watch" }
	FakeDevice { id: tag; name: "AA-BB-CC-DD-EE-FF"; deviceName: "" }

	QtObject {
		id: adapter

		property bool enabled: true
		property int state: BluetoothAdapterState.Enabled
		property bool discovering: false
		readonly property QtObject devices: QtObject {
			property var values: [tag, speaker, watch, keyboard, buds]
		}
	}

	function network(name: string): var {
		return networks.find(n => n.name.startsWith(name));
	}

	function device(name: string): var {
		return adapter.devices.values.find(d => d.name === name);
	}

	IpcHandler {
		target: "probe"

		function radios(): void {
			Wifi.enabled = true;
			Wifi.device = wifiCard;
			Bt.adapter = adapter;
		}

		function noRadios(): void {
			Wifi.device = null;
			Bt.adapter = null;
		}

		function noBacklight(): void {
			Brightness.device = "";
		}

		function wifi(on: bool): void {
			Wifi.enabled = on;
		}

		function bluetooth(on: bool): void {
			adapter.enabled = on;
		}

		function order(): string {
			return Wifi.networks.map(n => n.name.slice(0, 9)).join(",");
		}

		function devices(): string {
			return Bt.devices.map(d => d.name).join(",");
		}

		function fail(name: string, reason: int): void {
			probe.network(name).connectionFailed(reason);
		}

		function strength(name: string, level: real): void {
			probe.network(name).signalStrength = level;
		}

		function connecting(name: string): void {
			const network = probe.network(name);
			network.state = ConnectionState.Connecting;
			network.stateChanging = true;
		}

		function settled(name: string): void {
			const network = probe.network(name);
			network.state = ConnectionState.Disconnected;
			network.stateChanging = false;
		}

		function tried(name: string): void {
			connecting(name);
			settled(name);
		}

		function oddNames(): void {
			home.name = "<font color='#ff0000'>Home</font>\nlines";
			cafe.name = "<font color='#ff0000'>Cafe</font>";
			neighbour.name = "Two\nlines";
		}

		function names(): void {
			home.name = "Home";
			cafe.name = "Cafe";
			neighbour.name = "Neighbour";
		}

		function crowd(): void {
			const many = [];
			for (let i = 0; i < 40; i++)
				many.push(fake.createObject(probe, { name: `Network ${i}`, signalStrength: 1 - i / 50 }));
			probe.networks = probe.networks.concat(many);
		}

		function nothing(): void {
			probe.networks = [];
			adapter.devices.values = [];
		}

		function reset(): void {
			probe.networks = [home, office, neighbour, cafe, campus, weak];
			adapter.devices.values = [tag, speaker, watch, keyboard, buds];
		}

		function drop(name: string): void {
			const gone = probe.network(name);
			probe.networks = probe.networks.filter(n => n !== gone);
		}

		function pairing(name: string, on: bool): void {
			probe.device(name).pairing = on;
		}

		function paired(name: string, on: bool): void {
			probe.device(name).paired = on;
		}
	}

	// The button, where the bar would have it, but in a place known here.
	PanelWindow {
		anchors.left: true
		anchors.bottom: true
		implicitWidth: 60
		implicitHeight: 40
		color: Theme.colors.background

		ControlCenterButton {
			anchors.centerIn: parent
		}
	}

	Component {
		id: fake

		FakeNetwork {}
	}
}
QML

reload() {
	first_frames=$(seen 'okaeri: first frame')
	# Over the same file: that's what Quickshell sees for sure.
	sed 's/^\tControlCenter {}$/\tControlCenter {}\n\tProbe {}/' "$work/shell/shell.qml" >"$work/shell.qml"
	cat "$work/shell.qml" >"$work/shell/shell.qml"
	for _ in $(seq 100); do
		[ "$(seen 'okaeri: first frame')" -gt "$first_frames" ] && break
		sleep 0.1
	done
	[ "$(seen 'okaeri: first frame')" -gt "$first_frames" ]
}

# With the panel open, which takes back what opening started like closing does:
# nothing would after that.
when 'dry: wifi scan true' toggle
wait_log 'dry: bluetooth discovery true'
discoveries=$(seen 'dry: bluetooth discovery false')
when 'dry: wifi scan false' reload
sleep 0.2
[ "$(seen 'dry: bluetooth discovery false')" -gt "$discoveries" ]

ipc probe radios
[ "$(ipc probe order)" = 'Home,Office,Neighbour,Cafe,Campus,A very lo' ]
[ "$(ipc probe devices)" = 'Buds,Keyboard,Speaker,Watch' ]

# The button opens it; the panel covers it then, and the same click closes it.
when 'dry: wifi scan true' at 30 880
sleep 0.5
shot dark-wifi
when 'dry: wifi scan false' at 30 880
sleep 0.4

# Rows, by the pointer. 0 is connected, 1 known, 2 secured, 3 open, 4 one that
# takes more than a password, 5 secured with a long name.
action_x=1315
row_x=1150
toggle
when 'dry: wifi disconnect' at $action_x "$(row 0)"
never 'dry: wifi connect' at $row_x "$(row 0)"
when 'dry: wifi connect' at $row_x "$(row 1)"
when 'dry: wifi connect' at $row_x "$(row 3)"
never 'dry: wifi connect' at $row_x "$(row 4)"
never 'dry: wifi connect' at $row_x "$(row 2)"
sleep 0.3
shot dark-password

eye_x=1256
join_x=1321
field_below=35

# The field has the keys, and the list holds still under it: it only loses
# what went away.
type 'hunter2-'
ipc probe strength Neighbour 0.1
ipc probe drop Office
sleep 0.3
[ "$(ipc probe order)" = 'Home,Cafe,Campus,A very lo,Neighbour' ]
type 'hunter2'
at $eye_x $(($(row 1) + field_below))
sleep 0.2
shot dark-password-moved
when 'dry: wifi connect with a key' key Return
sleep 0.3
shot dark-key-given

# The same by the button.
ipc probe reset
sleep 0.3
never 'dry: wifi connect' at $row_x "$(row 5)"
type 'hunter2'
when 'dry: wifi connect with a key' at $join_x $(($(row 5) + field_below))
sleep 0.3
ipc probe strength Neighbour 0.9
sleep 0.3

# The arrows and a space stay in the field: the arrows would take the keys to
# the next row, and what comes after them to that network.
never 'dry: wifi connect' at $row_x "$(row 2)"
type 'abc'
key Down
key Down
key Up
type 'd e'
shot dark-field-arrows
when 'dry: wifi connect with a key' key Return
sleep 0.3

# Another network's wrong password shows in its row and leaves the field where
# it is, with what's typed in it.
never 'dry: wifi connect' at $row_x "$(row 2)"
type 'first-'
shot dark-field-in-use
ipc probe fail Office 1
sleep 0.3
shot dark-field-kept
[ "$(differ dark-field-in-use dark-field-kept "$(whole_row 2)")" = 0 ]
[ "$(differ dark-field-in-use dark-field-kept "$(whole_row 1)")" != 0 ]
type 'second'
when 'dry: wifi connect with a key' key Return
ipc probe tried Office
sleep 0.3

# Escape gets out of the field first, and then closes.
never 'dry: wifi connect' at $row_x "$(row 2)"
never 'dry: wifi scan false' key Escape
sleep 0.3
shot dark-field-dropped
when 'dry: wifi scan false' key Escape
sleep 0.3

# How a failure and a connection in progress show.
toggle
ipc probe fail Office 1
ipc probe fail Cafe 5
ipc probe connecting Neighbour
sleep 0.4
shot dark-failed
ipc probe settled Neighbour

# The wrong password opened a field, with nothing else going on, for another
# try: Escape gets out of that first.
never 'dry: wifi scan false' key Escape
when 'dry: wifi scan false' key Escape
sleep 0.4
ipc probe tried Office
ipc probe tried Cafe

# A try that ends with the panel closed shows when it's back, and until the
# next try.
move $outside_x $outside_y
toggle
sleep 0.3
shot dark-before-try
when 'dry: wifi connect' at $row_x "$(row 1)"
move $outside_x $outside_y
key Escape
sleep 0.4
ipc probe fail Office 1
toggle
sleep 0.3
shot dark-failed-closed
[ "$(color_in_wifi dark-failed-closed)" = yes ]
ipc probe tried Office
sleep 0.3
shot dark-next-try
[ "$(color_in_wifi dark-next-try)" = no ]

# Names are anyone's: no markup, and one line, here and in the summary.
ipc probe oddNames
sleep 0.3
shot dark-odd-names
[ "$(color_in_wifi dark-odd-names)" = no ]
[ "$(differ dark-before-try dark-odd-names "$(lower_line 2)")" = 0 ]
wifi_title=100x16+1068+157
[ "$(differ dark-before-try dark-odd-names $wifi_title)" = 0 ]
ipc probe names
key Escape
sleep 0.4

# By the keys: to the list past mute, the sliders, the fold and the switch.
toggle
key Tab
sleep 0.2
shot dark-focus
key Tab
key Tab
key Tab
key Tab
key Tab
key Down
when 'dry: wifi connect' key Return
shot dark-keys
key Escape
sleep 0.4

# Bluetooth unfolds, Wi-Fi folds. 0 is connected, 1 paired, 2 and 3 nearby; the
# one with only an address isn't there.
bt_row() {
	echo $((bt_y + 41 + $1 * row_step))
}
toggle
at $fold_x $bt_low_y
sleep 0.4
shot dark-bluetooth

# A wrong password opens no field in a folded section, where it would take
# what's typed out of sight, and the first Escape.
ipc probe fail Office 1
sleep 0.3
type 'hunter2'
never 'dry: wifi connect with a key' key Return
when 'dry: wifi scan false' key Escape
sleep 0.4
ipc probe tried Office
toggle

when 'dry: bluetooth disconnect' at $action_x "$(bt_row 0)"
when 'dry: bluetooth connect' at $row_x "$(bt_row 1)"

# Two pairings at once each end in connecting, with `paired` coming before the
# end of the pairing or after it.
when 'dry: bluetooth pair' at $row_x "$(bt_row 2)"
when 'dry: bluetooth pair' at $row_x "$(bt_row 3)"
ipc probe pairing Speaker true
ipc probe pairing Watch true
when 'dry: bluetooth trust and connect' ipc probe paired Speaker true
ipc probe pairing Speaker false
ipc probe pairing Watch false
when 'dry: bluetooth trust and connect' ipc probe paired Watch true

# One that failed is over: if something else pairs it later, that's not ours.
ipc probe paired Watch false
sleep 0.2
when 'dry: bluetooth pair' at $row_x "$(bt_row 3)"
ipc probe pairing Watch true
ipc probe pairing Watch false
sleep 3.2
never 'dry: bluetooth trust and connect' ipc probe paired Watch true

# Off, one and then the other: folded, and no scan or discovery while off.
when 'dry: wifi scan false' ipc probe wifi false
when 'dry: bluetooth discovery false' ipc probe bluetooth false
sleep 0.4
shot dark-off
when 'dry: wifi scan true' ipc probe wifi true
when 'dry: bluetooth discovery true' ipc probe bluetooth true
at $fold_x $wifi_y
sleep 0.4

# A list longer than the screen scrolls in its place, and the panel stays on
# the screen. Rows changing don't take it back to the top.
ipc probe crowd
sleep 0.5
shot dark-crowd
[ "$(strip "$out/dark-crowd.png")" = 1 ]
move $outside_x $outside_y
key Tab
key Tab
key Tab
key Tab
key Tab
key Tab
for _ in $(seq 12); do
	wtype -k Down
	sleep 0.05
done
sleep 0.4
shot dark-scrolled
ipc probe strength 'Network 39' 0.99
sleep 0.4
shot dark-scrolled-after
top=$(magick "$out/dark-crowd.png" -crop 300x100+1060+195 +repage -format '%#' info:)
kept=$(magick "$out/dark-scrolled-after.png" -crop 300x100+1060+195 +repage -format '%#' info:)
[ "$top" != "$kept" ]

# The same at twice the size.
printf '{"scale":2}' >"$XDG_CONFIG_HOME/okaeri/theme.json"
sleep 0.6
shot dark-scale
[ "$(magick "$out/dark-scale.png" -crop 760x8+620+892 +repage -format '%k' info:)" = 1 ]

# In the light theme.
printf '{"extends":"light"}' >"$XDG_CONFIG_HOME/okaeri/theme.json"
sleep 0.6
shot light-crowd

# The row at the bottom is cut; the list makes room for its field.
never 'dry: wifi connect' at $row_x 512
sleep 0.3
shot light-crowd-field
key Escape
sleep 0.2
key Escape
sleep 0.4
ipc probe reset
toggle
sleep 0.3
shot light-wifi
at $row_x "$(row 2)"
ipc probe fail Office 5
sleep 0.4
shot light-password
key Escape
at $fold_x $bt_low_y
sleep 0.4
shot light-bluetooth
key Escape
sleep 0.4

# Nothing around yet.
ipc probe nothing
toggle
sleep 0.3
shot light-empty-bluetooth
at $fold_x $wifi_y
sleep 0.4
shot light-empty-wifi
key Escape
sleep 0.4
ipc probe reset

# Square corners, and no animations at all.
printf '{"radius":0,"animations":false}' >"$XDG_CONFIG_HOME/okaeri/theme.json"
sleep 0.6
when 'dry: wifi scan true' ipc control toggle
sleep 0.2
at $row_x "$(row 2)"
sleep 0.2
shot dark-square
key Escape
when 'dry: wifi scan false' key Escape
sleep 0.2
when 'dry: wifi scan true' ipc control toggle
sleep 0.3
when 'dry: wifi scan false' key Escape

# No radios, no sections; no backlight, no brightness.
printf '{"extends":"light"}' >"$XDG_CONFIG_HOME/okaeri/theme.json"
sleep 0.6
ipc probe noRadios
ipc probe noBacklight
toggle
sleep 0.3
shot light-bare
key Escape
sleep 0.4

# What was asked for says what, and nothing else: no names, no password.
if log | grep 'dry:' | sed 's/.*dry: //' | grep -vxE 'volume [0-9.]+|mute (true|false)|brightness [0-9]+|wifi (true|false|connect|connect with a key|disconnect|scan true|scan false)|bluetooth (true|false|connect|pair|trust and connect|disconnect|discovery true|discovery false)'; then
	echo "control: something else in what was asked for" >&2
	exit 1
fi
if log | grep hunter2; then
	echo "control: the password got into the log" >&2
	exit 1
fi
