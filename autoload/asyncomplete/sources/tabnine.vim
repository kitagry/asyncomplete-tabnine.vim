let s:binary_dir = expand('<sfile>:p:h:h:h:h') . '/binaries'
let s:is_win = has('win32') || has('win64')
let s:job = v:null
let s:ctx = v:null

function! asyncomplete#sources#tabnine#completor(opt, ctx)
    call s:get_response(a:opt, a:ctx)
endfunction

function! asyncomplete#sources#tabnine#get_source_options(opts)
    call s:start_tabnine()
    return a:opts
endfunction

function! s:start_tabnine() abort
    let l:tabnine_path = s:get_tabnine_path(s:binary_dir)
    let l:cmd = [
      \   l:tabnine_path,
      \   '--client',
      \   'asyncomplete-vim',
      \   '--log-file-path',
      \   s:binary_dir . '/tabnine.log',
      \ ]
    if has('nvim')
        let s:job = jobstart(l:cmd, {'on_stdout': function('s:on_stdout')})
    else
        let l:job = job_start(l:cmd, {'out_cb': function('s:out_cb')})
        if job_status(l:job) == 'run'
            let s:job = l:job
        endif
    endif
endfunction

function! s:get_response(opt, ctx) abort
    let l:config = get(a:opt, 'config', {'line_limit': 1000, 'max_num_result': 10})
    let l:line_limit = get(l:config, 'line_limit', 1000)
    let l:max_num_result = get(l:config, 'max_num_result', 10)
    let l:pos = getpos('.')
    let l:last_line = line('$')
    let l:before_line = max([1, l:pos[1] - l:line_limit])
    let l:before_lines = getline(l:before_line, l:pos[1])
    if !empty(l:before_lines)
        let l:before_lines[-1] = l:before_lines[-1][:l:pos[2]-1]
    endif
    let l:after_line = min([l:last_line, l:pos[1] + l:line_limit])
    let l:after_lines = getline(l:pos[1], l:after_line)
    if !empty(l:after_lines)
        let l:after_lines[0] = l:after_lines[0][l:pos[2]:]
    endif

    let l:region_includes_beginning = v:false
    if l:before_line == 1
        let l:region_includes_beginning = v:true
    endif

    let l:region_includes_end = v:false
    if l:after_line == l:last_line
        let l:region_includes_end = v:true
    endif

    let l:params = {
       \   'filename': a:ctx['filepath'],
       \   'before': join(l:before_lines, "\n"),
       \   'after': join(l:after_lines, "\n"),
       \   'region_includes_beginning': l:region_includes_beginning,
       \   'region_includes_end': l:region_includes_end,
       \   'max_num_result': l:max_num_result,
       \ }
    call s:request('Autocomplete', l:params, a:opt, a:ctx)
endfunction

function! s:request(name, param, opt, ctx) abort
    let l:req = {
      \ 'version': '1.0.14',
      \ 'request': {
      \     a:name: a:param,
      \   },
      \ }

    if s:job == v:null
        return
    endif

    let l:buffer = json_encode(l:req) . "\n"
    let s:ctx = a:ctx
    if has('nvim')
        call chansend(s:job, l:buffer)
    else
        call ch_sendraw(s:job, l:buffer)
    endif
endfunction

function! s:out_cb(channel, msg) abort
    call s:complete(a:msg)
endfunction

function! s:on_stdout(channel, msg, event) abort
    call s:complete(a:msg)
endfunction

function! s:complete(msg) abort
    let l:col = s:ctx['col']
    let l:typed = s:ctx['typed']

    let l:kw = matchstr(l:typed, '\w\+$')
    let l:lwlen = len(l:kw)

    let l:startcol = l:col - l:lwlen

    let l:response = json_decode(a:msg)
    let l:words = []
    for l:result in l:response['results']
        let l:word = {}

        let l:new_prefix = get(l:result, 'new_prefix')
        if l:new_prefix == ''
            continue
        endif
        let l:word['word'] = l:new_prefix

        if get(l:result, 'old_suffix', '') != '' || get(l:result, 'new_suffix', '') != ''
            let l:user_data = {
               \   'old_suffix': get(l:result, 'old_suffix', ''),
               \   'new_suffix': get(l:result, 'new_suffix', ''),
               \ }
            let l:word['user_data'] = json_encode(l:user_data)
        endif

        let l:word['menu'] = '[tabnine]'
        if get(l:result, 'detail')
            let l:word['menu'] .= ' ' . l:result['detail']
        endif
        call add(l:words, l:word)
    endfor
    call asyncomplete#complete('tabnine', s:ctx, l:startcol, l:words)
endfunction

function! s:get_tabnine_path(binary_dir) abort
    let l:versions = glob(fnameescape(a:binary_dir) . '/*', 1, 1)
    let l:versions = reverse(sort(l:versions))
    for l:version in l:versions
        let l:triple = s:parse_architecture('') . '-' . s:get_os()
        let l:path = join([l:version, l:triple, s:executable_name('TabNine')], '/')
        if filereadable(l:path)
            return l:path
        endif
    endfor
endfunction

function! s:get_os() abort
  if has('macunix')
      return 'apple-darwin'
  elseif has('unix')
      return 'unknown-linux-musl'
  elseif s:is_win
      return 'pc-windows-gnu'
  endif
endfunction

function! s:parse_architecture(arch) abort
    if s:is_win
        " TODO: I don't know how to detect windows' architecture
        return 'x86_64'
    endif

    if has('macunix')
        return s:parse_macos_architecture()
    end

    let l:system = system('file -L "' . exepath(v:progpath) . '"')
    if  l:system =~ 'x86-64' || l:system =~ 'x86_64'
        return 'x86_64'
    endif
    return a:arch
endfunction

function! s:parse_macos_architecture() abort
    let l:system = system('uname -m')
    if  l:system =~ 'x86-64' || l:system =~ 'x86_64'
        return 'x86_64'
    elseif l:system =~ 'arm64'  " m1 mac
        return 'aarch64'
    endif
endfunction

function! s:executable_name(name) abort
    if s:is_win
        return a:name . '.exe'
    endif
    return a:name
endfunction
