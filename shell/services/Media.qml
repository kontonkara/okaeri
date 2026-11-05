pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Mpris

// The player the media keys are for: the one playing, else the last that
// played, else the first there is.
Singleton {
	id: media

	readonly property var players: Mpris.players.values
	readonly property var playing: players.find(player => player.isPlaying) ?? null
	property var last: null
	readonly property var player: playing ?? (players.includes(last) ? last : players[0] ?? null)

	onPlayingChanged: {
		if (playing)
			last = playing;
	}

	function toggle() {
		if (player?.canTogglePlaying)
			Env.act(`media toggle ${player.dbusName}`, () => player.togglePlaying());
	}

	function stop() {
		if (player?.canControl)
			Env.act(`media stop ${player.dbusName}`, () => player.stop());
	}

	function previous() {
		if (player?.canGoPrevious)
			Env.act(`media previous ${player.dbusName}`, () => player.previous());
	}

	function next() {
		if (player?.canGoNext)
			Env.act(`media next ${player.dbusName}`, () => player.next());
	}
}
