{
  ...
}:
let
  nvim-init = ''
    -- AstroNvim v6 + catppuccin Frappé
    -- 首次启动时克隆 lazy.nvim 并安装 AstroNvim 及全部插件（与官方 README 的最小引导一致）
    local lazypath = vim.env.LAZY or vim.fn.stdpath "data" .. "/lazy/lazy.nvim"

    if not (vim.env.LAZY or (vim.uv or vim.loop).fs_stat(lazypath)) then
      -- stylua: ignore
      vim.fn.system({ "git", "clone", "--filter=blob:none", "https://github.com/folke/lazy.nvim.git", "--branch=stable", lazypath })
    end

    vim.opt.rtp:prepend(lazypath)

    require "lazy_setup"
  '';

  lazy-setup = ''
    require("lazy").setup({
      {
        "AstroNvim/AstroNvim",
        version = "^6", -- 锁定 v6 大版本，移除则用 nightly
        import = "astronvim.plugins",
        opts = { -- AstroNvim 选项必须在 lazy.setup 前设置
          mapleader = " ",
          maplocalleader = " ",
        },
      },
      { import = "plugins" }, -- 用户插件: lua/plugins/*.lua
    }, {
      install = { colorscheme = { "astrotheme", "habamax" } },
      performance = {
        rtp = {
          disabled_plugins = { "gzip", "netrwPlugin", "tarPlugin", "tohtml", "zipPlugin" },
        },
      },
    })
  '';

  astrocore = ''
    return {
      "AstroNvim/astrocore",
      ---@type AstroCoreOpts
      opts = {
        filetypes = {
          pattern = {
            [".*nix/.*%.nix"] = "nix",
          },
        },
        options = {
          opt = {
            clipboard = "unnamedplus",
            mouse = "a",
            number = true,
            relativenumber = true,
            cursorline = true,
            expandtab = true,
            shiftwidth = 2,
            tabstop = 2,
            softtabstop = 2,
            smartindent = true,
            wrap = false,
            swapfile = false,
            backup = false,
            undofile = true,
            hlsearch = false,
            incsearch = true,
            scrolloff = 8,
            signcolumn = "yes",
            updatetime = 50,
            timeoutlen = 300,
            splitright = true,
            splitbelow = true,
            inccommand = "split",
          },
        },
        mappings = {
          n = {
            ["<Esc>"] = { "<cmd>nohlsearch<CR>", desc = "Clear search highlight" },
            ["<C-d>"] = { "<C-d>zz", desc = "Half page down, centered" },
            ["<C-u>"] = { "<C-u>zz", desc = "Half page up, centered" },
            ["n"] = { "nzzzv", desc = "Next match, centered" },
            ["N"] = { "Nzzzv", desc = "Prev match, centered" },
          },
          v = {
            ["J"] = { ":m '>+1<CR>gv=gv", desc = "Move selection down" },
            ["K"] = { ":m '<-2<CR>gv=gv", desc = "Move selection up" },
          },
          x = {
            ["<leader>p"] = { '"_dP', desc = "Paste over without clobbering register" },
          },
        },
      },
    }
  '';

  catppuccin-plugin = ''
    return {
      {
        "catppuccin/nvim",
        name = "catppuccin",
        priority = 1000, -- 先于 astroui 加载
        opts = {
          flavour = "frappe",
        },
        -- 插件加载后立即强制应用。用 "catppuccin-frappe" 而非 "catppuccin"：
        -- nvim 0.12 内置同名 catppuccin.vim(mocha) 会抢先应用，且 nvim 对同名 colorscheme 跳过重载
        config = function(_, opts)
          require("catppuccin").setup(opts)
          vim.cmd.colorscheme("catppuccin-frappe")
        end,
      },
      {
        "AstroNvim/astroui",
        opts = {
          colorscheme = "catppuccin-frappe",
        },
      },
    }
  '';
in
{
  xdg.configFile = {
    "nvim/init.lua".text = nvim-init;
    "nvim/lua/lazy_setup.lua".text = lazy-setup;
    "nvim/lua/plugins/astrocore.lua".text = astrocore;
    "nvim/lua/plugins/catppuccin.lua".text = catppuccin-plugin;
  };

  programs.fish.shellAliases = {
    e = "nvim";
    vi = "nvim";
    vim = "nvim";
  };
  programs.bash.shellAliases = {
    e = "nvim";
    vi = "nvim";
    vim = "nvim";
  };
}
