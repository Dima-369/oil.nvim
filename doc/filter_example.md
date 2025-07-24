# Oil.nvim Regex Filtering

This document shows how to use the new regex filtering feature in oil.nvim.

## API Functions

### `oil.set_filter(pattern, bufnr?)`
Set a regex filter for the current oil buffer.
- `pattern`: The regex pattern to filter by, or `nil` to clear the filter
- `bufnr`: Optional buffer number (defaults to current buffer)

### `oil.get_filter(bufnr?)`
Get the current regex filter for an oil buffer.
- `bufnr`: Optional buffer number (defaults to current buffer)
- Returns: The current filter pattern, or `nil` if no filter is set

### `oil.clear_filter(bufnr?)`
Clear the regex filter for an oil buffer.
- `bufnr`: Optional buffer number (defaults to current buffer)

### `oil.get_current_dir_and_filter(bufnr?)`
Get both the current directory and filter information.
- `bufnr`: Optional buffer number (defaults to current buffer)
- Returns: `dir, filter` - the current directory and filter pattern

## Enhanced Winbar Example

Here's an enhanced version of the winbar function that shows both the directory and any active filter:

```lua
function _G.get_oil_winbar()
  local bufnr = vim.api.nvim_win_get_buf(vim.g.statusline_winid)
  local dir, filter = require("oil").get_current_dir_and_filter(bufnr)
  
  if dir then
    local display = vim.fn.fnamemodify(dir, ":~")
    if filter then
      display = display .. " [filter: " .. filter .. "]"
    end
    return display
  else
    -- If there is no current directory (e.g. over ssh), just show the buffer name
    local name = vim.api.nvim_buf_get_name(bufnr)
    if filter then
      name = name .. " [filter: " .. filter .. "]"
    end
    return name
  end
end

-- Alternative simpler version that just extends the original
function _G.get_oil_winbar()
  local bufnr = vim.api.nvim_win_get_buf(vim.g.statusline_winid)
  local dir = require("oil").get_current_dir(bufnr)
  local filter = require("oil").get_filter(bufnr)
  
  local display
  if dir then
    display = vim.fn.fnamemodify(dir, ":~")
  else
    -- If there is no current directory (e.g. over ssh), just show the buffer name
    display = vim.api.nvim_buf_get_name(bufnr)
  end
  
  if filter then
    display = display .. " [" .. filter .. "]"
  end
  
  return display
end
```

## Usage Examples

```lua
-- Set a filter to show only .lua files
require("oil").set_filter("%.lua$")

-- Set a filter to show only files starting with "test"
require("oil").set_filter("^test")

-- Set a filter to show only directories (files ending with /)
-- Note: This won't work as expected since oil handles directory display differently
-- Better to use a pattern that matches directory names

-- Clear the current filter
require("oil").clear_filter()

-- Get the current filter
local current_filter = require("oil").get_filter()
if current_filter then
  print("Current filter: " .. current_filter)
else
  print("No filter active")
end
```

## Keymaps Example

You can add keymaps to make filtering more convenient:

```lua
-- In your oil setup
require("oil").setup({
  keymaps = {
    -- ... other keymaps
    ["gf"] = "actions.set_filter",
    ["gF"] = "actions.clear_filter",
    -- Or with custom callbacks:
    ["gf"] = {
      callback = function()
        vim.ui.input({ prompt = "Filter pattern: " }, function(pattern)
          if pattern then
            require("oil").set_filter(pattern)
          end
        end)
      end,
      desc = "Set regex filter",
    },
    ["gF"] = {
      callback = function()
        require("oil").clear_filter()
      end,
      desc = "Clear filter",
    },
  },
})
```

## Notes

- Filters are applied in addition to the existing hidden file logic
- The ".." parent directory entry is never filtered out
- Invalid regex patterns will show an error and not be applied
- Filters are automatically cleared when the buffer is unloaded
- You cannot change filters when there are unsaved changes in oil buffers