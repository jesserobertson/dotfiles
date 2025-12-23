-- TidalCycles live coding plugin
return {
    "tidalcycles/vim-tidal",
    ft = "tidal", -- Load only for .tidal files
    keys = {
        {
            "<C-e>",
            desc = "Send paragraph to TidalCycles",
            mode = { "n", "v" },
            ft = "tidal",
        },
        {
            "<localleader>ss",
            desc = "Send inner paragraph to TidalCycles",
            mode = "n",
            ft = "tidal",
        },
        {
            "<localleader>s",
            desc = "Send line/selection to TidalCycles",
            mode = { "n", "v" },
            ft = "tidal",
        },
        {
            "<localleader>h",
            desc = "Silence all TidalCycles streams",
            mode = "n",
            ft = "tidal",
        },
    },
    init = function()
        -- Set localleader for TidalCycles commands
        -- vim.g.maplocalleader = ","

        -- Use tmux as the target (since tmux is already installed)
        vim.g.tidal_target = "tmux"

        -- Use ghci via ghcup (default command should work)
        -- If needed, can customize with: vim.g.tidal_ghci = "ghci"
    end,
    config = function()
        -- Register .tidal file extension
        vim.filetype.add({
            extension = {
                tidal = "tidal",
            },
        })
    end,
}
