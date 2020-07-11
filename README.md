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

### Registration


```vim
call asyncomplete#register_source(asyncomplete#sources#tabnine#get_source_options({
  \ 'name': 'tabnine',
  \ 'allowlist': ['*'],
  \ 'completor': function('asyncomplete#sources#tabnine#completor'),
  \ }))
```

## Inspired

- [deoplete-tabnine](https://github.com/tbodt/deoplete-tabnine)

Copied `install.sh` and `install.ps1` from this plugin.

## TODO

- [x] Operation Check
    - [x] Windows
    - [x] Mac
    - [x] Ubuntu
