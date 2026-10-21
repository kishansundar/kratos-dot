{ config, pkgs, ... }:

# Keeping the system in shape: Nix's own settings, the weekly pruning of old generations, and the two commands from the
# scripts one folder up, "sysclean" (shows what a clean-up would remove; "sysclean go" does it) and "sysupdate" (the
# channel, the browsers, the system). How many generations the boot menu offers is in boot.nix.
let
  oldGenerations = pkgs.writeScript "old-generations" (builtins.readFile ../old-generations.sh);
in
{
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  # Identical files in the store are linked together as each package arrives, so a running program's file is never replaced later.
  nix.settings.auto-optimise-store = true;

  # Weekly: the old generations go (../old-generations.sh: Nix's 14-day rule, but every profile keeps its newest 3, the
  # boot menu's three, however old), then the store paths nothing uses any more. Never -d: that leaves no rollback.
  # NixOS's own collector (nix-gc.service and its timer), given no options, so it removes no generations itself; a week
  # missed while the machine was off runs at the next boot.
  nix.gc = {
    automatic = true;
    dates = "weekly";
    persistent = true;
  };
  systemd.services.nix-gc = {
    path = [ config.nix.package pkgs.gawk ];
    preStart = "${oldGenerations} go";
  };

  environment.systemPackages = [
    (pkgs.writeScriptBin "sysclean" (
      builtins.replaceStrings [ "@oldGenerations@" ] [ "${oldGenerations}" ] (builtins.readFile ../sysclean.sh)
    ))
    (pkgs.writeScriptBin "sysupdate" (builtins.readFile ../sysupdate.sh))
  ];
}
