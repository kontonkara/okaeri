pragma Singleton

import QtQuick
import Quickshell

// What the panels tell each other.
Singleton {
	// `panel` came up: what's in the same place makes way for it.
	signal opened(var panel)
}
