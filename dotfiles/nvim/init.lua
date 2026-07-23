local g = vim.g
local opt = vim.opt

local map = vim.keymap.set
local autocmd = vim.api.nvim_create_autocmd
local command = vim.api.nvim_create_user_command

g.mapleader = " "
g.maplocalleader = " "

vim.loader.enable()

vim.cmd.colorscheme("undefined")

-- #############################
-- # Options                   #
-- #############################

g.loaded_python3_provider = 0
g.loaded_node_provider = 0
g.loaded_ruby_provider = 0
g.loaded_perl_provider = 0

g.loaded_2html_plugin = 1
g.loaded_gzip = 1
g.loaded_man = 1
g.loaded_matchit = 1
g.loaded_matchparen = 1
g.loaded_netrw = 1
g.loaded_netrwPlugin = 1
g.loaded_remote_plugins = 1
g.loaded_spellfile_plugin = 1
g.loaded_tarPlugin = 1
g.loaded_tutor_mode_plugin = 1
g.loaded_zipPlugin = 1

-- to make keywordprg a no-op because multiple shift+k will eventually call the default behavior of keywordprg which is to open `:help` and breaks window layout
command("RayKeywordPrg", function() end, { nargs = "*" })

-- ui
opt.termguicolors = true
opt.number = true
opt.relativenumber = true
opt.signcolumn = "yes"
opt.cursorline = true
opt.laststatus = 3
opt.showcmdloc = "statusline"
opt.showmode = false
opt.title = true
opt.titlestring = "nvim: %t"
opt.winborder = "rounded"

-- interaction
opt.mouse = "a"
opt.mousemodel = "extend"
opt.clipboard = "unnamedplus"
opt.virtualedit = "block"
opt.confirm = true
opt.keywordprg = ":RayKeywordPrg"

if vim.fn.has("win32") == 1 then
  opt.shell = "pwsh -NoLogo"
  opt.shellcmdflag = "-NoProfile -ExecutionPolicy RemoteSigned -Command"
  opt.shellxquote = ""
  opt.shellpipe = "2>&1 | Out-File -Encoding UTF8 %s; exit $LastExitCode"
  opt.shellredir = "2>&1 | Out-File -Encoding UTF8 %s; exit $LastExitCode"
  -- remove this after https://github.com/neovim/neovim/issues/40832 fixed
  opt.shellslash = false
end

-- scrolling
opt.scrolloff = 3
opt.sidescrolloff = 3
opt.jumpoptions = "view"
opt.smoothscroll = true

-- wrapping
opt.linebreak = true
opt.breakindent = true

-- folds
opt.foldcolumn = "1"
opt.foldlevel = 99
opt.foldlevelstart = 99
opt.foldmethod = "expr"
opt.foldexpr = "v:lua.vim.treesitter.foldexpr()"
opt.fillchars = {
  foldopen = "",
  foldclose = "",
  fold = " ",
  foldsep = " ",
  diff = "╱",
  eob = " ",
}

