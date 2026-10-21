{ pkgs, ... }:

# Fonts: which are installed, and which each kind of text uses by default.
let
  # Libron serif font, packaged from github.com/nicoverbruggen/libron (not in nixpkgs); ../update-browsers.sh writes the newest version and hash.
  libron = pkgs.callPackage (
    {
      lib,
      stdenvNoCC,
      fetchzip,
    }:

    stdenvNoCC.mkDerivation (finalAttrs: {
      pname = "libron";
      version = "0.31";

      src = fetchzip {
        url = "https://github.com/nicoverbruggen/libron/releases/download/v${finalAttrs.version}/Libron.zip";
        hash = "sha256-UD+8cjdiomyEtGlLtkmcNd8Y8wNU8RIEwyPdq55nm4o=";
        stripRoot = false;
      };

      installPhase = ''
        runHook preInstall
        install -Dm644 -t $out/share/fonts/truetype *.ttf
        runHook postInstall
      '';

      meta = {
        description = "Serif font tuned for digital reading, a revision of Readerly";
        homepage = "https://github.com/nicoverbruggen/libron";
        license = lib.licenses.ofl;
        platforms = lib.platforms.all;
      };
    })
  ) { };
in
{
  # Not NixOS's default set (on by default with a graphical desktop; audit D16): Noto below already covers the scripts
  # its DejaVu, FreeFont, TeX Gyre and Unifont did, so only three of its packages are listed instead.
  fonts.enableDefaultPackages = false;

  # Fonts must be listed here, not in systemPackages, for fontconfig to see them.
  fonts.packages = [
    # Kept from that set: colour emoji; Chinese, Japanese and Korean (sans only: the serif set was 100 MB more);
    # Liberation, metric-compatible with Arial, Times New Roman and Courier New, so documents and pages that name them
    # keep their line breaks.
    pkgs.noto-fonts-color-emoji
    pkgs.noto-fonts-cjk-sans
    pkgs.liberation_ttf

    # The one type system (the owner's choice, 16 October 2026): Geist for every interface (app windows and menus, the
    # shell, the lock screen, mango's tab bar) and Geist Mono for terminals, code and annotations (kitty, the shell's
    # metadata, the editors). Vercel, OFL-1.1: a grotesque built on the principles of classic Swiss typography.
    pkgs.geist-font
    # The icon glyphs terminal programs draw (yazi, lazygit, the prompt; Geist Mono has none): kitty maps the private-use
    # planes to it (symbol_map), and fontconfig falls back to it after Geist Mono.
    pkgs.nerd-fonts.symbols-only
    # Last-resort symbol font for Emacs (not open source; allowed by name in configuration.nix).
    pkgs.symbola
    # Gone in the typography audit of 16 October 2026, nothing naming them any more: JetBrains Mono Nerd Font (the
    # terminal font until Geist Mono), IBM Plex Sans (the interface font before Geist; as a fallback it put a second
    # grotesque in Geist's gaps) and Material Symbols (the shell draws Swiss Glyphs).

    # Reading text. Packaged above.
    libron

    # Fallbacks the design names after Geist (design/swiss tokens: "Geist", "Noto Sans", "Noto Sans Tamil"; mono: "Geist
    # Mono", "Noto Sans Mono"): Geist covers only Latin, Cyrillic and Greek, so Tamil window titles and notifications fell
    # to FreeSerif (audit FA-01). All of Noto, as the design README says: cached, about 51 MB, every script (the three
    # families alone would be a local build from the 750 MB Noto source).
    pkgs.noto-fonts
  ];

  # What an app gets when it asks for "serif", "sans-serif" or "monospace" (and, through them, Zen's default page fonts,
  # Obsidian's code and anything else that names a generic family). Noto fills what Geist lacks, as the design names it.
  fonts.fontconfig.defaultFonts = {
    serif = [ "Libron" ];
    sansSerif = [ "Geist" "Noto Sans" "Noto Sans Tamil" ];
    monospace = [ "Geist Mono" "Symbols Nerd Font Mono" "Noto Sans Mono" ];
  };
}
