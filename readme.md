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
package manager, and puts two includes in niri's config, between `okaeri`
marks: at the top its start and its keys, which yours override, and at the end
what the shell needs of niri, with how windows look where the Look page says.
Another bar that niri starts, or what does what okaeri does, as mako or
swayidle, it offers to turn off, till okaeri goes, and it says which services
of yours do the same.
Running it again updates it. The keys are Mod+Space for the launcher, Mod+Alt+V
for the clipboard, Mod+Shift+Escape for the session menu and Mod+Shift+Comma for
the settings, and the media keys.

## Running it by hand

It takes niri 26.04 or newer, Quickshell 0.3 or newer, and `cliphist`, `qalc`,
`wl-clipboard`, `wtype`, `notify-send` and `pw-play` in `PATH`, `wlsunset` for the
night light, `wf-recorder` to record the screen and `slurp` for a part of it,
`ddcutil` for external monitors' brightness, with `/dev/i2c-*` yours, `nmcli` for
VPNs, the hotspot and sharing Wi-Fi, `qrencode` for the code a phone joins it by,
`udisksctl` for the drives one plugs in, KDE Connect's `kdeconnect-cli` for a
phone, `tesseract` for the text in screenshots, `satty` or `swappy` to edit
them, `curl` for pictures from Wallhaven, and the freedesktop sound theme for
sounds. `bin/okaeri` runs it from a clone of this repository, on any
distribution: `nix/` is a package and a Home Manager module for those who want
them. In niri's config:

