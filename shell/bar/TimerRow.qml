import QtQuick
import qs
import qs.services
import qs.ui

// A timer and a stopwatch, in the clock's card: a timer by one of a few
// lengths, or what's left of the one that runs and a way to stop it; the
// stopwatch beside pomodoros starts and stands by a click, and a right click
// has it at nothing again. `okaeri timer start 10m` and the launcher's /timer
// take any length. Pomodoros go from there too, or by `okaeri pomodoro start`.
// Two rows as wide as the card, each button an even share of one: as wide as
// the calendar above, in any language, and none of them on half a pixel.
Column {
	id: row

	readonly property real gap: Math.round(Theme.u(6))

	// An even number of whole pixels, `count` of them to a row.
	function share(count) {
		return Math.floor((width - gap * (count - 1)) / count / 2) * 2;
	}

	spacing: gap

	Row {
		spacing: row.gap

		Repeater {
			model: Timers.counting ? [] : [5, 10, 25]

			Button {
				required property int modelData

				width: row.share(3)
				height: Theme.u(28)
				flat: true
				longest: width - pad * 2
				text: Tr.f("%1 min", modelData)
				tip: Tr.t("A timer that long")
				onClicked: Timers.start(modelData * 60, "")
			}
		}

		Button {
			visible: Timers.counting
			width: row.share(1)
			height: Theme.u(28)
			icon: "close"
			longest: width - pad * 2 - Theme.u(24)
			text: [Timers.clock(Timers.left), Timers.label, Timers.phase ? `${(Timers.rounds - (Timers.phase === "work" ? 0 : 1)) % Math.max(1, Settings.pomodoro.rounds) + 1} of ${Settings.pomodoro.rounds}` : ""].filter(part => part !== "").join(" · ")
			tip: Timers.phase ? Tr.t("Stop the pomodoros") : Tr.t("Stop the timer")
			onClicked: Timers.stop()
		}
	}

	Row {
		spacing: row.gap

		Button {
			visible: !Timers.counting
			width: row.share(2)
			height: Theme.u(28)
			flat: true
			longest: width - pad * 2
			text: Tr.t("Pomodoro")
			tip: Tr.f("%1 min of work, then a break, and again", Settings.pomodoro.work)
			onClicked: Timers.startPomodoro()
		}

		Button {
			width: Timers.counting ? row.share(1) : row.share(2)
			height: Theme.u(28)
			flat: !Timers.watching && Timers.watched === 0
			icon: Timers.watching ? "pause" : "play"
			longest: width - pad * 2 - Theme.u(24)
			text: Timers.watching || Timers.watched > 0 ? Timers.clock(Timers.watched) : Tr.t("Stopwatch")
			tip: Timers.watching ? Tr.t("Stand · a right click starts over") : Timers.watched > 0 ? Tr.t("Go on · a right click starts over") : Tr.t("Start the stopwatch")
			onClicked: Timers.toggleWatch()
			onRightClicked: Timers.resetWatch()
		}
	}
}
