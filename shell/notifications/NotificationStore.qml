pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import qs
import qs.services

// What the server holds and what's shown of it: the history, the toasts, how
// many are unread, Do Not Disturb and the apps kept quiet for a while.
// NotificationCenter gives it `server` and `panel`; next to another shell there's
// no server and it all stays empty. The history is kept over a restart, in a
// directory only the user can read.
// Settings.notifications.rules say what's done with some: { app, text, toast,
// history, sound, bypass, timeout }, app being its name or desktop entry, in any
// case, and all if left out, text words it has to have, or between slashes a
// pattern for them, and the others what's different for it: false to not show or
// sound, bypass to go through Do Not Disturb, timeout in seconds, 0 to stay.
Singleton {
	id: store

	property var server: null
	property var panel: null
	property alias dnd: kept.dnd
	// When Do Not Disturb ends by itself, 0 for never.
	property alias dndUntil: kept.dndUntil
	readonly property alias dndLabel: timer.label
	// The apps kept quiet for a while, as Do Not Disturb keeps them all: when
	// that's over for each, by its name.
	readonly property var quietApps: JSON.parse(kept.quiet)

	// How many toasts show, and how many the history holds: past that the oldest go.
	readonly property int cap: Settings.notifications.cap
	readonly property int historyCap: Settings.notifications.history

	// While clear() works: all of this goes over the list once, not once for
	// each that's closed.
	property bool clearing: false

	// What the file had, once it's read: { id, appName, ... }, and those of it that
	// weren't still with the server, as PastNotification, newest first.
	property var fromFile: null
	property var past: []
	property bool restored: false

	readonly property string folder: `${Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state"}/okaeri/notifications`

	// Newest first.
	readonly property var all: server && !clearing ? server.trackedNotifications.values.slice().reverse().concat(past) : []
	// What's for the moment isn't for later.
	readonly property var history: all.filter(n => !fleeting(n))

	// The history by app, the one heard from last first, for the panel.
	readonly property var apps: [...new Set(history.map(n => n.appName))]
	readonly property var grouped: apps.reduce((all, app) => all.concat(history.filter(n => n.appName === app)), [])
	// Each app shows its newest, but for those opened here.
	property var opened: []
	readonly property var shown: apps.reduce((all, app) => {
		const own = history.filter(n => n.appName === app);
		return all.concat(opened.includes(app) ? own : own.slice(0, 1));
	}, [])
	// With one alone a heading would only say what its card does.
	readonly property bool headed: history.length > 1

	property var toastIds: []
	readonly property var up: all.filter(n => toastIds.includes(n.id))
	readonly property bool panelShown: !!panel && panel.shown
	// The panel shows it all, in the same corner.
	readonly property var toasts: panelShown ? [] : up.slice(0, cap)

	// Ids only grow: what's past this one wasn't looked at yet.
	property alias seenId: kept.seenId
	// When each came in, and how many alike it stands for, by id. A reload loses
	// these: objects don't go through it, and only a test ever reloads.
	property var times: ({})
	property var repeats: ({})
	// The screen's going out to someone.
	readonly property bool sharing: Settings.notifications.quietSharing && Niri.casts.length > 0
	readonly property int unread: panelShown ? 0 : history.filter(n => isUnread(n)).length

	onUpChanged: Qt.callLater(trim)
	onHistoryChanged: saving.restart()
	onUnreadChanged: saving.restart()
	onServerChanged: restore()

	onPanelShownChanged: {
		if (panelShown) {
			takeDown(n => !critical(n));
			past.forEach(n => n.unread = false);
		} else if (all.length) {
			seenId = all[0].id;
		}
	}

	onDndChanged: {
		if (dnd)
			takeDown(n => !critical(n));
	}

	onSharingChanged: {
		if (sharing)
			takeDown(n => !critical(n));
	}

	// Whether `words` say what a rule's `text` asks: have it, in any case, or,
	// with it between slashes, match that pattern.
	function says(words, text) {
		const pattern = /^\/(.+)\/$/.exec(text);
		if (!pattern)
			return words.toLowerCase().includes(text.toLowerCase());
		try {
			return new RegExp(pattern[1], "i").test(words);
		} catch (error) {
			// No pattern at all: it fits nothing.
			return false;
		}
	}

	// The first rule for this one, or none.
	function rule(notification) {
		const names = [notification.appName, notification.desktopEntry].map(name => (name || "").toLowerCase());
		const words = `${notification.summary} ${notification.body}`;
		return Settings.notifications.rules.find(rule => (!rule.app || names.includes(rule.app.toLowerCase())) && (!rule.text || says(words, rule.text))) ?? {};
	}

	// When it came in, in ms, 0 if that isn't known.
	function timeOf(notification) {
		return notification.isPast ? notification.time : times[notification.id] ?? 0;
	}

	function repeatsOf(notification) {
		return notification.isPast ? notification.repeats : repeats[notification.id] ?? 1;
	}

	// How long ago, or when, for a card: it goes on as the clock does.
	function when(notification) {
		const time = timeOf(notification);
		if (!time)
			return "";
		const minutes = Math.floor((clock.date.getTime() - time) / 60000);
		if (minutes < 1)
			return "now";
		if (minutes < 60)
			return `${minutes} min ago`;
		const date = new Date(time);
		return Qt.formatDateTime(date, date.toDateString() === clock.date.toDateString() ? "HH:mm" : "d MMM HH:mm");
	}

	// One alike in the history, for this one to take the place of.
	function twinOf(notification) {
		if (!Settings.notifications.stack)
			return null;
		return history.find(n => n.appName === notification.appName && n.summary === notification.summary && n.body === notification.body) ?? null;
	}

	function tooOld(time) {
		const days = Settings.notifications.maxAge;
		return days > 0 && time > 0 && Date.now() - time > days * 86400000;
	}

	function isUnread(notification) {
		return notification.isPast ? notification.unread : notification.id > seenId;
	}

	// For the moment, not for later.
	function fleeting(notification) {
		return notification.transient || rule(notification).history === false;
	}

	function critical(notification) {
		return notification.urgency === NotificationUrgency.Critical;
	}

	// Over the cap the oldest make room; critical ones wait for it instead. A
	// toast that's still up stays in the history too.
	function trim() {
		const others = up.filter(n => !critical(n));
		const room = Math.max(0, cap - (up.length - others.length));
		if (others.length > room)
			takeDown(n => others.indexOf(n) >= room);
		history.filter((n, index) => (index >= historyCap || tooOld(timeOf(n))) && !up.includes(n)).forEach(n => n.expire());
	}

	// Toasts keep quiet, for now.
	function quiet(notification) {
		const own = rule(notification);
		return !critical(notification) && (panelShown || own.toast === false || !!quietApps[notification.appName] || ((dnd || sharing) && !own.bypass));
	}

	function receive(notification) {
		// A replaced one doesn't come in again, it only changes: back up it goes.
		// Urgency comes after the words, and the same words from a new process
		// only change the hints. From the same process nothing changes at all,
		// so that one can't show again.
		const changes = [notification.summaryChanged, notification.bodyChanged, notification.urgencyChanged, notification.hintsChanged];
		changes.forEach(changed => changed.connect(() => {
			show(notification);
			saving.restart();
		}));
		if (!notification.lastGeneration) {
			times = Object.assign({}, times, { [notification.id]: Date.now() });
			// The same again takes the place of what's there, and counts it.
			const twin = twinOf(notification);
			if (twin) {
				repeats = Object.assign({}, repeats, { [notification.id]: repeatsOf(twin) + 1 });
				twin.dismiss();
			}
		}
		// From before a reload it had its toast, and only a critical one still has.
		const shows = !quiet(notification) && (!notification.lastGeneration || critical(notification));
		// Only in the server's list after this returns. A transient one that
		// won't show has no reason to get there.
		notification.tracked = shows || !fleeting(notification);
		if (shows) {
			show(notification);
			if (!notification.lastGeneration)
				ring(notification);
		}
	}

	// niri only says something for a screenshot.
	function ring(notification) {
		if (notification.appName === "niri") {
			if (Settings.sounds.screenshots)
				Sounds.play("screen-capture");
		} else if (Settings.sounds.notifications && notification.urgency !== NotificationUrgency.Low && rule(notification).sound !== false) {
			Sounds.play(critical(notification) ? "dialog-warning" : "message-new-instant");
		}
	}

	function show(notification) {
		if (!quiet(notification) && !toastIds.includes(notification.id))
			toastIds = [notification.id].concat(up.map(n => n.id));
	}

	// Takes down the toasts `gone` picks. They stay in the history, but a
	// transient one has nowhere else to be.
	function takeDown(gone) {
		const leaving = up.filter(gone);
		toastIds = toastIds.filter(id => !leaving.some(n => n.id === id));
		leaving.filter(fleeting).forEach(n => n.expire());
	}

	// How long a toast stays, in ms; 0 is until it's closed.
	function lifetime(notification) {
		const own = rule(notification).timeout;
		if (own !== undefined)
			return own * 1000;
		if (critical(notification))
			return Settings.notifications.timeoutCritical * 1000;
		if (Settings.notifications.appsDecide && notification.expireTimeout >= 0)
			return notification.expireTimeout;
		return (notification.urgency === NotificationUrgency.Low ? Settings.notifications.timeoutLow : Settings.notifications.timeout) * 1000;
	}

	// What it says, on the clipboard.
	function copy(notification) {
		const text = [notification.summary, notification.body].filter(part => part !== "").join("\n");
		Env.act("notification copy", () => Quickshell.execDetached(["wl-copy", "--", text]));
	}

	function reply(notification, text) {
		Env.act("notification reply", () => notification.sendInlineReply(text));
	}

	// The newest toast, for a key.
	function dismissLast() {
		toasts[0]?.dismiss();
	}

	function invoke(notification, action) {
		Env.act(`notification action ${action.identifier}`, () => action.invoke());
		if (panel)
			panel.hide();
	}

	// To where it came from: its default action, or else its app's window, and it's
	// done with then.
	function activate(notification) {
		const action = notification.actions.find(a => a.identifier === "default");
		if (action) {
			invoke(notification, action);
			return;
		}
		const names = [notification.desktopEntry, notification.appName];
		Env.act(`notification focus ${names.filter(name => !!name).join(" ")}`, () => Niri.focusApp(names));
		notification.dismiss();
		if (panel)
			panel.hide();
	}

	// The file it came with, in what opens such files, and it's done with then.
	function open(notification, file) {
		Env.act(`notification open ${file}`, () => Niri.spawn(["xdg-open", file]));
		notification.dismiss();
		if (panel)
			panel.hide();
	}

	function clear() {
		const gone = all;
		clearing = true;
		gone.forEach(n => n.dismiss());
		clearing = false;
	}

	// One that's over, from the toasts and the history alike.
	function withdraw(id) {
		all.find(n => n.id === id)?.dismiss();
	}

	// A past one, closed. It stays as an object: a card may be leaving with it.
	function forget(notification) {
		past = past.filter(other => other !== notification);
		notification.closed();
	}

	// The file's, once there's both that and a server to tell what a reload left of it.
	function restore() {
		if (!server || !fromFile || restored)
			return;
		restored = true;
		if (!Settings.notifications.keep)
			return;
		const live = server.trackedNotifications.values;
		past = fromFile.filter(saved => !tooOld(saved.time ?? 0) && !live.some(n => n.id === saved.id && n.summary === saved.summary)).slice(0, historyCap).map((saved, index) => pastKind.createObject(store, Object.assign({}, saved, { id: -index - 1 })));
	}

	// A picture that came as data has no name to go by afterwards.
	function save() {
		if (!restored)
			return;
		keptFile.setText(JSON.stringify(!Settings.notifications.keep ? [] : history.map(n => ({
			id: n.id,
			appName: n.appName,
			desktopEntry: n.desktopEntry,
			summary: n.summary,
			body: n.body,
			image: n.image.startsWith("image://qs") ? "" : n.image,
			appIcon: n.appIcon,
			urgency: n.urgency,
			unread: isUnread(n),
			time: timeOf(n),
			repeats: repeatsOf(n)
		}))));
	}

	function toggleApp(app) {
		opened = opened.includes(app) ? opened.filter(other => other !== app) : opened.concat([app]);
	}

	// How many it has in the history.
	function countOf(app) {
		return history.filter(n => n.appName === app).length;
	}

	function clearApp(app) {
		const gone = history.filter(n => n.appName === app);
		clearing = true;
		gone.forEach(n => n.dismiss());
		clearing = false;
	}

	// `notches` of the wheel on: half an hour each, and off at nothing left.
	function stepDnd(notches) {
		const end = timer.stepped(notches);
		setDnd(end > 0, end);
	}

	// For scripts: `seconds` from now.
	function dndFor(seconds) {
		setDnd(true, timer.after(seconds));
	}

	function setDnd(wanted, end) {
		dnd = wanted;
		dndUntil = wanted ? end : 0;
	}

	// `app` keeps quiet until `end`, or no longer with 0: what it has up goes.
	function setQuiet(app, end) {
		const next = Object.assign({}, quietApps);
		if (end > 0)
			next[app] = end;
		else
			delete next[app];
		kept.quiet = JSON.stringify(next);
		quieting.now = Date.now();
		if (end > 0)
			takeDown(n => n.appName === app && !critical(n));
	}

	// For an hour, or no longer if it is.
	function toggleQuiet(app) {
		setQuiet(app, quietApps[app] ? 0 : Date.now() + 3600000);
	}

	// How long `app` still keeps quiet, in words, "" if it doesn't.
	function quietLabel(app) {
		const end = quietApps[app] ?? 0;
		return end > 0 ? `${Power.span(Math.max(0, end - quieting.now) / 1000)} · until ${Qt.formatDateTime(new Date(end), "HH:mm")}` : "";
	}

	function togglePanel() {
		if (panel)
			panel.toggle();
	}

	SystemClock {
		id: clock

		precision: SystemClock.Minutes
		onDateChanged: Qt.callLater(store.trim)
	}

	Component {
		id: pastKind

		PastNotification {}
	}

	// Not with each one of a burst.
	Timer {
		id: saving

		interval: 500
		onTriggered: store.save()
	}

	// Turned off, what's there goes.
	Connections {
		target: Settings

		function onNotificationsChanged() {
			saving.restart();
		}
	}

	// What people wrote: only the user gets to read it.
	Process {
		running: !Env.guest
		command: ["mkdir", "-p", "-m", "700", store.folder]
		onExited: keptFile.path = `${store.folder}/history.json`
	}

	FileView {
		id: keptFile

		printErrors: false
		onLoaded: {
			store.fromFile = Theme.parse(text() || "[]", path);
			store.restore();
		}
		onLoadFailed: {
			store.fromFile = [];
			store.restore();
		}
	}

	Expiry {
		id: timer

		until: store.dndUntil
		onOver: store.setDnd(false, 0)
	}

	// Each second while an app keeps quiet, as a sleep would stop a long timer:
	// those whose time is over are let go.
	Timer {
		id: quieting

		property double now: Date.now()

		interval: 1000
		repeat: true
		running: Object.keys(store.quietApps).length > 0
		onTriggered: {
			now = Date.now();
			Object.keys(store.quietApps).filter(app => store.quietApps[app] <= now).forEach(app => store.setQuiet(app, 0));
		}
	}

	// What a reload leaves as it was.
	PersistentProperties {
		id: kept

		property bool dnd: false
		property double dndUntil: 0
		property int seenId: 0
		// As text: an object doesn't go through a reload.
		property string quiet: "{}"

		reloadableId: "notifications"
	}
}
