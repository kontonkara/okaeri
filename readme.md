# okaeri

*お帰り, "welcome back".* A desktop shell for
[niri](https://github.com/niri-wm/niri) on
[Quickshell](https://quickshell.org), with one design for everything on
screen. It goes with [yokoso](https://github.com/kontonkara/yokoso), the
greeter and lock screen.

Work in progress: the bar, the launcher, the control center, notifications,
the clipboard's history, the on-screen display, the polkit dialog, the session
menu, idling and the wallpaper are there and run together, tried so far only on
a test stand and next to another shell. It can't take over a desktop yet: there's
no dock, and media goes by its keys alone.

What it does is in `~/.config/okaeri/settings.json`, how it looks in `theme.json`
beside it: `shell/settings.json` and `shell/themes/dark.json` have every key.
`okaeri` runs it, and `okaeri volume up 10` and the like are for the
compositor's binds: `shell/keys/Keys.qml` has the keys.

`./try` opens it in a niri of its own, in a window, next to the desktop you
have. `tests/all.sh` runs every test, and `tests/part.sh` says how they run.