```kdl
spawn-at-startup "/path/to/okaeri/bin/okaeri"

// What the shell needs of niri, in a file it keeps itself: at the end, where
// how windows look, as the Look page says, goes over what comes before.
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

`okaeri doctor` says what of what it needs is here, and what each thing missing
is for.
`okaeri commands` lists all that binds and scripts can call, as the running shell
has it: `okaeri launcher open "/emoji "` opens the launcher at the emoji, and
`okaeri dock toggle` shows the dock or puts it away, `okaeri dock pin firefox`
keeps an app on it and `unpin` lets it go, `okaeri session run lock` does what
the session menu would, `okaeri calendar toggle`,
`okaeri media card`, `okaeri battery toggle` and `okaeri load toggle` open those
cards of the bar,
`okaeri volume output next` sends the sound to the next output there is, and
`okaeri volume set 40`, and `set` of `mic`, `brightness` and `keylight` the same
way, puts a level at once; `okaeri night warmth 3000` makes the night light that
warm.
Without the `include` it all runs still, but blur only has the wallpaper to show
and not the windows, the overview has no blurred wallpaper behind it, and
screencasts show the notifications.

## Settings

The settings window changes most things in place, over what the files say, and
`okaeri settings toggle` opens it. The files are `~/.config/okaeri/settings.json`
for what it does and `theme.json` beside it for how it looks:
`shell/settings.json` and `shell/themes/dark.json` have every key. How fast things
move, and how panels and notifications come, growing, fading, sliding, springing
or dropping in, and how wide panels are, are on the Look page with the rest. "Back
to the config", under the pages, takes back what the window set: on the page that
shows, or all of it. `okaeri theme toggle` goes between the day's and the night's
palettes, for a key. A choice in the window takes the wheel and the arrow keys,
and the Notifications page has one to show, to see how they come. The on-screen
display says what plays after a key of the player's, too, and as a track starts by
itself where its page says so.

A dot left of a line of the settings window says the window set it, and a click
on the dot takes that back; a line that's one of a list, as what has an on-screen
display or an app's rule for notifications, has a dot of its own; the button beside "Back to the config" copies all
that's set, the files' and the window's, as JSON or as Nix for the Home Manager
module. The search finds a line by its key too, as `saveTo`. `okaeri settings
get dock.magnify`, `okaeri settings set dock.magnify 160` and `reset` read and
change one setting, `theme.accent` and the like the look's, and `okaeri settings
config nix` prints it all.

The bar takes parts of your own, made on its page of the settings: a command, and
what it prints is on the bar. The first line shows and the second is what the
pointer on it says, or it's a line of JSON with `text`, `tooltip` and `class`.
It runs every so many seconds, or once, and then each line
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
each app playing or listening has a volume of its own, and one playing can have
an output of its own too, which WirePlumber keeps for it. The dock has the apps
it keeps and those with windows, all of them or only its screen's, and a right
click on one has its windows, what else it can start, bringing its windows here,
keeping it and closing it. Its icons grow under the pointer, an app hops as it
starts and while it asks to be looked at, and it can have a button for the
launcher, and stay in sight on an empty workspace where it hides. An app has how
many of its notifications are unread, and a line goes after the apps it keeps.
An app with a window, carried out of the dock onto a workspace of the bar, has
that window go there.

A click on a workspace that wants attention goes to the window that does, an
app's icon on a workspace dragged onto another takes its window there, and the
title of the window in focus has its app's icon. Workspaces can say their
numbers as they are, in Roman, in kanji or in circles, and be round or square.
The bar can have a button for the launcher, among its parts on the Bar page.
A right click on what plays has the players there are, to leave one out of the
bar, its card and the media keys, as a browser; so does a right click on one in
the card, and the Bar page, where the right click for that can be turned off.

The month under the clock has the events of calendars of yours in it, `calendars`
in the clock's settings and on the Bar page: `.ics` files, read again as they
change, and addresses that give one, as a calendar's secret address in iCal
format does, asked again every half hour. A dot is under each day with something
on it, and a click on a day says what.
A notification says that an event with a time is coming, ten minutes before, or
as long as the Bar page says.
The month's card has a timer and a stopwatch, which show beside the time while
they run; `okaeri timer start 10m`, or `1h30m`, `45s`, `1:30`, starts one of any
length, as `/timer 10m tea` in the launcher does, and `okaeri stopwatch toggle`
and `reset` are the stopwatch's. Pomodoros go from the clock's card, `/timer` and
`okaeri pomodoro start`: work, a break, work again, and a long break after a
few, each on to the next by itself, as long as the Bar page says.

A click on the battery shows it in full: how the charge went over the last day,
the power going in or out, the energy in it and how worn it is. Where UPower can
stop the charge short of full, the card turns that on and off, as `okaeri
battery limit true` does: easier on a battery that's mostly on the charger.
The load's card has what keeps the processor busiest now, and two clicks on one
end it.

The Wi-Fi page shares the network it's on with a phone: its name, its password
and a code the phone's camera reads. The hotspot's tile makes the machine one for
phones to get online through, and its page has the code for it; its name, the
machine's unless you give it another, and its password, made up the first time
where you don't, are with its width on the Control page, a click on its tile there.
A network that asks to be signed in to first has a button on the Wi-Fi page that
opens a page for that.
A wired network has a tile and a page of its own once a cable is in it: its
address, its gateway, its name servers and how fast it goes.
A drive plugged in says so, with a way to open it and one to eject it, and has a
tile and a page in the control center: a click on one opens it, mounting it
first, by udisksctl. With its tile chosen on the Control page it can be mounted at
once instead, and `okaeri drives list` says what there is.

A phone paired through KDE Connect, with its daemon running, has a tile in the
control center while it's in reach, with its charge, and a page to ring it,
ping it or send it what's copied; its charge is on the battery's card too, and
`okaeri phone ring` finds it by a key. What it says comes as KDE Connect's
notifications.

The Display page has each screen's resolution, scale, turn, adaptive sync and
place beside the others, and turns one off. niri has that at once, and okaeri has
it again as it starts, as a screen comes and as niri reads its config again; what
can leave a screen dark asks in the middle of the screens to be kept, by Enter or
its button, and goes back by itself in fifteen seconds otherwise. What niri
won't do is said in a notification.

With more screens than one, the Bar page picks whose lanes it shows: a screen's
bar can have parts of its own, and "Like the others" has it like every other
again. The Dock page does the same for a screen's dock: where it is, how
large, whether it hides and the rest.)

okaeri's own words are in English, or in Russian where the locale is, or where
the Look page says; another language is a file in `shell/i18n`, the English
words to its own, as `ru.json` has them. A few words put together with numbers
are English yet.

The bar can have a part for things to do and a note: how many are left, and a
card to add one, tick it off or take it away, and to write in. `/todo` in the
launcher adds one or ticks one off, `okaeri notes add` adds one from a script,
and `okaeri notes toggle` shows the card by a key.
With `cava` there, the bar can have the sound's bars too, which rise and fall
with it, and by its settings only while a player plays.
Another part says how many updates there are, by pacman's `checkupdates`, `apt`,
`dnf` or `flatpak`, whichever are there, looked for every few hours, and a
click on it runs a command of yours, a terminal with the update say.

Plugins are folders in `~/.config/okaeri/plugins`, each with a `plugin.json`:
its `name`, a `description`, and QML files of its own, `bar` for a part of the
bar, which goes on it by the folder's name as any part does, and `background`
for what runs with the shell, an `IpcHandler` say. They `import qs` and the rest
of okaeri's modules as its own files do. Their code runs as the shell's own, so
none runs until it's turned on, on the Plugins page of the settings, where
"Look again" finds new ones; `examples/plugins/hello` is one to start from.

Over the wallpaper and under the windows, the desktop can have the time, the
weather, what plays with its buttons, and what the calendars have coming, at a
corner or in the middle: on the Wallpaper page, with how pictures show.

Screenshots are under `/shot` in the launcher, of a part of the screen, the
screen or the window in focus, with the latest after them: Enter opens one and
Shift+Enter copies it. With tesseract there, the text off a part of the screen
goes onto the clipboard from there too, and with satty or swappy, or an editor
of one's own, the latest is edited; niri's word of one has Edit and Text
buttons for the same. The Display page has where they go, how long they wait,
the editor and the text's languages, the control center a tile for them among
those left out at first, and `okaeri screenshot take area`, `screen` or
`window` is one by a key.

The bell beside an app's name in the notifications' history keeps it quiet for
an hour, eight or until you say, and the Notifications page lists those that
are; a screenshot's toast opens its folder, copies it or deletes it.
A toast under the pointer has that bell too.
Toasts wait every day between two times too, as with Do Not Disturb on: the
quiet hours, on the Notifications page.

Its colors are a palette's: `extends` in `theme.json` names one of
`shell/themes`, your own `colors` go over it, and `palettes` there adds more by
name. The settings window picks one too, or two, for the day and for the night,
showing each by its colors, and can take the accent from the wallpaper, or all
of its colors, or have
one of your own over any palette's, `accent` in `theme.json` as `#rrggbb`, or
`okaeri theme accent '#3366cc'` for a script. The Look page keeps a look by a name,
all that it set, and `okaeri theme look evening` has that one on again. `okaeri wallpaper next` puts up
another picture of the wallpaper's folder, `okaeri wallpaper set <file>` that
one, and a right click on one in the settings makes it one screen's own or the
light colors'. With `curl` there, the Wallpaper page looks on Wallhaven too,
only when asked, for pictures safe for work as large as the screen: one picked
is fetched into the folder and goes up. `okaeri record toggle`
starts and stops a recording of the screen, and `okaeri settings open Wallpaper`
opens the settings at a page. For scripts, `okaeri dmenu` shows the lines of its
standard input in the launcher and prints the one picked, as dmenu does, with
`-p` for a prompt, `--password` to hide what's typed, `--index` to print where
the line picked was, from 0, `--only-match` to take nothing but a line, and
`--select` for the line to start on. The launcher finds apps' own actions by
their names too, as New Private Window, and Shift+Enter on a window under `/win`
closes it. Under `/ps` are your processes, the busiest first, with how much
of the processor and the memory each takes: Enter twice ends one, and
Shift+Enter twice kills it. A `>` in front runs the rest as a command, and a `?`
looks it up on the web, at the address its page of the settings has. `okaeri
color pick`, or `/color` there, copies the color of what's clicked next as `#rrggbb`. The button
in its field, or Ctrl+G, has the groups apps go by in the list's place: folders
of your own, made on its page of the settings and filled from an app's menu in
the launcher, and the kinds apps say they are, Games, Programming, Design and the
like; with one picked, the list and the search are that group's. The clipboard's history keeps nothing while it's paused, by the button
in its panel or `okaeri clipboard pause` till `resume`, and it can leave pictures
out. Commands of
yours can run when the charger goes in or comes out, the battery gets low, the
colors change or another wallpaper goes up, with what that's about in their
environment: they're `hooks` in the settings, and on the Session page.

A right click on an entry of the clipboard's history, or Right, shows it whole,
to copy or paste it, as it is or changed there first, open the link in it, or
save the picture, to `saveTo` in the clipboard's settings or Pictures.

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
    { "from": "~/my/colors.css", "to": "~/.config/myapp/colors.css" }
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

A mode for games has nothing move or blur, toasts wait and the machine stay
awake, each as the Session page says: by its tile in the control center, which
is among those left out at first, by `okaeri game toggle`, and by itself while
gamemode has a game, as `gamemoderun` starts one.

## Working on it

`./try` opens it in a niri of its own, in a window, next to the desktop you
have. `tests/all.sh` runs every test, or those it's given the names of, and says how
long each took; `tests/part.sh` says how they run.
