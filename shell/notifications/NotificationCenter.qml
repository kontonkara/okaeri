import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import qs.services

// The notification server and all that's shown for it. Body markup stays off:
// what an app sends is shown as plain text, and it can't load anything.
Scope {
	LazyLoader {
		id: server

		active: !Env.guest

		NotificationServer {
			actionsSupported: true
			imageSupported: true
			persistenceSupported: true
			inlineReplySupported: true
			onNotification: notification => NotificationStore.receive(notification)
		}
	}

	Binding {
		target: NotificationStore
		property: "server"
		value: server.item
	}

	Binding {
		target: NotificationStore
		property: "panel"
		value: history
	}

	BatteryWarning {}

	Toasts {}

	History {
		id: history
	}

	IpcHandler {
		target: "notifications"

		function toggle(): void {
			NotificationStore.togglePanel();
		}

		function clear(): void {
			NotificationStore.clear();
		}

		// The newest toast, for a key.
		function dismiss(): void {
			NotificationStore.dismissLast();
		}

		function dndFor(seconds: int): void {
			NotificationStore.dndFor(seconds);
		}

		function dnd(on: bool): void {
			NotificationStore.setDnd(on, 0);
		}

		// No toasts from `app` for so long, 0 for no longer.
		function quiet(app: string, seconds: int): void {
			NotificationStore.setQuiet(app, seconds > 0 ? Date.now() + seconds * 1000 : 0);
		}

		// For tests and scripts.
		function state(): string {
			return JSON.stringify({
				history: NotificationStore.history.length,
				toasts: NotificationStore.toasts.length,
				unread: NotificationStore.unread,
				dnd: NotificationStore.dnd,
				quiet: Object.keys(NotificationStore.quietApps).sort(),
				panel: NotificationStore.panelShown,
				order: NotificationStore.grouped.map(n => n.appName),
				shown: NotificationStore.shown.length,
				repeats: NotificationStore.history.map(n => NotificationStore.repeatsOf(n)),
				when: NotificationStore.history.map(n => NotificationStore.when(n))
			});
		}
	}
}
