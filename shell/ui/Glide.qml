import QtQuick
import qs

// The wheel and the touchpad on `view`, with weight to them: a notch of the wheel
// glides there and the next adds to where it's going, and what the fingers set
// going keeps on after they've left. The rest of the pointer goes through.
MouseArea {
	id: glide

	required property Flickable view
	// How far a notch goes.
	property real notch: Theme.u(92)
	// Where the wheel is taking it.
	property real goal: 0
	// How fast the fingers went, in pixels a second, and when they last did.
	property real speed: 0
	property double heard: 0

	function inside(y) {
		return Math.max(view.originY, Math.min(y, view.originY + view.contentHeight - view.height));
	}

	function roll(notches) {
		view.cancelFlick();
		goal = inside((gliding.running ? goal : view.contentY) - notches * notch);
		if (Theme.animate)
			gliding.restart();
		else
			view.contentY = goal;
	}

	// Glides to where what's from `top` to `bottom` of it shows, or as much as fits.
	function reveal(top, bottom) {
		const y = view.contentY;
		const to = bottom > y + view.height ? Math.min(top, bottom - view.height) : top < y ? top : y;
		if (to === y)
			return;
		view.cancelFlick();
		goal = inside(to);
		if (Theme.animate)
			gliding.restart();
		else
			view.contentY = goal;
	}

	function follow(pixels) {
		gliding.stop();
		view.cancelFlick();
		view.contentY = inside(view.contentY - pixels);
		const now = Date.now();
		const since = Math.max(1, now - heard);
		// After a stop it starts over.
		speed = since > 100 ? 0 : speed * 0.7 + pixels / since * 300;
		heard = now;
	}

	// They were still moving as they left, or there's nothing to go on with.
	function release() {
		if (Theme.animate && Date.now() - heard < 100 && Math.abs(speed) > Theme.u(200))
			view.flick(0, speed);
		speed = 0;
	}

	parent: view
	anchors.fill: parent
	z: 1
	acceptedButtons: Qt.NoButton

	// A wheel comes with no phase, and with pixels of its own as well.
	onWheel: event => {
		if (event.phase === Qt.NoScrollPhase)
			roll(event.angleDelta.y / 120);
		else if (event.phase === Qt.ScrollEnd)
			release();
		else
			follow(event.pixelDelta.y);
	}

	NumberAnimation {
		id: gliding

		target: glide.view
		property: "contentY"
		to: glide.goal
		duration: 320
		easing.type: Easing.OutCubic
		// The list may have turned out shorter than it looked from afar.
		onFinished: glide.view.returnToBounds()
	}

	// What it was going to isn't there any more.
	Connections {
		target: glide.view
		ignoreUnknownSignals: true

		function onCountChanged() {
			gliding.stop();
		}
	}
}
