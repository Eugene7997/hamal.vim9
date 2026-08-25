# hamal.vim9

Fast recursive line navigation for classic Vim, in pure Vim9script. A
Vim9script port of [hamal.nvim](https://github.com/ergodice/hamal.nvim).

Hamal lets you jump to any line on screen by repeatedly narrowing the
visible range into divisions and picking one, instead of counting lines 
or scrolling.

## Requirements

- Vim 9.0+ compiled with `+eval` (vim9script is not supported by Neovim,
  so this plugin will not load there)

## Installation

### vim-plug

```vim
Plug 'Eugene7997/hamal.vim9'
```

### vim9-native packages (no plugin manager)

```sh
git clone https://github.com/Eugene7997/hamal.vim9 ~/.vim/pack/plugins/start/hamal.vim9
```

Vim loads everything under `pack/*/start/*` automatically, no further
config required.

### Other managers

Any manager that can install a plain git-based Vim plugin (vim-plug,
minpac, dein, Vundle, packer-style managers, etc.) works, since this 
repo follows the standard `plugin/` + `autoload/` layout.

## Usage

By default, `<leader><leader>` enters hamal mode in normal mode. It splits
the currently visible window range into three sections, highlighting the
first one, and waits for a key:

> If <leader> is unconfigured in vim9+, it may be backslash "\".

| Key | Action |
| --- | --- |
| `h` | Focus the first (top) section, narrowing into it |
| `m` | Focus the second (middle) section, narrowing into it |
| `l` | Focus the third (bottom) section, narrowing into it |
| `H` | Jump to the top line of the current section and quit |
| `M` | Jump to the middle line of the current section and quit |
| `L` | Jump to the bottom line of the current section and quit |
| `-` | Undo the last focus, widening back out one level |
| `s` | Select the current section linewise (Visual mode) and quit |
| `<Esc>` | Quit hamal mode without moving |

Any other key quits hamal mode (by default) and is replayed as normal
input.

`<leader><leader>` is also mapped in operator-pending mode. This lets you
use hamal navigation to pick a range for an operator: for example,
`d<leader><leader>hs` deletes the top section. Vim applies the pending
operator to whatever range `s` leaves selected (see `:help o_v`), so this
works with any operator, not just `d`.

## Configuration

Call `hamal#Setup()` yourself with overrides, and set
`g:hamal_no_default_setup = true` to stop the plugin from calling it with
defaults on load.

E.g. in your `.vimrc` file, you can add the following:

```vim
let g:hamal_no_default_setup = 1
call hamal#Setup(#{
      \ divisions: 4,
      \ quit_on_unmapped_keys: v:true,
      \ highlights: #{
      \   section: [['HamalFirstSection', #{guibg: '#d0d0d0', ctermbg: 252}], ['HamalSecondSection', #{guibg: '#eeeeee', ctermbg: 255}]],
      \   border: [],
      \ },
      \ })
nmap <Space><Space> <Plug>(hamal-split)
```

### Colors

A highlight spec is either `{link: 'GroupName'}` or a dict of the usual
`:highlight` attributes: `guifg`, `guibg`, `guisp`, `gui`, `ctermfg`,
`ctermbg`, `cterm`.

The defaults are plain grey backgrounds with no foreground, so your syntax
colors keep showing through the band. They are picked from `&background` and
from how many colors the terminal actually has:

| | `background=light` | `background=dark` |
|---|---|---|
| **256 colors** | | |
| `HamalFirstSection` (top/bottom thirds) | `ctermbg=252 guibg=#d0d0d0` | `ctermbg=243 guibg=#727272` |
| `HamalSecondSection` (middle third) | `ctermbg=255 guibg=#eeeeee` | `ctermbg=236 guibg=#303030` |
| **16 colors** | | |
| `HamalFirstSection` (top/bottom thirds) | `ctermbg=7 guibg=#d0d0d0` | `ctermbg=8 guibg=#727272` |
| `HamalSecondSection` (middle third) | *(no ctermbg)* `guibg=#eeeeee` | *(no ctermbg)* `guibg=#303030` |

#### Check `&t_Co` before using a cterm index above 15

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

#### Linking is gui-only in practice

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

#### Your own colors

If you want your own colors, give both the gui and the cterm values. The
`ctermfg`/`ctermbg`/`cterm` you supply are passed through to `:highlight`
verbatim and are never overridden by the plugin:

```vim
let g:hamal_no_default_setup = 1
call hamal#Setup(#{
      \ highlights: #{
      \   section: [
      \     ['HamalFirstSection', #{guibg: '#00c8ff', guifg: '#ffff00', ctermbg: 8}],
      \     ['HamalSecondSection', #{guibg: '#00ff15', guifg: '#ffffff'}],
      \     ['HamalThirdSection', #{guibg: '#ff0000', guifg: '#000000', ctermbg: 8, ctermfg: 15}],
      \   ],
      \   border: [],
      \ },
      \ })
```

The `guifg`/`guibg` values apply when `'termguicolors'` is on (or in gvim);
the `ctermfg`/`ctermbg` values apply otherwise:

```vim
:set termguicolors
```

Two things worth knowing when picking colors:

- **Set a foreground whenever you set a background.** With only `guibg`,
  the buffer's own syntax foreground keeps showing through, which can land
  on an unreadable combination.
- **Palette indices 16-255 are not fixed colors.** Terminal themes remap
  them, so pick the indices that look right in *your* terminal rather than
  assuming the canonical xterm values.

The plugin sets exactly the attributes you give it. A spec with only gui
colors therefore has no visible effect in a terminal without
`'termguicolors'`; use `link`, or supply cterm values, for those.

### Options

- `divisions` (number, default `3`): how many sections to split the
  current range into at each level.
- `quit_on_unmapped_keys` (bool, default `true`): whether pressing a key
  not in `keymaps` exits hamal mode (and replays the key) instead of being
  ignored.
- `keymaps` (dict, default: see below): maps a `keytrans()`-normalized key
  string to a `func(): void` to call while in hamal mode. Overriding this
  replaces the whole table (it is not merged key-by-key).
- `highlights.section` (list): highlight groups cycled across the
  sections, in order, each entry `[name, spec]` where `spec` is either
  `{link: 'GroupName'}` or a dict of `guifg`/`guibg`/`guisp`/`gui`/
  `ctermfg`/`ctermbg`/`cterm` keys. Defaults to a pair of neutral greys
  picked from `&background`. See [Colors](#colors).
- `highlights.border` (list): optional highlight groups for section
  borders; entries are the same shape as `section`, or a
  `{top: [...], bottom: [...]}` dict for distinct top/bottom border
  highlights. Replaced wholesale, not merged.

### Mappings

The plugin exposes `<Plug>(hamal-split)` for the entry point. Map it to
whatever key you like:

```vim
nmap <leader><leader> <Plug>(hamal-split)
```

Set `g:hamal_no_default_mappings = true` to stop the plugin from mapping
`<leader><leader>` itself.

The plugin checks `hasmapto('<Plug>(hamal-split)', ...)` first, so it
won't touch `<leader><leader>` if something already routes to
`<Plug>(hamal-split)` (e.g. you mapped it yourself under a different key).
But if `<leader><leader>` is claimed by an unrelated mapping, the default
mapping uses `<unique>` and will fail loudly with `E227: mapping already
exists` instead of silently overwriting it; set
`g:hamal_no_default_mappings = true` and map `<Plug>(hamal-split)` to a
free key yourself.

## Local development

### Windows + gVim

If you're working on this repo, you can consider symlink into the pack 
directory instead of copying it, so that edits show up immediately:

```powershell
New-Item -ItemType Directory -Force -Path "C:\Users\<you>\vimfiles\pack\plugins\start"
New-Item -ItemType SymbolicLink -Path "C:\Users\<you>\vimfiles\pack\plugins\start\hamal.vim9" -Target "C:\...\path\to\hamal"
```

> Creating a symlink may need an elevated PowerShell (Run as Administrator).

**Note the path is `pack\plugins\start`, not `plugin\start`.** Vim's
startup runs `runtime! plugin/**/*.vim`, which recursively sources every
`.vim` file nested anywhere under any `plugin/` directory on the
runtimepath. If the symlink lands under `vimfiles\plugin\...` instead of
`vimfiles\pack\...\start\...`, Vim will still find and source
`plugin/hamal.vim` and `autoload/hamal.vim`, but it will *also* source
`test/test_hamal.vim` on every startup (since it's nested under the same
`plugin/` tree), running the test suite unconditionally instead of
loading the plugin properly.

Verify it loaded correctly with:

```vim
:scriptnames
```

You should see `pack\plugins\start\hamal.vim9\plugin\hamal.vim` and
`autoload\hamal.vim` in the list, and no `test_hamal.vim`.

## Testing

Run the headless smoke tests from the plugin root with real Vim 9+:

```sh
vim -Nu NONE -i NONE --not-a-term -c "source test/test_hamal.vim" -c "qa!"
```

or:

```sh
./test/run.sh
```

## Disclaimer

This `README.md` was generated with GenAI. I asked it to note down configurations 
that gave me troubles along the way but I didn't review it thoroughly. View it with 
a hint of salt.

I mainly built this for myself and did not test it with various different setups.
