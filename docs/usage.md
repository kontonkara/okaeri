# Using it

## The bar

Its parts are laid out on the Bar page of the settings: dragged to a lane, or off
the bar. A click on one there shows its settings, how it looks and what clicks and
the wheel on it run. The bar takes parts of your own too: a command, and what it
prints is on the bar. The first line shows and the second is what the pointer on
it says, or it's a line of JSON with `text`, `tooltip` and `class`. It runs every
so many seconds, or once, and then each line it goes on to print is shown in turn;
`okaeri bar update <name>` runs it again at once, for a script that knows when
what it shows has changed. A click or the wheel on any part, yours or not, can run
a command too, in place of what the part does with it, and a part of yours runs
again right after, to show what that changed.

A right click on a part with none of its own opens a menu by it: what it has to
set, where it has some, its settings, and taking it off the bar. The screen
recording can stay on the bar to start one, a click on the microphone in use mutes
it, and how far the wheel turns the volume is on the volume's card. The list of
failed units starts one again, takes it off the list, or shows what its journal
said last. With "The pointer opens panels" on the Bar page, the pointer resting on
the clock and the like opens its panel. With windows on the workspace the bar can
turn solid, without its glass, or hide as if it always did, and be back with none.

A click on a workspace that wants attention goes to the window that does, an
app's icon on a workspace dragged onto another takes its window there, and the
title of the window in focus has its app's icon. The bar can have a button for
the launcher. A right click on what plays has the players there are, to leave
one out of the bar, its card and the media keys, as a browser; so does a right
click on one in the card, and the Bar page, where the right click for that can
be turned off.

The bar can have a part for things to do and a note: how many are left, and a
card to add one, tick it off or take it away, and to write in; `/todo` in the
launcher adds one or ticks one off. With `cava` there, the bar can have the
sound's bars too, which rise and fall with it, and by its settings only while a
player plays. Another part says how many updates there are, by pacman's
`checkupdates`, `apt`, `dnf` or `flatpak`, whichever are there, looked for
every few hours, and a click on it runs a command of yours, a terminal with the
update say. The load on the bar is written as its `format` says, and turns red
past what its alerts say.

## The month, timers, the battery and the load

The month under the clock has the events of calendars of yours in it,
`calendars` in the clock's settings and on the Bar page: `.ics` files, read
again as they change, and addresses that give one, as a calendar's secret
address in iCal format does, asked again every half hour. A dot is under each
day with something on it, and a click on a day says what. A notification says
that an event with a time is coming, ten minutes before, or as long as the Bar
page says.

The month's card has a timer and a stopwatch, which show beside the time while
they run; `/timer 10m tea` in the launcher starts one of any length.
Pomodoros go from the clock's card and `/timer`: work, a break, work again,
and a long break after a few, each on to the next by itself, as long as the Bar
page says.

A click on the battery shows it in full: how the charge went over the last day,
the power going in or out, the energy in it and how worn it is. Where UPower
can stop the charge short of full, the card turns that on and off: easier on a
battery that's mostly on the charger. The load's card has what keeps the
processor busiest now, and two clicks on one end it.

## The control center

It takes tiles of your own the same way as the bar its parts: a command for a
click, and one that says whether the tile is on. A right click on any tile
opens what else it can do in the panel's place: what a recording takes in, how
warm the night light is, how long to keep awake, the power profile, and for
every tile whether it takes a whole row, where it sits, and leaving it out; all
of them can be small. A tile dragged onto another takes its place, and a right
click on the volume or the microphone opens its page, where each app playing or
listening has a volume of its own, and one playing can have an output of its
own too, which WirePlumber keeps for it.

The Wi-Fi page shares the network it's on with a phone: its name, its password
and a code the phone's camera reads. The hotspot's tile makes the machine one
for phones to get online through, and its page has the code for it; its name,
the machine's unless you give it another, and its password, made up the first
time where you don't, are with its width on the Control page, a click on its
tile there. A network that asks to be signed in to first has a button on the
Wi-Fi page that opens a page for that. A wired network has a tile and a page of
its own once a cable is in it: its address, its gateway, its name servers and
how fast it goes.

