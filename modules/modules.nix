{
  pkgs,
  # Note, this should be "the standard library" + PM extensions.
  lib,
  # Whether to enable module type checking.
  check ? true,
}:
with lib; let
  modules =
    [
      ./files.nix
      # ./misc/dconf.nix
      # ./misc/debug.nix
      ./misc/editorconfig.nix
      ./misc/lib.nix
      ./misc/news.nix
      # ./misc/specialisation.nix
      ./misc/submodule-support.nix
      ./misc/version.nix
      # ./misc/vte.nix
      # ./programs/bash.nix
      # ./programs/darcs.nix
      ./programs/direnv.nix
      # ./programs/emacs.nix
      # ./programs/fish.nix
      # ./programs/gh.nix
      # ./programs/gh-dash.nix
      # ./programs/git-cliff.nix
      # ./programs/git-credential-oauth.nix
      ./programs/git.nix
      # ./programs/just.nix
      # ./programs/mercurial.nix
      # ./programs/neovim.nix
      # ./programs/nushell.nix
      ./programs/project-manager.nix
      # ./programs/pylint.nix
      # ./programs/vim.nix
      # ./programs/vscode.nix
      # ./programs/zellij.nix
      # ./programs/zsh.nix
      ./project-environment.nix
      # ./services/git-sync.nix
      # ./services/lorri.nix
      (pkgs.path + "/nixos/modules/misc/assertions.nix")
      (pkgs.path + "/nixos/modules/misc/meta.nix")
    ]
    # ++ optional useNixpkgsModule ./misc/nixpkgs.nix
    # ++ optional (!useNixpkgsModule) ./misc/nixpkgs-disabled.nix
    ;

  pkgsModule = {config, ...}: {
    config = {
      _module.args.baseModules = modules;
      _module.args.pkgsPath = lib.mkDefault pkgs.path;
      _module.args.pkgs = lib.mkDefault pkgs;
      _module.check = check;
      lib = lib.pm;
    };
  };
in
  modules ++ [pkgsModule]
