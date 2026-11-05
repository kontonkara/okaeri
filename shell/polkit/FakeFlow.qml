import QtQuick

// A flow in AuthFlow's shape with nothing behind it, for demo(). Like PAM it
// takes a moment to ask and to check, and it turns down the first try. What
// it's given goes nowhere.
QtObject {
	id: fake

	property string message: "Authentication is needed to run `/usr/bin/true' as the super user"
	property string iconName: "dialog-password"
	property string actionId: "org.okaeri.demo"
	property string cookie: "demo"
	property var identities: [{ id: 1000, string: "alex", displayName: "Alex", isGroup: false }]
	property var selectedIdentity: identities[0]
	property bool isResponseRequired: false
	property string inputPrompt: ""
	property bool responseVisible: false
	property string supplementaryMessage: ""
	property bool supplementaryIsError: false
	property bool isCompleted: false
	property bool isSuccessful: false
	property bool isCancelled: false
	property bool failed: false

	// What it says when it turns one down. PAM often says nothing.
	property string refusal: "Sorry, that didn't work"
	// How long it takes to ask, and to check.
	property int delay: 300
	property int tries: 0
	property bool checking: false
	property bool started: false

	signal authenticationSucceeded
	signal authenticationFailed
	signal authenticationRequestCancelled

	function submit(value) {
		console.info("okaeri: submitted");
		isResponseRequired = false;
		inputPrompt = "";
		responseVisible = false;
		tries++;
		checking = true;
		pam.restart();
	}

	function cancelAuthenticationRequest() {
		pam.stop();
		console.info("okaeri: cancelled");
		isCancelled = true;
		isCompleted = true;
	}

	function answer() {
		if (checking && tries > 1) {
			console.info("okaeri: succeeded");
			isSuccessful = true;
			isCompleted = true;
			authenticationSucceeded();
			return;
		}
		if (checking) {
			console.info("okaeri: failed");
			if (refusal !== "") {
				supplementaryMessage = refusal;
				supplementaryIsError = true;
			}
			failed = true;
			authenticationFailed();
		}
		checking = false;
		inputPrompt = "Password: ";
		isResponseRequired = true;
		console.info("okaeri: asked");
	}

	Component.onCompleted: {
		started = true;
		pam.start();
	}

	// As in AuthFlow: another identity ends the session for a new one, the end
	// counts as a failure, and what was asked stays up until the new one asks.
	onSelectedIdentityChanged: {
		if (started) {
			console.info(`okaeri: identity ${selectedIdentity.string}`);
			checking = false;
			failed = true;
			authenticationFailed();
			pam.restart();
		}
	}

	readonly property Timer pam: Timer {
		interval: fake.delay
		onTriggered: fake.answer()
	}
}

