# oil.nvim (Enhanced Fork)

This is an enhanced fork of [stevearc/oil.nvim](https://github.com/stevearc/oil.nvim) with additional features and improvements.

## Enhanced Features

### Cursor Position Preservation During Refresh
- **Problem Solved**: The original oil.nvim would always move the cursor to the top when refreshing/reloading a directory, causing you to lose your current position and context.
- **Solution**: This fork preserves the cursor position during refresh operations, automatically returning to the same file/directory after refresh completes.
- **How it works**: 
  - Before refresh, the current cursor entry name is stored
  - Uses oil's existing cursor restoration system for consistent behavior
  - After refresh, cursor automatically jumps back to the same file name
  - Falls back gracefully if the file no longer exists

### Git Status Monitoring
- **Feature**: Real-time git status monitoring with visual indicators for file changes
- **How it works**:
  - Periodically runs `git status --porcelain` every 3 seconds (configurable)
  - Highlights modified files with `DiffChange` colors
  - Highlights added/untracked files with `Comment` colors
  - Highlights deleted files with `DiffDelete` colors
  - Works for any git repository without requiring sign column
- **Configuration**:
  ```lua
  require("oil").setup({
    git_status = {
      enabled = true,           -- Enable git status monitoring
      update_interval = 3000,   -- Update every 3 seconds (in milliseconds)
    },
  })
  ```

### Usage
Simply press your refresh key (default `<C-l>`) and the cursor will return to the same file after the directory is refreshed. No more losing your place in large directories!

Git status indicators will automatically appear on files as you modify them, providing instant visual feedback about your repository state.

---

# Original README

# oil.nvim

A [vim-vinegar](https://github.com/tpope/vim-vinegar) like file explorer that lets you edit your filesystem like a normal Neovim buffer.

https://user-images.githubusercontent.com/506791/209727111-6b4a11f4-634a-4efa-9461-80e9717cea94.mp4

<!-- TOC -->

- [Requirements](#requirements)
- [Installation](#installation)
- [Quick start](#quick-start)
- [Options](#options)
- [Adapters](#adapters)
- [Recipes](#recipes)
- [Third-party extensions](#third-party-extensions)
- [API](#api)
- [FAQ](#faq)

<!-- /TOC -->

## Requirements

- Neovim 0.8+
- Icon provider plugin (optional)
  - [mini.icons](https://github.com/echasnovski/mini.nvim/blob/main/readmes/mini-icons.md) for file and folder icons
  - [nvim-web-devicons](https://github.com/nvim-tree/nvim-web-devicons) for file icons

## Installation

oil.nvim supports all the usual plugin managers

<details>
  <summary>lazy.nvim</summary>

```lua
{
  'stevearc/oil.nvim',
  ---@module 'oil'
  ---@type oil.SetupOpts
  opts = {},
  dependencies = { { "echasnovski/mini.icons", opts = {} } },
  -- dependencies = { "nvim-tree/nvim-web-devicons" }, -- use if prefer nvim-web-devicons
}
```

</details>

<details>
  <summary>Packer</summary>

```lua
require('packer').startup(function()
    use {
      'stevearc/oil.nvim',
      config = function() require('oil').setup() end
    }
end)
```

</details>

<details>
  <summary>Paq</summary>

```lua
require "paq" {
    {'stevearc/oil.nvim'};
}
```

</details>

<details>
  <summary>vim-plug</summary>

```vim
Plug 'stevearc/oil.nvim'
```

</details>

<details>
  <summary>dein</summary>

```vim
call dein#add('stevearc/oil.nvim')
```

</details>

<details>
  <summary>Pathogen</summary>

```sh
git clone --depth=1 https://github.com/stevearc/oil.nvim.git ~/.vim/bundle/
```

</details>

<details>
  <summary>Neovim native package</summary>

```sh
git clone --depth=1 https://github.com/stevearc/oil.nvim.git \
  "${XDG_DATA_HOME:-$HOME/.local/share}"/nvim/site/pack/oil/start/oil.nvim
```

</details>

## Quick start

Add the following to your init.lua

```lua
require("oil").setup()
```

Then open a directory with `nvim .`. Use `<CR>` to open a file/directory, and `-` to go up a directory. Otherwise, just treat it like a normal buffer and make edits as you like. Remember to `:w` when you're done to actually perform the actions.

If you want to mimic the `vim-vinegar` method of navigating to the parent directory of a file, add this keymap:

```lua
vim.keymap.set("n", "-", "<CMD>Oil<CR>", { desc = "Open parent directory" })
```

You can open oil in a floating window with `require("oil").toggle_float()`.

## Options

```lua
require("oil").setup({
  -- Oil will take over directory buffers (e.g. `vim .` or `:e src/`)
  -- Set to false if you want some other plugin (e.g. netrw) to open when you edit directories.
  default_file_explorer = true,
  -- Id is automatically added at the beginning, and name at the end
  -- See :help oil-columns
  columns = {
    "icon",
    -- "permissions",
    -- "size",
    -- "mtime",
  },
  -- Buffer-local options to use for oil buffers
  buf_options = {
    buflisted = false,
    bufhidden = "hide",
  },
  -- Window-local options to use for oil buffers
  win_options = {
    wrap = false,
    signcolumn = "no",
    cursorcolumn = false,
    foldcolumn = "0",
    spell = false,
    list = false,
    conceallevel = 3,
    concealcursor = "nvic",
  },
  -- Send deleted files to the trash instead of permanently deleting them (:help oil-trash)
  delete_to_trash = false,
  -- Skip the confirmation popup for simple operations (:help oil.skip-confirm)
  skip_confirm_for_simple_edits = false,
  -- Selecting a new/moved/renamed file or directory will prompt you to save changes first
  -- (:help prompt_save_on_select_new_entry)
  prompt_save_on_select_new_entry = true,
  -- Oil will automatically delete hidden buffers after this delay
  -- You can set the delay to false to disable cleanup entirely
  -- Note that the cleanup process only starts when none of the oil buffers are currently displayed
  cleanup_delay_ms = 2000,
  lsp_file_methods = {
    -- Enable or disable LSP file operations
    enabled = true,
    -- Time to wait for LSP file operations to complete before skipping
    timeout_ms = 1000,
    -- Set to true to autosave buffers that are updated with LSP willRenameFiles
    -- Set to "unmodified" to only autosave unmodified buffers
    autosave_changes = false,
  },
  -- Constrain the cursor to the editable parts of the oil buffer
  -- Set to `false` to disable, or "name" to keep it on the file names
  constrain_cursor = "editable",
  -- Set to true to watch the filesystem for changes and reload oil
  watch_for_changes = false,
  -- Keymaps in oil buffer. Can be any value that `vim.keymap.set` accepts OR a table of keymap
  -- options with a `callback` (e.g. { callback = function() ... end, desc = "", mode = "n" })
  -- Additionally, if it is a string that matches "actions.<name>",
  -- it will use the mapping at require("oil.actions").<name>
  -- Set to `false` to remove a keymap
  -- See :help oil-actions for a list of all available actions
  keymaps = {
    ["g?"] = "actions.show_help",
    ["<CR>"] = "actions.select",
    ["<C-s>"] = { "actions.select", opts = { vertical = true }, desc = "Open the entry in a vertical split" },
    ["<C-h>"] = { "actions.select", opts = { horizontal = true }, desc = "Open the entry in a horizontal split" },
    ["<C-t>"] = { "actions.select", opts = { tab = true }, desc = "Open the entry in new tab" },
    ["<C-p>"] = "actions.preview",
    ["<C-c>"] = "actions.close",
    ["<C-l>"] = "actions.refresh",
    ["-"] = "actions.parent",
    ["_"] = "actions.open_cwd",
    ["`"] = "actions.cd",
    ["~"] = { "actions.cd", opts = { scope = "tab" }, desc = ":tcd to the current oil directory" },
    ["gs"] = "actions.change_sort",
    ["gx"] = "actions.open_external",
    ["g."] = "actions.toggle_hidden",
    ["g\\"] = "actions.toggle_trash",
  },
  -- Set to false to disable all of the above keymaps
  use_default_keymaps = true,
  view_options = {
    -- Show files and directories that start with "."
    show_hidden = false,
    -- This function defines what is considered a "hidden" file
    is_hidden_file = function(name, bufnr)
      return vim.startswith(name, ".")
    end,
    -- This function defines what will never be shown, even when `show_hidden` is set
    is_always_hidden = function(name, bufnr)
      return false
    end,
    -- Sort file names in a more intuitive order for humans. Is less performant,
    -- so you may want to set to false if you work with large directories.
    natural_order = true,
    -- Sort file and directory names case insensitive
    case_insensitive = false,
    sort = {
      -- sort order can be "asc" or "desc"
      -- see :help oil-columns to see which columns are sortable
      { "type", "asc" },
      { "name", "asc" },
    },
  },
  -- Extra arguments to pass to SCP when moving/copying files over SSH
  extra_scp_args = {},
  -- EXPERIMENTAL support for performing file operations with git
  git = {
    -- Return true to automatically git add/mv/rm files
    add = function(path)
      return false
    end,
    -- Return true to automatically git add/mv/rm files
    mv = function(src_path, dest_path)
      return false
    end,
    -- Return true to automatically git add/mv/rm files
    rm = function(path)
      return false
    end,
  },
  -- Configuration for the floating window in oil.toggle_float
  float = {
    -- Padding around the floating window
    padding = 2,
    max_width = 0,
    max_height = 0,
    border = "rounded",
    win_options = {
      winblend = 0,
    },
    -- preview_split: Split direction: "auto", "left", "right", "above", "below".
    preview_split = "auto",
    -- This is the config that will be passed to nvim_open_win.
    -- Change values here to customize the layout
    override = function(conf)
      return conf
    end,
  },
  -- Configuration for the actions floating preview window
  preview = {
    -- Width dimensions can be integers or a float between 0 and 1 (e.g. 0.4 for 40%)
    -- min_width and max_width can be a single value or a list of mixed integer/float types.
    -- max_width = {100, 0.8} means "the lesser of 100 columns or 80% of total"
    max_width = 0.9,
    -- min_width = {40, 0.4} means "the greater of 40 columns or 40% of total"
    min_width = { 40, 0.4 },
    -- optionally define an integer/float for the exact width of the preview window
    width = nil,
    -- Height dimensions can be integers or a float between 0 and 1 (e.g. 0.4 for 40%)
    -- min_height and max_height can be a single value or a list of mixed integer/float types.
    -- max_height = {80, 0.9} means "the lesser of 80 columns or 90% of total"
    max_height = 0.9,
    min_height = { 5, 0.1 },
    -- optionally define an integer/float for the exact height of the preview window
    height = nil,
    border = "rounded",
    win_options = {
      winblend = 0,
    },
    -- Whether the preview window is automatically updated when the cursor is moved
    update_on_cursor_moved = true,
  },
  -- Configuration for the floating progress window
  progress = {
    max_width = 0.9,
    min_width = { 40, 0.4 },
    width = nil,
    max_height = { 10, 0.9 },
    min_height = { 5, 0.1 },
    height = nil,
    border = "rounded",
    minimized_border = "none",
    win_options = {
      winblend = 0,
    },
  },
  -- Configuration for the floating SSH window
  ssh = {
    border = "rounded",
  },
  -- Configuration for the floating keymaps help window
  keymaps_help = {
    border = "rounded",
  },
})
```

## Adapters

Oil does all of its filesystem interaction through an *adapter* abstraction. In practice, this means that oil can be used to view and modify files in more places than just the local filesystem, so long as the destination has an adapter implementation.

Note that file operations work *across* adapters. You can copy files from a remote server over SSH into a local directory, or vice versa.

### Files

A simple adapter that lets you browse your local filesystem.

### SSH

Browse and edit files over SSH. To use this, simply open a directory using the following format:

```
nvim oil-ssh://[username@]hostname[:port]/[path]
```

This may prompt you for a password. If you want to avoid entering passwords, set up SSH keys or use an SSH agent.

Note that this adapter does not use SFTP, so it doesn't require an SFTP server to be running on the remote host. It uses SSH to execute shell commands on the remote server.

### Trash

View and restore files that have been deleted. Only works on systems that follow the [FreeDesktop.org Trash specification](https://specifications.freedesktop.org/trash-spec/trashspec-1.0.html) (Linux and some BSDs). MacOS has limited support: you can view and restore files, but deleting files from the trash is not supported.

To browse deleted files, open oil in the following directory:

```
nvim oil-trash://
```

## Recipes

See [recipes.md](doc/recipes.md) for some common configuration examples.

## Third-party extensions

- [refactoring.nvim](https://github.com/ThePrimeagen/refactoring.nvim) - Code refactoring with oil.nvim support
- [resession.nvim](https://github.com/stevearc/resession.nvim) - Session management with oil.nvim support

## API

See [api.md](doc/api.md) or `:help oil` for complete API documentation.

## FAQ

**Q: Why "oil"?**

**A:** From the vim-vinegar README:

> Split windows and the project drawer go together like oil and vinegar

Since this plugin is essentially a project drawer *inside* a split window, I named it "oil" to complete the pair.

**Q: Why would I want to edit my filesystem like a buffer?**

**A:** Because it's a familiar paradigm. You can use all of the vim motions you know and love. You can search with `/`. You can select files with visual mode. You can use vim macros. It's just a better way to interact with files than the slow, clunky "press j to move down" style that most file explorers use.

**Q: What if I want to see the directory structure as a tree like NvimTree or nvim-tree.lua?**

**A:** Try [neo-tree.nvim](https://github.com/nvim-neo-tree/neo-tree.nvim). It's a great plugin, and you should use the tool that best fits your workflow. Oil will never show a tree view because [trees are bad UX](https://youtu.be/k4jY9EXJG0g).

**Q: I am getting an error `BufReadCmd AutoCommand deleted buffer`**

**A:** This is likely due to a conflict with another plugin that is also trying to take control of directory buffers. The most common culprit is netrw, but other file explorer plugins can cause this issue as well. See [this issue](https://github.com/stevearc/oil.nvim/issues/23) for more details.

**Q: How do I disable netrw?**

**A:** Put this in your init.lua

```lua
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1
```