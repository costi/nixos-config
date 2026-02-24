{ pkgs, nixvim, ... }:

{
  imports = [ nixvim.homeModules.nixvim ];

  home.stateVersion = "25.11";

  programs.bash.enable = true;
  # Prefer nixvim in interactive shells while keeping system vi available if needed.
  programs.bash.shellAliases = {
    vi = "nvim";
    vim = "nvim";
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
  ];

  programs.codex.enable = true;

  programs.neovim = {
    enable = false;
    defaultEditor = true;
  };

  programs.nixvim = {
    enable = true;
    defaultEditor = true;
    colorschemes.catppuccin.enable = true;
    plugins.lualine.enable = true;
    plugins.treesitter.enable = true;

    # Basic options
    opts = {
      number = true;
      shiftwidth = 2;
    };
  };
}
