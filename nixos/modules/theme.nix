{ pkgs, ... }:

# How the desktop looks outside the shell: GTK and Qt apps, icons, pointer, the console and the login screen.
let
  # The Swiss Dark Mode colours, written by ~/.config/swiss-desktop/bin/swiss-build (also used by boot.nix).
  swiss = import ./swiss-colors.nix;

  # Mouse pointer for GTK apps (mango's own is cursor_theme in its config).
  cursorTheme = "Bibata-Modern-Ice";

  # Only the one cursor look in use; the full Bibata set is 320 MB.
  cursorPackage = pkgs.runCommand "bibata-modern-ice" { } ''
    mkdir -p $out/share/icons
    cp -r ${pkgs.bibata-cursors}/share/icons/${cursorTheme} $out/share/icons/
  '';
in
{
  environment.systemPackages = with pkgs; [
    adw-gtk3            # GTK3 theme; ~/.config/gtk-3.0/gtk.css gives it the Swiss colours
    papirus-icon-theme  # icons for GTK apps
    cursorPackage
  ];

  # Qt apps (qimgv, CoolerControl, OpenRGB; all Qt 6) through Qt's own GTK3 platform theme: GTK's colours
  # (the Swiss tokens, via ~/.config/gtk-3.0/gtk.css), fonts and dialogs, following light / dark with GTK. The shell is a
  # Qt app too and keeps this variable (so the apps its launcher and dock start inherit it); its own look is unchanged
  # by it once its icon theme is pinned (~/.config/quickshell/scripts/run-shell.sh: QS_ICON_THEME=hicolor).
  environment.sessionVariables.QT_QPA_PLATFORMTHEME = "gtk3";

  # The text console (boot messages, the ly login screen, Ctrl+Alt+F2) in the Swiss Dark Mode palette, the same sixteen as
  # kitty's, read from swiss-colors.nix (swiss-build writes it from ~/.config/swiss-desktop/tokens/dark.env, so the two
  # cannot drift apart again). Terminus at 32 px: the same size as the boot menu's text (Limine's font at 2x), from the
  # first line of boot on (earlySetup).
  console.colors = swiss.ansi;
  console.font = "ter-v32n";
  console.packages = [ pkgs.terminus_font ];
  console.earlySetup = true;

  # The login screen (ly) in the lock screen's terms: no animation, the 24-hour time in the top right corner (ly's big
  # clock is drawn in "#" on the console), the text in chalk, the box's hairline in grey, errors in red. The console has
  # only its sixteen colours, so ly names palette slots (eight-colour mode; 0x40000000 is "bright") instead of RGB
  # values. No brightness hints: the monitor has no backlight (its brightness is DDC, in the bar); no version string.
  services.displayManager.ly.settings = {
    animation = "none";
    clock = "%H:%M";
    full_color = false;
    fg = "0x40000008";          # bright white: slot 15, chalk
    border_fg = "0x40000001";   # bright black: slot 8, grey
    error_fg = "0x00000002";    # red: slot 1
    corner_top_left = "shutdown,restart,password";
    corner_bottom_left = "";
  };

  # GTK apps and file dialogs: default theme, icons, pointer and fonts.
  programs.dconf.enable = true;
  programs.dconf.profiles.user.databases = [{
    settings."org/gnome/desktop/interface" = {
      # Defaults before the first swiss-mode switch (Dark Mode); swiss-mode writes the user's own values over these.
      gtk-theme = "adw-gtk3-dark";
      icon-theme = "Papirus-Dark";
      color-scheme = "prefer-dark";
      accent-color = "red";
      cursor-theme = cursorTheme;
      font-name = "Geist 11";
      document-font-name = "Libron 11";
      monospace-font-name = "Geist Mono 11";
    };
    # No window buttons inside apps: mango has no title bars.
    settings."org/gnome/desktop/wm/preferences".button-layout = ":";
  }];
}
