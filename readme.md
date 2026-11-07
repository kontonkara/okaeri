# okaeri

*お帰り, "welcome back".* A desktop shell for
[niri](https://github.com/niri-wm/niri) on
[Quickshell](https://quickshell.org), with one design for everything on
screen. It goes with [yokoso](https://github.com/kontonkara/yokoso), the
greeter and lock screen.

Work in progress, and in daily use: the bar, the launcher, the control center,
notifications, the clipboard's history, the on-screen display, the polkit dialog,
the session menu, idling, the wallpaper and a settings window for all of that.

## Running it

It takes niri 26.04 or newer, Quickshell, and `cliphist`, `qalc`, `wl-clipboard` and
`notify-send` in `PATH`. `bin/okaeri` runs it from a clone of this repository, on
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
