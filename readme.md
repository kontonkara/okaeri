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
VPNs, the hotspot and sharing Wi-Fi, `qrencode` for the code a phone joins it by,
and the freedesktop sound theme for sounds. `bin/okaeri` runs it from a clone of
this repository, on any distribution: `nix/` is a package and a Home Manager
module for those who want them. In niri's config:

```kdl
spawn-at-startup "/path/to/okaeri/bin/okaeri"

// What the shell needs of niri, in a file it keeps itself.
include optional=true "~/.local/state/okaeri/niri.kdl"

// The keys install.sh binds: niri's default config has Mod+V and Mod+Escape.
binds {
    Mod+Space hotkey-overlay-title="Launcher" { spawn "/path/to/okaeri/bin/okaeri" "launcher" "toggle"; }
    Mod+Alt+V hotkey-overlay-title="Clipboard" { spawn "/path/to/okaeri/bin/okaeri" "clipboard" "toggle"; }
    Mod+Shift+Escape hotkey-overlay-title="Session menu" { spawn "/path/to/okaeri/bin/okaeri" "session" "toggle"; }
    Mod+Shift+Comma hotkey-overlay-title="Settings" { spawn "/path/to/okaeri/bin/okaeri" "settings" "toggle"; }
    XF86AudioRaiseVolume allow-when-locked=true { spawn "/path/to/okaeri/bin/okaeri" "volume" "up" "5"; }
    XF86AudioLowerVolume allow-when-locked=true { spawn "/path/to/okaeri/bin/okaeri" "volume" "down" "5"; }
    XF86AudioMute allow-when-locked=true { spawn "/path/to/okaeri/bin/okaeri" "volume" "mute"; }
    XF86AudioMicMute allow-when-locked=true { spawn "/path/to/okaeri/bin/okaeri" "mic" "mute"; }
    XF86MonBrightnessUp allow-when-locked=true { spawn "/path/to/okaeri/bin/okaeri" "brightness" "up" "5"; }
    XF86MonBrightnessDown allow-when-locked=true { spawn "/path/to/okaeri/bin/okaeri" "brightness" "down" "5"; }
    XF86AudioPlay allow-when-locked=true { spawn "/path/to/okaeri/bin/okaeri" "media" "toggle"; }
    XF86AudioNext allow-when-locked=true { spawn "/path/to/okaeri/bin/okaeri" "media" "next"; }
    XF86AudioPrev allow-when-locked=true { spawn "/path/to/okaeri/bin/okaeri" "media" "previous"; }
    XF86AudioStop allow-when-locked=true { spawn "/path/to/okaeri/bin/okaeri" "media" "stop"; }
    XF86KbdBrightnessUp allow-when-locked=true { spawn "/path/to/okaeri/bin/okaeri" "keylight" "up" "10"; }
    XF86KbdBrightnessDown allow-when-locked=true { spawn "/path/to/okaeri/bin/okaeri" "keylight" "down" "10"; }
}
```

`okaeri commands` lists all that binds and scripts can call, as the running shell
has it: `okaeri launcher open "/emoji "` opens the launcher at the emoji, and
`okaeri dock toggle` shows the dock or puts it away, `okaeri dock pin firefox`
keeps an app on it and `unpin` lets it go, `okaeri session run lock` does what
the session menu would, `okaeri calendar toggle`,
`okaeri media card`, `okaeri battery toggle` and `okaeri load toggle` open those
cards of the bar, and
`okaeri volume set 40`, and `set` of `mic`, `brightness` and `keylight` the same
way, puts a level at once; `okaeri night warmth 3000` makes the night light that
warm.
Without the `include` it all runs still, but blur only has the wallpaper to show
and not the windows, the overview has no blurred wallpaper behind it, and
screencasts show the notifications.

## Settings

The settings window changes most things in place, over what the files say, and
`okaeri settings toggle` opens it. The files are `~/.config/okaeri/settings.json` for
what it does and `theme.json` beside it for how it looks: `shell/settings.json` and
`shell/themes/dark.json` have every key. How fast things move, and how panels and
notifications come, growing, fading or sliding in, are on the Look page with the
rest. "Back to the config", under the pages, takes back what the window set: on
the page that shows, or all of it. `okaeri theme toggle` goes between the day's
and the night's palettes, for a key. A choice in the window takes the wheel and the
arrow keys, and the Notifications page has one to show, to see how they come. The
on-screen display says what plays after a key of the player's, too.

