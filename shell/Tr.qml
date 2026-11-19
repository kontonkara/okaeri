pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// okaeri's own words, written in English, in another language where shell/i18n
// has it: the one Settings.language.name picks, or else the locale's, as LANG
// says, with OKAERI_LANGUAGE before that, as a test has it. t() gives a word's
// own, and f() one with %1, %2 and so on in it, put in after.
Singleton {
	id: tr

	readonly property string wanted: Settings.language.name || Quickshell.env("OKAERI_LANGUAGE") || (Quickshell.env("LC_ALL") || Quickshell.env("LC_MESSAGES") || Quickshell.env("LANG") || "").slice(0, 2)
	property var words: ({})

	// The locale of that language, for the names of days and months, and date()
	// with it, in Qt's letters: the system's own where it's the system's language.
	readonly property var locale: wanted && wanted !== Qt.locale().name.slice(0, 2) ? Qt.locale(wanted) : Qt.locale()

	function date(when, format) {
		return (when instanceof Date ? when : new Date(when)).toLocaleString(locale, format);
	}

	function t(text) {
		return words[text] ?? text;
	}

	function f(text, ...values) {
		return values.reduce((all, value, at) => all.split(`%${at + 1}`).join(String(value)), t(text));
	}

	FileView {
		path: tr.wanted && tr.wanted !== "en" ? Quickshell.shellPath(`i18n/${tr.wanted}.json`) : ""
		printErrors: false
		onLoaded: {
			try {
				tr.words = JSON.parse(text());
			} catch (error) {
				tr.words = {};
			}
		}
		onLoadFailed: tr.words = {}
		onPathChanged: {
			if (!path)
				tr.words = {};
		}
	}
}
