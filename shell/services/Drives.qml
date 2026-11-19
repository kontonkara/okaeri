pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs

// The drives one plugs in: the filesystems UDisks2 has that aren't the system's,
// each with what it's called, how large it is and where it's mounted, read as
// udisksctl says something changed. One that comes says so in a notification,
// with Settings.drives.notify, to open or eject it there, and is mounted at once
// with Settings.drives.automount. Mounting, opening and ejecting go through
// udisksctl, as the one who's logged in may, with no password asked for.
Singleton {
	id: drives

	// For the lists, and what does it: a test has its own of each.
	readonly property string reader: "busctl"
	readonly property string tool: "udisksctl"
	// { object, device, label, kind, size, mount, drive, name, ejectable }, by
	// their devices.
	property var list: []
	property bool read: false
	// What the last try said, if it failed, and of which.
	property string failure
	property string failedOn

	// One that wasn't there at the last look; not those there as the shell starts.
	signal arrived(var drive)

	// What a drive says of itself in a notification, or on its row: its label, or
	// the drive's name, and how large.
	function nameOf(drive) {
		return drive.label || drive.name || drive.device.replace(/^\/dev\//, "");
	}

	function sizeOf(bytes) {
		return bytes >= 1e12 ? `${(bytes / 1e12).toFixed(1)} TB` : bytes >= 1e9 ? `${(bytes / 1e9).toFixed(1)} GB` : `${Math.max(1, Math.round(bytes / 1e6))} MB`;
	}

	// A byte string of UDisks2's, as busctl prints it, without its end.
	function text(value) {
		const bytes = (value?.data ?? []).filter(byte => byte !== 0);
		try {
			return decodeURIComponent(bytes.map(byte => "%" + byte.toString(16).padStart(2, "0")).join(""));
		} catch (error) {
			return String.fromCharCode(...bytes);
		}
	}

	// From what GetManagedObjects says, as busctl prints it.
	function readObjects(said) {
		let all = null;
		try {
			all = JSON.parse(said).data[0];
		} catch (error) {
			return;
		}
		const found = [];
		for (const object of Object.keys(all)) {
			const block = all[object]["org.freedesktop.UDisks2.Block"];
			const filesystem = all[object]["org.freedesktop.UDisks2.Filesystem"];
			if (!block || !filesystem || block.HintSystem?.data || block.HintIgnore?.data)
				continue;
			const drive = block.Drive?.data ?? "/";
			const about = all[drive]?.["org.freedesktop.UDisks2.Drive"] ?? {};
			found.push({
				object,
				device: text(block.Device),
				label: block.IdLabel?.data ?? "",
				kind: block.IdType?.data ?? "",
				size: Number(block.Size?.data ?? 0),
				mount: (filesystem.MountPoints?.data ?? []).map(point => text({ data: point }))[0] ?? "",
				drive,
				name: [about.Vendor?.data, about.Model?.data].filter(part => !!part).join(" ").trim(),
				ejectable: !!(about.Ejectable?.data || about.CanPowerOff?.data)
			});
		}
		found.sort((a, b) => a.device.localeCompare(b.device));
		const before = list;
		list = found;
		if (read)
			found.filter(drive => !before.some(other => other.object === drive.object)).forEach(drive => arrived(drive));
		read = true;
	}

	function look() {
		looking.running = true;
	}

	// Mounted, and then its folder opened with `opens`.
	function mount(drive, opens) {
		failure = "";
		Env.act(`drive mount ${drive.device}`, () => {
			mounting.opens = !!opens;
			mounting.failedOn = drive.object;
			mounting.exec([tool, "mount", "-b", drive.device, "--no-user-interaction"]);
		});
	}

	// Its folder, mounted first where it isn't.
	function open(drive) {
		if (!drive.mount)
			mount(drive, true);
		else
			Env.act(`drive open ${drive.device}`, () => Quickshell.execDetached(["xdg-open", drive.mount]));
	}

	function unmount(drive) {
		failure = "";
		Env.act(`drive unmount ${drive.device}`, () => {
			working.failedOn = drive.object;
			working.exec([tool, "unmount", "-b", drive.device, "--no-user-interaction"]);
		});
	}

	// Safe to pull out: all of the drive's filesystems unmounted, and it powered off.
	function eject(drive) {
		failure = "";
		const devices = list.filter(other => other.drive === drive.drive && other.mount).map(other => other.device);
		Env.act(`drive eject ${drive.device}`, () => {
			working.failedOn = drive.object;
			working.exec(["sh", "-c", 'tool=$1 drive=$2; shift 2; for device; do "$tool" unmount -b "$device" --no-user-interaction || exit; done; "$tool" power-off -p "$drive" --no-user-interaction', "sh", tool, drive.drive.replace("/org/freedesktop/UDisks2/", "")].concat(devices));
		});
	}

	function failed(object, said) {
		failedOn = object;
		failure = said.trim().split("\n").pop().replace(/^Error [^:]*: /, "").replace(/^GDBus\.Error:[^ ]* /, "") || "It didn't work";
	}

	// A notification, with a way to open it and one to eject it: only one waits for
	// an answer at a time, the next is said without.
	onArrived: drive => {
		if (Settings.drives.automount && !drive.mount)
			mount(drive, false);
		if (!Settings.drives.notify)
			return;
		Env.act(`drive arrived ${drive.device}`, () => {
			const words = ["notify-send", "--app-name=okaeri", "--icon=drive-removable-media", nameOf(drive), [drive.name, sizeOf(drive.size)].filter(part => !!part).join(" · ")];
			if (asking.running) {
				Quickshell.execDetached(words);
				return;
			}
			asking.drive = drive.object;
			asking.exec(words.slice(0, 3).concat(drive.ejectable ? ["--action=open=Open", "--action=eject=Eject"] : ["--action=open=Open"], words.slice(3)));
		});
	}

	Component.onCompleted: look()

	Process {
		id: looking

		command: [drives.reader, "--system", "--json=short", "call", "org.freedesktop.UDisks2", "/org/freedesktop/UDisks2", "org.freedesktop.DBus.ObjectManager", "GetManagedObjects"]
		stdout: StdioCollector {
			onStreamFinished: drives.readObjects(text)
		}
	}

	// Each line past its first is a change: a look a moment after the last of them.
	Process {
		running: true
		// It goes with the shell, however that ends.
		command: ["setpriv", "--pdeathsig", "TERM", drives.tool, "monitor"]
		stdout: SplitParser {
			onRead: again.restart()
		}
	}

	Timer {
		id: again

		interval: 400
		onTriggered: drives.look()
	}

	Process {
		id: mounting

		property bool opens: false
		property string failedOn

		stdout: StdioCollector {
			id: mounted
		}
		stderr: StdioCollector {
			id: mountSaid
		}
		onExited: code => {
			if (code !== 0) {
				drives.failed(failedOn, mountSaid.text);
				return;
			}
			const where = mounted.text.match(/ at (.+?)\.?\s*$/);
			if (opens && where)
				Quickshell.execDetached(["xdg-open", where[1]]);
			drives.look();
		}
	}

	Process {
		id: working

		property string failedOn

		stderr: StdioCollector {
			id: workSaid
		}
		onExited: code => {
			if (code !== 0)
				drives.failed(failedOn, workSaid.text);
			drives.look();
		}
	}

	// The notification of one that came, and what was picked on it.
	Process {
		id: asking

		property string drive

		stdout: StdioCollector {
			onStreamFinished: {
				const picked = drives.list.find(one => one.object === asking.drive);
				if (!picked)
					return;
				if (text.trim() === "open")
					drives.open(picked);
				else if (text.trim() === "eject")
					drives.eject(picked);
			}
		}
	}

	// `okaeri drives list` says what there is, as JSON; mount, open, unmount and
	// eject take a device, /dev/sdb1.
	IpcHandler {
		target: "drives"

		function list(): string {
			return JSON.stringify(drives.list.map(drive => ({ device: drive.device, label: drive.label, size: drive.size, mount: drive.mount, ejectable: drive.ejectable })));
		}

		function mount(device: string): void {
			const drive = drives.list.find(one => one.device === device);
			if (drive)
				drives.mount(drive, false);
		}

		function open(device: string): void {
			const drive = drives.list.find(one => one.device === device);
			if (drive)
				drives.open(drive);
		}

		function unmount(device: string): void {
			const drive = drives.list.find(one => one.device === device);
			if (drive)
				drives.unmount(drive);
		}

		function eject(device: string): void {
			const drive = drives.list.find(one => one.device === device);
			if (drive)
				drives.eject(drive);
		}
	}
}
