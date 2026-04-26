{
  description = "NixOS configuration for lianli";

  inputs = {
    # Pin nixpkgs to the same release you're on
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    pkgs-vllm.url = "github:CertainLach/nixpkgs/push-lklxouywkrnv";

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

  outputs = { self, nixpkgs, nixpkgs-unstable, pkgs-vllm, home-manager, nixvim, nix-minecraft, hermes-agent, ... }:
    let
      system = "x86_64-linux";
      pkgs-unstable = import nixpkgs-unstable {
        inherit system;
        config.allowUnfree = true;
        overlays = [
          (import ./overlays/ollama-0_20.nix)
        ];
      };
      vllm-pkgs = import pkgs-vllm {
        inherit system;
        config = {
          allowUnfree = true;
          # vLLM/PyTorch CUDA packages compile GPU kernels ahead of time.
          # The default nixpkgs CUDA arch list targets many NVIDIA generations,
          # which made the local PyTorch build enormous and caused nvcc/cicc to
          # get SIGKILLed on this machine. This host has an RTX 3090, which is
          # Ampere compute capability 8.6, so build only sm_86 kernels for our
          # actual GPU. If this config moves to a different GPU, update this.
          cudaSupport = true;
          cudaCapabilities = [ "8.6" ];
          cudaForwardCompat = false;
          problems.handlers = {
            flashinfer.broken = "warn";
          };
        };
      };
    in
    {
      packages.${system}.ollama-cuda-0_20 = pkgs-unstable.ollama-cuda;

      nixosConfigurations.lianli = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = {
          inherit pkgs-unstable hermes-agent;
          pkgs-vllm = vllm-pkgs;
        };

        modules = [
          ({ ... }: {
            # nix-minecraft ships its own module + overlay for server packages.
            imports = [ nix-minecraft.nixosModules.minecraft-servers ];
            nixpkgs.overlays = [ nix-minecraft.overlay ];
          })
          ./configuration.nix
          ./vllm.nix

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
