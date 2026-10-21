{ pkgs, ... }:

# Games: Steam with Proton, the per-game tools, and the game drive. Nothing here changes how the system runs until a game
# asks for it (gamemoderun, mangohud, gamescope in its launch options); tuning is only added after it was measured to
# help (gaming audit, 16 Oct 2026: ~/gaming-bench).
let
  # GE-Proton pinned ahead of nixpkgs (which has 11-7): 11-9 of 14 Oct 2026, the newest release. Steam lists it as
  # "GE-Proton" whatever the version, so games set to it move to each new build. Drop this override once nixpkgs has
  # 11-9 or newer (`nix eval nixpkgs#proton-ge-bin.version`). The tarball matched GE's published SHA-512 before pinning.
  geProton = pkgs.proton-ge-bin.overrideAttrs (finalAttrs: prev: {
    version = "GE-Proton11-9";
    # The package takes its src from passthru.variants (replaced below), so nixpkgs' "version without src" warning
    # does not apply; the flag only silences it and is not part of the build.
    __intentionallyOverridingVersion = true;
    passthru = prev.passthru // {
      variants = prev.passthru.variants // {
        x86_64-linux = {
          toolName = "${finalAttrs.version}-x86_64";
          src = pkgs.fetchzip {
            url = "https://github.com/GloriousEggroll/proton-ge-custom/releases/download/${finalAttrs.version}/${finalAttrs.version}-x86_64.tar.gz";
            hash = "sha256-1o3sTPdQmIOKkm6qctt9lQfDEMCsysFyVfVK4sfRpw8=";
          };
        };
      };
    };
  });
in
{
  programs.steam = {
    enable = true;                                  # also turns on 32-bit graphics, the controller udev rules, 32-bit ALSA
    extraCompatPackages = [ geProton ];             # GE-Proton as a choice per game (Properties > Compatibility); Valve's stays the default
    protontricks.enable = true;                     # winetricks for one game's Proton prefix, when a game needs a Windows component
    # NVIDIA's shader cache may grow to 16 GB per game (default 1 GB). Steam starts every game with
    # __GL_SHADER_DISK_CACHE_SKIP_CLEANUP=1, and with that set the driver stops saving new shaders once the cache passes its
    # size limit, so a big game (Overwatch's precompiled set is about 8.6 GB) stutters on the same shaders every session
    # (steam-for-linux #11392). Only Steam and its games get this; the caches live on the game drive.
    package = pkgs.steam.override {
      extraEnv.__GL_SHADER_DISK_CACHE_SIZE = "16000000000";
    };
  };

  # NTSYNC: the kernel's Windows-style sync objects (/dev/ntsync), which Proton 11 and GE-Proton 11 use in place of
  # fsync when the device exists. Measured equal to fsync here (Wukong benchmark, 18 Oct 2026: 13 passes, GPU-bound);
  # kept because Wine and Proton are moving to it and it copies Windows exactly. If a game freezes or misbehaves, give
  # that game `PROTON_NO_NTSYNC=1 %command%` to put it back on fsync.
  boot.kernelModules = [ "ntsync" ];

  # GameMode, for games started with `gamemoderun %command%`: while one runs, the CPU governor is "performance" and the
  # screensaver and lock wait (it asks hypridle through org.freedesktop.ScreenSaver). Everything goes back when it exits.
  # Its GPU settings are not used: on NVIDIA they need X11's NV-CONTROL, which mango does not have.
  programs.gamemode.enable = true;
  users.users.kishan.extraGroups = [ "gamemode" ];

  # Gamescope, per game (`gamescope -W 2560 -H 1440 -r 165 -f -- %command%`): its own compositor for a game that scales or
  # paces badly. Without CAP_SYS_NICE (the default): with it, gamescope cannot start inside Steam's sandbox (nixpkgs#351516).
  programs.gamescope.enable = true;

  # MangoHud: the frame-time overlay and logger (`mangohud %command%`; settings in ~/.config/MangoHud/MangoHud.conf).
  environment.systemPackages = [ pkgs.mangohud ];

  # The game drive: the Samsung 850 PRO (once the old Omarchy install), ext4, its top folder owned by kishan. Steam's
  # library goes in /mnt/games/SteamLibrary (Steam > Settings > Storage > Add Drive). nofail: a missing or failed drive
  # never stops the boot. Not on the NTFS drive "Galaxy": Proton's prefixes need a Linux file system.
  fileSystems."/mnt/games" = {
    device = "/dev/disk/by-label/Games";
    fsType = "ext4";
    options = [ "nofail" ];
  };
}
