{ pkgs, ... }:

# The shell (fish), its command-line tools, and the terminal (kitty).
{
  # The fetch at the top of each terminal is started from ~/.config/fish/config.fish (since 20 October 2026; here it ran
  # in every user's fish).
  programs.fish.enable = true;

  users.users."kishan".shell = pkgs.fish;

  programs.starship.enable = true;

  programs.zoxide.enable = true;

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

  environment.systemPackages = with pkgs; [
    kitty               # terminal (settings in ~/.config/kitty)
    eza
    bat
    fd
    ripgrep
    fzf
    fastfetch
    btop                # system monitor (Swiss colours: ~/.config/btop/themes/swiss.theme)

    fishPlugins.fzf-fish
    fishPlugins.autopair
  ];

  # kitty is the default terminal.
  environment.variables.TERMINAL = "kitty";
}
