-- Set leader keys before loading LazyVim
vim.g.mapleader = " "
vim.g.maplocalleader = "\\"

-- bootstrap lazy.nvim, LazyVim and your plugins
require("config.lazy")
