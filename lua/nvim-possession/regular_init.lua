local config = require("nvim-possession.config")
local ui = require("nvim-possession.ui")
local utils = require("nvim-possession.utils")
local sort = require("nvim-possession.sorting")

local M = {}

local PRINT_CUSTOM_DEBUG = true
local USE_PRINT = false

local function print_custom(...)
	if not PRINT_CUSTOM_DEBUG then
		return
	end

	local parts = {}
	for _, v in ipairs({ ... }) do
		table.insert(parts, tostring(v))
	end
	local msg = table.concat(parts, "\t")

	if USE_PRINT then
		print(msg)
	else
		vim.notify(msg, vim.log.levels.INFO)
	end
end

---expose the following interfaces:
---require("nvim-possession").new()
---require("nvim-possession").list()
---require("nvim-possession").update()
---require("nvim-possession").status()

---@param user_opts table
M.setup = function(user_opts)
	local fzf_ok, fzf = pcall(require, "fzf-lua")
	if not fzf_ok then
		print_custom("fzf-lua required as dependency")
		return
	end

	local user_config = vim.tbl_deep_extend("force", config, user_opts or {})

	M.user_config = user_config
	-- kinda bad but who cares

	---get global variable with session name: useful for statusbar components
	---@return string|nil
	M.status = function()
		local cur_session = vim.g[user_config.sessions.sessions_variable]
		return cur_session ~= nil and user_config.sessions.sessions_icon .. cur_session or nil
	end

	---update loaded session with current status
	M.update = function()
		local cur_session = vim.g[user_config.sessions.sessions_variable]
		if cur_session ~= nil then
			local confirm = vim.fn.confirm("overwrite session?", "&Yes\n&No", 2)
			if confirm == 1 then
				if type(user_config.save_hook) == "function" then
					user_config.save_hook()
				end
				vim.cmd.mksession({ args = { user_config.sessions.sessions_path .. cur_session }, bang = true })
				print_custom("updated session: " .. cur_session)
			end
		else
			print_custom("no session loaded")
		end
	end

	---save current session if session path exists
	---return if path does not exist
	M.new = function()
		if vim.fn.finddir(user_config.sessions.sessions_path) == "" then
			print_custom("sessions_path does not exist")
			return
		end

		local name = vim.fn.input("name: ")
		if name ~= "" then
			if next(vim.fs.find(name, { path = user_config.sessions.sessions_path })) == nil then
				vim.cmd.mksession({ args = { user_config.sessions.sessions_path .. name } })
				vim.g[user_config.sessions.sessions_variable] = vim.fs.basename(name)
				print_custom("saved in: " .. user_config.sessions.sessions_path .. name)
			else
				print_custom("session already exists")
			end
		end
	end
	fzf.config.set_action_helpstr(M.new, "new-session")

	---load selected session
	---@param selected string
	M.load = function(selected)
		local session = user_config.sessions.sessions_path .. selected[1]
		if user_config.autoswitch.enable and vim.g[user_config.sessions.sessions_variable] ~= nil then
			utils.autoswitch(user_config)
		end
		vim.cmd.source(session)
		vim.g[user_config.sessions.sessions_variable] = vim.fs.basename(session)
		if type(user_config.post_hook) == "function" then
			user_config.post_hook()
		end
	end
	fzf.config.set_action_helpstr(M.load, "load-session")

	-- create a new session given a name
	M.create = function(session_name)
		if session_name == "" then
			print_custom("Invalid session name")
			return
		end

		-- print_custom("💾 session name is : " .. session_name)
		-- Define full session file path
		local session_file = vim.fs.normalize(user_config.sessions.sessions_path .. session_name .. ".vim")

		-- print_custom("💾 Session file is: " .. session_file)

		-- Check if session already exists
		if next(vim.fs.find(session_name, { path = user_config.sessions.sessions_path })) == nil then
			vim.cmd.mksession({ args = { session_file } })
			vim.g[user_config.sessions.sessions_variable] = vim.fs.basename(session_name)
			-- print_custom("💾 Session saved in: " .. session_file)
		else
			print_custom("⚠️ Session '" .. session_name .. "' already exists")
		end
	end
	fzf.config.set_action_helpstr(M.create, "create-session")

	-- Function to either load or create a session
	M.load_or_create = function(session_name)
		if session_name == "" then
			print_custom("Invalid session name")
			return
		end

		-- Define the session file path
		local session_file = vim.fs.normalize(user_config.sessions.sessions_path .. session_name .. ".vim")

		-- Check if the session file exists
		local session_exists = next(vim.fs.find(session_name, { path = user_config.sessions.sessions_path })) ~= nil

		if session_exists then
			-- If the session exists, load it
			print_custom("Loading session: " .. session_name)
			vim.cmd.source(session_file) -- Load the session
			vim.g[user_config.sessions.sessions_variable] = vim.fs.basename(session_name) -- Set the session variable

			-- Call post hook if defined
			if type(user_config.post_hook) == "function" then
				user_config.post_hook()
			end
		else
			-- If the session doesn't exist, create it
			print_custom("Creating session: " .. session_name)
			vim.cmd.mksession({ args = { session_file } }) -- Create the session
			vim.g[user_config.sessions.sessions_variable] = vim.fs.basename(session_name) -- Set the session variable
		end
	end
	fzf.config.set_action_helpstr(M.load_or_create, "load-or-create-session")
	-- In Lua, define a function that optionally loads session then opens files

	M.load_session_and_open = function(session_name, files)
		if session_name then
			M.load_or_create(session_name)
		end

		vim.schedule(function()
			for _, f in ipairs(files) do
				print_custom("editing file: " .. vim.inspect(f))
				vim.cmd("edit " .. f)
			end
		end)
	end

	---wipe all sessions in the sessions directory
	local function wipe_all_sessions()
		local session_dir = vim.fn.stdpath("data") .. "/sessions/"
		local iter = vim.uv.fs_scandir(session_dir)
		if not iter then
			print("Session directory does not exist")
			return
		end

		local name, type = vim.uv.fs_scandir_next(iter)
		while name do
			local full_path = session_dir .. name
			local normalized_path = vim.fs.normalize(full_path)

			-- Only delete if it's a regular file and a child of session_dir
			if type == "file" and vim.startswith(normalized_path, vim.fs.normalize(session_dir)) then
				os.remove(full_path)
			end

			name, type = vim.uv.fs_scandir_next(iter)
		end
	end

	---delete selected session
	---@param selected string
	M.delete_selected = function(selected)
		local session = user_config.sessions.sessions_path .. selected[1]
		local confirm = vim.fn.confirm("delete session?", "&Yes\n&No", 2)
		if confirm == 1 then
			os.remove(session)
			print_custom("deleted " .. session)
			if vim.g[user_config.sessions.sessions_variable] == vim.fs.basename(session) then
				vim.g[user_config.sessions.sessions_variable] = nil
			end
		end
	end
	fzf.config.set_action_helpstr(M.delete_selected, "delete-session")

	--delete current active session
	M.delete = function()
		local cur_session = vim.g[user_config.sessions.sessions_variable]
		if cur_session ~= nil then
			local confirm = vim.fn.confirm("delete session " .. cur_session .. "?", "&Yes\n&No", 2)
			if confirm == 1 then
				local session_path = user_config.sessions.sessions_path .. cur_session
				os.remove(session_path)
				print_custom("deleted " .. session_path)
				if vim.g[user_config.sessions.sessions_variable] == vim.fs.basename(session_path) then
					vim.g[user_config.sessions.sessions_variable] = nil
				end
			end
		else
			print_custom("no active session")
		end
	end

	---list all existing sessions and their files
	---return fzf picker
	M.list = function()
		local iter = vim.uv.fs_scandir(user_config.sessions.sessions_path)
		if iter == nil then
			print_custom("session folder " .. user_config.sessions.sessions_path .. " does not exist")
			return
		end
		local next = vim.uv.fs_scandir_next(iter)
		if next == nil then
			print_custom("no saved sessions")
			return
		end

		local function list_sessions(fzf_cb)
			local sessions = {}
			for name, type in vim.fs.dir(user_config.sessions.sessions_path) do
				if type == "file" then
					local stat = vim.uv.fs_stat(user_config.sessions.sessions_path .. name)
					if stat then
						table.insert(sessions, { name = name, mtime = stat.mtime })
					end
				end
			end
			table.sort(sessions, function(a, b)
				if type(user_config.sort) == "function" then
					return user_config.sort(a, b)
				else
					return sort.alpha_sort(a, b)
				end
			end)
			for _, sess in ipairs(sessions) do
				fzf_cb(sess.name)
			end
			fzf_cb()
		end

		local opts = {
			user_config = user_config,
			prompt = user_config.sessions.sessions_icon .. user_config.sessions.sessions_prompt,
			cwd_prompt = false,
			file_icons = false,
			git_icons = false,
			cwd_header = false,
			no_header = true,

			previewer = ui.session_previewer,
			hls = user_config.fzf_hls,
			winopts = user_config.fzf_winopts,
			cwd = user_config.sessions.sessions_path,
			actions = {
				["enter"] = M.load,
				["ctrl-x"] = { M.delete_selected, fzf.actions.resume, header = "delete session" },
				["ctrl-n"] = { fn = M.new, header = "new session" },
			},
		}
		opts = require("fzf-lua.config").normalize_opts(opts, {})
		opts = require("fzf-lua.core").set_header(opts, { "actions" })
		fzf.fzf_exec(list_sessions, opts)
	end

	if user_config.autoload and vim.fn.argc() == 0 then
		utils.autoload(user_config)
	end

	if user_config.autosave then
		local autosave_possession = vim.api.nvim_create_augroup("AutosavePossession", {})
		vim.api.nvim_clear_autocmds({ group = autosave_possession })
		vim.api.nvim_create_autocmd("VimLeave", {
			group = autosave_possession,
			desc = "📌 save session on VimLeave",
			callback = function() utils.autosave(user_config) end,
		})
	end
end

return M
