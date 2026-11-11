# The control center, sourced by part.sh. First on what's really here, which
# only gets read: everything it asks for ends in the log, and so must leave
# names out. Then on made-up networks and devices, to reach what the machine
# doesn't show right now. Those come in through Probe, a file only this test
# has, put into the shell's copy, which Quickshell then reloads.

fail() {
	echo "control: $1" >&2
	exit 1
}
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
# Opens it at page $1, or goes there.
page() {
	ipc control page "$1"
	sleep 0.4
}
panels() {
	niri msg --json layers | jq '[.[] | select(.namespace == "okaeri-panel")] | length'
}

# Where things are on the tiles' side, with both sliders there and no
# microphone. The panel's right edge is 10 px in from the screen's, its top under
# the bar.
volume_y=120
brightness_y=154
mute_x=1051
slider_left=1074
slider_width=225
sound_x=1363
# The tiles: Wi-Fi and Bluetooth on the first row, with their arrows, the night
# light and keeping awake on the second, the power profile on the third.
left_tile_x=1096
right_tile_x=1289
wifi_arrow_x=1181
bt_arrow_x=1364
tiles_y=217
tiles_y2=283
tiles_y3=349
# A page: its header, with the way back and the switch, and its rows.
page_y=83
back_x=1051
switch_x=1350
row_y=126
row_step=38

row() {
	echo $((row_y + $1 * row_step))
}

# An empty place of the screen, and how a strip of the bottom of the panel's
# column looks with no panel in it.
outside_x=400
outside_y=500
strip() {
	magick "$1" -crop 380x8+1016+892 +repage -format '%k' info:
}

# How much two pictures differ in a part of them, 0 for not at all: letters
# drawn anew can be a shade off, and that doesn't count. That part is a row, or
# the lower line of one.
differ() {
	magick "$out/$1.png" "$out/$2.png" -crop "$3" +repage -fuzz 5% -metric AE -compare -format '%[distortion]' info:
}
# Whether two shots show the same panel in part $3, give or take how a shape is
# drawn again: under a hundredth of it.
alike() {
	awk -v d="$(differ "$1" "$2" "$3")" 'BEGIN { exit !(d < 0.01) }'
}
whole_row() {
	echo "250x34+1066+$(($(row "$1") - 17))"
}
lower_line() {
	echo "250x12+1066+$(($(row "$1") + 5))"
}

# Whether Wi-Fi's page has a color in it, red far from green. The themes are
# black and white and the edges of letters reach 0.3: more than that is the
# error color, or a color that came from somewhere else.
color_in_wifi() {
	magick "$out/$1.png" -crop 370x300+1021+60 +repage -channel RG -separate +channel \
		-compose difference -composite -format '%[fx:maxima]' info: |
		awk '{ print ($1 > 0.4 ? "yes" : "no") }'
}

# The machine's microphone and what its apps play would move all of this: none
# of it, up to the end. The reload is the only one so far.
sed -e 's/^\treadonly property var nodes: .*/\tproperty var nodes: []/' -e 's/^\treadonly property bool micReady: .*/\tproperty bool micReady: false/' \
	"$work/shell/services/Audio.qml" >"$work/Audio.qml"
mv "$work/Audio.qml" "$work/shell/services/Audio.qml"
# Those go unseen. A line more elsewhere reloads it all: a reload that finds
# Audio.qml cut off while it's written doesn't take it for a singleton.
printf '\n' >>"$work/shell/shell.qml"
wait_log 'Reloading configuration'
sleep 1

# On what's here ---------------------------------------------------------

# Whether the machine's Bluetooth is on: only then does opening start its discovery.
bt_on=false
[ "$(busctl get-property org.bluez /org/bluez/hci0 org.bluez.Adapter1 Powered 2>/dev/null)" = "b true" ] && bt_on=true

when 'dry: wifi scan true' toggle
[ "$bt_on" = false ] || wait_log 'dry: bluetooth discovery true'
sleep 0.8
shot real

