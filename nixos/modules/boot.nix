{ pkgs, lib, ... }:

let
  swiss = import ./swiss-colors.nix;   # the Swiss Dark Mode colours, written by ~/.config/swiss-desktop/bin/swiss-build
  ansi = n: builtins.elemAt swiss.ansi n;
in
{
  # Limine EFI boot loader. The newest 3 generations stay selectable in its menu.
  boot.loader.limine.enable = true;
  boot.loader.limine.maxGenerations = 3;
  boot.loader.efi.canTouchEfiVariables = true;

  # Plain boot menu, shown for 2s: no picture, Limine's own text in the Swiss Dark Mode colours (swiss-colors.nix, from
  # the tokens): chalk on the desktop's ground, each entry's comment line (the generation and kernel) in grey, the
  # countdown in the one red. Press any key to stop the countdown and pick an older generation.
  boot.loader.timeout = 2;
  boot.loader.limine.style = {
    wallpapers = [ ];
    interface = {
      resolution = "2560x1440";
      branding = "";
      helpColor = swiss.accent;         # the countdown, "Booting automatically in 2..."
      helpColorBright = swiss.text;     # its number
      helpHidden = true;
    };
    # Text at twice the size. Limine's eight slots: 0 the ground, 1 red, 6 ("cyan") the comment line, 7 grey; the
    # bright row likewise, ending in chalk. The rest are the terminal's own.
    graphicalTerminal = {
      font.scale = "2x2";
      palette = lib.concatStringsSep ";" [ swiss.background swiss.accent (ansi 2) (ansi 3) (ansi 4) (ansi 5) swiss.muted swiss.muted ];
      brightPalette = lib.concatStringsSep ";" [ swiss.rule swiss.accent (ansi 10) (ansi 11) (ansi 12) (ansi 13) swiss.text swiss.text ];
      foreground = swiss.text;
      background = swiss.background;
    };
  };

  # LTS kernel, not the latest: the GTX 1070 runs on NVIDIA's legacy 580 driver,
  # which gets kernel fixes later than the main driver does.
  boot.kernelPackages = pkgs.linuxPackages;

  # Console (boot text, ly) runs at the PG279Q's native 2560x1440; mango sets its own mode.
  boot.kernelParams = [ "video=2560x1440" ];

  environment.systemPackages = [
    pkgs.efibootmgr # lists and reorders the firmware's boot entries (Limine, the old systemd-boot)
  ];
}
