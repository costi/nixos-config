# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running 'nixos-help').

{ config, lib, pkgs, pkgs-unstable, hermes-agent, ... }:

let
  rebuild-switch = pkgs.writeShellScriptBin "rebuild-switch" ''
    set -euo pipefail

    repo=/home/costi/nixos-config
    cd "$repo"

    echo "==> Building lianli system toplevel without switching..."
    nix build --no-link ".#nixosConfigurations.lianli.config.system.build.toplevel" \
      --max-jobs 2 \
      --cores 8

    echo "==> Build OK, switching..."
    exec /run/current-system/sw/bin/nixos-rebuild switch \
      --flake /home/costi/nixos-config/.#lianli \
      --max-jobs 2 \
      --cores 8
  '';
in
{
  imports =
    [
      # Include the results of the hardware scan.
      ./hardware-configuration.nix
    ];

  # Bootloader.
  boot = {
    loader.systemd-boot.enable = true;
    loader.efi.canTouchEfiVariables = true;
    kernelParams = [ "nvidia-drm.fbdev=1" ]; # desperately trying to have nvidia working in gnome
  };

  networking = {
    hostName = "lianli"; # Define your hostname.
    # wireless.enable = true;  # Enables wireless support via wpa_supplicant.

    # Configure network proxy if necessary
    # proxy.default = "http://user:password@proxy:port/";
    # proxy.noProxy = "127.0.0.1,localhost,internal.domain";

    # Enable networking
    networkmanager.enable = true;
    # This host is behind a Wi-Fi repeater that does not pass IPv6, and new Codex
    # tries IPv6 first before falling back to IPv4 after timing out for about 2 minutes.

    # Open ports in the firewall.
    firewall.allowedTCPPorts = [ 80 443 ];
    # Mosh uses a high UDP port range by default.
    firewall.allowedUDPPortRanges = [
      { from = 60000; to = 61000; }
    ];
    # Or disable the firewall altogether.
    # firewall.enable = false;
  };

  # Set your time zone.
  time.timeZone = "America/Chicago";

  # Select internationalisation properties.
  i18n = {
    defaultLocale = "en_US.UTF-8";

    extraLocaleSettings = {
      LC_ADDRESS = "en_US.UTF-8";
      LC_IDENTIFICATION = "en_US.UTF-8";
      LC_MEASUREMENT = "en_US.UTF-8";
      LC_MONETARY = "en_US.UTF-8";
      LC_NAME = "en_US.UTF-8";
      LC_NUMERIC = "en_US.UTF-8";
      LC_PAPER = "en_US.UTF-8";
      LC_TELEPHONE = "en_US.UTF-8";
      LC_TIME = "en_US.UTF-8";
    };
  };

  nix = {
    settings.experimental-features = [ "nix-command" "flakes" ];

    # Deduplicate identical files in the store periodically (lightweight, reclaims space after big rebuilds)
    settings.auto-optimise-store = true;
  };

  # Boot to text mode, but allow starting X manually via `startx`.
  systemd.defaultUnit = lib.mkForce "multi-user.target";

  services = {
    displayManager.gdm.enable = false;

    xserver = {
      enable = true;

      # Configure keymap in X11
      xkb = {
        layout = "us";
        variant = "";
      };

      displayManager = {
        startx = {
          enable = true;
          generateScript = true;
        };
      };

      windowManager.i3.enable = true;

      # Load nvidia driver for Xorg and Wayland
      videoDrivers = [ "nvidia" ];
    };

    # Enable CUPS to print documents.
    printing.enable = true;

    # Enable sound with pipewire.
    pulseaudio.enable = false;
    pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
      # If you want to use JACK applications, uncomment this
      #jack.enable = true;

      # use the example session manager (no others are packaged yet so this is enabled by default,
      # no need to redefine it in your config for now)
      #media-session.enable = true;
    };

    # Enable touchpad support (enabled default in most desktopManager).
    # xserver.libinput.enable = true;

    # enable minecraft server (Paper via nix-minecraft)
    # Paper gives /tps and better performance, and nix-minecraft supports declarative ops.
    minecraft-servers = {
      enable = true;
      eula = true;
      openFirewall = true;
      servers.paper = {
        enable = true;
        # Pin Paper to a specific Minecraft version for client compatibility.
        package = pkgs.paperServers.paper-1_21_10;
        operators = {
          # UUID observed in usercache.json for "costitze".
          costitze = "7cc4fd35-3378-3b3b-9fa2-a4dfa5a9a4a4";
        };
        serverProperties = {
          motd = "Awesome fast minecraft server";
          # Offline mode so local accounts can join without Mojang auth.
          online-mode = false;
          enforce-secure-profile = false; # so we can sign in with bots unsigned
        };
      };
    };

    # avahi for mdns so my other ubuntu systems can find it in the network with hostname.local
    avahi = {
      enable = true;
      nssmdns4 = true;
      openFirewall = true;
      publish = {
        enable = true;
        addresses = true;
        workstation = true;
      };
    };

    caddy = {
      enable = true;
      environmentFile = "/var/lib/caddy/ollama.env";
      virtualHosts."ollama.random-studios.net".extraConfig =
        lib.replaceStrings
          [ "__OLLAMA_SITE_ROOT__" ]
          [ "${./caddy/ollama-site}" ]
          (builtins.readFile ./caddy/ollama.random-studios.net.caddy);
      virtualHosts."lol.random-studios.net".extraConfig = ''
        handle {
          respond "<h1>LOL!!!!</h1><p>YOU LAUGH YOU DIE</p>"
        }
      '';
    };

    # Enable the OpenSSH daemon.
    openssh = {
      enable = true;
      settings = {
        PasswordAuthentication = false;
        PermitRootLogin = "no"; # change from default "prohibit-password"
        KbdInteractiveAuthentication = false;
      };
    };
  };

  security = {
    rtkit.enable = true;
    sudo = {
      enable = true;
      extraRules = [
        {
          users = [ "costi" ];
          commands = [
            {
              # Allow Hermes to apply this exact NixOS rebuild helper without a
              # password. The root-owned /run/current-system path avoids a broad
              # /nix/store/* sudo wildcard, and the empty-argument matcher keeps
              # the rule scoped to the helper's baked-in command sequence.
              command = "/run/current-system/sw/bin/rebuild-switch \"\"";
              options = [ "NOPASSWD" ];
            }
          ];
        }
      ];
    };
  };

  # Define a user account. Don't forget to set a password with 'passwd'.
  users.users = {
    costi = {
      isNormalUser = true;
      description = "Constantin Gavrilescu";
      # Keep the user manager alive after logout so Hermes can keep running.
      linger = true;
      extraGroups = [ "networkmanager" "wheel" ];
      openssh.authorizedKeys.keys = [
        "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDh132yLWmzThEcR66D0VFSH0RpT2XfU5m7waEeebOEgXrnLeLvijIV2TNm0ew0PX8AQiiszURFcJ53Tx7RQCKvszKhOIh40+DAeoIbIP6OhQLDkL5r9cQWRboaSN8WcAzEay3m243MfQWimsZKvOGlpk68sw8YdjEFulUZ9cCLZRURq5vie0e/m8VOsfFjt4EXObKp4GoBzzyzyd77f2pWgdpbbGv+LEUvZWgYmNfEM+v21dn87wZN1vbDWkNH7eofa+P1DNX0yahfyuewjOvd/jtaJertyiLcVKKZ0Ws3tV5EkDJjt+NIEzQLi8NwiN1al7z5LTKeUN+1XmHqAZYj costi@costi-linux-zuper"
      ];
      packages = with pkgs; [
        #  thunderbird
      ];
    };

    acu = {
      isNormalUser = true;
      description = "Dorin Ilie Acu";
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBSiMeGIZv5bexHsg9HgKYDZzwlf4jeCM0pqIQ/NNKTP acu@TELOMERYX1"
      ];
    };

    sebi = {
      isNormalUser = true;
      description = "Sebi";
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDGhMzj7ecWvu/f2HSjFGBKw6iVRawLxkn7kBRAWyiYg sebis@notwindows"
      ];
    };
  };

  # Install firefox.
  programs = {
    firefox.enable = true;
    neovim = {
      enable = true; # system-wide nvim (e.g., root, other users)
      defaultEditor = true;
    };
  };

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # Podman with Docker-compatible socket/CLI
  virtualisation = {
    podman.enable = true;
    podman.dockerCompat = true;
  };

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    vim # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
    wget
    prismlauncher
    htop
    nodejs_22
    pnpm
    bun
    python3
    uv
    rustup
    sqlite
    git
    gh
    jq
    yq
    ripgrep
    fd
    bat
    fzf
    tree
    direnv
    just
    tmux
    nvtopPackages.nvidia
    mosh # for better ssh support
    fastfetch # just for fun so we can see what's installed
    lshw # to see what mb I have
    bandwhich # to monitor downloads
  ] ++ [
    rebuild-switch
    # Install Hermes from the system generation so the binary is rooted and
    # available on PATH, while the gateway itself still runs as a user service.
    hermes-agent.packages.${pkgs.stdenv.hostPlatform.system}.default
    pkgs-unstable.zellij
    pkgs-unstable.codex
    pkgs-unstable.opencode
    # Nixpkgs unstable already packages @mariozechner/pi-coding-agent and
    # exposes the same `pi` CLI that `npm install -g` would install, without
    # leaving mutable npm-managed state in the system profile.
    pkgs-unstable.pi-coding-agent
  ];

  # yo enable nvida support

  # Enable OpenGL
  hardware.graphics = {
    enable = true;
  };

  hardware.nvidia = {

    # Modesetting is required.
    modesetting.enable = true;

    # Nvidia power management. Experimental, and can cause sleep/suspend to fail.
    # Enable this if you have graphical corruption issues or application crashes after waking
    # up from sleep. This fixes it by saving the entire VRAM memory to /tmp/ instead
    # of just the bare essentials.
    powerManagement.enable = false;

    # Fine-grained power management. Turns off GPU when not in use.
    # Experimental and only works on modern Nvidia GPUs (Turing or newer).
    powerManagement.finegrained = false;

    # Use the NVidia open source kernel module (not to be confused with the
    # independent third-party "nouveau" open source driver).
    # Support is limited to the Turing and later architectures. Full list of
    # supported GPUs is at:
    # https://github.com/NVIDIA/open-gpu-kernel-modules#compatible-gpus
    # Only available from driver 515.43.04+
    open = false;

    # Enable the Nvidia settings menu,
    # accessible via `nvidia-settings`.
    nvidiaSettings = true;

    # Optionally, you may need to select the appropriate driver version for your specific GPU.
    package = config.boot.kernelPackages.nvidiaPackages.latest;
  };
  # end nvidia config

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It's perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "25.11"; # Did you read the comment?

}
