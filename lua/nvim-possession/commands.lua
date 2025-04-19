local M = {}

-- Make sure nvim-possession is available
local posession = require("nvim-possession.regular_init")

local user_config = posession.user_config

-- Create NvimPosessionCreate command
vim.api.nvim_create_user_command("NvimPossessionCreate", function(opts)
	local session_name = opts.args
	if session_name == "" then
		print("❌ Please provide a session name.")
		return
	end

	if vim.fn.finddir(user_config.sessions.sessions_path) == "" then
		vim.fn.mkdir(user_config.sessions.sessions_path, "p") -- "p" means create parent directories if necessary
		print("sessions_path created: " .. user_config.sessions.sessions_path)
	end

	-- Call the session creation function from nvim-possession
	posession.create(session_name)
end, { nargs = 1 }) -- `nargs = 1` ensures exactly one argument is required

-- Create NvimPosessionLoad command
vim.api.nvim_create_user_command("NvimPossessionLoad", function(opts)
	local session_name = opts.args
	if session_name == "" then
		print("❌ Please provide a session name.")
		return
	end

	if vim.fn.finddir(user_config.sessions.sessions_path) == "" then
		vim.fn.mkdir(user_config.sessions.sessions_path, "p") -- "p" means create parent directories if necessary
		print("sessions_path created: " .. user_config.sessions.sessions_path)
	end

	-- Load the selected session
	posession.load(session_name)
end, { nargs = 1 }) -- `nargs = 1` ensures exactly one argument is required

vim.api.nvim_create_user_command("NvimPossessionLoadOrCreate", function(opts)
	local session_name = opts.args
	if session_name == "" then
		print("❌ Please provide a session name.")
		return
	end

	if vim.fn.finddir(user_config.sessions.sessions_path) == "" then
		vim.fn.mkdir(user_config.sessions.sessions_path, "p") -- "p" means create parent directories if necessary
		print("sessions_path created: " .. user_config.sessions.sessions_path)
	end

	-- Load the selected session
	posession.load_or_create(session_name)
end, { nargs = 1 }) -- `nargs = 1` ensures exactly one argument is required

return M
