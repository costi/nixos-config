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

  programs.neovim = {
    enable = true;
    defaultEditor = true;
  };

  # Later, nixvim goes here (example):
  # programs.nixvim = { enable = true; ... };
}
