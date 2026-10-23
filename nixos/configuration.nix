{ config, lib, ... }:

# This machine: the files it is built from, and its own settings.
{
  imports = [
    ./hardware-configuration.nix # the hardware scan NixOS generated
    ./modules/maintenance.nix
    ./modules/boot.nix
    ./modules/hardware.nix
    ./modules/network.nix
    ./modules/accessories.nix
    ./modules/nvidia.nix
    ./modules/desktop.nix
    ./modules/theme.nix
    ./modules/fonts.nix
    ./modules/shell.nix
    ./modules/dev.nix
    ./modules/packages.nix
    ./modules/gaming.nix
    ./modules/scrypted.nix
    ./modules/home-assistant.nix
    ./modules/matterbridge.nix
    ./modules/apps/1password.nix
    ./modules/apps/helium.nix
    ./modules/apps/mpv.nix
    ./modules/apps/rustdesk.nix
    ./modules/apps/zen.nix
  ];

  networking.hostName = "Kratos";

  time.timeZone = "Asia/Kolkata";

  i18n.defaultLocale = "en_US.UTF-8";

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_IN";
    LC_IDENTIFICATION = "en_IN";
    LC_MEASUREMENT = "en_IN";
    LC_MONETARY = "en_IN";
    LC_NAME = "en_IN";
    LC_NUMERIC = "en_IN";
    LC_PAPER = "en_IN";
    LC_TELEPHONE = "en_IN";
    LC_TIME = "en_IN";
  };

  users.users."kishan" = {
    isNormalUser = true;
    description = "Kishan";
    extraGroups = [ "networkmanager" "wheel" ];
  };

  # Software that is not open source is blocked unless it is named here.
  nixpkgs.config.allowUnfreePredicate = pkg:
    builtins.elem (lib.getName pkg) [
      "1password"
      "claude-code"
      "unrar"
      "spotify"
      "obsidian"
      "symbola"
      "steam" "steam-unwrapped"   # Steam needs both names (gaming.nix)
      # NVIDIA driver (GTX 1070)
      "nvidia-x11" "nvidia-settings" "nvidia-kernel-modules"
    ];

  # The nixpkgs version this system is built from, written to ~/nixos/nixpkgs-revision at each switch so the repo records it (rebuild from it with: sudo nixos-rebuild switch -I nixpkgs=https://github.com/NixOS/nixpkgs/archive/$(cat ~/nixos/nixpkgs-revision).tar.gz).
  system.activationScripts.nixpkgsRevision.text = ''
    f=/home/kishan/nixos/nixpkgs-revision
    if [ -d /home/kishan/nixos ] && [ "$(cat "$f" 2>/dev/null)" != "${toString config.system.nixos.revision}" ]; then echo "${toString config.system.nixos.revision}" > "$f"; chown kishan:users "$f"; fi
  '';

  # The NixOS release first installed; it stays the same across upgrades.
  system.stateVersion = "26.05";
}
