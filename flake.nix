{
  description = "NixOS configuration for lianli";

  inputs = {
    # Pin nixpkgs to the same release you're on
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    # llama.cpp support for new GGUF/MoE models moves quickly, so keep a
    # separate unstable package set for inference tooling while the base system
    # stays on the 25.11 release branch.
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # nixvim input
    nixvim = {
      url = "github:nix-community/nixvim/nixos-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # nix-minecraft provides Paper + declarative ops via its module/overlay.
    nix-minecraft = {
      url = "github:Infinidoge/nix-minecraft";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # hermes AI agent
    hermes-agent.url = "github:NousResearch/hermes-agent";
  };

  outputs = { self, nixpkgs, nixpkgs-unstable, home-manager, nixvim, nix-minecraft, hermes-agent, ... }:
    let
      system = "x86_64-linux";
      pkgs-unstable = import nixpkgs-unstable {
        inherit system;
        config.allowUnfree = true;
        overlays = [
          (import ./overlays/ollama-0_20.nix)
        ];
      };
    in
    {
      packages.${system}.ollama-cuda-0_20 = pkgs-unstable.ollama-cuda;

      nixosConfigurations.lianli = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = {
          inherit pkgs-unstable hermes-agent;
        };

        modules = [
          ({ ... }: {
            # nix-minecraft ships its own module + overlay for server packages.
            imports = [ nix-minecraft.nixosModules.minecraft-servers ];
            nixpkgs.overlays = [ nix-minecraft.overlay ];
          })
          ./configuration.nix
          ./llama-cpp.nix

          home-manager.nixosModules.home-manager
          
          # nixvim.homeModules.nixvim

          ({ ... }: {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.extraSpecialArgs = { inherit nixvim hermes-agent; };
            home-manager.users.costi = import ./home.nix;
          })
        ];
      };
    };
}
