# Colors

This covers the gotchas behind `highlights.section` / `highlights.border`.
For the basic shape of a highlight spec and the shipped defaults, see the
[Colors section in the README](../README.md#colors).

## Check `&t_Co` before using a cterm index above 15

Vim does not reject an out-of-range `ctermbg`. It **masks it to the low four
bits**, so on a 16-color terminal you get a wrong color rather than an
error:

```
ctermbg=239  ->  239 & 15 = 15  ->  White
ctermbg=236  ->  236 & 15 = 12  ->  LightRed
```

This bites on Windows in particular: the console build reports `t_Co=16`
with `term=win32`, so the whole 232-255 greyscale ramp collapses onto a
handful of bright ANSI colors. Check what you actually have before picking
values:

```vim
:echo &t_Co
```

If it reports `16` and your terminal can do better, `:set termguicolors`
(available whenever `has('vtp')` or a truecolor terminal) switches rendering
to the `guibg` values and sidesteps the palette entirely.

## Linking is gui-only in practice

`{link: 'GroupName'}` is tempting, but check the group in a terminal before
relying on it. Several of the groups that look like a subtle tint in gui are
*attribute*-based in cterm, and attributes do not tint:

```
Visual       cterm=reverse    guibg=LightGrey / #575757
CursorLine   cterm=underline  guibg=Grey90 / Grey40
ColorColumn  ctermbg=12 / 4   guibg=LightRed / DarkRed
```

Linking a section to `Visual` gives you a soft grey band in gui and a solid
inverted block in a terminal, because `reverse` swaps foreground and
background instead of tinting. `CursorLine` gives you no background at all
in a terminal, only an underline. That is why the shipped defaults use
explicit values rather than links.

Linking is still the right choice when you specifically want to follow the
colorscheme, and when you have confirmed the target group is colored rather
than attribute-based in both modes.
