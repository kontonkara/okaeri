pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Mpris
import qs

// The player the media keys, the bar and its card are for: the one picked,
// until another starts playing, else the one playing, else the last that
// played, else the first there is. Those Settings.media.ignored names are left
// out of it all.
Singleton {
	id: media

	readonly property var everyone: Mpris.players.values
	readonly property var players: everyone.filter(player => !Settings.media.ignored.includes(player.identity))
	readonly property var playing: players.find(player => player.isPlaying) ?? null
	property var last: null
	property var picked: null
	readonly property var player: players.includes(picked) ? picked : playing ?? (players.includes(last) ? last : players[0] ?? null)

	onPlayingChanged: {
		if (!playing)
			return;
		last = playing;
		if (playing !== picked)
			picked = null;
	}

	// For the card's list and the keys: this one, until another starts playing.
	function pick(chosen) {
		picked = chosen;
	}

	// The next one along, for a key.
	function cycle() {
		if (players.length > 1)
			pick(players[(players.indexOf(player) + 1) % players.length]);
	}

	// How long `seconds` is, as a clock says it: 2:05, or 1:02:05.
	function clock(seconds) {
		const whole = Math.max(0, Math.floor(seconds));
		const hours = Math.floor(whole / 3600);
		const minutes = Math.floor(whole / 60) % 60;
		const rest = String(whole % 60).padStart(2, "0");
		return hours > 0 ? `${hours}:${String(minutes).padStart(2, "0")}:${rest}` : `${minutes}:${rest}`;
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

	// To `seconds` into the track.
	function seekTo(seconds) {
		if (!player?.canSeek || !player.positionSupported)
			return;
		const to = Math.max(0, player.lengthSupported ? Math.min(seconds, player.length) : seconds);
		Env.act(`media seek ${player.dbusName} ${Math.round(to)}`, () => player.position = to);
	}

	// `seconds` on, or back for fewer than none.
	function seek(seconds) {
		if (player?.canSeek)
			Env.act(`media seek ${player.dbusName} by ${seconds}`, () => player.seek(seconds));
	}

	function shuffle() {
		if (player?.canControl && player.shuffleSupported)
			Env.act(`media shuffle ${player.dbusName} ${!player.shuffle}`, () => player.shuffle = !player.shuffle);
	}

	// No repeat, then the list, then the track.
	function loop() {
		if (!player?.canControl || !player.loopSupported)
			return;
		const next = player.loopState === MprisLoopState.None ? MprisLoopState.Playlist : player.loopState === MprisLoopState.Playlist ? MprisLoopState.Track : MprisLoopState.None;
		Env.act(`media loop ${player.dbusName} ${MprisLoopState.toString(next)}`, () => player.loopState = next);
	}

	// Its window, to the front.
	function raise() {
		if (player?.canRaise)
			Env.act(`media raise ${player.dbusName}`, () => player.raise());
	}
}
