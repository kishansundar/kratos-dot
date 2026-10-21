{ pkgs, ... }:

{
  programs.nix-ld.enable = true;
  # No Docker since 20 October 2026 (audit D4): never used, and the docker group is root without a password.

  environment.systemPackages = with pkgs; [
    git
    zed-editor

    # Claude Code (not open source; allowed by name in configuration.nix).
    claude-code

    # Programs the LazyVim setup of Neovim needs (its config is in ~/.config/nvim).
    neovim
    gcc                 # C compiler; builds the syntax parsers LazyVim installs
    tree-sitter         # parser generator those builds go through
    lazygit             # git screen LazyVim opens with <leader>gg
    trash-cli           # trash command; makes deleting in the file tree recoverable
    gnumake             # make; a few plugins build with it
    nodejs              # npm; Mason installs some language servers with it

    # Emacs for the Doom config (Doom is in ~/.config/emacs, your settings in ~/.config/doom).
    emacs-pgtk          # Emacs 31.1, the build that draws on Wayland itself
    shellcheck          # optional: checks shell scripts in Doom
    pandoc              # optional: Markdown preview in Doom
  ];
}
