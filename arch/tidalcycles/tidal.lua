return {
	"tidalcycles/vim-tidal",
	build = ":UpdateRemotePlugins",
	ft = { "tidal", "tidalcycles" },

	keys = {
		{ "<leader>mb", "<Plug>(tidal-boot)", desc = "Tidal: Boot GHCi" },
		{ "<leader>mq", "<Plug>(tidal-quit)", desc = "Tidal: Quit GHCi" },
		{ "<leader>me", "<Plug>(tidal-eval)", desc = "Tidal: Eval Line" },
		{ "<leader>mE", "<Plug>(tidal-eval-block)", desc = "Tidal: Eval Block" },
		{ "<leader>mh", "<Plug>(tidal-hush)", desc = "Tidal: Hush" },
	},
}
