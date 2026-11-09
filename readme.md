# okaeri

*お帰り, "welcome back".* A desktop shell for
[niri](https://github.com/niri-wm/niri) on
[Quickshell](https://quickshell.org), with one design for everything on
screen. It goes with [yokoso](https://github.com/kontonkara/yokoso), the
greeter and lock screen.

Work in progress, and in daily use: the bar, the launcher, the control center,
notifications, the clipboard's history, the on-screen display, the polkit dialog,
the session menu, idling, the wallpaper and a settings window for all of that.

## Installing it

On any distribution, in one go:

```sh
curl -fsSL https://raw.githubusercontent.com/kontonkara/okaeri/main/install.sh | sh
```

and away again, settings too if you say so:

```sh
~/.local/share/okaeri/install.sh uninstall
```

It puts okaeri in `~/.local/share/okaeri`, offers to get what it needs from your
package manager, and puts two includes at the top of niri's config, between
`okaeri` marks: its start and its keys, which yours override, and what the shell
needs of niri. Another bar that niri starts it offers to turn off, till okaeri goes.
Running it again updates it. The keys are Mod+Space for the launcher, Mod+Alt+V
for the clipboard, Mod+Shift+Escape for the session menu and Mod+Shift+Comma for
the settings, and the media keys.

## Running it by hand

It takes niri 26.04 or newer, Quickshell 0.3 or newer, and `cliphist`, `qalc`,
`wl-clipboard`, `wtype`, `notify-send` and `pw-play` in `PATH`, `wlsunset` for the
night light, and the freedesktop sound theme for sounds. `bin/okaeri` runs it from a clone of this repository, on
any distribution: `nix/` is a package and a Home Manager module for those who want
them. In niri's config:

```kdl
spawn-at-startup "/path/to/okaeri/bin/okaeri"

// What the shell needs of niri, in a file it keeps itself.
include optional=true "~/.local/state/okaeri/niri.kdl"

binds {
    Mod+Space { spawn "okaeri" "launcher" "toggle"; }
    Mod+V { spawn "okaeri" "clipboard" "toggle"; }
    Mod+Escape { spawn "okaeri" "session" "toggle"; }
    XF86AudioRaiseVolume { spawn "okaeri" "volume" "up" "10"; }
    XF86AudioLowerVolume { spawn "okaeri" "volume" "down" "10"; }
    XF86MonBrightnessUp { spawn "okaeri" "brightness" "up" "10"; }
    XF86MonBrightnessDown { spawn "okaeri" "brightness" "down" "10"; }
}
```

`shell/keys/Keys.qml` has the rest of what binds can call. Without the `include`
it all runs still, but blur only has the wallpaper to show and not the windows, the
overview has no blurred wallpaper behind it, and screencasts show the notifications.

## Settings

The settings window changes most things in place, over what the files say, and
`okaeri settings toggle` opens it. The files are `~/.config/okaeri/settings.json` for
what it does and `theme.json` beside it for how it looks: `shell/settings.json` and
`shell/themes/dark.json` have every key.

## Working on it

`./try` opens it in a niri of its own, in a window, next to the desktop you
have. `tests/all.sh` runs every test, and `tests/part.sh` says how they run.
