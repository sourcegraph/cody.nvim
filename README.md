# Cody for Neovim!

## Installation

Just add `cody.nvim` to your favourite plugin manager, for example, for example using `lazy.nvim`:

```lua
-- Other plugins
{
    "pjlast/cody.nvim",
    config = function()
        require("cody").setup({
            url = "YOUR_SOURCEGRAPH_URL",
            accessToken = "YOUR_ACCESS_TOKEN",
        })
    end
}
```

## Commands

`cody.nvim` registers 3 commands:

- `:CodyChat`
  - Opens a chat window where you can talk to Cody. Pressing `k` and `j` will move you between the chat and input windows. You can quit the chat screen  by pressing `q`. Send a message by pressing Enter in NORMAL mode.
- `:CodyExplain <message>`
  - This will send a prompt to Cody, attaching any highlighted text as context. Cody will respond in a floating window. You can close the window by pressing `q`.
- `:CodyDiff <message>`
  - This will ask Cody to perform an action on the highlighted code. Cody will respond in a floating window. You can accept Cody's suggestion by pressing Enter, or dismiss it by pressing `q`.
