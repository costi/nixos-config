# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, lib, pkgs, pkgs-unstable, hermes-agent, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
    ];

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  boot.kernelParams = ["nvidia-drm.fbdev=1"]; # desperately trying to have nvidia working in gnome

  networking.hostName = "lianli"; # Define your hostname.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Enable networking
  networking.networkmanager.enable = true;
  # This host is behind a Wi-Fi repeater that does not pass IPv6, and new Codex
  # tries IPv6 first before falling back to IPv4 after timing out for about 2 minutes.

  # Set your time zone.
  time.timeZone = "America/Chicago";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";

  i18n.extraLocaleSettings = {
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

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # Deduplicate identical files in the store periodically (lightweight, reclaims space after big rebuilds)
  nix.settings.auto-optimise-store = true;

  # Boot to text mode, but allow starting X manually via `startx`.
  services.xserver.enable = true;
  services.displayManager.gdm.enable = false;
  services.xserver.displayManager.startx.enable = true;
  services.xserver.displayManager.startx.generateScript = true;
  services.xserver.windowManager.i3.enable = true;
  systemd.defaultUnit = lib.mkForce "multi-user.target";

  # Configure keymap in X11
  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };

  # Enable CUPS to print documents.
  services.printing.enable = true;

  # Enable sound with pipewire.
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
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
  # services.xserver.libinput.enable = true;


  # enable minecraft server (Paper via nix-minecraft)
  # Paper gives /tps and better performance, and nix-minecraft supports declarative ops.
  services.minecraft-servers = {
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

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.costi = {
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

  users.users.acu = {
    isNormalUser = true;
    description = "Dorin Ilie Acu";
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBSiMeGIZv5bexHsg9HgKYDZzwlf4jeCM0pqIQ/NNKTP acu@TELOMERYX1"
    ];
  };

  users.users.sebi = {
    isNormalUser = true;
    description = "Sebi";
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDGhMzj7ecWvu/f2HSjFGBKw6iVRawLxkn7kBRAWyiYg sebis@notwindows"
    ];
  };

  # Install firefox.
  programs.firefox.enable = true;
  programs.neovim = {
    enable = true; # system-wide nvim (e.g., root, other users)
    defaultEditor = true;
  };

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # Podman with Docker-compatible socket/CLI
  virtualisation.podman.enable = true;
  virtualisation.podman.dockerCompat = true;

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
    # Install Hermes from the system generation so the binary is rooted and
    # available on PATH, while the gateway itself still runs as a user service.
    hermes-agent.packages.${pkgs.system}.default
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

  # Load nvidia driver for Xorg and Wayland
  services.xserver.videoDrivers = ["nvidia"];

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

  # List services that you want to enable:

  # avahi for mdns so my other ubuntu systems can find it in the network with hostname.local
  services.avahi = {
    enable = true;
    nssmdns4 = true;
    openFirewall = true;
    publish = {
      enable = true;
      addresses = true;
      workstation = true;
    };
  };

  services.caddy = {
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
  services.openssh.enable = true;
  services.openssh.settings = {
    PasswordAuthentication = false;
    PermitRootLogin = "no"; # change from default "prohibit-password"
    KbdInteractiveAuthentication = false;
  };

  # Open ports in the firewall.
  networking.firewall.allowedTCPPorts = [ 80 443 ];
  # Mosh uses a high UDP port range by default.
  networking.firewall.allowedUDPPortRanges = [
    { from = 60000; to = 61000; }
  ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "25.11"; # Did you read the comment?

}
