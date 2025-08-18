# She(r)llock 🔍

*Shell script checking and formatting without LSP*

## Documentation

see `:help sherllock`

This plugin helps in formatting and checking of shell scripts without the need for an LSP but still indicating errors and also putting them into a quickfix list for easy navigation. Everything happens with autocmd on `BufWritePost` and `InsertLeave`.

## Dependencies

Relies on `shellcheck` and `shfmt` to work.

## Setup with LazyVim

```lua
return {
    {
        "gwirn/sherllock",
        config = function()
            require("sherllock").setup()
        end,
    }
}
```


### Tested on NVIM v0.11.3
