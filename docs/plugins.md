# Plugins

Plugins are folders in `~/.config/okaeri/plugins`, each with a `plugin.json`:
its `name`, a `description`, and QML files of its own, `bar` for a part of the
bar, which goes on it by the folder's name as any part does, and `background`
for what runs with the shell, an `IpcHandler` say. They `import qs` and the
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
