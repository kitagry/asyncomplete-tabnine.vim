let s:line_limit = 1000
let s:max_num_result = 10
let s:binary_dir = expand('<sfile>:p:h:h:h:h') . '/binaries'
let s:job = v:none
let s:chan = v:none
let s:buffer = ''
let s:ctx = {}
let s:startcol = 0
let s:is_win = has('win32') || has('win64')

function! asyncomplete#sources#tabnine#completor(opt, ctx)
    let l:col = a:ctx['col']
    let l:typed = a:ctx['typed']

    let l:kw = matchstr(l:typed, '\w\+$')
    let l:lwlen = len(l:kw)

    let l:startcol = l:col - l:lwlen

    let s:ctx = a:ctx
    let s:startcol = l:startcol
    call s:get_response(a:opt, a:ctx)
endfunction

function! asyncomplete#sources#tabnine#get_source_options(opts)
    call s:start_tabnine()
    return a:opts
endfunction

function! asyncomplete#sources#tabnine#get_chan()
    return s:chan
endfunction

function! s:start_tabnine() abort
    let l:tabnine_path = s:get_tabnine_path(s:binary_dir)
    let l:cmd = [
      \   l:tabnine_path,
      \   '--client',
      \   'sublime',
      \   '--log-file-path',
      \   s:binary_dir . '/tabnine.log',
      \ ]
    let s:job = job_start(l:cmd)
    if job_status(s:job) == 'run'
        let s:chan = job_getchannel(s:job)
    endif
endfunction

function! s:get_response(opt, ctx) abort
    let l:pos = getpos('.')
    let l:last_line = line('$')
    let l:before_line = max([1, l:pos[1] - s:line_limit])
    let l:before_lines = getline(l:before_line, l:pos[1])
    if !empty(l:before_lines)
        let l:before_lines[-1] = l:before_lines[-1][:l:pos[2]-1]
    endif
    let l:after_line = min([l:last_line, l:pos[1] + s:line_limit])
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
       \   'max_num_result': s:max_num_result,
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

    if s:chan == v:none
        return
    endif

    let s:buffer = json_encode(l:req) . "\n"
    call ch_setoptions(s:chan, {"callback": function("s:out_cb", [a:opt, a:ctx])})
    call ch_sendraw(s:chan, s:buffer)
endfunction

function! s:out_cb(opt, ctx, channel, msg) abort
    let l:col = a:ctx['col']
    let l:typed = a:ctx['typed']

    let l:kw = matchstr(l:typed, '\w\+$')
    let l:lwlen = len(l:kw)

    let l:startcol = l:col - l:lwlen

    let l:response = json_decode(a:msg)
    let l:words = []
    for l:result in l:response['results']
        let l:word = []
        call add(l:word, l:result['new_prefix'])
        if has_key(l:result, 'detail')
            call add(l:word, l:result['detail'])
        else
            call add(l:word, '')
        endif
        call add(l:words, l:word)
    endfor
    let l:matches = map(l:words, {_, val -> {"word": val[0],"dup":1,"icase":1,"menu": '[tabnine:' . val[1] . ']'}})
    call asyncomplete#complete('tabnine', a:ctx, l:startcol, l:matches)
endfunction

function! s:get_tabnine_path(binary_dir) abort
    let l:os = ''
    if has('macunix')
        let l:os = 'apple-darwin'
    elseif has('unix')
        let l:os = 'unknown-linux-gnu'
    elseif s:is_win
        let l:os = 'pc-windows-gnu'
    endif

    let l:versions = glob(fnameescape(a:binary_dir) . '/*', 1, 1)
    let l:versions = reverse(sort(l:versions))
    for l:version in l:versions
        let l:triple = s:parse_architecture('') . '-' . l:os
        let l:path = join([l:version, l:triple, s:executable_name('TabNine')], '/')
        if filereadable(l:path)
            return l:path
        endif
    endfor
endfunction

function! s:parse_architecture(arch) abort
    if s:is_win
        " TODO: I don't know how to detect windows' architecture
        return 'x86_64'
    endif

    let l:system = system('file -L "' . exepath(v:progpath) . '"')
    if  l:system =~ 'x86-64' || l:system =~ 'x86_64'
        return 'x86_64'
    endif
    return a:arch
endfunction

function! s:executable_name(name) abort
    if s:is_win
        return a:name . '.exe'
    endif
    return a:name
endfunction