at $((slider_left + slider_width / 2)) $volume_y
wait_log 'dry: volume 0.'
log | grep -E 'dry: volume 0\.(49|5)' >/dev/null
when 'dry: volume' wheel 1
fail_awake() {
	echo "control: $1" >&2
	exit 1
}
# The power profile's tile goes on to the next one, and so does the wheel on it.
when 'dry: power profile' at $left_tile_x $tiles_y3
when 'dry: power profile' wheel 1
# The night light: on, wlsunset as set; the wheel on its tile makes it warmer.
when 'dry: night light -t 4000 -T 4001' ipc night toggle
move $left_tile_x $tiles_y2
when 'dry: night light -t 3750 -T 3751' wheel 1
shot night
ipc night toggle
# Keeping awake: the wheel gives it half an hour, and takes it back.
awake() {
	ipc awake state | jq -r .on
}
move $right_tile_x $tiles_y2
wheel 1
sleep 0.3
[ "$(awake)" = true ] || fail_awake "the wheel didn't turn it on"
shot awake-wheel
wheel -1
sleep 0.3
[ "$(awake)" = false ] || fail_awake "the wheel didn't turn it off"

when 'dry: mute' at $mute_x $volume_y
when 'dry: brightness' at $((slider_left + slider_width / 4)) $brightness_y

# A click on a tile switches it.
when 'dry: wifi false' at $left_tile_x $tiles_y
when 'dry: bluetooth ' at $right_tile_x $tiles_y
move $outside_x $outside_y
sleep 0.2
shot real-tiles
# Its arrow opens its page in the panel's place; Escape goes back to the tiles,
# and so does the way back.
at $wifi_arrow_x $tiles_y
sleep 0.4
move $outside_x $outside_y
sleep 0.2
shot real-wifi
[ "$(differ real-tiles real-wifi 380x300+1016+60)" != 0 ] || fail "the arrow opened no page"
key Escape
sleep 0.4
[ "$(panels)" = 1 ] || fail "Escape on a page closed the panel"
move $outside_x $outside_y
sleep 0.2
shot real-back
alike real-tiles real-back 380x260+1016+100 || fail "Escape didn't go back to the tiles"
at $bt_arrow_x $tiles_y
sleep 0.4
move $outside_x $outside_y
sleep 0.2
shot real-bluetooth
at $back_x $page_y
sleep 0.4
move $outside_x $outside_y
sleep 0.2
shot real-back-again
alike real-tiles real-back-again 380x260+1016+100 || fail "the way back didn't go back"
# Closed on a page, it opens on the tiles again.
at $wifi_arrow_x $tiles_y
sleep 0.3
toggle
toggle
move $outside_x $outside_y
sleep 0.6
shot real-reopened
alike real-tiles real-reopened 380x260+1016+100 || fail "it opened on the page it was closed on"

