# How it looks

## The bar

The bar is one piece across the screen, an island for each lane, or a capsule
for each part, as the Look page has it. A part chosen on the Bar page can have
a capsule of its own all the same, and a fill and a color for its icons and
words: one of a few, one typed, or one taken off the screen. The accent and the
warnings keep theirs. Separators and spaces go between parts as any part does,
as many as wanted. Workspaces can say their numbers as they are, in Roman, in
kanji or in circles, and be round or square.

## Layouts and windows

The Look page has layouts, a click each, drawn small: where the bar is and
how, what's on it, and the dock, with "As it was" to take the last one back.
It sets how niri draws windows too, in the theme's colors: the gaps between
them, a border, the ring around the one in focus and their corners, or leaves
them to niri's config. How fast things move, how panels and notifications
come, growing, fading, sliding, springing or dropping in, and how wide panels
are, are there too, with the font, picked from those installed.

## Colors

Its colors are a palette's: `extends` in `theme.json` names one of
`shell/themes`, your own `colors` go over it, and `palettes` there adds more by
name. The settings window picks one too, or two, for the day and for the
night, showing each by its colors, and can take the accent from the
wallpaper, or all of its colors, or have one of your own over any palette's,
`accent` in `theme.json` as `#rrggbb`. The Look page keeps a look by a name,
all that it set, to have it on again later.

## The wallpaper and the desktop

The Wallpaper page picks a picture of a folder, one for each screen, and one
for the light colors, by a right click on it. With `curl` there it looks on
Wallhaven too, only when asked, for pictures safe for work as large as the
screen: one picked is fetched into the folder and goes up.

Over the wallpaper and under the windows, the desktop can have the time, the
weather, what plays with its buttons, and what the calendars have coming, at a
corner or in the middle, or dragged anywhere on a screen, where they stay on
it: on the Wallpaper page, with how pictures show.

## Other apps in the same colors

Other apps can have the shell's colors too, as matugen and pywal give them out:
a template is written to a file of the app's as the colors change, from light
to dark and back as well, and again as the template itself changes. In a
template `{{accent}}` is that color as `#rrggbb`, `{{accent.strip}}` the same
without the `#` and `{{accent.rgb}}` as `r, g, b`, and so for every color of
the palette; `{{mode}}` is `light` or `dark`, and what it doesn't know stays as
it is. A file is written only when that changes it, and before the colors'
command runs, which can then have the app read it again. They're `templates`
in the `hooks`, and on the Session page, with `~` for your home:

```json
{ "hooks": { "templates": [
    { "from": "kitty.conf", "to": "~/.config/kitty/okaeri.conf" },
    { "from": "~/my/colors.css", "to": "~/.config/myapp/colors.css" }
] } }
```

A `from` that isn't a whole path is one that comes with okaeri, in
`shell/templates`, wherever it's installed: `kitty.conf`, `foot.ini`,
`alacritty.toml`, `ghostty`, `wezterm.toml`, `tmux.conf`, `btop.theme`,
`fuzzel.ini`, `qtct.conf` for qt6ct and qt5ct, and `gtk3.css` and `gtk4.css`,
for `~/.config/gtk-3.0/gtk.css` and `~/.config/gtk-4.0/gtk.css`. Each says at
its top where to write it and what to put in the app's own config to take it
in, and a click on its name on the Session page adds it so. Colors that let
what's under them through, as `dim` does, are written as they look over the
background.

## The language

okaeri's own words are in English, or in Russian where the locale is, or where
the Look page says; another language is a file in `shell/i18n`, the English
words to its own, as `ru.json` has them. A few words put together with numbers
are English yet.
