# blink-emmet-vim

A [blink.cmp](https://github.com/Saghen/blink.cmp) completion source that exposes
[emmet-vim](https://github.com/mattn/emmet-vim) abbreviation expansions as LSP
snippets.

## Requirements

- Neovim >= 0.11
- [blink.cmp](https://github.com/Saghen/blink.cmp)
- [emmet-vim](https://github.com/mattn/emmet-vim)

## Installation

[lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
    "ts7m/blink-emmet-vim",
    dependencies = { "mattn/emmet-vim" },
},

```

Add as source for blink.cmp:

```lua
{
    "Saghen/blink.cmp",
    opts = {
        sources = {
            default = { "emmet" },
            providers = {
                emmet = {
                    name = "emmet",
                    module = "blink_emmet_vim",
                },
            },
        },
    },
},
```

## Configuration

- `filetypes`: File types to activate emmet source

Example:

```lua
providers = {
    emmet = {
        name = "emmet",
        module = "blink_emmet_vim",
        opts = {
            filetypes = { "html", "css" },
        },
    },
},
```

## Thanks

- [https://github.com/mattn/emmet-vim](mattn/emmet-vim): Source of emmet completion
- [https://github.com/dcampos/cmp-emmet-vim](dcampos/cmp-emmet-vim): This project is based of this project, a completion source for nvim-cmp.
