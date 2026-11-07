pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import qs
import qs.services

// What the server holds and what's shown of it: the history, the toasts, how
// many are unread and Do Not Disturb. NotificationCenter gives it `server` and
// `panel`; next to another shell there's no server and it all stays empty.
// Settings.notifications.rules hold back an app's: { app, toast, history }, app
// being its name or desktop entry, in any case, and the others false to not show.
Singleton {
	id: store

	property var server: null
	property var panel: null
	property alias dnd: kept.dnd
	// When Do Not Disturb ends by itself, 0 for never.
	property alias dndUntil: kept.dndUntil
	readonly property alias dndLabel: timer.label

	// How many toasts show, how long one stays when its app doesn't say, and
	// how many the history holds: past that the oldest go.
	readonly property int cap: 4
	readonly property int defaultTimeout: 6000
	readonly property int historyCap: 100

	// While clear() works: all of this goes over the list once, not once for
	// each that's closed.
	property bool clearing: false

	// Newest first.
	readonly property var all: server && !clearing ? server.trackedNotifications.values.slice().reverse() : []
	// What's for the moment isn't for later.
	readonly property var history: all.filter(n => !fleeting(n))

	// The history by app, the one heard from last first, for the panel.
	readonly property var apps: [...new Set(history.map(n => n.appName))]
	readonly property var grouped: apps.reduce((all, app) => all.concat(history.filter(n => n.appName === app)), [])
	// With several apps each shows its newest, but for those opened here.
	property var opened: []
	readonly property var shown: apps.length < 2 ? grouped : apps.reduce((all, app) => {
		const own = history.filter(n => n.appName === app);
		return all.concat(opened.includes(app) ? own : own.slice(0, 1));
	}, [])

	property var toastIds: []
	readonly property var up: all.filter(n => toastIds.includes(n.id))
	readonly property bool panelShown: !!panel && panel.shown
	// The panel shows it all, in the same corner.
	readonly property var toasts: panelShown ? [] : up.slice(0, cap)

	// Ids only grow: what's past this one wasn't looked at yet.
	property alias seenId: kept.seenId
	readonly property int unread: panelShown ? 0 : history.filter(n => n.id > seenId).length

	onUpChanged: Qt.callLater(trim)

	onPanelShownChanged: {
		if (panelShown)
			takeDown(n => !critical(n));
		else if (all.length)
			seenId = all[0].id;
	}

	onDndChanged: {
		if (dnd)
			takeDown(n => !critical(n));
	}

	// The rule for this one's app, or none.
	function rule(notification) {
		const names = [notification.appName, notification.desktopEntry].map(name => (name || "").toLowerCase());
		return Settings.notifications.rules.find(rule => names.includes(rule.app.toLowerCase())) ?? {};
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
		history.slice(historyCap).filter(n => !up.includes(n)).forEach(n => n.expire());
	}

	// Toasts keep quiet, for now.
	function quiet(notification) {
		return !critical(notification) && (dnd || panelShown || rule(notification).toast === false);
	}

	function receive(notification) {
		// A replaced one doesn't come in again, it only changes: back up it goes.
		// Urgency comes after the words, and the same words from a new process
		// only change the hints. From the same process nothing changes at all,
		// so that one can't show again.
		const changes = [notification.summaryChanged, notification.bodyChanged, notification.urgencyChanged, notification.hintsChanged];
		changes.forEach(changed => changed.connect(() => show(notification)));
		// From before a reload it had its toast, and only a critical one still has.
		const shows = !quiet(notification) && (!notification.lastGeneration || critical(notification));
		// Only in the server's list after this returns. A transient one that
		// won't show has no reason to get there.
		notification.tracked = shows || !fleeting(notification);
		if (shows)
			show(notification);
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
		if (critical(notification))
			return 0;
		return notification.expireTimeout < 0 ? defaultTimeout : notification.expireTimeout;
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

	function togglePanel() {
		if (panel)
			panel.toggle();
	}

	Expiry {
		id: timer

		until: store.dndUntil
		onOver: store.setDnd(false, 0)
	}

	// What a reload leaves as it was.
	PersistentProperties {
		id: kept

		property bool dnd: false
		property double dndUntil: 0
		property int seenId: 0

		reloadableId: "notifications"
	}
}
