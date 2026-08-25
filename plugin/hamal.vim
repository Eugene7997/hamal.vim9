vim9script

if exists('g:loaded_hamal')
  finish
endif
g:loaded_hamal = 1

if !get(g:, 'hamal_no_default_setup', false)
  hamal#Setup()
endif

nnoremap <silent> <Plug>(hamal-split) <Cmd>call hamal#Split()<CR>
onoremap <silent> <Plug>(hamal-split) <Cmd>call hamal#Split()<CR>

if !get(g:, 'hamal_no_default_mappings', false)
  if !hasmapto('<Plug>(hamal-split)', 'n')
    nmap <unique> <leader><leader> <Plug>(hamal-split)
  endif
  if !hasmapto('<Plug>(hamal-split)', 'o')
    omap <unique> <leader><leader> <Plug>(hamal-split)
  endif
endif
