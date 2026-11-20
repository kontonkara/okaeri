import QtQuick
import qs.services

// A mode of the launcher's, /hi: a row that greets whom is typed, and a click
// on it says so as the bar's part does.
QtObject {
	property string mode: "hi"
	property string text: "Say hi"
	property string icon: "text"

	function rows(query) {
		const whom = query || "you";
		return [{ text: `${Plugins.option("hello", "greeting")}, ${whom}`, subtext: "Enter says it in the log", does: () => console.info("okaeri: hello:", whom) }];
	}
}
