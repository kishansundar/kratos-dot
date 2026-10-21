{ pkgs, ... }:

{
  # General applications; packages that belong to one feature are in its file.
  environment.systemPackages = with pkgs; [
    wget
    spotify             # music
    unzip
    zip
    unrar               # not open source; allowed by name in configuration.nix
    qimgv
    obsidian
  ];
}
