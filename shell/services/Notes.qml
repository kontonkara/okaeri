pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs

// Things to do and a note, kept in okaeri/notes.json of the state directory:
// each thing { text, done }, those not done first, newest last; the note any
// text. The bar's part shows them, and the launcher's /todo and `okaeri notes
// add`, in Keys, add to them.
Singleton {
	id: notes

	property var todos: []
	property string note
	readonly property int open: todos.filter(todo => !todo.done).length
	// The file read: until then nothing goes into it.
	property bool read: false

	function add(text) {
		const wanted = String(text).trim();
		if (!wanted)
			return;
		todos = todos.filter(todo => !todo.done).concat([{ text: wanted, done: false }], todos.filter(todo => todo.done));
		save();
	}

	// Done, or not done again: done ones go after the rest.
	function toggle(index) {
		const all = todos.slice();
		const todo = Object.assign({}, all[index], { done: !all[index].done });
		all.splice(index, 1);
		todos = all.filter(one => !one.done).concat(todo.done ? [] : [todo], all.filter(one => one.done), todo.done ? [todo] : []);
		save();
	}

	function remove(index) {
		todos = todos.filter((todo, at) => at !== index);
		save();
	}

	function clearDone() {
		todos = todos.filter(todo => !todo.done);
		save();
	}

	// As it's typed: kept a moment after the last key.
	function write(text) {
		if (text === note)
			return;
		note = text;
		saving.restart();
	}

	function save() {
		if (read)
			file.setText(JSON.stringify({ todos, note }, null, "\t") + "\n");
	}

	Timer {
		id: saving

		interval: 600
		onTriggered: notes.save()
	}

	FileView {
		id: file

		path: `${Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state"}/okaeri/notes.json`
		printErrors: false
		onLoaded: {
			try {
				const kept = JSON.parse(text());
				notes.todos = Array.isArray(kept.todos) ? kept.todos.filter(todo => todo && typeof todo.text === "string").map(todo => ({ text: todo.text, done: !!todo.done })) : [];
				notes.note = typeof kept.note === "string" ? kept.note : "";
			} catch (error) {}
			notes.read = true;
		}
		onLoadFailed: notes.read = true
	}
}
