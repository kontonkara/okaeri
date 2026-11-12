# okaeri

*お帰り, "welcome back".* A desktop shell for
[niri](https://github.com/niri-wm/niri) on
[Quickshell](https://quickshell.org), with one design for everything on
screen. It goes with [yokoso](https://github.com/kontonkara/yokoso), the
greeter and lock screen.

Work in progress, and in daily use: the bar, at any edge of the screen, a dock,
the launcher, the control center, notifications, the clipboard's history, the
on-screen display, the polkit dialog, the session menu, idling, the wallpaper
and a settings window for all of that.

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
night light, `wf-recorder` to record the screen and `slurp` for a part of it,
`ddcutil` for external monitors' brightness, with `/dev/i2c-*` yours, `nmcli` for
VPNs, and the freedesktop sound theme for sounds. `bin/okaeri` runs it from a
clone of this repository, on any distribution: `nix/` is a package and a Home
Manager module for those who want them. In niri's config:

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

`okaeri commands` lists all that binds and scripts can call, as the running shell
has it: `okaeri launcher open "/emoji "` opens the launcher at the emoji, and
`okaeri dock toggle` shows the dock or puts it away. Without the `include` it all
runs still, but blur only has the wallpaper to show and not the windows, the
overview has no blurred wallpaper behind it, and screencasts show the notifications.

## Settings

The settings window changes most things in place, over what the files say, and
`okaeri settings toggle` opens it. The files are `~/.config/okaeri/settings.json` for
what it does and `theme.json` beside it for how it looks: `shell/settings.json` and
`shell/themes/dark.json` have every key.

The bar takes parts of your own, made on its page of the settings: a command, and
what it prints is on the bar. The first line shows and the second is what the
pointer on it says, or it's a line of JSON as waybar's scripts print, with `text`,
`tooltip` and `class`. It runs every so many seconds, or once, and then each line
it goes on to print is shown in turn. A click or the wheel on any part, yours or
not, can run a command too, in place of what the part does with it. `okaeri bar
toggle` has the bar hide, or stay. The control center takes tiles of your own the
same way: a command for a click, and one that says whether the tile is on.

Its colors are a palette's: `extends` in `theme.json` names one of
`shell/themes`, your own `colors` go over it, and `palettes` there adds more by
name. The settings window picks one too, or two, for the day and for the night,
and can take the accent from the wallpaper. `okaeri wallpaper next` puts up
another picture of the wallpaper's folder, `okaeri record toggle` starts and stops
a recording of the screen, and `okaeri settings open Wallpaper` opens the
settings at a page. For scripts, `okaeri dmenu` shows the lines of its standard
input in the launcher and prints the one picked, as dmenu does. Commands of
yours can run when the charger goes in or comes out, the battery gets low, the
colors change or another wallpaper goes up, with what that's about in their
environment: they're `hooks` in the settings, and on the Session page.

## Working on it

`./try` opens it in a niri of its own, in a window, next to the desktop you
have. `tests/all.sh` runs every test, and `tests/part.sh` says how they run.
