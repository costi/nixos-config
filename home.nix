{ pkgs, nixvim, hermes-agent, ... }:

{
  imports = [ nixvim.homeModules.nixvim ];

  home.stateVersion = "25.11";

  programs.bash.enable = true;
  # Prefer nixvim in interactive shells while keeping system vi available if needed.
  programs.bash.shellAliases = {
    vi = "nvim";
    vim = "nvim";
    n = "nvim";
  };

  programs.git = {
    enable = true;
    settings = {
      user.name = "Constantin Gavrilescu";
      user.email = "comisarulmoldovan@gmail.com";
    };
  };

  home.packages = with pkgs; [
    atool
    httpie
    ripgrep
    fd
    nodejs
    python3
    lua-language-server
    nil # nix lsp
    lazygit
  ];

  # Configure pi-coding-agent declaratively for Costi. The local inference
  # endpoint is vLLM on port 8000, not Ollama on 11434; vLLM exposes an
  # OpenAI-compatible /v1/chat/completions API and ignores the dummy API key.
  # vllm.nix sets --served-model-name so clients can use a stable model id
  # instead of the local /var/lib/vllm model directory path.
  home.file.".pi/agent/models.json".text = builtins.toJSON {
    providers = {
      vllm = {
        baseUrl = "http://localhost:8000/v1";
        api = "openai-completions";
        apiKey = "vllm";
        compat = {
          supportsDeveloperRole = false;
          supportsReasoningEffort = false;
        };
        models = [
          {
            id = "qwen3-coder";
            name = "qwen3-coder";
            reasoning = true;
            contextWindow = 262144;
            maxTokens = 32768;
          }
        ];
      };
    };
  };

  programs.neovim = {
    enable = false;
    defaultEditor = true;
  };

  # Hermes is intentionally run as a user service, not as a system-wide daemon,
  # so its state stays under ~/.hermes and each user can own their own agent.
  # This also replaces the imperative `hermes gateway install` unit.
  systemd.user.services.hermes-gateway = {
    Unit = {
      Description = "Hermes Agent Gateway";
      After = [ "network.target" ];
    };

    Service = {
      Type = "simple";
      ExecStart = "${hermes-agent.packages.${pkgs.system}.default}/bin/hermes gateway run --replace";
      WorkingDirectory = "%h";
      Environment = [
        "HERMES_HOME=%h/.hermes"
      ];
      Restart = "on-failure";
      RestartSec = 30;
    };

    Install = {
      WantedBy = [ "default.target" ];
    };
  };

  programs.nixvim = {
    enable = true;
    defaultEditor = true;
    colorschemes.catppuccin.enable = true;
    plugins.lualine.enable = true;
    plugins.treesitter.enable = true;
    plugins.which-key.enable = true;
    plugins.telescope.enable = true;
    plugins.telescope.extensions.fzf-native.enable = true;
    plugins.telescope.extensions.file-browser.enable = true;
    plugins.web-devicons.enable = true;
    plugins.gitsigns.enable = true;
    plugins.lsp.enable = true;
    plugins.neo-tree.enable = true;
    plugins.project-nvim.enable = true;
    plugins.trouble.enable = true;
    plugins.nvim-autopairs.enable = true;
    plugins.vim-surround.enable = true;
    plugins.lsp.servers = {
      nil_ls.enable = true;
      lua_ls.enable = true;
    };
    plugins.cmp.enable = true;
    plugins.cmp.settings = {
      snippet.expand = "function(args) require('luasnip').lsp_expand(args.body) end";
      mapping = {
        "<C-Space>" = "cmp.mapping.complete()";
        "<CR>" = "cmp.mapping.confirm({ select = true })";
        "<Tab>" = "cmp.mapping(function(fallback) if cmp.visible() then cmp.select_next_item() else fallback() end end, { 'i', 's' })";
        "<S-Tab>" = "cmp.mapping(function(fallback) if cmp.visible() then cmp.select_prev_item() else fallback() end end, { 'i', 's' })";
      };
      sources = [
        { name = "nvim_lsp"; }
        { name = "luasnip"; }
        { name = "buffer"; }
        { name = "path"; }
      ];
    };
    plugins.luasnip.enable = true;
    plugins.cmp-nvim-lsp.enable = true;
    plugins.cmp-buffer.enable = true;
    plugins.cmp-path.enable = true;
    plugins.friendly-snippets.enable = true;

    # Basic options
    opts = {
      number = true;
      shiftwidth = 2;
    };
    globals = {
      mapleader = " ";
      maplocalleader = " ";
    };

    keymaps = [
      {
        mode = "n";
        key = "<leader>ff";
        action = "<cmd>Telescope find_files<cr>";
        options.desc = "Find Files";
      }
      {
        mode = "n";
        key = "<leader>fg";
        action = "<cmd>Telescope live_grep<cr>";
        options.desc = "Grep";
      }
      {
        mode = "n";
        key = "<leader>fb";
        action = "<cmd>Telescope buffers<cr>";
        options.desc = "Buffers";
      }
      {
        mode = "n";
        key = "<leader>fh";
        action = "<cmd>Telescope help_tags<cr>";
        options.desc = "Help";
      }
      {
        mode = "n";
        key = "<leader>fp";
        action = "<cmd>Telescope projects<cr>";
        options.desc = "Projects";
      }
      {
        mode = "n";
        key = "<leader>fe";
        action = "<cmd>Telescope file_browser<cr>";
        options.desc = "File Browser";
      }
      {
        mode = "n";
        key = "<leader>e";
        action = "<cmd>Neotree toggle<cr>";
        options.desc = "Explorer";
      }
      {
        mode = "n";
        key = "<leader>gg";
        action = "<cmd>LazyGit<cr>";
        options.desc = "LazyGit";
      }
      {
        mode = "n";
        key = "<leader>gh";
        action = "<cmd>Gitsigns preview_hunk<cr>";
        options.desc = "Preview Hunk";
      }
      {
        mode = "n";
        key = "<leader>gb";
        action = "<cmd>Gitsigns toggle_current_line_blame<cr>";
        options.desc = "Blame Line";
      }
      {
        mode = "n";
        key = "<leader>bd";
        action = "<cmd>bdelete<cr>";
        options.desc = "Delete Buffer";
      }
      {
        mode = "n";
        key = "<leader>bn";
        action = "<cmd>bnext<cr>";
        options.desc = "Next Buffer";
      }
      {
        mode = "n";
        key = "<leader>bp";
        action = "<cmd>bprevious<cr>";
        options.desc = "Prev Buffer";
      }
      {
        mode = "n";
        key = "<leader>qq";
        action = "<cmd>qa<cr>";
        options.desc = "Quit All";
      }
      {
        mode = "n";
        key = "<leader>tn";
        action = "<cmd>tabnew<cr>";
        options.desc = "New Tab";
      }
      {
        mode = "n";
        key = "<leader>to";
        action = "<cmd>tabclose<cr>";
        options.desc = "Close Tab";
      }
      {
        mode = "n";
        key = "<leader>tp";
        action = "<cmd>tabprevious<cr>";
        options.desc = "Prev Tab";
      }
      {
        mode = "n";
        key = "<leader>tl";
        action = "<cmd>tabnext<cr>";
        options.desc = "Next Tab";
      }
      {
        mode = "n";
        key = "<leader>qQ";
        action = "<cmd>qa!<cr>";
        options.desc = "Force Quit All";
      }
      {
        mode = "n";
        key = "<S-h>";
        action = "<cmd>tabprevious<cr>";
        options.desc = "Prev Tab";
      }
      {
        mode = "n";
        key = "<S-l>";
        action = "<cmd>tabnext<cr>";
        options.desc = "Next Tab";
      }
      {
        mode = "n";
        key = "<leader>sv";
        action = "<cmd>vsplit<cr>";
        options.desc = "Split Vertical";
      }
      {
        mode = "n";
        key = "<leader>sh";
        action = "<cmd>split<cr>";
        options.desc = "Split Horizontal";
      }
      {
        mode = "n";
        key = "<leader>se";
        action = "<cmd>wincmd =<cr>";
        options.desc = "Equalize Splits";
      }
      {
        mode = "n";
        key = "<leader>sx";
        action = "<cmd>close<cr>";
        options.desc = "Close Split";
      }
      {
        mode = "n";
        key = "<C-h>";
        action = "<cmd>wincmd h<cr>";
        options.desc = "Window Left";
      }
      {
        mode = "n";
        key = "<C-j>";
        action = "<cmd>wincmd j<cr>";
        options.desc = "Window Down";
      }
      {
        mode = "n";
        key = "<C-k>";
        action = "<cmd>wincmd k<cr>";
        options.desc = "Window Up";
      }
      {
        mode = "n";
        key = "<C-l>";
        action = "<cmd>wincmd l<cr>";
        options.desc = "Window Right";
      }
      {
        mode = "n";
        key = "[d";
        action = "<cmd>lua vim.diagnostic.goto_prev()<cr>";
        options.desc = "Prev Diagnostic";
      }
      {
        mode = "n";
        key = "]d";
        action = "<cmd>lua vim.diagnostic.goto_next()<cr>";
        options.desc = "Next Diagnostic";
      }
      {
        mode = "n";
        key = "<leader>cd";
        action = "<cmd>lua vim.diagnostic.open_float()<cr>";
        options.desc = "Line Diagnostics";
      }
      {
        mode = "n";
        key = "<leader>cD";
        action = "<cmd>lua vim.diagnostic.setloclist()<cr>";
        options.desc = "Buffer Diagnostics";
      }
      {
        mode = "n";
        key = "<leader>xx";
        action = "<cmd>Trouble<cr>";
        options.desc = "Trouble";
      }
      {
        mode = "n";
        key = "<leader>xw";
        action = "<cmd>Trouble diagnostics toggle<cr>";
        options.desc = "Workspace Diagnostics";
      }
      {
        mode = "n";
        key = "<leader>xd";
        action = "<cmd>Trouble diagnostics toggle filter.buf=0<cr>";
        options.desc = "Buffer Diagnostics";
      }
      {
        mode = "n";
        key = "<leader>xl";
        action = "<cmd>Trouble loclist toggle<cr>";
        options.desc = "Location List";
      }
      {
        mode = "n";
        key = "<leader>xq";
        action = "<cmd>Trouble qflist toggle<cr>";
        options.desc = "Quickfix List";
      }
      {
        mode = "n";
        key = "gd";
        action = "<cmd>lua vim.lsp.buf.definition()<cr>";
        options.desc = "Go to Definition";
      }
      {
        mode = "n";
        key = "gD";
        action = "<cmd>lua vim.lsp.buf.declaration()<cr>";
        options.desc = "Go to Declaration";
      }
      {
        mode = "n";
        key = "gr";
        action = "<cmd>lua vim.lsp.buf.references()<cr>";
        options.desc = "References";
      }
      {
        mode = "n";
        key = "gi";
        action = "<cmd>lua vim.lsp.buf.implementation()<cr>";
        options.desc = "Go to Implementation";
      }
      {
        mode = "n";
        key = "K";
        action = "<cmd>lua vim.lsp.buf.hover()<cr>";
        options.desc = "Hover";
      }
      {
        mode = "n";
        key = "<leader>lr";
        action = "<cmd>lua vim.lsp.buf.rename()<cr>";
        options.desc = "Rename";
      }
      {
        mode = "n";
        key = "<leader>la";
        action = "<cmd>lua vim.lsp.buf.code_action()<cr>";
        options.desc = "Code Action";
      }
      {
        mode = "n";
        key = "<leader>lf";
        action = "<cmd>lua vim.lsp.buf.format({ async = true })<cr>";
        options.desc = "Format";
      }
    ];

    extraPlugins = with pkgs.vimPlugins; [
      vim-lastplace
      auto-session
    ];
    extraConfigLua = ''
      require("auto-session").setup({
        auto_save_enabled = true,
        auto_restore_enabled = true,
        auto_session_suppress_dirs = { vim.fn.expand("~") },
      })
      require("telescope").load_extension("projects")
      vim.o.timeout = true
      vim.o.timeoutlen = 300
      require("which-key").add({
        { "<leader>f", group = "file/find" },
        { "<leader>b", group = "buffer" },
        { "<leader>g", group = "git" },
        { "<leader>s", group = "search" },
        { "<leader>q", group = "quit/session" },
        { "<leader>t", group = "tab" },
        { "<leader>l", group = "lsp" },
      })
      require("luasnip.loaders.from_vscode").lazy_load()
    '';
  };
}