A dot left of a line of the settings window says the window set it, and a click
on the dot takes that back; the button beside "Back to the config" copies all
that's set, the files' and the window's, as JSON or as Nix for the Home Manager
module. The search finds a line by its key too, as `saveTo`. `okaeri settings
get dock.magnify`, `okaeri settings set dock.magnify 160` and `reset` read and
change one setting, `theme.accent` and the like the look's, and `okaeri settings
config nix` prints it all.

The bar takes parts of your own, made on its page of the settings: a command, and
what it prints is on the bar. The first line shows and the second is what the
pointer on it says, or it's a line of JSON as waybar's scripts print, with `text`,
`tooltip` and `class`. It runs every so many seconds, or once, and then each line
it goes on to print is shown in turn. A click or the wheel on any part, yours or
not, can run a command too, in place of what the part does with it, and a part of
yours runs again right after, to show what that changed. A right click on a part
with none of its own opens a menu by it: what it has to set, where it has some,
its settings, and taking it off the bar. The screen recording can stay on the bar
to start one, a click on the microphone in use mutes it, and how far the wheel
turns the volume is on the volume's card. `okaeri bar toggle` has the bar hide,
or stay. The list of failed units starts one again, takes it off the list, or
shows what its journal said last. The control center takes tiles of your own
the same way: a command for a click, and one that says whether the tile is on. A
right click on any tile opens what else it can do in the panel's place: what a
recording takes in, how warm the night light is, how long to keep awake, the power
profile, and for every tile whether it takes a whole row, where it sits, and
leaving it out; all of them can be small. A tile dragged onto another takes its
place, and a right click on the volume or the microphone opens its page, where
each app playing or listening has a volume of its own. The dock has the apps it
keeps and those with windows, all of them or only its screen's, and a right click
on one has its windows, what else it can start, bringing its windows here,
keeping it and closing it. Its icons grow under the pointer, an app hops as it
starts and while it asks to be looked at, and it can have a button for the
launcher, and stay in sight on an empty workspace where it hides.

A click on a workspace that wants attention goes to the window that does, an
app's icon on a workspace dragged onto another takes its window there, and the
title of the window in focus has its app's icon.

The month under the clock has the events of calendars of yours in it, `calendars`
in the clock's settings and on the Bar page: `.ics` files, read again as they
change, and addresses that give one, as a calendar's secret address in iCal
format does, asked again every half hour. A dot is under each day with something
on it, and a click on a day says what.

A click on the battery shows it in full: how the charge went over the last day,
the power going in or out, the energy in it and how worn it is.

The Wi-Fi page shares the network it's on with a phone: its name, its password
and a code the phone's camera reads. The hotspot's tile makes the machine one for
phones to get online through, and its page has the code for it; its name, the
machine's unless you give it another, and its password, made up the first time
where you don't, are with its width on the Control page, a click on its tile there.

The bell beside an app's name in the notifications' history keeps it quiet for
an hour, eight or until you say, and the Notifications page lists those that
are; a screenshot's toast opens its folder, copies it or deletes it.

Its colors are a palette's: `extends` in `theme.json` names one of
`shell/themes`, your own `colors` go over it, and `palettes` there adds more by
name. The settings window picks one too, or two, for the day and for the night,
showing each by its colors, and can take the accent from the wallpaper or have
one of your own over any palette's, `accent` in `theme.json` as `#rrggbb`, or
`okaeri theme accent '#3366cc'` for a script. `okaeri wallpaper next` puts up
another picture of the wallpaper's folder, `okaeri wallpaper set <file>` that
one, and a right click on one in the settings makes it one screen's own or the
light colors'. `okaeri record toggle`
starts and stops a recording of the screen, and `okaeri settings open Wallpaper`
opens the settings at a page. For scripts, `okaeri dmenu` shows the lines of its
standard input in the launcher and prints the one picked, as dmenu does, with
`-p` for a prompt, `--password` to hide what's typed, `--index` to print where
the line picked was, from 0, `--only-match` to take nothing but a line, and
`--select` for the line to start on. The launcher finds apps' own actions by
their names too, as New Private Window, and Shift+Enter on a window under `/win`
closes it. The clipboard's history keeps nothing while it's paused, by the button
in its panel or `okaeri clipboard pause` till `resume`, and it can leave pictures
out. Commands of
yours can run when the charger goes in or comes out, the battery gets low, the
colors change or another wallpaper goes up, with what that's about in their
environment: they're `hooks` in the settings, and on the Session page.

A right click on an entry of the clipboard's history, or Right, shows it whole,
to copy or paste it, open the link in it, or save the picture, to `saveTo` in
the clipboard's settings or Pictures.

Other apps can have the shell's colors too, as matugen and pywal give them out:
a template is written to a file of the app's as the colors change, from light to
dark and back as well, and again as the template itself changes. In a template
`{{accent}}` is that color as `#rrggbb`, `{{accent.strip}}` the same without the
`#` and `{{accent.rgb}}` as `r, g, b`, and so for every color of the palette;
`{{mode}}` is `light` or `dark`, and what it doesn't know stays as it is. A file
is written only when that changes it, and before the colors' command runs, which
can then have the app read it again. They're `templates` in the `hooks`, and on the
Session page, with `~` for your home:

```json
{ "hooks": { "templates": [
    { "from": "kitty.conf", "to": "~/.config/kitty/okaeri.conf" },
    { "from": "~/my/waybar.css", "to": "~/.config/waybar/colors.css" }
] } }
```

A `from` that isn't a whole path is one that comes with okaeri, in
`shell/templates`, wherever it's installed: `kitty.conf`, `foot.ini`,
`alacritty.toml`, `gtk3.css` and `gtk4.css`, for `~/.config/gtk-3.0/gtk.css` and
`~/.config/gtk-4.0/gtk.css`, and `fuzzel.ini`. Each says at its top what to put in
the app's own config to take it in.

With nothing done for a while the session locks, the screens go off and the
machine can sleep, each sooner on battery where the Session page says so, and it
sleeps suspended, hibernated, or suspended and later hibernated as logind is set
for that.

## Working on it

`./try` opens it in a niri of its own, in a window, next to the desktop you
have. `tests/all.sh` runs every test, and `tests/part.sh` says how they run.
