return {
  {
    treesitter = { "javascript", "typescript" },
    mason = { "vtsls", "js-debug-adapter" },
    lsp = { "vtsls" },
    settings = {
      -- See: https://github.com/typescript-language-server/typescript-language-server/blob/master/docs/configuration.md
      -- See: https://github.com/yioneko/vtsls/blob/main/packages/service/conjfiguration.schema.json
      ["js/ts"] = {
        implicitProjectConfig = {
          checkJs = true,
          target = "ES2022",
        },
      },
      javascript = {
        inlayHints = {
          parameterNames = { enabled = "literals" },
          parameterTypes = { enabled = true },
          variableTypes = { enabled = true },
          propertyDeclarationTypes = { enabled = true },
          functionLikeReturnTypes = { enabled = true },
          enumMemberValues = { enabled = true },
        },
      },
      typescript = {
        inlayHints = {
          parameterNames = { enabled = "literals" },
          parameterTypes = { enabled = true },
          variableTypes = { enabled = true },
          propertyDeclarationTypes = { enabled = true },
          functionLikeReturnTypes = { enabled = true },
          enumMemberValues = { enabled = true },
        },
      },
    },
  },
  {
    treesitter = { "python" },
    mason = { "ruff" },
    lsp = { "rufflsp" },
    settings = {
      -- See: https://github.com/microsoft/pyright/blob/main/docs/settings.md
      -- See: https://code.visualstudio.com/docs/python/settings-reference
      python = {
        pythonPath = vim.fn.exepath("python"),
        analysis = {
          inlayHints = {
            variableTypes = true,
            functionReturnTypes = true,
            callArgumentNames = true,
            pytestParameters = true,
          },
          typeCheckingMode = "basic",
          diagnosticMode = "openFilesOnly",
          autoImportCompletions = true,
          diagnosticSeverityOverrides = {
            reportOptionalSubscript = "none",
            reportOptionalMemberAccess = "none",
            reportOptionalCall = "none",
            reportOptionalIterable = "none",
            reportOptionalContextManager = "none",
            reportOptionalOperand = "none",
          },
        },
      },
    },
  },
  {
    treesitter = { "c" },
    mason = { "clangd" },
    lsp = { "clangd" },
  },
  {
    treesitter = { "lua" },
    mason = { "lua-language-server" },
    lsp = { "lua_ls" },
    settings = {
      Lua = {
        runtime = {
          version = "LuaJIT",
        },
        diagnostics = {
          globals = { "vim" },
        },
        workspace = {
          library = {
            vim.env.VIMRUNTIME,
          },
        },
      },
    },
  },
  {
    treesitter = { "bash" },
    mason = { "bash-language-server" },
    lsp = { "bashls" },
  },
  {
    treesitter = { "vim", "vimdoc" },
    mason = { "vim-language-server" },
    lsp = { "vimls" },
  },
  {
    treesitter = { "yaml" },
    mason = { "yaml-language-server" },
    lsp = { "yamlls" },
  },
  {
    treesitter = { "css" },
    mason = { "css-lsp" },
    lsp = { "cssls" },
  },
  {
    treesitter = { "html" },
    mason = { "html-lsp" },
    lsp = { "html" },
  },
  {
    treesitter = { "markdown", "markdown_inline" },
    mason = { "marksman" },
    lsp = { "marksman" },
  },
  {
    treesitter = { "json" },
  },
  {
    treesitter = { "xml" },
  },
  {
    treesitter = { "diff", "gitcommit" },
  },
  {
    treesitter = { "http" },
  },
}
