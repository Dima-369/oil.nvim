-- Git status monitoring with periodic updates
local uv = vim.uv or vim.loop
local util = require("oil.util")

local M = {}

-- Cache for git status results
-- Structure: { [repo_root] = { [relative_path] = status_code } }
local status_cache = {}

-- Timer for periodic updates
local update_timer = nil

-- Configuration
local config = {
  enabled = false,
  update_interval = 3000, -- 3 seconds in milliseconds
}

---@param path string
---@return string|nil
local function get_git_root(path)
  local git_dir = vim.fs.find(".git", { upward = true, path = path })[1]
  if git_dir then
    return vim.fs.dirname(git_dir)
  else
    return nil
  end
end

---Parse git status --porcelain output
---@param output string
---@return table<string, string>
local function parse_git_status(output)
  local status = {}
  for line in vim.gsplit(output, "\n", { plain = true, trimempty = true }) do
    if #line >= 3 then
      local status_code = line:sub(1, 2)
      local file_path = line:sub(4)
      -- Handle renamed files (format: "old_name -> new_name")
      if file_path:match(" -> ") then
        local new_name = file_path:match(" -> (.+)$")
        if new_name then
          file_path = new_name
        end
      end
      status[file_path] = status_code
    end
  end
  return status
end

---Update git status for a specific repository
---@param repo_root string
---@param callback? fun()
local function update_repo_status(repo_root, callback)
  local proc = vim.system(
    { "git", "status", "--porcelain" },
    {
      cwd = repo_root,
      text = true,
    },
    function(result)
      if result.code == 0 then
        status_cache[repo_root] = parse_git_status(result.stdout or "")
      else
        -- Clear cache if git command fails
        status_cache[repo_root] = {}
      end
      if callback then
        vim.schedule(callback)
      end
    end
  )
end

---Update git status for all known repositories
local function update_all_repos()
  if not config.enabled then
    return
  end
  
  local repos = vim.tbl_keys(status_cache)
  if #repos == 0 then
    return
  end
  
  for _, repo_root in ipairs(repos) do
    update_repo_status(repo_root, function()
      -- Refresh oil buffers after periodic update
      local view = require("oil.view")
      view.rerender_all_oil_buffers({ refetch = false })
    end)
  end
end

---Check if a directory has any files with git changes
---@param dir_path string
---@param repo_root string
---@return string|nil status_code
local function get_directory_status(dir_path, repo_root)
  if not status_cache[repo_root] then
    return nil
  end
  
  local dir_relative = dir_path:sub(#repo_root + 2) -- Remove repo root and slash
  
  -- Check if any files in this directory have changes
  for file_path, status in pairs(status_cache[repo_root]) do
    -- Check if file is directly in this directory or subdirectory
    if vim.startswith(file_path, dir_relative .. "/") then
      return status -- Return the first status found
    end
  end
  
  return nil
end

---Get git status for a file or directory
---@param file_path string
---@param is_directory? boolean
---@return string|nil status_code
M.get_status = function(file_path, is_directory)
  if not config.enabled then
    return nil
  end
  
  local repo_root = get_git_root(file_path)
  if not repo_root then
    return nil
  end
  
  -- Initialize cache for this repo if needed
  if not status_cache[repo_root] then
    status_cache[repo_root] = {}
    -- Trigger async update
    update_repo_status(repo_root, function()
      -- Refresh oil buffers that might be affected
      local view = require("oil.view")
      view.rerender_all_oil_buffers({ refetch = false })
    end)
    return nil
  end
  
  -- Get relative path from repo root
  local relative_path
  if vim.startswith(file_path, repo_root) then
    relative_path = file_path:sub(#repo_root + 2) -- +2 to skip the trailing slash
  else
    relative_path = vim.fn.fnamemodify(file_path, ":.")
  end
  
  local status = status_cache[repo_root][relative_path]
  
  -- If it's a directory and no direct status, check for files within the directory
  if not status and is_directory then
    status = get_directory_status(file_path, repo_root)
  end
  
  return status
end

---Get highlight group for git status
---@param status_code string|nil
---@return string|nil
M.get_highlight_group = function(status_code)
  if not status_code then
    return nil
  end
  
  local first_char = status_code:sub(1, 1)
  local second_char = status_code:sub(2, 2)
  
  -- Check index status (first character)
  if first_char == "A" then
    return "OilGitAdded"
  elseif first_char == "M" then
    return "OilGitModified"
  elseif first_char == "D" then
    return "OilGitDeleted"
  elseif first_char == "R" then
    return "OilGitRenamed"
  elseif first_char == "C" then
    return "OilGitCopied"
  end
  
  -- Check working tree status (second character)
  if second_char == "M" then
    return "OilGitModified"
  elseif second_char == "D" then
    return "OilGitDeleted"
  end
  
  -- Untracked files
  if status_code == "??" then
    return "OilGitUntracked"
  end
  
  return nil
end

---Setup git status monitoring
---@param opts table
M.setup = function(opts)
  opts = opts or {}
  config.enabled = opts.enabled ~= false
  config.update_interval = opts.update_interval or 3000
  
  if not config.enabled then
    if update_timer then
      update_timer:stop()
      update_timer:close()
      update_timer = nil
    end
    status_cache = {}
    return
  end
  
  -- Setup periodic updates
  if update_timer then
    update_timer:stop()
    update_timer:close()
  end
  
  update_timer = uv.new_timer()
  if update_timer then
    update_timer:start(1000, config.update_interval, update_all_repos)
  end
  
  -- Setup highlight groups with foreground colors
  vim.api.nvim_set_hl(0, "OilGitAdded", { fg = "#22c55e" })      -- green 500
  vim.api.nvim_set_hl(0, "OilGitModified", { fg = "#3b82f6" })   -- blue 500
  vim.api.nvim_set_hl(0, "OilGitDeleted", { fg = "#ef4444" })    -- red 500
  vim.api.nvim_set_hl(0, "OilGitRenamed", { fg = "#3b82f6" })    -- blue 500
  vim.api.nvim_set_hl(0, "OilGitCopied", { fg = "#22c55e" })     -- green 500
  vim.api.nvim_set_hl(0, "OilGitUntracked", { fg = "#f59e0b" })  -- amber 500
  
  -- Setup buffer save autocmd for immediate git status updates
  vim.api.nvim_create_autocmd("BufWritePost", {
    group = vim.api.nvim_create_augroup("OilGitStatus", { clear = true }),
    callback = function(args)
      local file_path = vim.api.nvim_buf_get_name(args.buf)
      local repo_root = get_git_root(file_path)
      if repo_root and status_cache[repo_root] then
        -- Update git status immediately after save
        update_repo_status(repo_root, function()
          local view = require("oil.view")
          view.rerender_all_oil_buffers({ refetch = false })
        end)
      end
    end,
  })
end

---Clear git status cache
M.clear_cache = function()
  status_cache = {}
end

---Check if git status monitoring is enabled
---@return boolean
M.is_enabled = function()
  return config.enabled
end

---Manually refresh git status for current directory
M.refresh = function()
  if not config.enabled then
    return
  end
  
  local cwd = vim.fn.getcwd()
  local repo_root = get_git_root(cwd)
  if repo_root then
    update_repo_status(repo_root, function()
      local view = require("oil.view")
      view.rerender_all_oil_buffers({ refetch = false })
    end)
  end
end

return M
