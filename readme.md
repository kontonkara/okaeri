# okaeri

*お帰り, "welcome back".* A desktop shell for
[niri](https://github.com/niri-wm/niri) on
[Quickshell](https://quickshell.org), with one design for everything on
screen. It goes with [yokoso](https://github.com/kontonkara/yokoso), the
greeter and lock screen.

Work in progress: the bar, the launcher, the control center, notifications,
the clipboard's history, the on-screen display and the polkit dialog are there
and run together, tried so far only on a test stand and next to another shell.
It can't take over a desktop yet: there's no wallpaper, session menu or idle
handling, no media controls, and no way yet to bind the volume and brightness
keys to it.

`./try` opens it in a niri of its own, in a window, next to the desktop you
have. `tests/all.sh` runs every test, and `tests/part.sh` says how they run.
