# NixOS Configuration (lianli)

This repo contains a NixOS flake for the `lianli` machine, plus Home Manager
configuration for the `costi` user. It includes a nixvim setup with a
LazyVim-inspired UX and a small set of dev tools.

## Highlights

- Flake-based NixOS configuration (nixos-25.11)
- Home Manager for user config
- nixvim with Telescope, which-key, LSP, completion, sessions, and more
- Dev toolchain (node, pnpm, bun, python, rustup, sqlite, etc.)
- Podman with Docker compatibility

## Usage

Build/switch the system:

```bash
sudo nixos-rebuild switch --flake .#lianli
```

Check flake:

```bash
nix flake check
```

## Nixvim quick keys

Leader is space.

- `<leader>ff` find files
- `<leader>fg` live grep
- `<leader>fb` buffers
- `<leader>fh` help tags
- `<leader>fe` file browser
- `<leader>fp` projects
- `<leader>e` file explorer
- `<leader>gg` LazyGit
- `<leader>xx` Trouble
- `<S-h>/<S-l>` prev/next tab

## Layout

- `flake.nix` flake outputs and inputs
- `configuration.nix` system configuration
- `home.nix` user (Home Manager) configuration