local function append_fold_virtual_text(chunks, line_text, line_number, column_offset)
  if not column_offset then
    column_offset = 0
  end

  local chunk_text = ""
  local current_highlight

  for index = 1, #line_text do
    local char = line_text:sub(index, index)
    local captures = vim.treesitter.get_captures_at_pos(0, line_number, column_offset + index - 1)
    local capture = captures[#captures]

    if capture then
      local next_highlight = "@" .. capture.capture

      if next_highlight ~= current_highlight then
        table.insert(chunks, { chunk_text, current_highlight })
        chunk_text = ""
        current_highlight = nil
      end

      chunk_text = chunk_text .. char
      current_highlight = next_highlight
    else
      chunk_text = chunk_text .. char
    end
  end

  table.insert(chunks, { chunk_text, current_highlight })
end
function _G.ray_foldtext()
  local folded_line_count = vim.v.foldend - vim.v.foldstart
  local start_line = vim.fn.getline(vim.v.foldstart):gsub("\t", string.rep(" ", vim.o.tabstop))
  local end_line = vim.fn.getline(vim.v.foldend)
  local trimmed_end_line = vim.trim(end_line)
  local chunks = {}

  append_fold_virtual_text(chunks, start_line, vim.v.foldstart - 1)
  table.insert(chunks, { " ... ", "Delimiter" })
  append_fold_virtual_text(chunks, trimmed_end_line, vim.v.foldend - 1, #(end_line:match("^(%s+)") or ""))
  table.insert(chunks, { ("   󰁂 %d lines"):format(folded_line_count), "Comment" })

  return chunks
end
opt.foldtext = "v:lua.ray_foldtext()"

-- indentation
opt.tabstop = 2
opt.shiftwidth = 2
opt.softtabstop = 2
opt.expandtab = true

-- whitespace
opt.list = true
opt.listchars = {
  lead = "·",
  precedes = "<",
  extends = ">",
  tab = "» ",
  trail = "·",
  nbsp = "␣",
}

-- search
opt.ignorecase = true
opt.smartcase = true
opt.inccommand = "split"
opt.gdefault = true

-- splits
opt.equalalways = false
opt.splitright = true
opt.splitbelow = true
opt.splitkeep = "screen"

-- files
opt.fileformats = { "unix", "dos", "mac" }
opt.undofile = true
opt.swapfile = false

-- sessions
opt.sessionoptions = { "buffers", "curdir", "folds", "help", "tabpages", "winsize", "winpos", "localoptions" }

-- responsiveness
opt.updatetime = 250
opt.timeoutlen = 500
opt.ttimeoutlen = 10

-- messages
opt.messagesopt = "wait:1000,history:500,progress:c"

-- #############################
-- # UI2                       #
-- #############################

require("vim._core.ui2").enable()

-- #############################
-- # Plugins                   #
-- #############################

local gh = function(repo)
  return "https://github.com/" .. repo
end

vim.pack.add({
  gh("nvim-mini/mini.nvim"),
  gh("willothy/flatten.nvim"),
  gh("folke/snacks.nvim"),
  gh("mrjones2014/codesettings.nvim"),
  gh("mason-org/mason.nvim"),
  gh("saghen/filler-begone.nvim"),
  gh("so1ve/tiny-treesitter.nvim"),
}, { confirm = false, load = true })

vim.pack.add({
  gh("CRAG666/betterTerm.nvim"),
  { src = gh("saghen/blink.cmp"), version = vim.version.range("1.*") },
  gh("stevearc/conform.nvim"),
  gh("zbirenbaum/copilot.lua"),
  gh("copilotlsp-nvim/copilot-lsp"),
  gh("gbprod/yanky.nvim"),
  gh("Wansmer/treesj"),
  gh("NeogitOrg/neogit"),
  gh("esmuellert/codediff.nvim"),
  gh("MagicDuck/grug-far.nvim"),
  gh("DrKJeff16/wezterm-types"),
  gh("Saecki/crates.nvim"),
  gh("neovim/nvim-lspconfig"),
  gh("b0o/schemastore.nvim"),
  gh("nvim-treesitter/nvim-treesitter-textobjects"),
  gh("wakatime/vim-wakatime"),
  gh("jake-stewart/multicursor.nvim"),
  gh("ThePrimeagen/refactoring.nvim"),
  gh("lewis6991/async.nvim"),
  gh("nvim-treesitter/nvim-treesitter-context"),
  gh("windwp/nvim-ts-autotag"),
  gh("folke/trouble.nvim"),
  gh("so1ve/tiny-comment.nvim"),
  gh("so1ve/copilot-ai-commit.nvim"),
  gh("so1ve/code-action-menu.nvim"),
  gh("so1ve/noicelet.nvim"),
  gh("so1ve/panels.nvim"),
}, { confirm = false, load = false })

local safely = require("mini.misc").safely

local function plugin_path(name)
  return vim.pack.get({ name }, { info = false })[1].path
end

local function load_plugins(when, names, configure)
  safely(when, function()
    for _, name in ipairs(type(names) == "table" and names or { names }) do
      vim.cmd.packadd(name)
    end

    if configure then
      configure()
    end
  end)
end

require("flatten").setup({
  window = {
    open = "alternate",
  },
})

-- #############################
-- # Diagnostics               #
-- #############################

vim.diagnostic.config({
  float = {
    border = "rounded",
    close_events = { "BufHidden", "CursorMoved", "CursorMovedI", "InsertCharPre" },
    format = function(diagnostic)
      return diagnostic.message:gsub("\n", " \n") .. (diagnostic.code and "" or " ")
    end,
    header = "",
    max_width = 80,
    source = "if_many",
    suffix = function(diagnostic)
      return diagnostic.code and (" [" .. diagnostic.code .. "] ") or "", "Comment"
    end,
  },
  severity_sort = true,
  virtual_text = true,
})

-- #############################
-- # Filetypes                 #
-- #############################

vim.g.filetype_typ = "typst"

vim.filetype.add({
  extension = {
    json5 = "jsonc",
  },
  filename = {
    ["compose.yaml"] = "yaml.docker-compose",
    ["compose.yml"] = "yaml.docker-compose",
    ["docker-compose.yaml"] = "yaml.docker-compose",
    ["docker-compose.yml"] = "yaml.docker-compose",
  },
  pattern = {
    [".*[\\/]%.github[\\/]workflows[\\/][^\\/]+%.ya?ml%..*"] = { "yaml", { priority = 1 } },
    [".*[\\/]%.github[\\/]workflows[\\/][^\\/]+%.ya?ml"] = "yaml.github-actions",
    ["compose%..*%.ya?ml"] = "yaml.docker-compose",
    ["docker%-compose%..*%.ya?ml"] = "yaml.docker-compose",
  },
})

-- #############################
-- # ftplugins                 #
-- #############################

autocmd("FileType", {
  pattern = { "tex", "typst" },
  callback = function()
    vim.opt_local.formatoptions:remove("r")
    vim.opt_local.formatoptions:append("o")
  end,
})

autocmd("FileType", {
  pattern = "markdown",
  callback = function()
    vim.opt_local.conceallevel = 0
  end,
})

autocmd("FileType", {
  pattern = "vue",
  callback = function()
    vim.opt_local.formatoptions:append("ro")

    -- Vue's bundled ftplugin only declares HTML comments. Include C-style comments so
    -- JSDoc blocks inside <script> keep Vim's native star continuation behavior.
    vim.bo.comments = table.concat({
      "sO:* -",
      "mO:*  ",
      "exO:*/",
      "s1:/*",
      "mb:*",
      "ex:*/",
      "://",
      "s:<!--",
      "m:    ",
      "e:-->",
    }, ",")
  end,
})

autocmd("FileType", {
  pattern = { "css", "scss", "html", "vue", "svelte" },
  callback = function()
    vim.opt_local.iskeyword:append("-")
  end,
})

-- #############################
-- # Ignored Files             #
-- #############################

local ignore_root
local ignored_paths = {}

local function ignored_files_changed()
  vim.api.nvim_exec_autocmds("User", { pattern = "RayGitIgnoreCacheUpdated" })
end

local function normalize_ignored_path(path)
  return vim.fs.normalize(path):gsub("\\", "/"):gsub("/+$", "")
end

local function relative_ignored_path(path)
  path = normalize_ignored_path(path)
  if ignore_root and path:sub(1, #ignore_root + 1) == ignore_root .. "/" then
    return path:sub(#ignore_root + 2)
  end
  return path:gsub("^%./", "")
end

local function refresh_ignored()
  local git_root = vim.fs.root(vim.fn.getcwd(), ".git")
  ignore_root = git_root and normalize_ignored_path(git_root)

  if not ignore_root then
    ignored_paths = {}
    ignored_files_changed()
    return
  end

  local refresh_root = ignore_root
  vim.system(
    { "git", "-C", ignore_root, "ls-files", "--ignored", "--others", "--exclude-standard", "--directory", "-z" },
    { text = true },
    vim.schedule_wrap(function(result)
      if ignore_root ~= refresh_root then
        return
      end

      ignored_paths = result.code == 0 and { [".git"] = true } or {}
      for path in (result.stdout or ""):gmatch("[^%z]+") do
        ignored_paths[relative_ignored_path(path)] = true
      end
      ignored_files_changed()
    end)
  )
end

local function is_ignored(path)
  path = relative_ignored_path(path)
  while path ~= "" do
    if ignored_paths[path] then
      return true
    end
    path = path:match("(.+)/[^/]+$") or ""
  end

  return false
end

refresh_ignored()
autocmd("DirChanged", { callback = refresh_ignored })
autocmd("BufWritePost", {
  pattern = { ".gitignore", "*/.gitignore", ".git/info/exclude", "*/.git/info/exclude" },
  callback = refresh_ignored,
})

-- #############################
-- # Terminal                  #
-- #############################

load_plugins("later", "betterTerm.nvim", function()
  require("betterTerm").setup({
    new_tab_mapping = "<C-n>",
    jump_tab_mapping = "<A-$tab>",
    index_base = 1,
    predefined = {
      { index = 1, name = "Main" },
      { index = 2, name = "Server" },
    },
  })
end)

map({ "n", "t" }, "<leader>tt", function()
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if vim.bo[vim.api.nvim_win_get_buf(win)].filetype == "better_term" then
      if vim.api.nvim_get_current_win() == win then
        require("betterTerm").open()
      else
        vim.api.nvim_win_hide(win)
      end
      return
    end
  end

  require("panels").open("better-term", function()
    require("betterTerm").open()
  end, { reuse = false })
end, { desc = "Toggle terminal" })

map("t", "<C-q>", function()
  require("betterTerm").close(vim.fn.bufname("%"))
end, { desc = "Close current terminal" })

map("n", "<leader>ts", function()
  require("betterTerm").select()
end, { desc = "Select terminal" })

map("n", "<leader>tr", function()
  require("betterTerm").rename()
end, { desc = "Rename terminal" })

-- #############################
-- # Completion                #
-- #############################

load_plugins("now", "blink.cmp", function()
  require("blink.cmp").setup({
    appearance = {
      kind_icons = {
        Array = "",
        Boolean = "",
        Class = "",
        Color = "",
        Constant = "",
        Constructor = "",
        Enum = "",
        EnumMember = "",
        Event = "",
        Field = "",
        File = "",
        Folder = "",
        Function = "",
        Interface = "",
        Key = "",
        Keyword = "",
        Method = "",
        Module = "",
        Namespace = "",
        Null = "",
        Number = "",
        Object = "",
        Operator = "",
        Package = "",
        Property = "",
        Reference = "",
        Snippet = "",
        String = "",
        Struct = "",
        Text = "",
        TypeParameter = "",
        Unit = "",
        Value = "",
        Variable = "",
      },
    },
    snippets = {
      preset = "mini_snippets",
    },
    keymap = {
      preset = "none",
      ["<Tab>"] = {
        "select_and_accept",
        function()
          local suggestion = require("copilot.suggestion")
          if not suggestion.is_visible() then
            return false
          end
          suggestion.accept()
          return true
        end,
        function()
          local nes = require("copilot.nes.api")
          if not nes.nes_apply_pending_nes() then
            return false
          end
          nes.nes_walk_cursor_end_edit()
          return true
        end,
        "fallback",
      },
      ["<C-space>"] = { "show", "show_documentation", "hide_documentation" },
      ["<C-d>"] = { "scroll_documentation_down", "scroll_signature_down", "fallback" },
      ["<C-u>"] = { "scroll_documentation_up", "scroll_signature_up", "fallback" },
      ["<C-n>"] = { "select_next", "show" },
      ["<C-p>"] = { "select_prev", "show" },
      ["<C-j>"] = { "select_next", "show" },
      ["<C-k>"] = { "select_prev", "show" },
      ["<Up>"] = { "select_prev", "fallback" },
      ["<Down>"] = { "select_next", "fallback" },
      ["<C-e>"] = { "hide", "fallback" },
    },
    cmdline = {
      keymap = {
        ["<Tab>"] = { "show", "accept" },
        ["<C-j>"] = { "select_next", "show" },
        ["<C-k>"] = { "select_prev", "show" },
      },
      completion = {
        menu = {
          auto_show = true,
        },
      },
    },
    completion = {
      menu = {
        draw = {
          gap = 2,
          treesitter = { "lsp" },
          columns = { { "kind_icon" }, { "label" }, { "detail" }, { "kind" } },
          components = {
            detail = {
              width = { max = 30 },
              text = function(ctx)
                local detail = ctx.item and ctx.item.detail

                if type(detail) ~= "string" then
                  return ""
                end

                return detail:match("^[^\r\n]+") or ""
              end,
              highlight = "BlinkCmpLabelDetail",
            },
            kind = {
              text = function(ctx)
                return ctx.kind or ""
              end,
              highlight = "Comment",
            },
          },
        },
      },
      documentation = {
        auto_show = true,
        auto_show_delay_ms = 0,
        window = {
          desired_min_width = 24,
          desired_min_height = 5,
          direction_priority = {
            menu_north = { "e", "n", "s" },
            menu_south = { "e", "s", "n" },
          },
        },
      },
    },
    sources = {
      providers = {
        lsp = {
          transform_items = function(ctx, items)
            if
              vim.bo[ctx.bufnr].filetype ~= "toml"
              or vim.fn.fnamemodify(vim.api.nvim_buf_get_name(ctx.bufnr), ":t") ~= "Cargo.toml"
            then
              return items
            end

            return vim
              .iter(items)
              :filter(function(item)
                return item.client_name ~= "crates.nvim"
                  or (item.kind_name ~= "Version" and item.kind_name ~= "Feature")
              end)
              :totable()
          end,
        },
        snippets = {
          opts = {
            use_items_cache = true,
            use_label_description = true,
          },
        },
      },
    },
    signature = {
      enabled = true,
    },
  })
end)

-- #############################
-- # Project Settings          #
-- #############################

local Control = require("codesettings.extensions").Control

require("codesettings").setup({
  loader_extensions = {
    "codesettings.extensions.vscode",
    {
      object = function(root, context)
        local gopls = root.gopls

        if #context.path ~= 0 or type(gopls) ~= "table" then
          return Control.CONTINUE
        end

        for _, source in pairs({ gopls.build, gopls.formatting, gopls.ui }) do
          if type(source) == "table" then
            for key, value in pairs(source) do
              if gopls[key] == nil then
                gopls[key] = value
              end
            end
          end
        end

        return Control.CONTINUE
      end,
    },
  },
  live_reload = true,
})

-- #############################
-- # Formatting                #
-- #############################

vim.env.PRETTIERD_LOCAL_PRETTIER_ONLY = "1"

local prettier = { "prettierd", "prettier", stop_after_first = true }

load_plugins("later", "conform.nvim", function()
  require("conform").setup({
    default_format_opts = {
      lsp_format = "fallback",
    },
    formatters_by_ft = {
      css = prettier,
      html = prettier,
      javascript = prettier,
      javascriptreact = prettier,
      json = prettier,
      jsonc = prettier,
      lua = { "stylua" },
      nix = { "nixfmt" },
      ps1 = { lsp_format = "never" },
      python = { "ruff_organize_imports", "ruff_format" },
      scss = prettier,
      toml = prettier,
      typescript = prettier,
      typescriptreact = prettier,
      vue = prettier,
      yaml = prettier,
    },
    format_after_save = function(bufnr)
      if vim.g.disable_autoformat or vim.b[bufnr].disable_autoformat then
        return nil
      end

      return {
        async = true,
      }
    end,
  })
end)

map({ "n", "v" }, "<leader>cf", function()
  require("conform").format({ async = true })
end, { desc = "Format buffer" })

-- #############################
-- # Copilot                   #
-- #############################

local restart = {
  delay = 5000,
  window = 5 * 60 * 1000,
  limit = 3,
  times = {},
}

local function restart_copilot(code)
  if code == 0 then
    return
  end

  local now = vim.uv.now()

  restart.times = vim
    .iter(restart.times)
    :filter(function(time)
      return now - time <= restart.window
    end)
    :totable()

  if #restart.times >= restart.limit then
    vim.notify(
      "Copilot LSP exited repeatedly; leaving it offline. Run :Copilot enable after the network recovers.",
      vim.log.levels.WARN
    )
    return
  end

  restart.times[#restart.times + 1] = now

  vim.defer_fn(function()
    local ok, err = pcall(vim.cmd, "Copilot enable")
    if not ok then
      vim.notify("Failed to restart Copilot LSP: " .. tostring(err), vim.log.levels.ERROR)
    end
  end, restart.delay)
end

vim.g.copilot_nes_debounce = 350

load_plugins("later", { "copilot-lsp", "copilot.lua" }, function()
  require("copilot").setup({
    filetypes = {
      markdown = true,
    },
    panel = { enabled = false },
    suggestion = {
      auto_trigger = true,
      keymap = {
        accept = false,
      },
    },
    nes = {
      enabled = true,
      auto_trigger = true,
    },
    server_opts_overrides = {
      on_exit = restart_copilot,
    },
  })

  autocmd("User", {
    pattern = "BlinkCmpMenuOpen",
    callback = function()
      require("copilot.suggestion").dismiss()
      vim.b.copilot_suggestion_hidden = true
    end,
  })

  autocmd("User", {
    pattern = "BlinkCmpMenuClose",
    callback = function()
      vim.b.copilot_suggestion_hidden = false
    end,
  })
end)

-- #############################
-- # Editing                   #
-- #############################

load_plugins("later", "yanky.nvim", function()
  require("yanky").setup({
    highlight = {
      on_put = false,
      timer = 300,
    },
  })
end)

map({ "n", "x" }, "y", "<Plug>(YankyYank)", { desc = "Yank text" })
map({ "n", "x" }, "p", "<Plug>(YankyPutAfter)", { desc = "Put after cursor" })
map({ "n", "x" }, "P", "<Plug>(YankyPutBefore)", { desc = "Put before cursor" })
map({ "n", "x" }, "gp", "<Plug>(YankyGPutAfter)", { desc = "Put after cursor and move cursor" })
map({ "n", "x" }, "gP", "<Plug>(YankyGPutBefore)", { desc = "Put before cursor and move cursor" })
map("n", "<C-p>", "<Plug>(YankyPreviousEntry)", { desc = "Previous yank" })
map("n", "<C-n>", "<Plug>(YankyNextEntry)", { desc = "Next yank" })
map({ "n", "x" }, "<leader>fy", function()
  Snacks.picker.yanky()
end, { desc = "Yank history" })

-- not using mini.splitjoin because it doesn't support rust match arms
--
-- ```
-- match arm {
--     true => {
--         1
--     }
-- }
-- ```
--
-- to
--
-- ```
-- match arm {
--     true => 1
-- }
load_plugins("later", "treesj", function()
  require("treesj").setup({
    use_default_keymaps = false,
  })
end)

map("n", "gs", function()
  require("treesj").toggle()
end, { desc = "Toggle split/join" })

load_plugins("later", "tiny-comment.nvim", function()
  require("tiny-comment").setup()
end)

-- #############################
-- # Git                       #
-- #############################

load_plugins("later", { "codediff.nvim", "copilot-ai-commit.nvim", "neogit" }, function()
  require("copilot-ai-commit").setup()
  require("codediff").setup({
    diff = {
      compute_moves = true,
    },
    explorer = {
      initial_focus = "explorer",
      visible_groups = {
        staged = true,
        unstaged = true,
        conflicts = true,
      },
    },
    keymaps = {
      view = {
        next_file = "<Tab>",
        prev_file = "<S-Tab>",
      },
      explorer = {
        refresh = "<c-r>",
        stage_all = "S",
        unstage_all = "U",
        restore = "x",
      },
      conflict = {
        next_conflict = "<leader>gcn",
        prev_conflict = "<leader>gcp",
        accept_incoming = "<leader>gci",
        accept_current = "<leader>gcc",
        accept_both = "<leader>gcb",
        discard = "<leader>gcB",
        accept_all_incoming = "<leader>gcI",
        accept_all_current = "<leader>gcC",
        accept_all_both = "<leader>gcA",
        discard_all = "<leader>gcX",
        diffget_incoming = "2do",
        diffget_current = "3do",
      },
    },
  })
  require("neogit").setup({
    treesitter_diff_highlight = true,
    disable_insert_on_commit = true,
    process_spinner = true,
    graph_style = "kitty",
    signs = {
      hunk = { "", "" },
      item = { "", "" },
      section = { "", "" },
    },
    integrations = {
      codediff = true,
      diffview = false,
      snacks = false,
      mini_pick = false,
    },
    diff_viewer = "codediff",
    mappings = {
      status = {
        ["C"] = function()
          require("copilot-ai-commit").commit_with_generated_message()
        end,
      },
    },
    commit_editor = {
      staged_diff_split_kind = "vsplit",
      spell_check = false,
    },
  })
end)

map("n", "<leader>gg", function()
  require("neogit").open()
end, { desc = "Git status" })

-- #############################
-- # Search and Replace        #
-- #############################

load_plugins("later", "grug-far.nvim", function()
  require("grug-far").setup({
    engines = {
      ripgrep = {
        defaults = {
          flags = "--smart-case",
        },
      },
    },
    keymaps = {
      close = { n = "q" },
      qflist = { n = "<localleader>F" },
      refresh = { n = "<C-r>" },
    },
    startInInsertMode = false,
  })
end)

map({ "n", "x" }, "<leader>sr", function()
  require("panels").open("grug-far", function()
    require("grug-far").open({
      transient = true,
      prefills = { paths = vim.fn.expand("%") },
    })
  end)
end, { desc = "Search and replace current file" })

map({ "n", "x" }, "<leader>sR", function()
  require("panels").open("grug-far", function()
    require("grug-far").open({ transient = true })
  end)
end, { desc = "Search and replace" })

-- #############################
-- # LSP                       #
-- #############################

local function expand_rust_macro(client, bufnr)
  client:request(
    "rust-analyzer/expandMacro",
    vim.lsp.util.make_position_params(0, client.offset_encoding),
    function(err, result)
      if err then
        vim.notify(err.message or "Failed to expand macro", vim.log.levels.ERROR)
        return
      end

      if not result then
        vim.notify("No macro under cursor", vim.log.levels.INFO)
        return
      end

      vim.schedule(function()
        local expansion_bufnr = vim.api.nvim_create_buf(false, true)

        vim.api.nvim_buf_set_lines(expansion_bufnr, 0, -1, false, vim.split(result.expansion, "\r?\n"))
        vim.bo[expansion_bufnr].bufhidden = "wipe"
        vim.bo[expansion_bufnr].filetype = "rust"
        vim.bo[expansion_bufnr].modifiable = false

        vim.cmd("botright vsplit")
        vim.api.nvim_win_set_buf(0, expansion_bufnr)
      end)
    end,
    bufnr
  )
end

local function configure_lsp_buffer(event)
  local bufnr = event.buf
  local client = vim.lsp.get_client_by_id(event.data.client_id)

  if not client then
    return
  end

  local function buf_map(lhs, rhs, desc)
    map("n", lhs, rhs, { buffer = bufnr, desc = desc })
  end

  buf_map("K", vim.lsp.buf.hover, "Hover documentation")
  buf_map("gd", Snacks.picker.lsp_definitions, "Go to definition")
  buf_map("gD", Snacks.picker.lsp_declarations, "Go to declaration")
  buf_map("gi", Snacks.picker.lsp_implementations, "Go to implementation")
  buf_map("gr", Snacks.picker.lsp_references, "References")
  buf_map("gy", Snacks.picker.lsp_type_definitions, "Go to type definition")
  map({ "n", "x" }, "<leader>ca", function()
    require("code-action-menu").code_action()
  end, { buffer = bufnr, desc = "Code action" })

  if client:supports_method(vim.lsp.protocol.Methods.textDocument_documentSymbol, bufnr) then
    buf_map("<leader>fs", Snacks.picker.lsp_symbols, "Document symbols")
  end

  if client:supports_method(vim.lsp.protocol.Methods.workspace_symbol) then
    buf_map("<leader>fS", Snacks.picker.lsp_workspace_symbols, "Workspace symbols")
  end

  if client:supports_method(vim.lsp.protocol.Methods.textDocument_inlayHint, bufnr) then
    vim.lsp.inlay_hint.enable(true, { bufnr = bufnr })
    buf_map("<leader>ci", function()
      local is_enabled = vim.lsp.inlay_hint.is_enabled({ bufnr = bufnr })
      vim.lsp.inlay_hint.enable(not is_enabled, { bufnr = bufnr })
    end, "Toggle inlay hints")
  end

  buf_map("<leader>cr", vim.lsp.buf.rename, "Rename symbol")
end

local tsserver_language_settings = {
  updateImportsOnFileMove = { enabled = "always" },
  suggest = {
    completeFunctionCalls = true,
  },
}

local servers = {
  ["*"] = {
    capabilities = {
      workspace = {
        fileOperations = {
          didRename = true,
          willRename = true,
        },
      },
    },
  },
  cssls = {},
  docker_compose_language_service = {},
  dockerls = {},
  gopls = {},
  html = {},
  unocss = {},
  vue_ls = {},
  zls = {},
  clangd = {
    cmd = {
      "clangd",
      "--background-index",
      "--completion-style=detailed",
      "--header-insertion=iwyu",
    },
  },
  jsonls = function()
    return {
      settings = {
        json = {
          format = {
            enable = true,
          },
          schemas = require("schemastore").json.schemas(),
          validate = {
            enable = true,
          },
        },
      },
    }
  end,
  tombi = {
    settings = {
      tombi = {
        extensions = {
          ["tombi-toml/cargo"] = {
            lsp = {
              ["code-action"] = {
                ["update-dependency-to-latest-version"] = {
                  enabled = false,
                },
              },
            },
          },
        },
      },
    },
  },
  yamlls = {
    filetypes = { "yaml", "yaml.github-actions" },
    capabilities = {
      textDocument = {
        foldingRange = {
          dynamicRegistration = false,
          lineFoldingOnly = true,
        },
      },
    },
    before_init = function(_, config)
      config.settings.yaml.schemas =
        vim.tbl_deep_extend("force", config.settings.yaml.schemas or {}, require("schemastore").yaml.schemas())
    end,
    settings = {
      redhat = {
        telemetry = {
          enabled = false,
        },
      },
      yaml = {
        keyOrdering = false,
        format = {
          enable = true,
        },
        validate = true,
        schemaStore = {
          enable = false,
          url = "",
        },
      },
    },
  },
  eslint = {
    before_init = function(_, config)
      if not config.root_dir then
        return
      end

      -- vscode-eslint expects a file URI here. On Windows, the upstream
      -- default raw path can make projectService resolve test files wrong.
      config.settings.workspaceFolder = {
        name = vim.fn.fnamemodify(config.root_dir, ":t"),
        uri = vim.uri_from_fname(config.root_dir),
      }
    end,
    filetypes = {
      "javascript",
      "typescript",
      "javascriptreact",
      "typescriptreact",
      "vue",
      "html",
      "markdown",
      "mdc",
      "json",
      "jsonc",
      "toml",
      "yaml",
      "yaml.github-actions",
      "svelte",
      "astro",
    },
    settings = {
      format = false,
      workingDirectory = {
        mode = "location",
      },
    },
  },
  texlab = {
    settings = {
      texlab = {
        latexFormatter = "latexindent",
        latexindent = {
          modifyLineBreaks = false,
        },
      },
    },
  },
  lua_ls = {
    settings = {
      Lua = {
        completion = {
          callSnippet = "Replace",
        },
        codeLens = {
          enable = true,
        },
        diagnostics = {
          globals = { "vim" },
        },
        runtime = {
          path = { "lua/?.lua", "lua/?/init.lua" },
          version = "LuaJIT",
        },
        telemetry = {
          enable = false,
        },
        workspace = {
          checkThirdParty = false,
          library = {
            vim.env.VIMRUNTIME,
            plugin_path("snacks.nvim"),
            plugin_path("mini.nvim"),
            plugin_path("wezterm-types"),
          },
        },
        doc = {
          privateName = { "^_" },
        },
        hint = {
          enable = true,
          setType = false,
          paramType = true,
          paramName = "Disable",
          semicolon = "Disable",
          arrayIndex = "Disable",
        },
      },
    },
  },
  powershell_es = {
    bundle_path = vim.fs.joinpath(vim.fn.stdpath("data"), "mason", "packages", "powershell-editor-services"),
  },
  basedpyright = {
    settings = {
      basedpyright = {
        analysis = {
          diagnosticSeverityOverrides = {
            reportUnusedImport = "none",
            reportUnusedVariable = "none",
          },
          typeCheckingMode = "standard",
        },
      },
    },
  },
  ruff = {
    cmd_env = {
      RUFF_TRACE = "messages",
    },
    init_options = {
      settings = {
        fixAll = true,
        logLevel = "error",
        lint = {
          extendSelect = { "I" },
        },
        organizeImports = true,
      },
    },
    on_attach = function(client)
      client.server_capabilities.hoverProvider = false
    end,
  },
  vtsls = {
    filetypes = {
      "javascript",
      "javascriptreact",
      "javascript.jsx",
      "typescript",
      "typescriptreact",
      "typescript.tsx",
      "vue",
    },
    settings = {
      complete_function_calls = true,
      vtsls = {
        autoUseWorkspaceTsdk = true,
        tsserver = {
          globalPlugins = {
            {
              name = "@vue/typescript-plugin",
              location = vim.fs.joinpath(
                vim.fn.stdpath("data"),
                "mason",
                "packages",
                "vue-language-server",
                "node_modules",
                "@vue",
                "language-server"
              ),
              languages = { "vue" },
              configNamespace = "typescript",
              enableForWorkspaceTypeScriptVersions = true,
            },
          },
        },
        experimental = {
          maxInlayHintLength = 30,
          completion = {
            enableServerSideFuzzyMatch = true,
          },
        },
      },
      typescript = tsserver_language_settings,
      javascript = tsserver_language_settings,
    },
  },
  tinymist = {
    settings = {
      formatterMode = "typstyle",
    },
  },
  rust_analyzer = {
    on_attach = function(client, bufnr)
      map("n", "<leader>ce", function()
        expand_rust_macro(client, bufnr)
      end, { buffer = bufnr, desc = "Expand macro" })
    end,
    settings = {
      ["rust-analyzer"] = {
        cargo = {
          allFeatures = true,
          loadOutDirsFromCheck = true,
          buildScripts = {
            enable = true,
          },
        },
        checkOnSave = true,
        check = {
          command = "clippy",
        },
        diagnostics = {
          enable = true,
        },
        files = {
          exclude = {
            ".direnv",
            ".git",
            ".github",
            ".gitlab",
            ".jj",
            ".venv",
            "bin",
            "node_modules",
            "target",
            "venv",
          },
          watcher = "client",
        },
        procMacro = {
          enable = true,
        },
        rustfmt = {
          rangeFormatting = {
            enable = true,
          },
        },
      },
    },
  },
  stylelint_lsp = {
    filetypes = { "css", "scss", "html", "vue" },
    settings = {
      stylelint = {
        validate = { "css", "scss", "html", "vue" },
      },
    },
  },
}

load_plugins("later", "crates.nvim", function()
  require("crates").setup({
    completion = {
      crates = {
        enabled = true,
      },
    },
    lsp = {
      enabled = true,
      actions = true,
      completion = true,
      hover = true,
    },
  })
end)

load_plugins("later", "code-action-menu.nvim", function()
  require("code-action-menu").setup()
end)

load_plugins("later", "noicelet.nvim", function()
  require("noicelet").setup({
    window = {
      x_padding = 10,
      y_padding = 2,
    },
  })
end)

load_plugins("now", { "schemastore.nvim", "nvim-lspconfig" }, function()
  for server_name, config in pairs(servers) do
    config = type(config) == "function" and config() or config
    local before_init = config.before_init

    config.before_init = function(init_params, client_config)
      if before_init then
        before_init(init_params, client_config)
      end
      local loader = require("codesettings").loader()
      if client_config.root_dir then
        loader = loader:root_dir(client_config.root_dir)
      end
      loader:with_local_settings(
        client_config.name == "rust_analyzer" and "rust-analyzer" or client_config.name,
        client_config
      )
    end

    vim.lsp.config(server_name, config)

    if server_name ~= "*" then
      vim.lsp.enable(server_name)
    end
  end

  autocmd("LspAttach", {
    callback = configure_lsp_buffer,
  })
end)

-- #############################
-- # Mason                     #
-- #############################

require("mason").setup()

local mason_tools = {
  "basedpyright",
  "clangd",
  "css-lsp",
  "docker-compose-language-service",
  "dockerfile-language-server",
  "eslint-lsp",
  "gofumpt",
  "goimports",
  "gopls",
  "html-lsp",
  "json-lsp",
  "latexindent",
  "lua-language-server",
  "nixfmt",
  "powershell-editor-services",
  "prettier",
  "prettierd",
  "ruff",
  "stylelint-language-server",
  "stylua",
  "texlab",
  "tinymist",
  "tombi",
  "unocss-language-server",
  "vtsls",
  "vue-language-server",
  "yaml-language-server",
  "zls",
}

local mason_registry = require("mason-registry")
local mason_notify = vim.schedule_wrap(function(message, level)
  vim.notify(message, level, { title = "Mason" })
end)

mason_registry.refresh(function()
  for _, name in ipairs(mason_tools) do
    local tool = mason_registry.get_package(name)
    if not tool:is_installed() then
      mason_notify(name .. ": installing", vim.log.levels.INFO)
      tool:install({}, function(success)
        mason_notify(
          name .. (success and ": successfully installed" or ": failed to install"),
          success and vim.log.levels.INFO or vim.log.levels.ERROR
        )
      end)
    end
  end
end)

-- #############################
-- # Mini                      #
-- #############################

local mini_excluded_filetypes = {
  "bigfile",
  "gitcommit",
  "help",
  "markdown",
}

require("mini.misc").setup_restore_cursor()

local icons = require("mini.icons")
icons.setup()
icons.mock_nvim_web_devicons()

safely("later", function()
  local clue = require("mini.clue")
  local gen_clues = clue.gen_clues

  clue.setup({
    triggers = {
      { mode = { "n", "x" }, keys = "<Leader>" },
      { mode = { "n", "x" }, keys = "g" },
      { mode = { "n", "x" }, keys = "z" },
      { mode = "n", keys = "<C-w>" },
      { mode = "n", keys = "[" },
      { mode = "n", keys = "]" },
      { mode = { "n", "x" }, keys = "'" },
      { mode = { "n", "x" }, keys = "`" },
      { mode = { "n", "x" }, keys = '"' },
      { mode = "i", keys = "<C-x>" },
      { mode = { "i", "c" }, keys = "<C-r>" },
      { mode = { "n", "x" }, keys = "s" },
    },
    clues = {
      { mode = "n", keys = "<Leader>a", desc = "+AI" },
      { mode = "n", keys = "<Leader>b", desc = "+Buffer" },
      { mode = "n", keys = "<Leader>c", desc = "+Code" },
      { mode = "n", keys = "<Leader>d", desc = "+Diagnostics" },
      { mode = "n", keys = "<Leader>f", desc = "+Find" },
      { mode = "n", keys = "<Leader>g", desc = "+Git" },
      { mode = "n", keys = "<Leader>gc", desc = "+Conflicts" },
      { mode = "n", keys = "<Leader>gcn", desc = "Next", postkeys = "<Leader>gc" },
      { mode = "n", keys = "<Leader>gcp", desc = "Previous", postkeys = "<Leader>gc" },
      { mode = "n", keys = "<Leader>gcr", desc = "Refresh", postkeys = "<Leader>gc" },
      { mode = "n", keys = "<Leader>gcc", desc = "Accept current", postkeys = "<Leader>gc" },
      { mode = "n", keys = "<Leader>gci", desc = "Accept incoming", postkeys = "<Leader>gc" },
      { mode = "n", keys = "<Leader>gcB", desc = "Accept both", postkeys = "<Leader>gc" },
      { mode = "n", keys = "<Leader>gcb", desc = "Accept base", postkeys = "<Leader>gc" },
      { mode = "n", keys = "<Leader>gcl", desc = "Files" },
      { mode = "n", keys = "<Leader>gcQ", desc = "Quickfix" },
      { mode = "n", keys = "<Leader>m", desc = "+Multicursor" },
      { mode = { "n", "x" }, keys = "<Leader>m<C-j>", desc = "Add cursor down", postkeys = "<Leader>m" },
      { mode = { "n", "x" }, keys = "<Leader>m<C-k>", desc = "Add cursor up", postkeys = "<Leader>m" },
      { mode = { "n", "x" }, keys = "<Leader>ma", desc = "Add all matches" },
      { mode = "n", keys = "<Leader>n", desc = "+Notifications" },
      { mode = "n", keys = "<Leader>p", desc = "+Project" },
      { mode = "n", keys = "<Leader>q", desc = "+Quit / Buffer / Window" },
      { mode = "n", keys = "<Leader>r", desc = "+Refactor" },
      { mode = "n", keys = "<Leader>s", desc = "+Search" },
      { mode = "n", keys = "<Leader>t", desc = "+Terminal" },
      { mode = "n", keys = "<Leader>u", desc = "+UI" },
      { mode = "n", keys = "<Leader>x", desc = "+Trouble" },
      { mode = { "n", "x" }, keys = "<Leader>y", desc = "+Yank/Paste" },
      { mode = { "n", "x" }, keys = "s", desc = "+Surround" },

      gen_clues.builtin_completion(),
      gen_clues.g(),
      gen_clues.marks(),
      gen_clues.registers(),
      gen_clues.windows({
        submode_move = true,
        submode_navigate = true,
        submode_resize = true,
      }),
      gen_clues.square_brackets(),
      gen_clues.z(),
    },
    window = {
      delay = 300,
      config = {
        width = "auto",
      },
    },
  })
end)

safely("later", function()
  local function disable_buffer_modules(buf)
    if vim.bo[buf].buftype ~= "" or vim.tbl_contains(mini_excluded_filetypes, vim.bo[buf].filetype) then
      vim.b[buf].miniindentscope_disable = true
      vim.b[buf].minicursorword_disable = true
    end
  end

  autocmd({ "BufWinEnter", "FileType" }, {
    callback = function(event)
      disable_buffer_modules(event.buf)
    end,
  })

  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    disable_buffer_modules(buf)
  end

  local ai = require("mini.ai")
  local gen_ai_spec = require("mini.extra").gen_ai_spec
  local ts = ai.gen_spec.treesitter
  ai.setup({
    n_lines = 500,
    search_method = "cover",
    custom_textobjects = {
      ["="] = ts({ a = "@assignment.outer", i = "@assignment.inner" }),
      ["/"] = ts({ a = "@comment.outer", i = "@comment.inner" }),
      B = gen_ai_spec.buffer(),
      F = ts({ a = "@call.outer", i = "@call.inner" }),
      I = gen_ai_spec.indent(),
      a = ts({ a = "@parameter.outer", i = "@parameter.inner" }),
      b = ts({ a = "@block.outer", i = "@block.inner" }),
      c = ts({ a = "@class.outer", i = "@class.inner" }),
      f = ts({ a = "@function.outer", i = "@function.inner" }),
      i = ts({ a = "@conditional.outer", i = "@conditional.inner" }),
      r = ts({ a = "@return.outer", i = "@return.inner" }),
      -- intentional: use outer for both because inner is not consistent across languages
      s = ts({ a = "@statement.outer", i = "@statement.outer" }),
    },
  })

  require("mini.git").setup()
  require("mini.align").setup()
  require("mini.pairs").setup({
    mappings = {
      ['"'] = false,
      ["'"] = false,
      ["`"] = false,
    },
  })
  require("mini.surround").setup()
  require("mini.jump").setup()
  require("mini.cursorword").setup({ delay = 0 })
  require("mini.indentscope").setup({
    symbol = "│",
    draw = {
      animation = function()
        return 8
      end,
    },
    mappings = {
      object_scope = "",
      object_scope_with_border = "",
      goto_top = "",
      goto_bottom = "",
    },
  })

  local jump2d = require("mini.jump2d")
  local spotter =
    jump2d.gen_spotter.union(jump2d.builtin_opts.word_start.spotter, jump2d.gen_spotter.pattern(".+", "end"))
  jump2d.setup({
    spotter = spotter,
    labels = "abcdefghijklmnopqrstuvwxyz",
    view = { n_steps_ahead = 2 },
    allowed_windows = { not_current = false },
    mappings = { start_jumping = "<leader>j" },
  })

  require("mini.move").setup()
  require("mini.operators").setup({
    exchange = { prefix = "gX" },
    replace = { prefix = "gR" },
    sort = { prefix = "" },
  })
  require("mini.trailspace").setup()
  require("mini.bracketed").setup({
    buffer = { suffix = "" },
    comment = { suffix = "" },
    file = { suffix = "" },
    treesitter = { suffix = "" },
  })
end)

safely("later", function()
  local diff = require("mini.diff")

  diff.setup({
    mappings = {
      apply = "gh",
      reset = "gH",
      textobject = "gh",
      goto_first = "[C",
      goto_prev = "[c",
      goto_next = "]c",
      goto_last = "]C",
    },
  })

  map("n", "<leader>go", function()
    diff.toggle_overlay(0)
  end, { desc = "Toggle diff overlay" })

  map("n", "<leader>gh", function()
    local hunks = diff.export("qf", { scope = "current" })

    if #hunks == 0 then
      vim.notify("No hunks in current file", vim.log.levels.INFO)

      return
    end

    vim.fn.setqflist(hunks, "r")
    vim.cmd.copen()
  end, { desc = "Current file hunks" })
end)

safely("later", function()
  local show_hidden = false

  local files = require("mini.files")

  local opts = {
    content = {
      filter = function(entry)
        return show_hidden or not is_ignored(entry.path or entry.name)
      end,
      highlight = function(entry)
        if is_ignored(entry.path or entry.name) then
          return "MiniFilesHidden"
        end

        return files.default_highlight(entry)
      end,
    },
    mappings = {
      go_in = "L",
      go_in_plus = "<C-l>",
      go_out = "H",
      go_out_plus = "<C-h>",
      synchronize = "s",
    },
    windows = {
      preview = true,
      width_preview = 40,
    },
  }

  files.setup(opts)

  autocmd("User", {
    pattern = "MiniFilesExplorerOpen",
    callback = function()
      files.set_bookmark("c", vim.fn.stdpath("config"), { desc = "Config" })
      files.set_bookmark("w", vim.fn.getcwd, { desc = "Working directory" })
    end,
  })

  autocmd("User", {
    pattern = "MiniFilesBufferCreate",
    callback = function(args)
      map("n", "<CR>", function()
        files.go_in({ close_on_file = true })
      end, { buffer = args.data.buf_id, desc = "Go in plus" })
      map("n", "J", "j", { buffer = args.data.buf_id, desc = "Move down" })
      map("n", "K", "k", { buffer = args.data.buf_id, desc = "Move up" })
      map("n", "gh", function()
        show_hidden = not show_hidden
        files.refresh(opts)
      end, { buffer = args.data.buf_id, desc = "Toggle hidden entries" })
    end,
  })

  autocmd("User", {
    pattern = "RayGitIgnoreCacheUpdated",
    callback = function()
      files.refresh(opts)
    end,
  })

  autocmd("User", {
    pattern = "MiniFilesActionDelete",
    callback = function(event)
      Snacks.bufdelete({ file = vim.fs.normalize(event.data.from) })
    end,
  })

  map("n", "<leader>e", function()
    files.close()
    files.open(vim.fn.getcwd(), false)
  end, { desc = "Explore files" })
  map("n", "<leader>E", function()
    files.close()
    local path = vim.api.nvim_buf_get_name(0)
    -- silently ignore if file doesn't exist
    if path == "" or not vim.uv.fs_stat(path) then
      files.open(vim.fn.getcwd(), false)
      return
    end

    files.open(path, false)
    files.reveal_cwd()
  end, { desc = "Reveal current file" })
end)

safely("later", function()
  -- Match keyword labels followed by a colon or parenthesis, but not dotted access like vim.log.levels.WARN.
  local todo_suffix = "%s*[:%(]"

  local function todo_highlighter(keyword, group)
    return {
      pattern = {
        "^()" .. keyword .. "()" .. todo_suffix,
        "[^%.%w_]()" .. keyword .. "()" .. todo_suffix,
      },
      group = function(buf_id, _, data)
        for _, capture in ipairs(vim.treesitter.get_captures_at_pos(buf_id, data.line - 1, data.from_col - 1)) do
          if capture.capture:find("^comment") then
            return group
          end
        end
      end,
    }
  end

  local hipatterns = require("mini.hipatterns")

  hipatterns.setup({
    highlighters = {
      hex_color = hipatterns.gen_highlighter.hex_color(),

      bug = todo_highlighter("BUG", "MiniHipatternsFixme"),
      fix = todo_highlighter("FIX", "MiniHipatternsFixme"),
      fixit = todo_highlighter("FIXIT", "MiniHipatternsFixme"),
      fixme = todo_highlighter("FIXME", "MiniHipatternsFixme"),
      hack = todo_highlighter("HACK", "MiniHipatternsHack"),
      info = todo_highlighter("INFO", "MiniHipatternsNote"),
      issue = todo_highlighter("ISSUE", "MiniHipatternsFixme"),
      note = todo_highlighter("NOTE", "MiniHipatternsNote"),
      optimize = todo_highlighter("OPTIMIZE", "MiniHipatternsPerf"),
      optim = todo_highlighter("OPTIM", "MiniHipatternsPerf"),
      passed = todo_highlighter("PASSED", "MiniHipatternsTest"),
      perf = todo_highlighter("PERF", "MiniHipatternsPerf"),
      performance = todo_highlighter("PERFORMANCE", "MiniHipatternsPerf"),
      test = todo_highlighter("TEST", "MiniHipatternsTest"),
      testing = todo_highlighter("TESTING", "MiniHipatternsTest"),
      todo = todo_highlighter("TODO", "MiniHipatternsTodo"),
      warn = todo_highlighter("WARN", "MiniHipatternsWarn"),
      warning = todo_highlighter("WARNING", "MiniHipatternsWarn"),
    },
  })
end)

safely("later", function()
  local minimap = require("mini.map")

  minimap.setup({
    integrations = {
      -- FIXME: `builtin_search` moves the source cursor and restores it via
      -- `winrestview()`, but cursor-relative float geometry stays stale until redraw,
      -- so DiagnosticChanged refreshes can send blink.cmp to the top-left corner.
      -- Wait for https://github.com/nvim-mini/mini.nvim/issues/2509
      -- minimap.gen_integration.builtin_search({ search = "MiniMapSearch" }),
      minimap.gen_integration.diagnostic({
        error = "MiniMapDiagnosticError",
        warn = "MiniMapDiagnosticWarn",
        info = "MiniMapDiagnosticInfo",
        hint = "MiniMapDiagnosticHint",
      }),
      minimap.gen_integration.diff({
        add = "MiniMapDiffAdd",
        change = "MiniMapDiffChange",
        delete = "MiniMapDiffDelete",
      }),
    },
    window = {
      zindex = 60,
    },
  })

  local function sync_map(event)
    if event and event.buf ~= vim.api.nvim_get_current_buf() then
      return
    end

    if
      vim.api.nvim_win_get_config(0).relative ~= ""
      or vim.bo.buftype ~= ""
      or vim.api.nvim_buf_get_name(0) == ""
      or vim.tbl_contains(mini_excluded_filetypes, vim.bo.filetype)
    then
      minimap.close()
      return
    end

    minimap.open()
  end

  map("n", "<leader>um", minimap.toggle, { desc = "Toggle minimap" })

  autocmd({ "BufWinEnter", "FileType" }, {
    callback = sync_map,
  })
  sync_map()
end)

local sessions = require("mini.sessions")

local session_dir = vim.fs.joinpath(vim.fn.stdpath("state"), "sessions")

local function decode_path(path)
  local decoded = path:gsub("%%", "/")

  if jit.os:find("Windows") then
    decoded = decoded:gsub("^(%w)/", "%1:/")
  end

  return decoded
end

local function current_session_name()
  return vim.fn.getcwd():gsub("[\\/:]+", "%%") .. ".vim"
end

local function session_path(name)
  return vim.fs.joinpath(session_dir, name)
end

local function read_session(name)
  if vim.fn.filereadable(session_path(name)) == 1 then
    sessions.read(name)
  end
end

local function has_file_buffer()
  return vim.iter(vim.api.nvim_list_bufs()):any(function(buf)
    return vim.bo[buf].buftype == "" and vim.api.nvim_buf_get_name(buf) ~= ""
  end)
end

local function save_session(verbose, require_file_buffer)
  if require_file_buffer and not has_file_buffer() then
    return
  end

  sessions.write(current_session_name(), { verbose = verbose })
end

local function list_sessions()
  local paths = vim.fn.glob(session_dir .. "/*.vim", true, true)

  table.sort(paths, function(a, b)
    return vim.fn.getftime(a) > vim.fn.getftime(b)
  end)

  return vim.tbl_map(function(path)
    local name = vim.fn.fnamemodify(path, ":t")
    return { dir = decode_path(vim.fn.fnamemodify(name, ":r")), name = name }
  end, paths)
end

local function select_session()
  vim.ui.select(list_sessions(), {
    prompt = "Select a session: ",
    format_item = function(item)
      return vim.fn.fnamemodify(item.dir, ":p:~")
    end,
  }, function(item)
    if not item then
      return
    end

    save_session(false, true)
    vim.fn.chdir(item.dir)
    read_session(item.name)
  end)
end

sessions.setup({
  autowrite = false,
  directory = session_dir,
  file = "",
})

autocmd("DirChanged", {
  callback = function()
    if vim.v.this_session ~= "" then
      vim.v.this_session = session_path(current_session_name())
    end
  end,
})

autocmd("ExitPre", {
  callback = function()
    save_session(false, true)
  end,
})

map("n", "<leader>pr", function()
  read_session(current_session_name())
end, { desc = "Restore project session" })
map("n", "<leader>pw", function()
  save_session(true, false)
end, { desc = "Save session" })
map("n", "<leader>ps", select_session, { desc = "Select session" })
map("n", "<leader>pl", sessions.read, { desc = "Restore last session" })

-- TODO: reverted to `mini.snippets` again because builtin `vim.snippet` cannot exit session correctly
-- when sessions are nested
safely("later", function()
  local snippets = require("mini.snippets")
  local gen_loader = snippets.gen_loader

  snippets.setup({
    snippets = {
      gen_loader.from_lang({
        lang_patterns = {
          javascriptreact = { "**/javascript.json" },
          typescript = { "**/javascript.json" },
          typescriptreact = { "**/javascript.json" },
          vue = { "**/vue.json", "**/javascript.json" },
        },
      }),
    },
    mappings = {
      expand = "",
      jump_next = "",
      jump_prev = "",
    },
    expand = {
      insert = function(snippet)
        return snippets.default_insert(snippet, {
          empty_tabstop = "",
          empty_tabstop_final = "",
        })
      end,
    },
  })

  autocmd("ModeChanged", {
    pattern = "*:n",
    callback = function()
      while snippets.session.get() do
        snippets.session.stop()
      end
    end,
  })
end)

safely("now", function()
  local trunc_width = 120
  local max_path_width = 100

  local function statusline_escape(text)
    return tostring(text):gsub("%%", "%%%%")
  end

  local function statusline_macro()
    local register = vim.fn.reg_recording()

    if register == "" then
      return ""
    end

    return statusline_escape("recording @" .. register)
  end

  local function statusline_workspace()
    local workspace = vim.fn.fnamemodify(vim.fn.getcwd(0), ":t")

    if workspace == "" then
      return ""
    end

    return statusline_escape(workspace:upper())
  end

  local function statusline_show_fileinfo()
    return not MiniStatusline.is_truncated(trunc_width) and vim.bo.buftype == ""
  end

  local function redraw_statusline()
    vim.schedule(function()
      vim.cmd.redrawstatus()
    end)
  end

  local function statusline_metadata()
    if not statusline_show_fileinfo() then
      return ""
    end

    local encoding = vim.bo.fileencoding ~= "" and vim.bo.fileencoding or vim.o.encoding
    local format = vim.bo.fileformat

    return string.format("%s[%s]", encoding, format)
  end

  local function statusline_highlight(hl, text)
    return "%#" .. hl .. "#" .. statusline_escape(text)
  end

  local function statusline_diff()
    if MiniStatusline.is_truncated(75) or type(vim.b.minidiff_summary) ~= "table" then
      return ""
    end

    local summary = vim.b.minidiff_summary
    local parts = {}

    if (summary.add or 0) > 0 then
      table.insert(parts, statusline_highlight("MiniStatuslineDiffAdd", "+" .. summary.add))
    end

    if (summary.change or 0) > 0 then
      table.insert(parts, statusline_highlight("MiniStatuslineDiffChange", "~" .. summary.change))
    end

    if (summary.delete or 0) > 0 then
      table.insert(parts, statusline_highlight("MiniStatuslineDiffDelete", "-" .. summary.delete))
    end

    if #parts == 0 then
      return ""
    end

    return table.concat(parts, " ") .. "%#MiniStatuslineDevinfo#"
  end

  local function statusline_diagnostic_counts()
    if MiniStatusline.is_truncated(90) then
      return ""
    end

    local counts = vim.diagnostic.count(0)

    local parts = {}

    for _, item in ipairs({
      { vim.diagnostic.severity.ERROR, "MiniStatuslineDiagnosticError" },
      { vim.diagnostic.severity.WARN, "MiniStatuslineDiagnosticWarn" },
      { vim.diagnostic.severity.INFO, "MiniStatuslineDiagnosticInfo" },
      { vim.diagnostic.severity.HINT, "MiniStatuslineDiagnosticHint" },
    }) do
      local severity, group = item[1], item[2]
      local count = counts[severity] or 0

      if count > 0 then
        local label = vim.diagnostic.severity[severity]:sub(1, 1)
        table.insert(parts, statusline_highlight(group, label .. " " .. count))
      end
    end

    if #parts == 0 then
      return ""
    end

    return table.concat(parts, " ") .. "%#MiniStatuslineDiagnostics#"
  end

  local function statusline_pretty_path()
    local path = vim.api.nvim_buf_get_name(0)

    if path == "" then
      return ""
    end

    path = vim.fs.normalize(vim.fn.fnamemodify(path, ":p"))

    local cwd = vim.fs.normalize(vim.fn.getcwd(0))
    local relative = vim.fs.relpath(cwd, path)

    relative = (relative or path):gsub("\\", "/")

    if vim.fn.strdisplaywidth(relative) <= max_path_width then
      return relative
    end

    local parts = vim.split(relative, "/", { plain = true })

    if #parts <= 2 then
      return relative
    end

    for tail_start = 3, #parts do
      local shortened = { parts[1], "…" }

      for index = tail_start, #parts do
        table.insert(shortened, parts[index])
      end

      relative = table.concat(shortened, "/")

      if vim.fn.strdisplaywidth(relative) <= max_path_width then
        break
      end
    end

    return relative
  end

  local function statusline_file()
    local path = vim.api.nvim_buf_get_name(0)

    if path == "" or vim.bo.buftype ~= "" then
      return ""
    end

    local icon, icon_hl = MiniIcons.get("file", path)
    local icon_part = "%#" .. icon_hl .. "#" .. statusline_escape(icon)

    if MiniStatusline.is_truncated(trunc_width) then
      return icon_part
    end

    local pretty_path = statusline_pretty_path()
    local directory, filename = pretty_path:match("^(.*[/\\])([^/\\]+)$")
    local path_part = "%#MiniStatuslineFilename#" .. statusline_escape(filename or pretty_path)

    if filename then
      path_part = "%#MiniStatuslineDirectory#"
        .. statusline_escape(directory)
        .. "%#MiniStatuslineFilename#"
        .. statusline_escape(filename)
    end

    return icon_part .. "%#MiniStatuslinePath# " .. path_part
  end

  local function statusline_active()
    local mode, mode_hl = MiniStatusline.section_mode({ trunc_width = trunc_width })
    local workspace = statusline_workspace()
    local git = MiniStatusline.section_git({ trunc_width = trunc_width })
    local diff = statusline_diff()
    local file = statusline_file()
    local diagnostics = statusline_diagnostic_counts()
    local metadata = statusline_metadata()

    return MiniStatusline.combine_groups({
      { hl = mode_hl, strings = { mode } },
      { hl = "MiniStatuslineWorkspace", strings = { workspace } },
      { hl = "MiniStatuslineDevinfo", strings = { git, diff } },
      "%<",
      { hl = "MiniStatuslinePath", strings = { file } },
      { hl = "MiniStatuslineDiagnostics", strings = { diagnostics } },
      "%=",
      { hl = "MiniStatuslineInputState", strings = { statusline_macro(), "%S" } },
      { hl = "MiniStatuslineMetadata", strings = { statusline_escape(metadata) } },
      { hl = mode_hl, strings = { "%l/%L:%v" } },
    })
  end

  local function statusline_inactive()
    return "%#MiniStatuslineInactive#%="
  end

  require("mini.statusline").setup({
    content = {
      active = statusline_active,
      inactive = statusline_inactive,
    },
  })

  autocmd({ "RecordingEnter", "RecordingLeave", "DiagnosticChanged" }, {
    callback = redraw_statusline,
  })

  autocmd("User", {
    pattern = { "MiniDiffUpdated", "MiniGitUpdated" },
    callback = redraw_statusline,
  })
end)

safely("now", function()
  local tabline = require("mini.tabline")

  tabline.setup({
    format = function(buf_id, label)
      local suffix = vim.bo[buf_id].modified and "[+] " or ""

      return " " .. tabline.default_format(buf_id, label) .. suffix .. " "
    end,
    tabpage_section = "right",
  })
end)

-- #############################
-- # Miscellaneous             #
-- #############################

load_plugins("later", "vim-wakatime")

-- #############################
-- # Multicursor               #
-- #############################

-- TODO: https://x.com/justinmk/status/2075633035504910551
load_plugins("later", "multicursor.nvim", function()
  local mc = require("multicursor-nvim")

  mc.setup()

  local append_at_line_end = function()
    mc.action(function(ctx)
      ctx:forEachCursor(function(cursor)
        cursor:feedkeys("$")
      end)
    end)
    mc.feedkeys("a")
  end

  local add_cursor_down = function()
    mc.lineAddCursor(1)
  end

  local add_cursor_up = function()
    mc.lineAddCursor(-1)
  end

  local match_all = function()
    local mode = vim.fn.mode()
    local cursor = vim.fn.getpos(".")
    local anchor = vim.fn.getpos("v")

    mc.matchAllAddCursors()

    if mode == "n" then
      mc.feedkeys("e")
      return
    end

    local cursor_before_anchor = cursor[2] < anchor[2] or (cursor[2] == anchor[2] and cursor[3] < anchor[3])
    local start = cursor_before_anchor and cursor or anchor
    local row = cursor[2] - start[2]
    local col = cursor[3] - (row == 0 and start[3] or 1)

    mc.action(function(ctx)
      ctx:forEachCursor(function(curr)
        curr:setPos({
          curr:line() + row,
          row == 0 and curr:col() + col or col + 1,
        })
      end)
    end)
  end

  map({ "n", "x" }, "<leader>m<C-j>", add_cursor_down, { desc = "Add cursor down" })
  map({ "n", "x" }, "<leader>m<C-k>", add_cursor_up, { desc = "Add cursor up" })
  map({ "n", "x" }, "<leader>ma", match_all, { desc = "Add cursor to all matches" })

  map("n", "<C-leftmouse>", mc.handleMouse, { desc = "Add cursor with mouse" })
  map("n", "<C-leftdrag>", mc.handleMouseDrag, { desc = "Drag cursor with mouse" })
  map("n", "<C-leftrelease>", mc.handleMouseRelease, { desc = "Release cursor with mouse" })
  map("n", "<Esc>", function()
    if mc.hasCursors() then
      mc.clearCursors()
    else
      vim.cmd("nohlsearch")
    end
  end, { desc = "Clear search highlight or multicursors" })

  mc.addKeymapLayer(function(layer_map)
    layer_map("n", "A", append_at_line_end)
    layer_map("n", "<C-j>", add_cursor_down)
    layer_map("n", "<C-k>", add_cursor_up)
    layer_map("x", "I", mc.insertVisual)
    layer_map("x", "A", mc.appendVisual)
    layer_map("n", "<Esc>", function()
      if not mc.cursorsEnabled() then
        mc.enableCursors()
      else
        mc.clearCursors()
      end
    end)
  end)
end)

-- #############################
-- # Panels                    #
-- #############################

local function is_loclist(_, win)
  return vim.fn.getwininfo(win)[1].loclist == 1
end

load_plugins("later", "panels.nvim", function()
  require("panels").setup({
    panels = {
      ["grug-far"] = {
        title = "Search & Replace",
        position = "right",
        ft = "grug-far",
      },
      ["better-term"] = {
        position = "bottom",
        ft = "better_term",
        size = 15,
      },
      ["trouble.problems"] = {
        title = "Problems",
        position = "bottom",
        ft = "trouble",
      },
      help = {
        title = "Help",
        position = "bottom",
        ft = "help",
        size = 1 / 2,
        filter = function(buf)
          return vim.bo[buf].buftype == "help"
        end,
      },
      quickfix = {
        title = "Quickfix",
        position = "bottom",
        ft = "qf",
        filter = function(buf, win)
          return not is_loclist(buf, win)
        end,
      },
      loclist = {
        title = "Loclist",
        position = "bottom",
        ft = "qf",
        filter = is_loclist,
      },
      terminal = {
        title = "Terminal Buffer",
        position = "bottom",
        ft = "",
        filter = function(buf)
          return vim.bo[buf].buftype == "terminal" and vim.bo[buf].filetype ~= "better_term"
        end,
      },
    },
  })
end)

-- #############################
-- # Refactoring               #
-- #############################

load_plugins("later", { "async.nvim", "refactoring.nvim" }, function()
  require("refactoring").setup()
end)
map("x", "<leader>rf", function()
  return require("refactoring").extract_func()
end, { expr = true, desc = "Extract function" })
map("x", "<leader>rF", function()
  return require("refactoring").extract_func_to_file()
end, { expr = true, desc = "Extract function to file" })
map("x", "<leader>rv", function()
  return require("refactoring").extract_var()
end, { expr = true, desc = "Extract variable" })
map({ "n", "x" }, "<leader>ri", function()
  return require("refactoring").inline_var()
end, { expr = true, desc = "Inline variable" })
map({ "n", "x" }, "<leader>rI", function()
  return require("refactoring").inline_func()
end, { expr = true, desc = "Inline function" })
map({ "n", "x" }, "<leader>rs", function()
  require("refactoring").select_refactor()
end, { desc = "Select refactor" })

-- #############################
-- # Snacks                    #
-- #############################

require("snacks").setup({
  bigfile = {},
  quickfile = {},
  picker = {
    sources = {
      files = {
        hidden = true,
      },
      lsp_symbols = {
        filter = {
          default = {
            "Class",
            "Constant",
            "Constructor",
            "Enum",
            "EnumMember",
            "Field",
            "Function",
            "Interface",
            "Method",
            "Module",
            "Namespace",
            "Package",
            "Property",
            "Struct",
            "Trait",
            "TypeParameter",
            "Variable",
          },
        },
      },
    },
    actions = {
      trouble_open = function(picker)
        require("trouble.sources.snacks").open(picker)
      end,
    },
    win = {
      input = {
        keys = {
          ["<C-t>"] = { "trouble_open", mode = { "n", "i" } },
        },
      },
    },
  },
  input = {},
  notifier = {
    height = { min = 1, max = 0.4 },
  },
  statuscolumn = {},
})

map("n", "<leader>ff", function()
  Snacks.picker.files()
end, { desc = "Find files" })
map("n", "<leader>fg", function()
  Snacks.picker.grep()
end, { desc = "Live grep" })
map("n", "<leader>fb", function()
  Snacks.picker.buffers()
end, { desc = "Buffers" })
map("n", "<leader>fr", function()
  Snacks.picker.registers()
end, { desc = "Registers" })
map("n", "<leader>fu", function()
  Snacks.picker.undo()
end, { desc = "Undo history" })
map("n", "<leader>fd", function()
  Snacks.picker.diagnostics_buffer()
end, { desc = "Buffer diagnostics" })
map("n", "<leader>fD", function()
  Snacks.picker.diagnostics()
end, { desc = "Workspace diagnostics" })
map("n", "<leader>fk", function()
  Snacks.picker.keymaps()
end, { desc = "Keymaps" })
map("n", "<leader>fc", function()
  Snacks.picker.commands()
end, { desc = "Commands" })
map("n", "<leader>f:", function()
  Snacks.picker.command_history()
end, { desc = "Command history" })
map("n", "<leader>fl", function()
  local buf = vim.api.nvim_get_current_buf()

  Snacks.picker.pick({
    finder = function()
      local extmarks = require("snacks.picker.util.highlight").get_highlights({ buf = buf, extmarks = true })
      local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
      local items = {}

      for lnum, line in ipairs(lines) do
        items[#items + 1] = {
          buf = buf,
          text = line,
          pos = { lnum, (line:find("%S") or 1) - 1 },
          highlights = extmarks[lnum],
        }
      end

      return items
    end,
    format = "lines",
    title = "Buffer Lines",
    layout = {
      layout = {
        backdrop = 60,
      },
    },
  })
end, { desc = "Search current buffer" })
map("n", "<leader>nh", function()
  Snacks.picker.notifications()
end, { desc = "Notification history" })

-- #############################
-- # Treesitter                #
-- #############################

require("tiny-treesitter").setup({
  ensure_installed = {
    "bib",
    "c",
    "cpp",
    "css",
    "dockerfile",
    "go",
    "gomod",
    "gosum",
    "gotmpl",
    "gowork",
    "html",
    "javascript",
    "json",
    "lua",
    "markdown",
    "latex",
    "powershell",
    "python",
    "rust",
    "scss",
    "toml",
    "typescript",
    "tsx",
    "typst",
    "vue",
    "yaml",
    "zig",
    "bash",
    "diff",
    "gitcommit",
    "markdown_inline",
    "regex",
    "vim",
  },
  auto_install = true,
})

autocmd("FileType", {
  callback = function(event)
    local parser = vim.treesitter.language.get_lang(vim.bo[event.buf].filetype)
    if parser and vim.treesitter.language.add(parser) == true then
      vim.treesitter.start(event.buf, parser)
    end
  end,
})

load_plugins("later", "nvim-treesitter-context", function()
  require("treesitter-context").setup({
    max_lines = 4,
    mode = "topline",
    multiline_threshold = 4,
  })
end)

load_plugins("later", "nvim-treesitter-textobjects")

map({ "n", "x", "o" }, "[f", function()
  require("nvim-treesitter-textobjects.move").goto_previous_start("@function.outer")
end, { desc = "Previous function start" })
map({ "n", "x", "o" }, "]f", function()
  require("nvim-treesitter-textobjects.move").goto_next_start("@function.outer")
end, { desc = "Next function start" })
map({ "n", "x", "o" }, "[F", function()
  require("nvim-treesitter-textobjects.move").goto_previous_end("@function.outer")
end, { desc = "Previous function end" })
map({ "n", "x", "o" }, "]F", function()
  require("nvim-treesitter-textobjects.move").goto_next_end("@function.outer")
end, { desc = "Next function end" })
map({ "n", "x", "o" }, "[a", function()
  require("nvim-treesitter-textobjects.move").goto_previous_start("@parameter.inner")
end, { desc = "Previous parameter" })
map({ "n", "x", "o" }, "]a", function()
  require("nvim-treesitter-textobjects.move").goto_next_start("@parameter.inner")
end, { desc = "Next parameter" })
map("n", "(", function()
  require("nvim-treesitter-textobjects.swap").swap_previous("@parameter.inner")
end, { desc = "Swap previous parameter" })
map("n", ")", function()
  require("nvim-treesitter-textobjects.swap").swap_next("@parameter.inner")
end, { desc = "Swap next parameter" })
map("n", "gC", function()
  require("treesitter-context").go_to_context(vim.v.count1)
end, { desc = "Go to sticky context" })

load_plugins("later", "nvim-ts-autotag", function()
  require("nvim-ts-autotag").setup()
end)

-- #############################
-- # Trouble                   #
-- #############################

load_plugins("later", "trouble.nvim", function()
  require("trouble").setup()
end)

map("n", "<leader>xd", function()
  require("panels").open("trouble.problems", "Trouble diagnostics toggle filter.buf=0")
end, { desc = "Buffer diagnostics" })
map("n", "<leader>xD", function()
  require("panels").open("trouble.problems", "Trouble diagnostics toggle")
end, { desc = "Workspace diagnostics" })
map("n", "<leader>xl", function()
  require("panels").open("trouble.problems", "Trouble loclist toggle")
end, { desc = "Loclist" })
map("n", "<leader>xq", function()
  require("panels").open("trouble.problems", "Trouble qflist toggle")
end, { desc = "Quickfix" })

-- #############################
-- # Keymaps                   #
-- #############################

local map_multistep = require("mini.keymap").map_multistep

-- Remove builtin mappings that conflict with plugin/LSP behavior. When LSP is not
-- ready for references, `gr` otherwise opens the builtin key hint menu instead of
-- showing the expected "no references" feedback.
for mode, keys in pairs({
  n = { "gO", "gra", "gri", "grn", "grr", "grt", "grx", "<C-W>d", "<C-W><C-D>" },
  i = { "<C-S>" },
  v = { "<C-S>" },
  x = { "gra" },
}) do
  for _, lhs in ipairs(keys) do
    vim.keymap.del(mode, lhs)
  end
end

-- Search
map("n", "<Esc>", "<cmd>nohlsearch<CR>", { desc = "Clear search highlight" })

-- Editing
map("n", "x", '"_x', { desc = "Delete without yanking" })
map("n", "q", "<Nop>", { noremap = true, silent = true })
map("n", "Q", "q", { noremap = true, silent = true })
map({ "i", "c" }, "jj", "<Esc>", { desc = "Exit insert or command-line mode" })
map("i", "<C-z>", "<C-o>u", { desc = "Undo" })
map("i", "<C-y>", "<C-o><C-r>", { desc = "Redo" })
map_multistep("i", "<C-l>", { "minisnippets_next", "jump_after_close" })
map_multistep("i", "<C-h>", { "minisnippets_prev", "jump_before_open" })

-- Clipboard
map({ "c", "i" }, "<C-v>", "<C-r>+", { desc = "Paste from clipboard" })
map("n", "<leader>yi", "i<C-r>0<Esc>", { desc = "Insert yanked text at cursor" })

-- Line motions
map({ "n", "x" }, "j", "v:count == 0 ? 'gj' : 'j'", { desc = "Move down display line", expr = true, silent = true })
map({ "n", "x" }, "k", "v:count == 0 ? 'gk' : 'k'", { desc = "Move up display line", expr = true, silent = true })
map({ "n", "x", "o" }, "H", "^", { desc = "Move to first non-blank character" })
map({ "n", "x", "o" }, "L", "$", { desc = "Move to end of line" })

-- Prevent bare <Leader> from falling back to Normal-mode <space>, which moves
-- the cursor when no leader sequence is completed.
map({ "n", "x" }, "<leader>", "<Nop>", { desc = "Leader", silent = true })

-- Files
map("n", "<leader>w", "<cmd>write<CR>", { desc = "Write file" })
map("n", "<leader>W", function()
  local prev = vim.b.disable_autoformat
  vim.b.disable_autoformat = true
  vim.cmd.write()
  vim.b.disable_autoformat = prev
end, { desc = "Write without formatting" })

-- Buffers
map("n", "[b", "<cmd>bprevious<cr>", { desc = "Previous buffer" })
map("n", "]b", "<cmd>bnext<cr>", { desc = "Next buffer" })

-- UI
map("n", "<leader>lw", "<cmd>setlocal wrap!<CR>", { desc = "Toggle line wrap" })

-- Quit / close
map("n", "<leader>Q", "<cmd>qa<CR>", { desc = "Quit all" })
map("n", "<leader>qb", function()
  Snacks.bufdelete()
end, { desc = "Quit buffer" })
-- workaround for not deleting all buffers
local function delete_twice(filter)
  Snacks.bufdelete(filter)
  Snacks.bufdelete(filter)
end
map("n", "<leader>q[", function()
  local current = vim.api.nvim_get_current_buf()
  delete_twice(function(buf)
    return buf < current
  end)
end, { desc = "Quit buffers to the left" })
map("n", "<leader>q]", function()
  local current = vim.api.nvim_get_current_buf()

  delete_twice(function(buf)
    return buf > current
  end)
end, { desc = "Quit buffers to the right" })
map("n", "<leader>qo", function()
  Snacks.bufdelete.other()
  Snacks.bufdelete.other()
end, { desc = "Quit other buffers" })
map("n", "<leader>qt", "<cmd>tabclose<CR>", { desc = "Quit tab" })
map("n", "<leader>qT", "<cmd>tabonly<CR>", { desc = "Quit other tabs" })
map("n", "<leader>qw", "<C-W>c", { desc = "Delete window", remap = true })

-- Tabs
map("n", "[t", "<cmd>tabprevious<CR>", { desc = "Previous tab" })
map("n", "]t", "<cmd>tabnext<CR>", { desc = "Next tab" })
map("n", "[T", "<cmd>tabfirst<CR>", { desc = "First tab" })
map("n", "]T", "<cmd>tablast<CR>", { desc = "Last tab" })

-- Line editing
map("n", "[<Space>", "O<Esc>", { desc = "Blank line above" })
map("n", "]<Space>", "o<Esc>", { desc = "Blank line below" })
map("n", "<leader>,", function()
  local row, col = unpack(vim.api.nvim_win_get_cursor(0))
  local line = vim.api.nvim_buf_get_lines(0, row - 1, row, false)[1] or ""

  vim.api.nvim_buf_set_lines(0, row, row, false, { line })
  vim.api.nvim_win_set_cursor(0, { row + 1, math.min(col, #line) })
end, { desc = "Duplicate line" })
map("n", "gK", "i<CR><Esc>", { desc = "Split line at cursor" })

-- Windows
map("n", "<C-h>", "<C-w>h", { desc = "Move to left window" })
map("n", "<C-j>", "<C-w>j", { desc = "Move to lower window" })
map("n", "<C-k>", "<C-w>k", { desc = "Move to upper window" })
map("n", "<C-l>", "<C-w>l", { desc = "Move to right window" })
map("t", "<Esc><Esc>", "<C-\\><C-n>", { desc = "Exit terminal mode" })
map("t", "<C-h>", "<C-\\><C-n><C-w>h", { desc = "Move to left window" })
map("t", "<C-j>", "<C-\\><C-n><C-w>j", { desc = "Move to lower window" })
map("t", "<C-k>", "<C-\\><C-n><C-w>k", { desc = "Move to upper window" })
map("t", "<C-l>", "<C-\\><C-n><C-w>l", { desc = "Move to right window" })
map("n", "<C-Right>", "<C-w>>", { desc = "Increase window width" })
map("n", "<C-Left>", "<C-w><", { desc = "Decrease window width" })
map("n", "<C-Up>", "<C-w>+", { desc = "Increase window height" })
map("n", "<C-Down>", "<C-w>-", { desc = "Decrease window height" })
map("n", "<leader>=", function()
  require("panels").equalize()
end, { desc = "Equalize windows" })

-- Navigation
map("i", "<A-h>", "<Left>", { desc = "Move left cursor" })
map("i", "<A-j>", "<Down>", { desc = "Move down cursor" })
map("i", "<A-k>", "<Up>", { desc = "Move up cursor" })
map("i", "<A-l>", "<Right>", { desc = "Move right cursor" })
map("c", "<A-h>", "<Left>", { desc = "Move left in command line" })
map("c", "<A-l>", "<Right>", { desc = "Move right in command line" })

-- Diagnostics
map("n", "<leader>cd", function()
  vim.diagnostic.open_float({ scope = "line" })
end, { desc = "Line diagnostics" })

-- Git
map("n", "<leader>gr", function()
  refresh_ignored()
  vim.notify("Refreshed ignored files", vim.log.levels.INFO, { title = "Git Ignore" })
end, { desc = "Refresh ignored files" })

-- #############################
-- # Commands                  #
-- #############################

command("ToggleFormat", function(args)
  if args.bang then
    vim.g.disable_autoformat = not vim.g.disable_autoformat
    vim.notify("Global format-on-save: " .. (vim.g.disable_autoformat and "disabled" or "enabled"))

    return
  end

  vim.b.disable_autoformat = not vim.b.disable_autoformat
  vim.notify("Buffer format-on-save: " .. (vim.b.disable_autoformat and "disabled" or "enabled"))
end, { bang = true, desc = "Toggle format-on-save for buffer, or globally with !" })

command("TSReset", function()
  local bufnr = vim.api.nvim_get_current_buf()
  vim.treesitter.stop(bufnr)
  vim.defer_fn(function()
    vim.treesitter.start(bufnr)
    vim.notify("Treesitter reset for current buffer", vim.log.levels.INFO)
  end, 100)
end, { desc = "Reset treesitter for current buffer" })
