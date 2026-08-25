vim9script

# hamal.vim - fast recursive line navigation for classic Vim/gvim.
# A Vim9script port of https://github.com/ergodice/hamal.nvim

# ---------------------------------------------------------------------------
# Split model: a plain {start, finish} dict
# ---------------------------------------------------------------------------

def SplitNew(start: number, finish: number): dict<number>
  if start > finish
    throw $'hamal: invalid split range {start}-{finish}'
  endif
  return {start: start, finish: finish}
enddef

def SplitTop(s: dict<number>): number
  return s.start
enddef

def SplitMiddle(s: dict<number>): number
  return (s.start + s.finish) / 2
enddef

def SplitBottom(s: dict<number>): number
  return s.finish
enddef

def SplitLines(s: dict<number>): number
  return s.finish - s.start + 1
enddef

def SplitDivide(s: dict<number>, divisions: number): list<dict<number>>
  var result: list<dict<number>> = []
  var length = SplitLines(s)
  var size = length / divisions
  var remain = length % divisions
  var start = s.start

  for i in range(1, divisions)
    var width = size
    if i <= remain
      width += 1
    endif
    var finish = start + width - 1
    add(result, SplitNew(start, finish))
    start = finish + 1
  endfor

  return result
enddef

def SplitChild(s: dict<number>, index: number, divisions: number): dict<number>
  if index < 1 || index > divisions
    throw $'hamal: index {index} out of range for {divisions} divisions'
  endif
  return SplitDivide(s, divisions)[index - 1]
enddef

# ---------------------------------------------------------------------------
# Config / state
# ---------------------------------------------------------------------------

var config: dict<any> = {}
var controllers: dict<dict<any>> = {}

def DeepExtend(base: dict<any>, extra: dict<any>): dict<any>
  var result = deepcopy(base)
  for [k, v] in items(extra)
    if type(v) == v:t_dict && has_key(result, k) && type(result[k]) == v:t_dict
      result[k] = DeepExtend(result[k], v)
    else
      result[k] = v
    endif
  endfor
  return result
enddef

# This function only matters for a plain terminal. In the GUI, and 
# in a terminal with 'termguicolors' set, Vim uses guifg/guibg.
def Has256(): bool
  if has('gui_running') || &termguicolors
    return true
  endif
  return str2nr(&t_Co) >= 256
enddef

def SetHl(name: string, spec: dict<any>): void
  if empty(name)
    return
  endif
  if has_key(spec, 'link')
    execute $'highlight default link {name} {spec.link}'
    return
  endif

  # ctermfg/ctermbg/cterm given by the user are passed in verbatim.
  var parts: list<string> = []
  for key in ['guifg', 'guibg', 'guisp', 'gui', 'ctermfg', 'ctermbg', 'cterm']
    if has_key(spec, key)
      add(parts, $'{key}={spec[key]}')
    endif
  endfor
  if empty(parts)
    execute $'highlight default {name} cterm=NONE gui=NONE'
  else
    execute 'highlight ' .. name .. ' ' .. join(parts, ' ')
  endif
enddef

# Set once the user supplies their own section highlights, so that later
# Setup() calls stop overwriting them with the &background-derived defaults.
var userSections = false

export def Setup(opts: dict<any> = {}): void
  config = DeepExtend(config, opts)

  if has_key(opts, 'highlights') && has_key(opts.highlights, 'section')
    config.highlights.section = opts.highlights.section
    userSections = true
  elseif !userSections
    config.highlights.section = DefaultSections()
  endif

  if has_key(opts, 'highlights') && has_key(opts.highlights, 'border')
    config.highlights.border = opts.highlights.border
  endif

  for pair in config.highlights.section
    SetHl(pair[0], pair[1])
  endfor

  for entry in config.highlights.border
    if type(entry) == v:t_dict && has_key(entry, 'top')
      SetHl(entry.top[0], entry.top[1])
      SetHl(entry.bottom[0], entry.bottom[1])
    elseif !empty(entry)
      SetHl(entry[0], entry[1])
    endif
  endfor
