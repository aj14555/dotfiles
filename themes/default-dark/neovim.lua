return {
	{
		"nyoom-engineering/oxocarbon.nvim",
		priority = 1000,
	},
	{
		"LazyVim/LazyVim",
		opts = {
			colorscheme = "oxocarbon",
		},
	},
	{
		"akinsho/bufferline.nvim",
		opts = {
			highlights = {
				indicator_selected = {
					fg = "#d8dee9",
					default = false,
				},
			},
		},
	},
}
