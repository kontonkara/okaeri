# Plugins

Plugins are folders in `~/.config/okaeri/plugins`, each with a `plugin.json`:
its `name`, a `description`, and QML files of its own, `bar` for a part of the
bar, which goes on it by the folder's name as any part does, `background` for
what runs with the shell, an `IpcHandler` say, and `launcher` for a mode of
the launcher's. They `import qs` and the
rest of okaeri's modules as its own files do.

Their code runs as the shell's own, so none runs until it's turned on, on the
Plugins page of the settings, where "Look again" finds new ones.
[`examples/plugins/hello`](../examples/plugins/hello) is one to start from.

## Their settings

A plugin's `settings` list what it has to set there, under its line while
it's on: each a `key`, its `text`, a `type`, "toggle", "text", "number" with
its `values` or "choice" with its `options`, and a `default`. Its code reads
one with `Plugins.option("hello", "greeting")`:

```json
{
	"name": "Hello",
	"bar": "Bar.qml",
	"settings": [
		{ "key": "greeting", "text": "What it says", "type": "text", "default": "Hello" },
		{ "key": "count", "text": "It counts clicks", "type": "toggle", "default": true }
	]
}
```

## In the launcher

A plugin's `modes` are the launcher's as the ones made in its settings are,
their commands run in the plugin's folder: `list` prints the rows, a line
each, with what's typed as `$1`, a `live` one asked again as it changes;
`run` takes the row picked as `$1` and what's typed as `$2`, and with none
Enter copies the row. A row can say more after a tab, what goes under it, and
after another what Enter takes instead of its text. `text` and `subtext` are
how the mode shows under a lone `/`.

```json
{
	"name": "Hello",
	"modes": [
		{ "mode": "greet", "text": "Greetings", "list": "printf 'Hello\\tIn English\\nPrivet\\tIn Russian\\n'", "run": "notify-send \"$1\"" }
	]
}
```

What a command can't do, a QML file can: `launcher` names one whose root has
a `mode`, its `text`, `subtext` and `icon` if it likes, and `rows(query)`,
which gives the rows for what's typed, each a `text`, a `subtext`, an `icon`,
`does`, a function, and `stays: true` for the launcher to stay open after.
A `changed()` signal of its has the list asked again while it's open.

```qml
import QtQuick

QtObject {
	property string mode: "hi"
	property string text: "Say hi"

	function rows(query) {
		return [{ text: `Hi, ${query || "you"}`, does: () => console.info("hi", query) }];
	}
}
```
