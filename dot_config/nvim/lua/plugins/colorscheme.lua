return {
    -- -- add dracula
    -- { "Mofiqul/dracula.nvim" },

    -- add nord-vim
    -- { "arcticicestudio/nord-vim", name = "nord" }, -- offical one but it
    -- looks weird
    { "dupeiran001/nord.nvim", name = "nord" },
    -- {
    --     "catppuccin/nvim",
    --     name = "catppuccin",
    --     priority = 1000,
    --     opts = { flavour = "frappe" },
    -- },

    -- Configure LazyVim to load nord
    {
        "LazyVim/LazyVim",
        opts = {
            colorscheme = "nord",
        },
    },
}
