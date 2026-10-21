# Import from the desktop host's config: fonts.packages = ... ++ (import ./quickshell-swiss/design/fonts.nix { inherit pkgs; });
{ pkgs }:
let
  swissGlyphs = pkgs.runCommandLocal "swiss-glyphs-1.0" { } ''
    install -Dm644 ${./glyphs/SwissGlyphs.ttf} $out/share/fonts/truetype/SwissGlyphs.ttf
  '';
in [ pkgs.geist-font pkgs.noto-fonts swissGlyphs ]
