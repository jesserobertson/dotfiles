return {
    -- add dracula
    -- { "Mofiqul/dracula.nvim" },
    { "maxmx03/dracula.nvim", name = "dracula" },

    -- installs NORD
    { "arcticicestudio/nord-vim", name = "nord" }, -- offical one but it
    -- looks weird

    -- Installs catppuccin
    {
        "catppuccin/nvim",
        name = "catppuccin",
        priority = 1000,
        opts = { flavour = "frappe" },
    },

    -- Configure LazyVim to load nord
    {
        "LazyVim/LazyVim",
        opts = {
            colorscheme = "dracula",
            -- colorscheme = "nord",
            -- colorscheme = "catppucin"
        },
    },
}