# Closing takes back what opening started: a key, then a click elsewhere.
when 'dry: wifi scan false' key Escape
[ "$bt_on" = false ] || wait_log 'dry: bluetooth discovery false'
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
		property bool pairable: false
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

		function reaches(name: string, screens: string): bool {
			Audio.screens = screens.split(",");
			return Audio.reaches({ name });
		}

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

		function vpns(): string {
			return Vpn.connections.map(connection => `${connection.name}=${connection.kind}${connection.on ? "+" : ""}`).join(",");
		}

		// As if bluetoothctl, the agent, had printed it.
		function heard(text: string): void {
			Bt.hear(text);
		}

		function asking(): string {
			return JSON.stringify(Bt.asking);
		}

		// How many didn't pair the last time.
		function failedPairs(): int {
			return Bt.failed.length;
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
[ "$bt_on" = false ] || wait_log 'dry: bluetooth discovery true'
discoveries=$(seen 'dry: bluetooth discovery false')
when 'dry: wifi scan false' reload
sleep 0.2
[ "$bt_on" = false ] || [ "$(seen 'dry: bluetooth discovery false')" -gt "$discoveries" ]

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
action_x=1321
row_x=1156
page wifi
when 'dry: wifi disconnect' at $action_x "$(row 0)"
never 'dry: wifi connect' at $row_x "$(row 0)"
when 'dry: wifi connect' at $row_x "$(row 1)"
# A saved one goes on a second click, soon after the first.
forget_x=1345
never 'dry: wifi forget' at $forget_x "$(row 1)"
sleep 0.2
shot dark-forget
when 'dry: wifi forget' at $forget_x "$(row 1)"
when 'dry: wifi connect' at $row_x "$(row 3)"
never 'dry: wifi connect' at $row_x "$(row 4)"
never 'dry: wifi connect' at $row_x "$(row 2)"
sleep 0.3
shot dark-password

eye_x=1262
join_x=1327
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

# Escape gets out of the field first, then back to the tiles, and then closes.
never 'dry: wifi connect' at $row_x "$(row 2)"
never 'dry: wifi scan false' key Escape
sleep 0.3
shot dark-field-dropped
never 'dry: wifi scan false' key Escape
when 'dry: wifi scan false' key Escape
sleep 0.3

# How a failure and a connection in progress show.
page wifi
ipc probe fail Office 1
ipc probe fail Cafe 5
ipc probe connecting Neighbour
sleep 0.4
shot dark-failed
ipc probe settled Neighbour

# The wrong password opened a field, with nothing else going on, for another
# try: Escape gets out of that first.
never 'dry: wifi scan false' key Escape
never 'dry: wifi scan false' key Escape
when 'dry: wifi scan false' key Escape
sleep 0.4
ipc probe tried Office
ipc probe tried Cafe

# A try that ends with the panel closed shows when it's back, and until the
# next try.
move $outside_x $outside_y
page wifi
sleep 0.3
shot dark-before-try
when 'dry: wifi connect' at $row_x "$(row 1)"
move $outside_x $outside_y
toggle
sleep 0.4
ipc probe fail Office 1
page wifi
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
wifi_title=60x14+1101+70
[ "$(differ dark-before-try dark-odd-names $wifi_title)" = 0 ]
ipc probe names
toggle

# By the keys: Tab to the Wi-Fi tile, the right arrow to its page, where they
# are on its way back, Tab past the switch to the list, and a row's Enter.
toggle
key Tab
sleep 0.2
shot dark-focus
key Tab
key Tab
key Tab
key Tab
key Tab
key Tab
key Right
sleep 0.4
shot dark-keys-page
key Tab
key Tab
key Down
when 'dry: wifi connect' key Return
shot dark-keys
toggle

# Bluetooth's page. 0 is connected, 1 paired, 2 and 3 nearby; the one with only
# an address isn't there.
bt_row() {
	row "$1"
}
page bluetooth
shot dark-bluetooth

# A wrong password opens no field on a page that isn't there, where it would
# take what's typed out of sight, and the first Escape.
ipc probe fail Office 1
sleep 0.3
type 'hunter2'
never 'dry: wifi connect with a key' key Return
never 'dry: wifi scan false' key Escape
when 'dry: wifi scan false' key Escape
sleep 0.4
ipc probe tried Office
page bluetooth

when 'dry: bluetooth disconnect' at $action_x "$(bt_row 0)"
when 'dry: bluetooth connect' at $row_x "$(bt_row 1)"
never 'dry: bluetooth forget' at $forget_x "$(bt_row 1)"
sleep 0.2
when 'dry: bluetooth forget' at $forget_x "$(bt_row 1)"

# Two pairings at once each end in connecting, with `paired` coming before the
# end of the pairing or after it. Meanwhile the adapter is pairable, with an
# agent, and then it's as it was.
when 'dry: bluetooth pairable true' at $row_x "$(bt_row 2)"
wait_log 'dry: bluetooth agent'
when 'dry: bluetooth pair' at $row_x "$(bt_row 3)"
ipc probe pairing Speaker true
ipc probe pairing Watch true
when 'dry: bluetooth trust and connect' ipc probe paired Speaker true
ipc probe pairing Speaker false
ipc probe pairing Watch false
when 'dry: bluetooth pairable false' ipc probe paired Watch true
[ "$(seen 'dry: bluetooth trust and connect')" = 2 ] || fail "not both connected after pairing"

# One that failed is over: if something else pairs it later, that's not ours.
ipc probe paired Watch false
sleep 0.2
when 'dry: bluetooth pair' at $row_x "$(bt_row 3)"
ipc probe pairing Watch true
ipc probe pairing Watch false
sleep 3.2
[ "$(ipc probe failedPairs)" = 1 ] || fail "a pairing that failed isn't said: $(ipc probe failedPairs)"
shot bt-failed
never 'dry: bluetooth trust and connect' ipc probe paired Watch true
# Tried again, it's not one that failed any more.
ipc probe paired Watch false
sleep 0.2
when 'dry: bluetooth pair' at $row_x "$(bt_row 3)"
[ "$(ipc probe failedPairs)" = 0 ] || fail "a new try still says it failed"
ipc probe pairing Watch true
# What BlueZ asks of it meanwhile comes over the devices, as its agent prints it,
# colors and all: a code to compare, and the answer goes back.
asking() {
	[ "$(ipc probe asking)" = "$1" ] || fail "asked is $(ipc probe asking), not $1"
}
ipc probe heard "$(printf 'Request confirmation\n\033[0;94m[agent] Confirm passkey 123456 (yes/no): \033[0m')"
sleep 0.4
asking '{"kind":"confirm","code":"123456"}'
shot bt-asked
when 'dry: bluetooth answer confirm yes' at 1342 193
asking null
# A PIN to type here: the field has the keys, and what's typed stays out of the log.
ipc probe heard "$(printf 'Request PIN code\n[agent] Enter PIN code: ')"
sleep 0.4
asking '{"kind":"pin","code":""}'
type '0000'
when 'dry: bluetooth answer pin' key Return
log | grep -F 'bluetooth answer' | grep -qF 0000 && fail "the PIN is in the log"
asking null
# One to type on the device is only shown, until BlueZ says that's over.
ipc probe heard "$(printf '[agent] Passkey: \033[1;90m\033[1;37m654321\n\033[0m')"
sleep 0.3
asking '{"kind":"show","code":"654321"}'
shot bt-shown
ipc probe heard "$(printf 'Request canceled\n')"
sleep 0.3
asking null
# Asked with the panel closed, it comes up at the page.
toggle
[ "$(panels)" = 0 ] || fail "the panel didn't close"
ipc probe heard "$(printf 'Request authorization\n[agent] Accept pairing (yes/no): ')"
sleep 0.6
[ "$(panels)" = 1 ] || fail "a question didn't bring the panel"
asking '{"kind":"accept","code":""}'
shot bt-accept
when 'dry: bluetooth answer accept no' at 1286 160
asking null
ipc probe pairing Watch true
ipc probe pairing Watch false
sleep 3.2

# Airplane mode, the tile beside the power profile's: Wi-Fi and Bluetooth go
# off, what they were is kept, and they come back as it ends.
at $back_x $page_y
sleep 0.4
airplane=$XDG_STATE_HOME/okaeri/airplane.json
offs=$(seen 'dry: bluetooth false')
when 'dry: wifi false' at $right_tile_x $tiles_y3
sleep 0.3
[ "$(seen 'dry: bluetooth false')" -gt "$offs" ] || fail "airplane mode left Bluetooth on"
[ "$(jq -c . "$airplane")" = '{"wifi":true,"bluetooth":true}' ] || fail "what was on isn't kept: $(cat "$airplane")"
shot airplane-on
ons=$(seen 'dry: bluetooth true')
when 'dry: wifi true' at $right_tile_x $tiles_y3
sleep 0.3
[ "$(seen 'dry: bluetooth true')" -gt "$ons" ] || fail "Bluetooth didn't come back after airplane mode"
[ ! -s "$airplane" ] || fail "airplane mode is still kept: $(cat "$airplane")"
# One of them turned on by hand meanwhile ends it, and the other stays as it is.
ipc probe bluetooth false
sleep 0.2
when 'dry: wifi false' at $right_tile_x $tiles_y3
[ "$(jq -c . "$airplane")" = '{"wifi":true,"bluetooth":false}' ] || fail "what was on isn't kept: $(cat "$airplane")"
never 'dry: wifi true' ipc probe bluetooth true
[ ! -s "$airplane" ] || fail "airplane mode goes on with Bluetooth turned on"

# The VPNs NetworkManager has, WireGuard too, and nothing else of its: a tile,
# which takes down the one that's up, and a page of them.
printf '%s\n' 'Work:11111111-2222-3333-4444-555555555555:vpn:activated' 'Home\: wg:66666666-7777-8888-9999-000000000000:wireguard:' \
	'Wired:aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee:802-3-ethernet:activated' >"$work/vpns"
sleep 3.5
[ "$(ipc probe vpns)" = 'Work=VPN+,Home: wg=WireGuard' ] || fail "the VPNs are $(ipc probe vpns)"
shot vpn-tile
tiles_y4=$((tiles_y3 + 66))
when 'dry: vpn down' at $left_tile_x $tiles_y4
# Recording the screen is the tile beside it: the panel goes first, as it isn't
# what's to be recorded.
when 'dry: record start screen none' at $right_tile_x $tiles_y4
sleep 0.4
[ "$(panels)" = 0 ] || fail "the panel stays for a recording"
toggle
at $wifi_arrow_x $tiles_y4
sleep 0.4
shot vpn-page
when 'dry: vpn up' at $row_x "$(row 1)"
at $back_x $page_y
sleep 0.4
: >"$work/vpns"
sleep 3.5
[ "$(ipc probe vpns)" = '' ] || fail "the VPNs that went are still $(ipc probe vpns)"

# A tile of one's own, beside the recording's: it's on while its check ends well,
# looked at every few seconds, and a click runs its command.
printf '{ "control": { "custom": [{ "name": "Mine", "command": "touch %s", "check": "test -e %s" }] } }\n' "$work/flag" "$work/flag" >"$XDG_CONFIG_HOME/okaeri/settings.json"
sleep 0.8
shot own-off
touch "$work/flag"
sleep 3.5
shot own-on
[ "$(differ own-off own-on 170x50+1210+390)" != 0 ] || fail "a tile of one's own doesn't follow its check"
when 'dry: tile run' at $right_tile_x $tiles_y4
rm "$work/flag"
printf '{}\n' >"$XDG_CONFIG_HOME/okaeri/settings.json"
sleep 0.5
page bluetooth

# Off, one and then the other: no scan or discovery while off, and the tiles
# say so.
at $back_x $page_y
when 'dry: wifi scan false' ipc probe wifi false
when 'dry: bluetooth discovery false' ipc probe bluetooth false
sleep 0.4
shot dark-off
when 'dry: wifi scan true' ipc probe wifi true
when 'dry: bluetooth discovery true' ipc probe bluetooth true
at $wifi_arrow_x $tiles_y
sleep 0.4

# A list longer than the screen scrolls in its place, and the panel stays on
# the screen. Rows changing don't take it back to the top.
ipc probe crowd
sleep 0.5
shot dark-crowd
[ "$(strip "$out/dark-crowd.png")" = 1 ]
move 1200 "$(row 4)"
notch 6
sleep 0.6
move $outside_x $outside_y
sleep 0.2
shot dark-scrolled
ipc probe strength 'Network 39' 0.99
sleep 0.4
shot dark-scrolled-after
top=$(magick "$out/dark-crowd.png" -crop 300x100+1066+110 +repage -format '%#' info:)
kept=$(magick "$out/dark-scrolled-after.png" -crop 300x100+1066+110 +repage -format '%#' info:)
[ "$top" != "$kept" ]

# The same at a big size: twice would ask more of this 900 px screen than the
# panel has to give, with all that's on it now.
printf '{"scale":1.75}' >"$XDG_CONFIG_HOME/okaeri/theme.json"
sleep 0.6
shot dark-scale
[ "$(magick "$out/dark-scale.png" -crop 760x4+620+896 +repage -format '%k' info:)" = 1 ]

# In the light theme.
printf '{"extends":"light"}' >"$XDG_CONFIG_HOME/okaeri/theme.json"
sleep 0.6
shot light-crowd

# The row at the bottom is cut; the list makes room for its field.
never 'dry: wifi connect' at $row_x $(($(row 8) - 5))
sleep 0.3
shot light-crowd-field
toggle
ipc probe reset
page wifi
sleep 0.3
shot light-wifi
# One that hides its name, under the rest: asked for by its name and its password,
# neither of which gets to the log.
at 1125 351
sleep 0.3
type 'Quiet'
key Return
type 'hunter22'
when 'dry: wifi connect hidden' key Return
sleep 0.3
at $row_x "$(row 2)"
ipc probe fail Office 5
sleep 0.4
shot light-password
key Escape
page bluetooth
shot light-bluetooth
toggle

# Nothing around yet.
ipc probe nothing
page bluetooth
shot light-empty-bluetooth
page wifi
shot light-empty-wifi
toggle
ipc probe reset

# Square corners, and no animations at all.
printf '{"radius":0,"animations":false}' >"$XDG_CONFIG_HOME/okaeri/theme.json"
sleep 0.6
when 'dry: wifi scan true' ipc control page wifi
sleep 0.2
at $row_x "$(row 2)"
sleep 0.2
shot dark-square
key Escape
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

# What apps play, on a stand-in: the machine's own come and go.
sed -e 's/^\tproperty var nodes: .*/\tproperty var nodes: [{ audio: { volume: 0.5 }, name: "x", properties: { "application.name": ".Player-wrapped" } }]/' \
	-e 's/^\tproperty var outputs: \[\]$/\tproperty var outputs: [{ description: "Speakers", nickname: "Built in", name: "alsa_output.one" }, { description: "Headphones", nickname: "Jack", name: "alsa_output.two" }]/' \
	-e 's/^\tproperty var inputs: \[\]$/\tproperty var inputs: [{ description: "Microphone", nickname: "Built in", name: "alsa_input.one" }, { description: "Headset", nickname: "USB", name: "alsa_input.two" }]/' \
	-e 's/^\tproperty bool micReady: false$/\tproperty bool micReady: true/' \
	-e 's/^\treadonly property real micVolume: .*/\tproperty real micVolume: 0.7/' \
	-e 's/^\treadonly property bool micMuted: .*/\tproperty bool micMuted: false/' \
	"$work/shell/services/Audio.qml" >"$work/Audio.qml"
grep -q 'Player-wrapped' "$work/Audio.qml"
reloads=$(seen "Reloading configuration")
cat "$work/Audio.qml" >"$work/shell/services/Audio.qml"
for _ in $(seq 50); do
	[ "$(seen "Reloading configuration")" -gt "$reloads" ] && break
	sleep 0.1
done
sleep 1
toggle
sleep 0.4
shot app-volume
# The microphone's level under the brightness, with its mute.
mic_y=189
when 'dry: mic volume' at $((slider_left + slider_width / 2)) $mic_y
when 'dry: mic mute' at $mute_x $mic_y
# The sound's page: two outputs, a click on one moves the sound there, and what
# plays, muted from there.
at $sound_x $volume_y
sleep 0.4
shot outputs
when 'dry: output' at 1200 183
when 'dry: app volume' at 1218 263
when 'dry: app mute true' at $mute_x 263
shot playback
at $back_x $page_y
sleep 0.3
# The microphone's page: two microphones, the same way.
at $sound_x $mic_y
sleep 0.4
shot inputs
when 'dry: input' at 1200 157
toggle

# A GPU's output goes by whether that GPU has a screen, and others aren't asked.
hdmi=alsa_output.pci-0000_01_00.1.hdmi-stereo
[ "$(ipc probe reaches "$hdmi" 0000:06:00)" = false ] || fail "an output with no screen"
[ "$(ipc probe reaches "$hdmi" 0000:06:00,0000:01:00)" = true ] || fail "no output with a screen"
[ "$(ipc probe reaches alsa_output.pci-0000_06_00.6.analog-stereo none)" = true ] || fail "no speakers"
[ "$(ipc probe reaches bluez_output.AA_BB.1 none)" = true ] || fail "no headphones"

# What the settings leave out isn't there, and comes back.
toggle
sleep 0.5
shot all-sections
printf '{ "control": { "hidden": ["wifi", "bluetooth", "power", "awake"] } }\n' >"$XDG_CONFIG_HOME/okaeri/settings.json"
sleep 0.7
shot few-sections
[ "$(magick compare -metric AE "$out/all-sections.png" "$out/few-sections.png" null: 2>&1 | cut -d' ' -f1)" != 0 ] || fail "the settings left nothing out"
printf '{}\n' >"$XDG_CONFIG_HOME/okaeri/settings.json"
sleep 0.7
key Escape
sleep 0.4

# External monitors: one on a GPU that's awake, which gets a slider, and one on a
# GPU that sleeps, which isn't asked, as asking would wake it.
for card in 1 2; do
	mkdir -p "$work/drm/card$card/device/power" "$work/drm/card$card-DP-$card"
	echo connected >"$work/drm/card$card-DP-$card/status"
	ln -s "../../i2c-$((card + 6))" "$work/drm/card$card-DP-$card/ddc"
done
echo active >"$work/drm/card1/device/power/runtime_status"
echo suspended >"$work/drm/card2/device/power/runtime_status"
printf '{ "display": { "ddc": true } }\n' >"$XDG_CONFIG_HOME/okaeri/settings.json"
for _ in $(seq 30); do
	grep -q 'getvcp' "$work/ddcutil.log" 2>/dev/null && break
	sleep 0.1
done
grep -qF -- '--bus 7 --brief getvcp 10' "$work/ddcutil.log" || fail "the monitor wasn't asked: $(cat "$work/ddcutil.log" 2>/dev/null)"
! grep -qF -- '--bus 8' "$work/ddcutil.log" || fail "a monitor on a sleeping GPU was asked"
toggle
sleep 0.4
shot ddc
# Its slider, under the brightness: what it's moved to goes out once it rests.
when 'dry: ddc DP-1' at 1200 202
key Escape
sleep 0.4

# What was asked for says what, and nothing else: no names, no password.
if log | grep 'dry:' | sed 's/.*dry: //' | grep -vxE 'sound [a-z-]+|wifi forget|bluetooth forget|output|input|ddc DP-1 [0-9]+|night light -t [0-9]+ -T [0-9]+|app volume [0-9.]+|app mute (true|false)|mic volume [0-9.]+|mic mute (true|false)|power profile [A-Za-z]+|volume [0-9.]+|mute (true|false)|brightness [0-9]+|wifi (true|false|connect|connect hidden|connect with a key|disconnect|scan true|scan false)|vpn (up|down)|record start screen none|tile run|bluetooth (true|false|connect|pair|pairable true|pairable false|agent|answer (confirm|accept) (yes|no)|answer (pin|passkey)|trust and connect|disconnect|discovery true|discovery false)'; then
	echo "control: something else in what was asked for" >&2
	exit 1
fi
if log | grep hunter2; then
	echo "control: the password got into the log" >&2
	exit 1
fi
