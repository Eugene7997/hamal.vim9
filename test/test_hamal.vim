vim9script

# Headless smoke test for autoload/hamal.vim.
# Requires real Vim 9+ (vim9script is not supported by Neovim).
#
# Run from the plugin root with:
#   vim -Nu NONE -i NONE --not-a-term -c "source test/test_hamal.vim" -c "qa!"
#
# Note: must run in plain batch mode, not "-es" (Ex-silent) — Visual mode
# and the '</'> marks don't behave correctly under -es.

var failures = 0
var results: list<string> = []

def Assert(cond: bool, msg: string): void
  if !cond
    failures += 1
    add(results, $'FAIL: {msg}')
  else
    add(results, $'ok:   {msg}')
  endif
enddef

var root = expand('<sfile>:p:h:h')
execute $'set rtp+={root}'

# 30-line scratch buffer
enew!
setline(1, range(1, 30)->mapnew((_, v) => $'line {v}'))

hamal#Setup()

# Enter hamal mode, then feed keys for the blocking getcharstr() loop to consume.
feedkeys('hhs', 'nt')
hamal#Split()

# 'h' focuses division 1 twice (narrowing), then 's' selects -> Visual mode, linewise.
Assert(mode() == 'V', $'mode after select is Visual-line, got {string(mode())}')

execute "normal! \<Esc>"

var startline = line("'<")
var endline = line("'>")
Assert(startline == 1, $'select start line, got {startline}')
Assert(endline <= 5, $'select end line narrowed down, got {endline}')

# Regression: narrowing into a range smaller than config.divisions used to
# throw "invalid split range" because Highlight() tried to subdivide the
# already-too-small current range before checking IsFinished(). A 5-line
# buffer with the default 3 divisions produces a 2-line first child, which
# reproduces it in a single 'h' press.
enew!
setline(1, range(1, 5)->mapnew((_, v) => $'small {v}'))
var threw = false
var thrownMsg = ''
try
  feedkeys('h', 'nt')
  hamal#Split()
catch
  threw = true
  thrownMsg = v:exception
endtry
Assert(!threw, $'focusing into an undersized range does not throw (got: {thrownMsg})')
Assert(line('.') == 1, $'cursor lands on middle (rounds down) of the 2-line child, got {line(".")}')

# Test Top/Middle/Bottom jump-and-quit shortcuts (H/M/L)
enew!
setline(1, range(1, 9)->mapnew((_, v) => $'row {v}'))
feedkeys('M', 'nt')
hamal#Split()
Assert(line('.') == 5, $'M jumps to middle line of 9-line split, got {line(".")}')

for line in results
  echom line
endfor

if failures == 0
  echom 'ALL TESTS PASSED'
else
  echom $'{failures} TEST(S) FAILED'
  cquit 1
endif
