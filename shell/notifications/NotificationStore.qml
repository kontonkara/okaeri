pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import qs.services

// What the server holds and what's shown of it: the history, the toasts, how
// many are unread and Do Not Disturb. NotificationCenter gives it `server` and
// `panel`; next to another shell there's no server and it all stays empty.
Singleton {
	id: store

	property var server: null
	property var panel: null
	property alias dnd: kept.dnd

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
	// A transient one is for the moment, not for later.
	readonly property var history: all.filter(n => !n.transient)

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
		return !critical(notification) && (dnd || panelShown);
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
		notification.tracked = shows || !notification.transient;
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
		leaving.filter(n => n.transient).forEach(n => n.expire());
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

	function clear() {
		const gone = all;
		clearing = true;
		gone.forEach(n => n.dismiss());
		clearing = false;
	}

	function togglePanel() {
		if (panel)
			panel.toggle();
	}

	// What a reload leaves as it was.
	PersistentProperties {
		id: kept

		property bool dnd: false
		property int seenId: 0

		reloadableId: "notifications"
	}
}
