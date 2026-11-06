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

		function dnd(on: bool): void {
			NotificationStore.dnd = on;
		}

		// For tests and scripts.
		function state(): string {
			return JSON.stringify({
				history: NotificationStore.history.length,
				toasts: NotificationStore.toasts.length,
				unread: NotificationStore.unread,
				dnd: NotificationStore.dnd,
				panel: NotificationStore.panelShown,
				order: NotificationStore.grouped.map(n => n.appName),
				shown: NotificationStore.shown.length
			});
		}
	}
}
