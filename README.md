## asyncomplete-tabnine.vim

[asyncomplete](https://github.com/prabirshrestha/asyncomplete.vim) source for [TabNine](https://www.tabnine.com/)

### Installation

For [dein.vim](https://github.com/Shougo/dein.vim)

```vim
if has('win32') || has('win64')
  call dein#add('kitagry/asyncomplete-tabnine.vim', { 'build': 'powershell.exe .\install.ps1'  })
else
  call dein#add('kitagry/asyncomplete-tabnine.vim', { 'build': './install.sh'  })
endif
```

For [vim-plug](https://github.com/junegunn/vim-plug)

```vim
if has('win32') || has('win64')
  Plug 'kitagry/asyncomplete-tabnine.vim', { 'do': 'powershell.exe .\install.ps1' }
else
  Plug 'kitagry/asyncomplete-tabnine.vim', { 'do': './install.sh' }
endif
```

### Registration

```vim
  call asyncomplete#register_source(asyncomplete#sources#tabnine#get_source_options({
    \ 'name': 'tabnine',
    \ 'allowlist': ['*'],
    \ 'completor': function('asyncomplete#sources#tabnine#completor'),
    \ 'config': {
    \   'line_limit': 1000,
    \   'max_num_result': 20,
    \  },
    \ }))
```

#### `line_limit` (default: 1000)

The number of lines before and after the cursor to send to TabNine. If the option is smaller, the performance may be improved.

#### `max_num_results` (default: 10)

The max number of results from Tabnine.

## Inspired

- [deoplete-tabnine](https://github.com/tbodt/deoplete-tabnine)

Copied `install.sh` and `install.ps1` from this plugin.