enddef

const SIGN_GROUP = 'hamal'
var definedSigns: dict<bool> = {}

def SignName(hlgroup: string): string
  return $'Hamal_{hlgroup}'
enddef

def DefineSign(hlgroup: string): string
  var name = SignName(hlgroup)
  if !has_key(definedSigns, hlgroup)
    sign_define(name, {linehl: hlgroup})
    definedSigns[hlgroup] = true
  endif
  return name
enddef

def PlaceLineHl(bufnr: number, lnum: number, hlgroup: string): void
  sign_place(0, SIGN_GROUP, DefineSign(hlgroup), bufnr, {lnum: lnum})
enddef

def HighlightLines(bufnr: number, hlgroup: string, top: number, bottom: number): void
  for lnum in range(top, bottom)
    PlaceLineHl(bufnr, lnum, hlgroup)
  endfor
enddef

def GetHl(kind: string, div: number): any
  var groups = config.highlights[kind]
  var count = len(groups)
  if count == 0
    return []
  endif
  var idx = div % count
  return idx == 0 ? groups[count - 1] : groups[idx - 1]
enddef

def ClearHighlight(ctrl: dict<any>): void
  sign_unplace(SIGN_GROUP, {buffer: ctrl.bufnr})
enddef

def Highlight(ctrl: dict<any>): void
  ClearHighlight(ctrl)

  var children = SplitDivide(ctrl.current, config.divisions)

  for div in range(1, config.divisions)
    var child = children[div - 1]

    var sectionHl = GetHl('section', div)
    if !empty(sectionHl) && !empty(sectionHl[0])
      HighlightLines(ctrl.bufnr, sectionHl[0], SplitTop(child), SplitBottom(child))
    endif

    var borderHl = GetHl('border', div)
    if !empty(borderHl)
      if type(borderHl) == v:t_dict && has_key(borderHl, 'top') && has_key(borderHl, 'bottom')
        PlaceLineHl(ctrl.bufnr, SplitTop(child), borderHl.top[0])
        PlaceLineHl(ctrl.bufnr, SplitBottom(child), borderHl.bottom[0])
      else
        PlaceLineHl(ctrl.bufnr, SplitTop(child), borderHl[0])
        PlaceLineHl(ctrl.bufnr, SplitBottom(child), borderHl[0])
      endif
    endif
  endfor

  redraw
enddef

# ---------------------------------------------------------------------------
# Controller lookup
# ---------------------------------------------------------------------------

def CurrentController(): dict<any>
  var key = string(win_getid())
  return get(controllers, key, {})
enddef

def IsFinished(ctrl: dict<any>): bool
  return SplitLines(ctrl.current) <= 1 || SplitLines(ctrl.current) < config.divisions
enddef

def PlaceLine(ctrl: dict<any>, place: number): number
  if place == 1
    return SplitTop(ctrl.current)
  elseif place == 2
    return SplitMiddle(ctrl.current)
  else
    return SplitBottom(ctrl.current)
  endif
enddef

def SetCursorAt(ctrl: dict<any>, place: number): void
  cursor(PlaceLine(ctrl, place), col('.'))
enddef

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

export def Split(): void
  var winid = win_getid()
  var split = SplitNew(line('w0'), line('w$'))

  var ctrl: dict<any> = {
    winid: winid,
    bufnr: bufnr('%'),
    current: split,
    history: [],
    active: true,
  }
  controllers[string(winid)] = ctrl

  Highlight(ctrl)
  RunLoop(ctrl)
enddef

def RunLoop(ctrl: dict<any>): void
  while ctrl.active
    var c: string
    try
      c = getcharstr()
    catch /^Vim:Interrupt$/
      Quit()
      break
    endtry

    if c == ''
      continue
    endif

    var key = keytrans(c)
    if has_key(config.keymaps, key)
      config.keymaps[key]()
    elseif config.quit_on_unmapped_keys
      Quit()
      feedkeys(c, 'i')
      break
    endif
  endwhile
