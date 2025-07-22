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
  vim.notify("[Oil Git Debug] Running git status in: " .. repo_root, vim.log.levels.INFO)
  
  local proc = vim.system(
    { "git", "status", "--porcelain" },
    {
      cwd = repo_root,
      text = true,
    },
    function(result)
      if result.code == 0 then
        local parsed_status = parse_git_status(result.stdout or "")
        status_cache[repo_root] = parsed_status
        
        local file_count = vim.tbl_count(parsed_status)
        vim.notify(
          string.format("[Oil Git Debug] Found %d files with git status in %s", file_count, repo_root),
          vim.log.levels.INFO
        )
        
        if file_count > 0 then
          vim.notify("[Oil Git Debug] Files with status: " .. vim.inspect(parsed_status), vim.log.levels.INFO)
        end
      else
        -- Clear cache if git command fails
        status_cache[repo_root] = {}
        vim.notify(
          string.format("[Oil Git Debug] Git command failed in %s: %s", repo_root, result.stderr or "unknown error"),
          vim.log.levels.WARN
        )
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
  
  vim.notify("[Oil Git Debug] Timer update - refreshing " .. #repos .. " repositories", vim.log.levels.INFO)
  
  for _, repo_root in ipairs(repos) do
    update_repo_status(repo_root, function()
      -- Refresh oil buffers after periodic update
      vim.notify("[Oil Git Debug] *** PERIODIC RERENDER CALLBACK TRIGGERED ***", vim.log.levels.ERROR)
      local view = require("oil.view")
      view.rerender_all_oil_buffers({ refetch = false })
      vim.notify("[Oil Git Debug] *** PERIODIC RERENDER CALLBACK COMPLETED ***", vim.log.levels.ERROR)
    end)
  end
end

---Get git status for a file
---@param file_path string
---@return string|nil status_code
M.get_status = function(file_path)
  if not config.enabled then
    vim.notify("[Oil Git Debug] Git status disabled", vim.log.levels.DEBUG)
    return nil
  end
  
  local repo_root = get_git_root(file_path)
  if not repo_root then
    vim.notify("[Oil Git Debug] No git root found for: " .. file_path, vim.log.levels.DEBUG)
    return nil
  end
  
  vim.notify("[Oil Git Debug] Checking status for: " .. file_path .. " in repo: " .. repo_root, vim.log.levels.DEBUG)
  
  -- Initialize cache for this repo if needed
  if not status_cache[repo_root] then
    vim.notify("[Oil Git Debug] Initializing cache for repo: " .. repo_root, vim.log.levels.INFO)
    status_cache[repo_root] = {}
    -- Trigger async update
    update_repo_status(repo_root, function()
      -- Refresh oil buffers that might be affected
      vim.notify("[Oil Git Debug] *** RERENDER CALLBACK TRIGGERED ***", vim.log.levels.ERROR)
      vim.notify("[Oil Git Debug] Refreshing oil buffers after git status update", vim.log.levels.INFO)
      local view = require("oil.view")
      view.rerender_all_oil_buffers({ refetch = false })
      vim.notify("[Oil Git Debug] *** RERENDER CALLBACK COMPLETED ***", vim.log.levels.ERROR)
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
  
  vim.notify(
    string.format("[Oil Git Debug] Path conversion - full: %s, repo: %s, relative: %s", 
      file_path, repo_root, relative_path),
    vim.log.levels.INFO
  )
  
  local status = status_cache[repo_root][relative_path]
  if status then
    vim.notify("[Oil Git Debug] Found status '" .. status .. "' for file: " .. relative_path, vim.log.levels.DEBUG)
  else
    vim.notify("[Oil Git Debug] No status found for file: " .. relative_path, vim.log.levels.DEBUG)
  end
  
  return status
end

---Get highlight group for git status
---@param status_code string|nil
---@return string|nil
M.get_highlight_group = function(status_code)
  if not status_code then
    vim.notify("[Oil Git Debug] No status code provided to get_highlight_group", vim.log.levels.DEBUG)
    return nil
  end
  
  vim.notify("[Oil Git Debug] Getting highlight for status: '" .. status_code .. "'", vim.log.levels.DEBUG)
  
  local first_char = status_code:sub(1, 1)
  local second_char = status_code:sub(2, 2)
  
  local highlight = nil
  
  -- Check index status (first character)
  if first_char == "A" then
    highlight = "OilGitAdded"
  elseif first_char == "M" then
    highlight = "OilGitModified"
  elseif first_char == "D" then
    highlight = "OilGitDeleted"
  elseif first_char == "R" then
    highlight = "OilGitRenamed"
  elseif first_char == "C" then
    highlight = "OilGitCopied"
  end
  
  -- Check working tree status (second character)
  if second_char == "M" then
    highlight = "OilGitModified"
  elseif second_char == "D" then
    highlight = "OilGitDeleted"
  end
  
  -- Untracked files
  if status_code == "??" then
    highlight = "OilGitUntracked"
  end
  
  if highlight then
    vim.notify("[Oil Git Debug] Returning highlight: " .. highlight .. " for status: " .. status_code, vim.log.levels.INFO)
  else
    vim.notify("[Oil Git Debug] No highlight found for status: " .. status_code, vim.log.levels.WARN)
  end
  
  return highlight
end

---Setup git status monitoring
---@param opts table
M.setup = function(opts)
  opts = opts or {}
  config.enabled = opts.enabled ~= false
  config.update_interval = opts.update_interval or 3000
  
  vim.notify(
    string.format("[Oil Git Debug] Setup called - enabled: %s, interval: %d", 
      tostring(config.enabled), config.update_interval),
    vim.log.levels.INFO
  )
  
  if not config.enabled then
    vim.notify("[Oil Git Debug] Git status monitoring disabled", vim.log.levels.INFO)
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
    vim.notify("[Oil Git Debug] Timer started with interval: " .. config.update_interval .. "ms", vim.log.levels.INFO)
  else
    vim.notify("[Oil Git Debug] Failed to create timer", vim.log.levels.ERROR)
  end
  
  -- Setup highlight groups
  vim.api.nvim_set_hl(0, "OilGitAdded", { link = "DiffAdd" })
  vim.api.nvim_set_hl(0, "OilGitModified", { link = "DiffChange" })
  vim.api.nvim_set_hl(0, "OilGitDeleted", { link = "DiffDelete" })
  vim.api.nvim_set_hl(0, "OilGitRenamed", { link = "DiffChange" })
  vim.api.nvim_set_hl(0, "OilGitCopied", { link = "DiffAdd" })
  vim.api.nvim_set_hl(0, "OilGitUntracked", { link = "Comment" })
  
  vim.notify("[Oil Git Debug] Highlight groups configured", vim.log.levels.INFO)
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