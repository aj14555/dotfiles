local M = {}

M.groups = {
	"Normal",
	"NormalFloat",
	"FloatBorder",
	"Pmenu",
	"Terminal",
	"EndOfBuffer",
	"FoldColumn",
	"Folded",
	"SignColumn",
	"LineNr",
	"CursorLineNr",
	"NormalNC",
	"WhichKeyFloat",
	"TelescopeBorder",
	"TelescopeNormal",
	"TelescopePromptBorder",
	"TelescopePromptTitle",
	"NeoTreeNormal",
	"NeoTreeNormalNC",
	"NeoTreeVertSplit",
	"NeoTreeWinSeparator",
	"NeoTreeEndOfBuffer",
	"NvimTreeNormal",
	"NvimTreeVertSplit",
	"NvimTreeEndOfBuffer",
	"NotifyINFOBody",
	"NotifyERRORBody",
	"NotifyWARNBody",
	"NotifyTRACEBody",
	"NotifyDEBUGBody",
	"NotifyINFOTitle",
	"NotifyERRORTitle",
	"NotifyWARNTitle",
	"NotifyTRACETitle",
	"NotifyDEBUGTitle",
	"NotifyINFOBorder",
	"NotifyERRORBorder",
	"NotifyWARNBorder",
	"NotifyTRACEBorder",
	"NotifyDEBUGBorder",
}

function M.apply()
	for _, name in ipairs(M.groups) do
		vim.api.nvim_set_hl(0, name, { bg = "NONE", ctermbg = "NONE" })
	end
end

function M.apply_late()
	M.apply()
	vim.defer_fn(M.apply, 50)
	vim.defer_fn(M.apply, 200)
	vim.defer_fn(function()
		M.apply()
		vim.cmd("redraw!")
	end, 500)
end

function M.setup()
	M.apply()
	_G.omarchy_apply_transparency = M.apply

	local group = vim.api.nvim_create_augroup("omarchy_transparency", { clear = true })

	-- Defer so we run after other ColorScheme handlers
	vim.api.nvim_create_autocmd("ColorScheme", {
		group = group,
		callback = M.apply_late,
	})

	vim.api.nvim_create_autocmd("User", {
		group = group,
		pattern = "LazyReload",
		callback = function()
			vim.defer_fn(M.apply_late, 250)
		end,
	})
end

return M
