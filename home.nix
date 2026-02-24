{ pkgs, ... }:

{
  home.stateVersion = "25.11";

  programs.bash.enable = true;

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
    enable = true;
    defaultEditor = true;
  };

  # programs.nixvim = {
  #   enable = true;

  #   colorschemes.catppuccin.enable = true;
  #   plugins.lualine.enable = true;
  #   plugins.treesitter.enable = true;
  #   
  #   # Basic options
  #   options = {
  #     number = true;
  #     shiftwidth = 2;
  #   };
  # };
}
