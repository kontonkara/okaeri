# okaeri

*お帰り, "welcome back".* A desktop shell for
[niri](https://github.com/niri-wm/niri) on
[Quickshell](https://quickshell.org), with one design for everything on
screen. It goes with [yokoso](https://github.com/kontonkara/yokoso), the
greeter and lock screen.

Work in progress, and in daily use:

- The bar, at any edge of the screen, whole, as islands or as capsules, with
  parts of your own, plugins', separators, and a look of its own for each
  part; a bar of its own for each screen, too.
- A dock, the launcher (apps, windows, emoji, sums, processes, screenshots,
  `dmenu` for scripts), the control center, notifications with a history and
  quiet hours, the clipboard's history, the on-screen display, the polkit
  dialog and the session menu.
- The month with calendars of yours, timers and pomodoros, the battery's and
  the load's cards, Wi-Fi, a hotspot, wired networks, drives, a phone through
  KDE Connect, screens and screenshots.
- Idling, locking and sleeping, the wallpaper with what's on the desktop, a
  palette for the day and one for the night, other apps in the same colors.
- A settings window for all of that, layouts in a click, and how niri draws
  windows; English and Russian.

## Installing it

On any distribution, in one go:

```sh
curl -fsSL https://raw.githubusercontent.com/kontonkara/okaeri/main/install.sh | sh
```

and away again, settings too if you say so:

```sh
~/.local/share/okaeri/install.sh uninstall
```

The keys are Mod+Space for the launcher, Mod+Alt+V for the clipboard,
Mod+Shift+Escape for the session menu and Mod+Shift+Comma for the settings,
and the media keys. What it does to niri's config, running it by hand and on
NixOS are in [installing](docs/install.md); `okaeri doctor` says what of what
it needs is here.

## Documentation

- [Installing it](docs/install.md): install.sh, what it needs, niri's
  config by hand, Nix
- [Using it](docs/usage.md): the bar and its cards, the control center, the
  dock, the launcher, the clipboard, notifications, screens, idling
- [How it looks](docs/looks.md): the bar's looks, layouts, windows, palettes,
  the wallpaper and the desktop, other apps' colors, the language
- [Settings](docs/settings.md): the window, the files, hooks, a schema
- [Commands](docs/commands.md): `okaeri …` for keys and scripts
- [Plugins](docs/plugins.md): a part for the bar, code that runs with the
  shell, and their settings
- [Working on it](docs/development.md): `./try` and the tests
