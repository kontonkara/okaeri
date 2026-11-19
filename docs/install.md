# Installing it

## install.sh

```sh
curl -fsSL https://raw.githubusercontent.com/kontonkara/okaeri/main/install.sh | sh
```

It puts okaeri in `~/.local/share/okaeri`, offers to get what it needs from
your package manager, and puts two includes in niri's config, between
`okaeri` marks: at the top its start and its keys, which yours override, and
at the end what the shell needs of niri, with how windows look where the Look
page says. Another bar that niri starts, or what does what okaeri does, as
mako or swayidle, it offers to turn off, till okaeri goes, and it says which
services of yours do the same. Running it again updates it;
`~/.local/share/okaeri/install.sh uninstall` takes it all away again, and your
settings if you say so.

## What it needs

niri 26.04 or newer and Quickshell 0.3 or newer, and in `PATH`:

- `cliphist`, `wl-clipboard`, `wtype`, `qalc`, `notify-send` and `pw-play`,
  and the freedesktop sound theme for sounds
- `wlsunset` for the night light, `wf-recorder` to record the screen and
  `slurp` for a part of it
- `ddcutil` for external monitors' brightness, with `/dev/i2c-*` yours
- `nmcli` for VPNs, the hotspot and sharing Wi-Fi, `qrencode` for the code a
  phone joins it by
- `udisksctl` for the drives one plugs in, KDE Connect's `kdeconnect-cli` for a
  phone
- `tesseract` for the text in screenshots, `satty` or `swappy` to edit them
- `curl` for pictures from Wallhaven, `cava` for the sound's bars

`okaeri doctor` says what of that is here, and what each thing missing is
for.

## By hand

`bin/okaeri` runs it from a clone of this repository, on any distribution.
In niri's config:

```kdl
spawn-at-startup "/path/to/okaeri/bin/okaeri"

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

// What the shell needs of niri, in a file it keeps itself: at the end, where
// how windows look, as the Look page says, goes over what comes before.
include optional=true "~/.local/state/okaeri/niri.kdl"
```

niri's default config has Mod+V and Mod+Escape for itself, hence those keys.
Without the `include` it all runs still, but blur only has the wallpaper to
show and not the windows, the overview has no blurred wallpaper behind it,
screencasts show the notifications, and the Look page can't change how
windows look.

## Nix

The flake has the package and a Home Manager module, `programs.okaeri`, whose
`settings` and `theme` are `settings.json` and `theme.json`:

```nix
{
  inputs.okaeri.url = "github:kontonkara/okaeri";

  # in a Home Manager module:
  imports = [ inputs.okaeri.homeManagerModules.default ];
  programs.okaeri = {
    enable = true;
    settings.bar.look = "islands";
    theme.accent = "#3366cc";
  };
}
```

It starts the shell as a service of the session, so niri needs no
`spawn-at-startup` for it; the keys and the `include` are as above. The settings
window copies all that's set as Nix for it, by the button beside "Back to the
config".
