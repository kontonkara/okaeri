# Settings

The settings window changes most things in place, over what the files say.
The files are `~/.config/okaeri/settings.json` for what it does and
`theme.json` beside it for how it looks: [`shell/settings.json`](../shell/settings.json)
and [`shell/themes/dark.json`](../shell/themes/dark.json) have every key.
"Back to the config", under the pages, takes back what the window set: on the
page that shows, or all of it.

A dot left of a line says the window set it, and a click on the dot takes that
back; a line that's one of a list, as what has an on-screen display or an
app's rule for notifications, has a dot of its own. The button beside "Back to
the config" copies all that's set, the files' and the window's, as JSON or as
Nix for the Home Manager module. The search finds a line by its key too, as
`saveTo`. A choice in the window takes the wheel and the arrow keys, and the
Notifications page has one to show, to see how they come.

`okaeri settings get dock.magnify`, `set dock.magnify 160` and `reset` read
and change one setting, `theme.accent` and the like the look's, and `okaeri
settings config nix` prints it all. `okaeri settings schema` prints a JSON
Schema of settings.json, for an editor to complete and check it by: kept
beside it as `settings.schema.json`, `"$schema": "./settings.schema.json"` in
it says so.

## Hooks

Commands of yours can run when the charger goes in or comes out, the battery
gets low, the colors change or another wallpaper goes up, with what that's
about in their environment: they're `hooks` in the settings, and on the
Session page. The templates for other apps' colors are there too; see
[how it looks](looks.md#other-apps-in-the-same-colors).
