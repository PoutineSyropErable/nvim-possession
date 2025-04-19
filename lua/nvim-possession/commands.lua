local M = {}

local function send_notification(message)
	local cmd = string.format("notify-send -t 5000 '[Neovim Debug]' '%s'", message)
	os.execute(cmd) -- Send notification
	print("🟢 Debug: " .. message) -- Also log to Neovim
end

-- Make sure nvim-possession is available
local possession = require("nvim-possession.regular_init")

-- Function to ensure sessions_path is created if its parent directory exists
local function ensure_session_dir_path_exists(user_config)
	-- Get the parent directory of the sessions_path
	local parent_dir = vim.fn.fnamemodify(user_config.sessions.sessions_path, ":p:h")

	-- Check if the parent directory exists
	if vim.fn.isdirectory(parent_dir) == 0 then
		-- If the parent directory doesn't exist, print an error and return
		send_notification("Error: Parent directory '" .. parent_dir .. "' does not exist.")
		return false
	end

	-- If the sessions_path directory doesn't exist, create it
	if vim.fn.isdirectory(user_config.sessions.sessions_path) == 0 then
		vim.fn.mkdir(user_config.sessions.sessions_path, "p") -- Create sessions_path
		print("Created sessions_path: " .. user_config.sessions.sessions_path)
		return true
	else
		-- If the directory already exists, inform the user
		print("sessions_path already exists: " .. user_config.sessions.sessions_path)
		return true
	end
end

-- Create NvimPosessionCreate command
vim.api.nvim_create_user_command("NvimPossessionCreate", function(opts)
	local session_name = opts.args
	if session_name == "" then
		print("❌ Please provide a session name.")
		return
	end

	local ret = ensure_session_dir_path_exists(possession.user_config)
	if not ret then
		return
	end

	-- Call the session creation function from nvim-possession
	possession.create(session_name)
end, { nargs = 1 }) -- `nargs = 1` ensures exactly one argument is required

-- Create NvimPosessionLoad command
vim.api.nvim_create_user_command("NvimPossessionLoad", function(opts)
	local session_name = opts.args
	if session_name == "" then
		print("❌ Please provide a session name.")
		return
	end

	local ret = ensure_session_dir_path_exists(possession.user_config)
	if not ret then
		return
	end

	-- Load the selected session
	possession.load(session_name)
end, { nargs = 1 }) -- `nargs = 1` ensures exactly one argument is required

vim.api.nvim_create_user_command("NvimPossessionLoadOrCreate", function(opts)
	local session_name = opts.args
	if session_name == "" then
		print("❌ Please provide a session name.")
		return
	end

	local ret = ensure_session_dir_path_exists(possession.user_config)
	if not ret then
		return
	end

	-- Load the selected session
	possession.load_or_create(session_name)
end, { nargs = 1 }) -- `nargs = 1` ensures exactly one argument is required

-- In Lua, define a function that optionally loads session then opens files
M.load_session_and_open = function(session_name, files)
	if session_name then
		require("nvim-possession").load_or_create(session_name)
	end
	for _, f in ipairs(files) do
		vim.cmd("edit " .. f)
	end
end

return M