A drive plugged in says so, with a way to open it and one to eject it, and has
a tile and a page in the control center: a click on one opens it, mounting it
first, by udisksctl. With its tile chosen on the Control page it can be mounted
at once instead.

A phone paired through KDE Connect, with its daemon running, has a tile in the
control center while it's in reach, with its charge, and a page to ring it,
ping it or send it what's copied; its charge is on the battery's card too.
What it says comes as KDE Connect's notifications.

## The dock

It has the apps it keeps and those with windows, all of them or only its
screen's, and a right click on one has its windows, what else it can start,
bringing its windows here, keeping it and closing it. Its icons grow under the
pointer, an app hops, grows or rocks as it starts and while it asks to be
looked at, a dot, a line or a dot for each window marks one that's open, and
it can have a button for the launcher, and stay in sight on an empty workspace
where it hides. An app has how many of its notifications are unread, and a line
goes after the apps it keeps. An app with a window, carried out of the dock
onto a workspace of the bar, has that window go there.

## The launcher

It finds apps, and their own actions by their names too, as New Private
Window. The button in its field, or Ctrl+G, has the groups apps go by in the
list's place: folders of your own, made on its page of the settings and filled
from an app's menu in the launcher, and the kinds apps say they are, Games,
Programming, Design and the like; with one picked, the list and the search are
that group's.

- `/win` has the windows: Shift+Enter on one closes it.
- `/ps` has your processes, the busiest first, with how much of the processor
  and the memory each takes: Enter twice ends one, and Shift+Enter twice
  kills it.
- `/shot` takes a screenshot of a part of the screen, the screen or the
  window in focus, with the latest after them: Enter opens one and
  Shift+Enter copies it. With tesseract there, the text off a part of the
  screen goes onto the clipboard from there too, and with satty or swappy, or
  an editor of one's own, the latest is edited; niri's word of one has Edit
  and Text buttons for the same. The Display page has where they go, how long
  they wait, the editor and the text's languages.
- `/color` copies the color of what's clicked next as `#rrggbb`, `/emoji`
  types one, `/timer` and `/todo` are above.
- A `>` in front runs the rest as a command, and a `?` looks it up on the web,
  at the address its page of the settings has.

## The clipboard

Its history keeps nothing while it's paused, by the button in its panel, and
it can leave pictures out. A right click on an entry, or Right, shows it whole,
to copy or paste it, as it is or changed there first, open the link in it, or
save the picture, to `saveTo` in the clipboard's settings or Pictures.

## Notifications

The bell beside an app's name in the history keeps it quiet for an hour, eight or
until you say, and the Notifications page lists those that are; a screenshot's
toast opens its folder, copies it or deletes it. A toast under the pointer has
that bell too. Toasts wait every day between two times too, as with Do Not Disturb
on: the quiet hours, on the Notifications page. An app's rule there, or one for
some words, can keep its toasts or its history away, let it through Do Not
Disturb, give it a sound of its own, from the sound theme or a file, and run a
command as one comes, with `OKAERI_APP`, `OKAERI_SUMMARY`, `OKAERI_BODY` and
`OKAERI_URGENCY` in its environment. The on-screen display says what plays after a
key of the player's, too, and as a track starts by itself where its page says so.

## Screens

The Display page has each screen's resolution, scale, turn, adaptive sync and
place beside the others, and turns one off. niri has that at once, and okaeri
has it again as it starts, as a screen comes and as niri reads its config
again; what can leave a screen dark asks in the middle of the screens to be
kept, by Enter or its button, and goes back by itself in fifteen seconds
otherwise. What niri won't do is said in a notification.

With more screens than one, the Bar page picks whose lanes it shows: a
screen's bar can have parts of its own, and "Like the others" has it like every
other again. The Dock page does the same for a screen's dock: where it is, how
large, whether it hides and the rest. The on-screen display and the
notifications show on the screen in focus, or on one of their own, as their
pages say.

## Idling, and games

With nothing done for a while the session locks, the screens go off and the
machine can sleep, each sooner on battery where the Session page says so, and
it sleeps suspended, hibernated, or suspended and later hibernated as logind is
set for that.

A mode for games has nothing move or blur, toasts wait and the machine stay
awake, each as the Session page says: by its tile in the control center, which
is among those left out at first, and by itself while gamemode has a game, as
`gamemoderun` starts one.
