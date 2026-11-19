# Commands

`okaeri commands` lists all that binds and scripts can call, as the running
shell has it; `okaeri doctor` says what of what it needs is here. Some of
them:

| Command | What it does |
| --- | --- |
| `okaeri launcher open "/emoji "` | the launcher, at the emoji |
| `okaeri clipboard toggle`, `pause`, `resume` | the clipboard's history, and keeping nothing for a while |
| `okaeri session toggle`, `session run lock` | the session menu, or what it would do |
| `okaeri settings toggle`, `settings open Wallpaper` | the settings window, at a page |
| `okaeri settings get dock.magnify`, `set`, `reset`, `config nix`, `schema` | one setting, all of them, their schema |
| `okaeri bar toggle` | the bar hides, or stays |
| `okaeri bar update <name>` | a part of your own runs again now, `""` every one |
| `okaeri dock toggle`, `dock pin firefox`, `unpin` | the dock, and what it keeps |
| `okaeri calendar toggle`, `media card`, `battery toggle`, `load toggle` | the bar's cards |
| `okaeri notes add`, `notes toggle` | things to do |
| `okaeri timer start 10m` (`1h30m`, `45s`, `1:30`), `stopwatch toggle`, `reset` | a timer, the stopwatch |
| `okaeri pomodoro start`, `stop` | pomodoros |
| `okaeri volume up 5`, `set 40`, `output next`; `mic`, `brightness`, `keylight` the same | levels, and where the sound goes |
| `okaeri night warmth 3000` | how warm the night light is |
| `okaeri battery limit true` | the charge stops short of full, where UPower can |
| `okaeri drives list` | the drives plugged in |
| `okaeri phone ring` | the phone, by a key |
| `okaeri screenshot take area`, `screen`, `window` | a screenshot |
| `okaeri record toggle` | a recording of the screen |
| `okaeri color pick` | the color of what's clicked next, copied |
| `okaeri game toggle` | the mode for games |
| `okaeri theme toggle`, `theme accent '#3366cc'`, `theme look evening` | the day's or the night's palette, an accent, a look kept by a name |
| `okaeri wallpaper next`, `wallpaper set <file>` | another picture |
| `okaeri layouts list`, `take <name>`, `back` | a layout, or the last one taken back |
| `okaeri plugins list`, `look` | the plugins |

## dmenu

`okaeri dmenu` shows the lines of its standard input in the launcher and
prints the one picked, as dmenu does, with `-p` for a prompt, `--password` to
hide what's typed, `--index` to print where the line picked was, from 0,
`--only-match` to take nothing but a line, and `--select` for the line to
start on.
