# Working on it

`./try` opens it in a niri of its own, in a window, next to the desktop you
have. `tests/all.sh` runs every test, or those it's given the names of, and
says how long each took; [`tests/part.sh`](../tests/part.sh) says how they
run: the bar and one part of the shell in a niri of its own, in a headless
sway on the iGPU, on a session bus of its own, with nothing of the real
desktop or the machine changed. `tests/measure.sh` prints its start time,
memory and idle CPU, on one screen and two.

The shader the bar recolors its parts with is
[`shell/ui/shaders/recolor.frag`](../shell/ui/shaders/recolor.frag), built
with Qt's `qsb` as it says at its top.
