syntax enable           " enable syntax processing
set tabstop=4           " number of visual spaces per TAB
set softtabstop=4       " number of spaces in tab when editing
set expandtab           " tabs are spaces
set showcmd             " show command in bottom bar
set number              " show line numbers 
set scrolloff=2

set ai "Auto indent
set si "Smart indent
set wrap "Wrap lines

filetype indent on      " load filetype-specific indent files
set wildmenu            " visual autocomplete for command menu
set lazyredraw          " redraw only when we need to.
set showmatch           " highlight matching [{()}]

set incsearch           " search as characters are entered
set hlsearch            " highlight matches

augroup qs_colors
  autocmd!
  autocmd ColorScheme * highlight QuickScopePrimary guifg='#afff5f' gui=underline ctermfg=155 cterm=underline
  autocmd ColorScheme * highlight QuickScopeSecondary guifg='#5fffff' gui=underline ctermfg=81 cterm=underline
augroup END

set termguicolors
colorscheme xcodedarkhc 

" transparent background
highlight Normal guibg=NONE ctermbg=NONE
highlight NonText guibg=NONE ctermbg=NONE
highlight EndOfBuffer guibg=NONE ctermbg=NONE

" vim airline theme
let g:airline_theme='bubblegum'

let g:airline_powerline_fonts=1
let g:airline_left_sep = "\uE0B8"
let g:airline_right_sep = "\uE0BE"

set guifont=Cascadia\ Mono\ PL

" Enable completion where available.
" This setting must be set before ALE is loaded.
"
" You should not turn this setting on if you wish to use ALE as a completion
" source for other completion plugins, like Deoplete.
let g:ale_completion_enabled = 1

" Rainbow brackets config
let g:rainbow_active = 1
let g:rainbow_conf = {
\	'guifgs': ['slateblue3', 'skyblue2', 'turquoise2', 'lightgreen'],
\	'separately': {
\		'nerdtree': 0,
\	}
\}

" quick-scope config
let g:qs_highlight_on_keys = ['f', 'F', 't', 'T']

" Cursor in terminal
" https://vim.fandom.com/wiki/Configuring_the_cursor
" 1 or 0 -> blinking block
" 2 solid block
" 3 -> blinking underscore
" 4 solid underscore
" Recent versions of xterm (282 or above) also support
" 5 -> blinking vertical bar
" 6 -> solid vertical bar

if &term =~ "xterm\\|rxvt"
  " normal mode
  let &t_EI .= "\<Esc>[1 q"
  " insert mode
  let &t_SI .= "\<Esc>[5 q"

  " Reset cursor on startup
  augroup ResetCursorShape
  au!
  autocmd VimEnter * normal! :startinsert :stopinsert
  augroup END
endif