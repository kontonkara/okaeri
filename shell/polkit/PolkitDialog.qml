import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Polkit
import qs
import qs.services
import qs.ui

// Polkit's password dialog. Only one agent can answer for a session, so
// there's none in tests or next to another shell: in tests demo() opens the
// dialog on a fake. A click elsewhere doesn't throw a request away, Escape does.
Scope {
	id: dialog

	// The request at hand, in AuthFlow's shape: the agent's, or demo()'s.
	readonly property var flow: fake ?? agent.item?.flow ?? null
	readonly property bool open: !!flow && !flow.isCompleted && !flow.isCancelled
	property var fake: null
	readonly property var identities: Array.from(flow?.identities ?? [])

	// Whether the last try was turned down. AuthFlow's `failed` can't say: it
	// stays on for good, and leaving a session for another identity sets it.
	property bool tried: false
	property bool refused: false

	readonly property var live: {
		const chosen = flow?.selectedIdentity;
		const asking = !!flow?.isResponseRequired;
		const secret = !flow?.responseVisible;
		// PAM often says nothing about a wrong password, and what it said before
		// stays until it says something else.
		const said = refused && !flow?.supplementaryIsError ? "That didn't work, try again" : flow?.supplementaryMessage ?? "";
		const only = identities.length === 1 ? identities[0] : null;
		return {
			message: flow?.message ?? "",
			rows: identities.map(identity => ({
				text: identity.displayName || identity.string,
				subtext: identity.displayName === identity.string ? "" : identity.string,
				check: identity.id === chosen?.id && identity.isGroup === chosen?.isGroup
			})),
			// With one there's nothing to pick, but it's still good to know whose
			// password it wants.
			who: only ? (only.id === 0 && !only.isGroup ? "root" : only.displayName || only.string) : "",
			asking,
			prompt: (flow?.inputPrompt ?? "").replace(/:\s*$/, ""),
			secret,
			// With nothing else to say, what a hidden password would be typed with.
			note: said || (asking && secret && Locks.caps ? "Caps Lock is on" : ""),
			error: refused || !!flow?.supplementaryIsError
		};
	}
	// What's on screen. The agent deletes a flow as it ends, and a property
	// holding one empties with it: plain values last through the fade out.
	property var view: live

	// The field is the only place a password is, and only until it's sent.
	function forget() {
		field.text = "";
		field.revealed = false;
	}

	// No try yet, and nothing in the field for one.
	function startOver() {
		tried = false;
		refused = false;
		forget();
	}

	function submit() {
		if (open && authenticate.enabled) {
			tried = true;
			refused = false;
			flow.submit(field.text);
			forget();
		}
	}

	function cancel() {
		if (open)
			flow.cancelAuthenticationRequest();
	}

	function pick(index) {
		if (open) {
			startOver();
			flow.selectedIdentity = identities[index];
		}
	}

	function demo(properties) {
		if (Env.dry && !open)
			fake = fakeFlow.createObject(dialog, properties);
	}

	onFlowChanged: startOver()

	onLiveChanged: {
		if (open)
			view = live;
	}

	onOpenChanged: {
		forget();
		if (open) {
			view = live;
			scroller.contentY = 0;
			panel.show();
		} else {
			panel.hide();
		}
	}

	LazyLoader {
		id: agent

		active: !Env.dry && !Env.guest

		PolkitAgent {
			Component.onCompleted: console.info("okaeri: polkit agent up")
		}
	}

	Component {
		id: fakeFlow

		FakeFlow {}
	}

	// Gone as it ends, as the agent's are.
	Connections {
		target: dialog.fake

		function onIsCompletedChanged() {
			const ended = dialog.fake;
			dialog.fake = null;
			ended.destroy();
		}
	}

	Connections {
		target: dialog.flow

		function onAuthenticationFailed() {
			dialog.refused = dialog.tried;
		}
	}

	IpcHandler {
		target: "polkit"

		function demo(): void {
			dialog.demo({});
		}

		// Two to pick from, a note up front, and silence on a wrong password.
		function demoIdentities(): void {
			dialog.demo({
				identities: [
					{ id: 1000, string: "alex", displayName: "Alex Doe", isGroup: false },
					{ id: 0, string: "root", displayName: "root", isGroup: false }
				],
				supplementaryMessage: "Any of these can say yes",
				refusal: ""
			});
		}

		// Anything else a fake can say, as JSON.
		function demoWith(properties: string): void {
			dialog.demo(JSON.parse(properties));
		}

		function cancel(): void {
			dialog.cancel();
		}
	}

	Panel {
		id: panel

		align: "center"
		padding: Theme.u(18)
		modal: true

		FocusScope {
			width: parent.width
			height: content.height
			focus: true

			Keys.onEscapePressed: dialog.cancel()
			// The field has no use for these, the list takes them for itself.
			Keys.onUpPressed: scroller.scroll(-1)
			Keys.onDownPressed: scroller.scroll(1)

			Column {
				id: content

				// The message and the list come from outside and can be any length:
				// they share what the rest leaves of the screen, clear of the bar.
				readonly property real most: Math.max(Theme.u(60), (panel.height
					- 2 * (Theme.below + panel.padding) - spacing * 6
					- heading.height - label.height - field.height - note.height - buttons.height) / 2)

				width: parent.width
				spacing: Theme.u(12)

				Row {
					id: heading

					spacing: Theme.u(8)

					Icon {
						anchors.verticalCenter: parent.verticalCenter
						name: "lock"
					}

					Text {
						anchors.verticalCenter: parent.verticalCenter
						text: "Authentication required"
						color: Theme.colors.text
						font.family: Theme.font
						font.pixelSize: Theme.fontSize + Theme.u(2)
						font.weight: Theme.fontWeight
					}

					// Whose password, on the same line, so the rest stays where it is.
					Text {
						anchors.verticalCenter: parent.verticalCenter
						visible: dialog.view.who !== ""
						width: Math.max(0, Math.min(implicitWidth, content.width - x))
						text: `as ${dialog.view.who}`
						textFormat: Text.PlainText
						elide: Text.ElideRight
						color: Theme.colors.subtext
						font.family: Theme.font
						font.pixelSize: Theme.fontSize
					}
				}

				Flickable {
					id: scroller

					// A step of the keys, down for 1. A flick moves on by itself, and
					// that's an animation.
					function scroll(by) {
						if (Theme.animate)
							flick(0, -by * Theme.u(600));
						else
							contentY = Math.max(originY, Math.min(contentY + by * Theme.u(120), originY + contentHeight - height));
					}

					width: parent.width
					height: Math.min(contentHeight, content.most)
					contentHeight: message.height
					clip: true
					boundsBehavior: Flickable.StopAtBounds

					Text {
						id: message

						width: parent.width
						// Clear of the mark.
						rightPadding: Theme.u(8)
						text: dialog.view.message
						color: Theme.colors.subtext
						wrapMode: Text.Wrap
						textFormat: Text.PlainText
						font.family: Theme.font
						font.pixelSize: Theme.fontSize
					}

					ScrollMark {
						view: scroller
					}
				}

				Column {
					width: parent.width
					visible: dialog.view.rows.length > 1
					spacing: Theme.u(4)

					Text {
						id: label

						text: "Authenticate as"
						color: Theme.colors.text
						font.family: Theme.font
						font.pixelSize: Theme.fontSize
						font.weight: Theme.fontWeight
					}

					List {
						id: list

						width: parent.width
						height: Math.min(implicitHeight, content.most)
						model: dialog.view.rows
						onActivated: index => {
							dialog.pick(index);
							// A new model starts over at the top.
							currentIndex = index;
							field.take();
						}

						ScrollMark {
							view: list
						}
					}
				}

				TextField {
					id: field

					width: parent.width
					focus: true
					enabled: dialog.view.asking
					placeholder: dialog.view.prompt || "One moment"
					secret: dialog.view.secret
					onAccepted: dialog.submit()
					onEnabledChanged: {
						if (enabled)
							take();
					}
				}

				// One line even when empty, so that an error doesn't move the field.
				Text {
					id: note

					width: parent.width
					text: dialog.view.note
					color: dialog.view.error ? Theme.colors.error : Theme.colors.subtext
					wrapMode: Text.Wrap
					maximumLineCount: 3
					elide: Text.ElideRight
					textFormat: Text.PlainText
					font.family: Theme.font
					font.pixelSize: Theme.fontSize
				}

				Row {
					id: buttons

					anchors.right: parent.right
					spacing: Theme.u(8)

					Button {
						text: "Cancel"
						onClicked: dialog.cancel()
					}

					Button {
						id: authenticate

						text: "Authenticate"
						filled: true
						enabled: field.enabled && field.text !== ""
						onClicked: dialog.submit()
					}
				}
			}
		}
	}
}
