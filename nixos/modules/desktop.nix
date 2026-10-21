{ lib, pkgs, ... }:

# What the desktop runs: mango, the login screen, locking and the keyring.
{
  # --- Session ---

  # mango is the desktop (~/.config/mango); its autostart.sh starts the rest of the session.
  programs.mango.enable = true;
  # The nixpkgs mango module routes the Inhibit portal to gtk, which cannot inhibit here (no GNOME session: "Inhibiting
  # other than idle not supported", 118 errors on 15 October). none, as in mango's own upstream portals.conf: apps then use
  # org.freedesktop.ScreenSaver (served by hypridle) or Wayland's idle inhibit instead.
  xdg.portal.config.mango."org.freedesktop.impl.portal.Inhibit" = lib.mkForce [ "none" ];

  # Login screen: ly, a text login on the console (how it looks: theme.nix).
  services.displayManager.ly.enable = true;

  # Log in to mango by itself at boot, so a restart from afar comes back to a running desktop; autostart.sh locks it at once.
  # No password is typed at this login, so the keyring opens at the first unlock of the lock screen instead (hyprlock's
  # PAM entry below).
  services.displayManager.autoLogin = {
    enable = true;
    user = "kishan";
  };
  services.displayManager.defaultSession = "mango";

  environment.systemPackages = with pkgs; [
    hypridle            # locks and turns the screen off when idle
    hyprlock            # screen locker
    wlopm               # turns the screens off and on (used by hypridle)
    wlr-randr           # lists what each screen offers: sizes, refresh rates, scale (by hand; nothing calls it)
    cmatrix             # screensaver: matrix rain (started by hypridle)
    wlsunset            # night light (Super+Alt+N in mango's bind.conf)
    # quickshell: bar, panels and notifications (~/.config/quickshell); wrapped so its Qt also finds the WebP reader the package leaves out
    (symlinkJoin {
      name = "quickshell";
      paths = [ quickshell ];
      nativeBuildInputs = [ makeWrapper ];
      postBuild = "wrapProgram $out/bin/quickshell --prefix QT_PLUGIN_PATH : ${qt6.qtimageformats}/lib/qt-6/plugins";
    })
    wl-clipboard        # clipboard for terminal, Neovim and screenshots
    cliphist            # clipboard history
    grim                # screenshots
    slurp               # screenshot region picker
    yazi                # terminal file manager
    nautilus            # graphical file manager
    ffmpegthumbnailer   # video thumbnails in Nautilus
    playerctl           # media keys
    ddcutil             # monitor brightness and contrast over DDC/CI (the bar's sun and the brightness keys)
    pavucontrol         # "sound settings" in the bar's sound panel
    networkmanagerapplet  # nm-connection-editor: "network settings" in the bar's network panel
    libqalculate        # qalc: the launcher's calculator ("=2^10", "=12 km to mi")
    perl                # the shell's scripts/metrics.pl and bt-agent.sh (otherwise only there as a NixOS default package)
    python3             # the shell's scripts/screenshot.sh; also the language servers and Doom modules (dev.nix)
  ];

  # Chromium and Electron apps run on Wayland directly, not through XWayland.
  environment.sessionVariables.NIXOS_OZONE_WL = "1";

  # Text-to-speech (Speech Dispatcher): a web page's speechSynthesis speaks in Zen instead of showing "Speech Dispatcher
  # won't open". It brings about 650 MB of voices; a user socket starts it the first time something asks to speak.
  services.speechd.enable = true;
  # Without the MBROLA voices and flite (audit D6): about 700 MiB of the speech closure, where espeak-ng and pico, the
  # voices in use, take 7. Speech Dispatcher and espeak-ng then build here (a few minutes, once per update of either).
  services.speechd.package = pkgs.speechd.override {
    withFlite = false;
    espeak = pkgs.espeak-ng.override { mbrolaSupport = false; };
  };
  # One voice module. With no AddModule line Speech Dispatcher starts every sd_* module it has: 14 processes, 6 of
  # them zombies of modules that aren't installed (baratinoo, cicero, festival, kali, openjtalk, voxin). Expect three
  # (espeak-ng, and the espeak-ng fallback and dummy modules it always loads). The other lines are the package's own
  # speechd.conf. Setting it replaces the package's whole /etc/speech-dispatcher, so the module's own settings follow
  # (its espeak-ng.conf, comments left out); the package's one client file is an empty emacs block, so no Include.
  services.speechd.modules."espeak-ng" = ''
    Debug 0
    EspeakSoundIconFolder "/usr/share/sounds/sound-icons/"
    EspeakSoundIconVolume 0
    EspeakPunctuationList "@+_"
    EspeakCapitalPitchRise 0
    EspeakMinRate 80
    EspeakNormalRate 170
    EspeakMaxRate 449
    EspeakAudioChunkSize 300
    EspeakAudioQueueMaxSize 441000
    EspeakIndexing 1
    EspeakMbrola 0
  '';
  services.speechd.config = ''
    LogLevel 3
    LogDir "default"
    DefaultVolume 100
    SymbolsPreproc "char"
    SymbolsPreprocFile "gender-neutral.dic"
    SymbolsPreprocFile "font-variants.dic"
    SymbolsPreprocFile "symbols.dic"
    SymbolsPreprocFile "emojis.dic"
    SymbolsPreprocFile "orca.dic"
    SymbolsPreprocFile "orca-chars.dic"
    AddModule "espeak-ng" "sd_espeak-ng" "espeak-ng.conf"
    DefaultModule espeak-ng
  '';

  # Nautilus needs this to show its trash, phones and network folders.
  services.gvfs.enable = true;

  # --- Locking and passwords ---

  # hyprlock checks the password through its own PAM entry (without one it borrows su's). With autologin it is the
  # first place a password is typed after boot, so it also unlocks the "login" keyring with it (audit NIX-02).
  security.pam.services.hyprlock.enableGnomeKeyring = true;

  # hypridle (~/.config/hypr/hypridle.conf) as a user service, restarted if it crashes and logged to the journal; mango's
  # autostart.sh used to start it unsupervised and unlogged. It starts with mango-session.target, which mango starts
  # only after exporting WAYLAND_DISPLAY: graphical-session.target is reached earlier at login (by
  # nixos-fake-graphical-session), before the display exists. Its PATH is the system profile, so the commands in
  # hypridle.conf (loginctl, hyprlock, wlopm, flock, the screensaver's kitty) resolve as in a login shell.
  systemd.user.services.hypridle = {
    description = "hypridle: screensaver, lock and screen-off steps when idle (~/.config/hypr/hypridle.conf)";
    partOf = [ "graphical-session.target" ];
    after = [ "graphical-session.target" "mango-session.target" ];
    wantedBy = [ "mango-session.target" ];
    path = [ "/run/wrappers" "/run/current-system/sw" ];
    unitConfig.ConditionEnvironment = "WAYLAND_DISPLAY";
    serviceConfig = {
      ExecStart = "${pkgs.hypridle}/bin/hypridle";
      Restart = "on-failure";
      RestartSec = 2;
    };
  };

  # Keyring for app sign-ins such as Zed's and Helium's. The "login" keyring opens with the first lock-screen unlock after
  # boot; other keyrings open from it when their passwords are stored there ("automatically unlock" in their prompt).
  services.gnome.gnome-keyring.enable = true;
  # Without the keyring's SSH agent (gcr-ssh-agent, on by default with it): nothing could reach it (SSH_AUTH_SOCK was
  # only in systemd's environment) and there are no SSH keys here to hold (audit D11).
  services.gnome.gcr-ssh-agent.enable = false;
}
