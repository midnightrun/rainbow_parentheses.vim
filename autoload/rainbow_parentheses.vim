"==============================================================================
"  Description: Rainbow colors for parentheses, based on rainbow_parenthsis.vim
"               by Martin Krischik and others.
"==============================================================================

function! s:uniq(list)
  let ret = []
  let map = {}
  for items in a:list
    let ok = 1
    for item in filter(copy(items), '!empty(v:val)')
      if has_key(map, item)
        let ok = 0
      endif
      let map[item] = 1
    endfor
    if ok
      call add(ret, items)
    endif
  endfor
  return ret
endfunction

function! s:colors_to_hi(colors)
  return
    \ join(
    \   values(
    \     map(
    \       filter({ 'ctermfg': a:colors[0], 'guifg': a:colors[1] },
    \              '!empty(v:val)'),
    \       'v:key."=".v:val')), ' ')
endfunction

function! s:extract_fg(line)
  let cterm = get(matchlist(a:line, 'ctermfg=\(\S*\)'), 1, '')
  let gui = get(matchlist(a:line, 'guifg=\(\S*\)'), 1, '')
  return [cterm, gui]
endfunction

function! s:extract_colors()
  redir => output
    silent hi
  redir END
  let lines = filter(split(output, '\n'), 'v:val =~# "fg" && v:val !~# "bg"')
  let colors = s:uniq(reverse(map(lines, 's:extract_fg(v:val)')))
  let blacklist = {}
  for c in get(g:, 'rainbow#blacklist', [])
    let blacklist[c] = 1
  endfor
  let colors = filter(colors, '!has_key(blacklist, v:val[0]) && !has_key(blacklist, v:val[1])')
  return map(colors, 's:colors_to_hi(v:val)')
endfunction

function! s:show_colors()
  for level in reverse(range(1, b:rainbow_max_level))
    execute 'hi rainbowParensShell'.level
  endfor
endfunction

function! rainbow_parentheses#activate()
  let max = get(g:, 'rainbow#max_level', 16)
  let colors = exists('g:rainbow#colors') ?
    \ map(copy(g:rainbow#colors[&bg]), 's:colors_to_hi(v:val)') :
    \ s:extract_colors()

  for level in range(1, max)
    let col = colors[(level - 1) % len(colors)]
    execute printf('hi rainbowParensShell%d %s', max - level + 1, col)
  endfor
  call s:regions(max)

  command! -bang -nargs=? -bar RainbowParenthesesColors call s:show_colors()
  augroup rainbow_parentheses
    autocmd!
    autocmd ColorScheme,Syntax * call rainbow_parentheses#activate()
  augroup END
  let b:rainbow_max_level = max
endfunction

function! rainbow_parentheses#deactivate()
  if exists('b:rainbow_max_level')
    for level in range(1, b:rainbow_max_level)
      execute 'hi clear rainbowParensShell'.level
      execute 'syntax clear rainbowParens'.level
    endfor
    augroup rainbow_parentheses
      autocmd!
    augroup END
    augroup! rainbow_parentheses
    unlet b:rainbow_max_level
    delc RainbowParenthesesColors
  endif
endfunction

function! rainbow_parentheses#toggle()
  if exists('b:rainbow_max_level')
    call rainbow_parentheses#deactivate()
  else
    call rainbow_parentheses#activate()
  endif
endfunction

function! s:regions(max)
  let pairs = get(g:, 'rainbow#pairs', [['(',')']])
  for level in range(1, a:max)
    let cmd = 'syntax region rainbowParens%d matchgroup=rainbowParensShell%d start=/%s/ end=/%s/ contains=%s'
    let children = extend(['TOP'], map(range(level, a:max), '"rainbowParens".v:val'))
    for pair in pairs
      let [open, close] = map(copy(pair), 'escape(v:val, "[]/")')
      execute printf(cmd, level, level, open, close, join(children, ','))
    endfor
  endfor
endfunction