enddef

export def Focus(index: number): void
  var ctrl = CurrentController()
  if empty(ctrl)
    return
  endif

  try
    var child = SplitChild(ctrl.current, index, config.divisions)
    add(ctrl.history, ctrl.current)
    ctrl.current = child
  catch
    echohl ErrorMsg | echomsg v:exception | echohl None
    return
  endtry

  if IsFinished(ctrl)
    SetCursorAt(ctrl, 2)
    Quit()
    return
  endif

  Highlight(ctrl)
enddef

export def PanFocus(): void
  var ctrl = CurrentController()
  if empty(ctrl) || empty(ctrl.history)
    return
  endif
  ctrl.current = remove(ctrl.history, -1)
  Highlight(ctrl)
enddef

export def Quit(): void
  var key = string(win_getid())
  if !has_key(controllers, key)
    return
  endif
  var ctrl = controllers[key]
  ctrl.active = false
  ClearHighlight(ctrl)
  remove(controllers, key)
enddef

export def Top(): void
  var ctrl = CurrentController()
  if empty(ctrl)
    return
  endif
  SetCursorAt(ctrl, 1)
enddef

export def Middle(): void
  var ctrl = CurrentController()
  if empty(ctrl)
    return
  endif
  SetCursorAt(ctrl, 2)
enddef

export def Bottom(): void
  var ctrl = CurrentController()
  if empty(ctrl)
    return
  endif
  SetCursorAt(ctrl, 3)
enddef

# Selects the current split as a linewise Visual selection.
export def Select(): void
  var ctrl = CurrentController()
  if empty(ctrl)
    return
  endif
  cursor(SplitTop(ctrl.current), 1)
  normal! V
  cursor(SplitBottom(ctrl.current), 1)
  Quit()
enddef

# ---------------------------------------------------------------------------
# Default keymap wrappers (h/m/l always map to divisions
# 1/2/3) + default config.
# ---------------------------------------------------------------------------

def FocusFirst(): void
  Focus(1)
enddef

def FocusSecond(): void
  Focus(2)
enddef

def FocusThird(): void
  Focus(3)
enddef

def JumpTopAndQuit(): void
  Top()
  Quit()
enddef

def JumpMiddleAndQuit(): void
  Middle()
  Quit()
enddef

def JumpBottomAndQuit(): void
  Bottom()
  Quit()
enddef

# Default section colors with explicit gui *and* cterm values.
def DefaultSections(): list<any>
  var dark = &background ==# 'dark'

  if !Has256()
    return dark
      ? [['HamalFirstSection', {guibg: '#727272', ctermbg: 8}],
         ['HamalSecondSection', {guibg: '#303030'}]]
      : [['HamalFirstSection', {guibg: '#d0d0d0', ctermbg: 7}],
         ['HamalSecondSection', {guibg: '#eeeeee'}]]
  endif

  return dark
    ? [['HamalFirstSection', {guibg: '#727272', ctermbg: 243}],
       ['HamalSecondSection', {guibg: '#303030', ctermbg: 236}]]
    : [['HamalFirstSection', {guibg: '#d0d0d0', ctermbg: 252}],
       ['HamalSecondSection', {guibg: '#eeeeee', ctermbg: 255}]]
enddef

config = {
  divisions: 3,
  quit_on_unmapped_keys: true,
  keymaps: {
    '<Esc>': Quit,
    'h': FocusFirst,
    'm': FocusSecond,
    'l': FocusThird,
    's': Select,
    'H': JumpTopAndQuit,
    'M': JumpMiddleAndQuit,
    'L': JumpBottomAndQuit,
    '-': PanFocus,
  },
  highlights: {
    section: DefaultSections(),
    border: [],
  },
}
