{
  files = ./files;
  # ./misc/dconf.nix
  # ./misc/debug.nix
  editorconfig = ./misc/editorconfig;
  news = ./misc/news.nix;
  # ./misc/specialisation.nix
  version = ./misc/version.nix;
  # ./misc/vte.nix
  xdg = ./misc/xdg.nix;
  # ./programs/bash.nix
  cabal2nix = ./programs/cabal2nix.nix;
  # ./programs/darcs.nix
  direnv = ./programs/direnv.nix;
  # ./programs/emacs.nix
  # ./programs/fish.nix
  # ./programs/gh.nix
  # ./programs/gh-dash.nix
  # ./programs/git-cliff.nix
  # ./programs/git-credential-oauth.nix
  git = ./programs/git;
  hpack = ./programs/hpack.nix;
  hpack-dhall = ./programs/hpack-dhall.nix;
  just = ./programs/just.nix;
  mercurial = ./programs/mercurial.nix;
  # ./programs/neovim.nix
  # ./programs/nushell.nix
  project-manager = ./programs/project-manager.nix;
  # ./programs/pylint.nix
  shellcheck = ./programs/shellcheck.nix;
  treefmt = ./programs/treefmt.nix;
  vale = ./programs/vale.nix;
  # ./programs/vim.nix
  # ./programs/vscode.nix
  # ./programs/zellij.nix
  # ./programs/zsh.nix
  project-environment = ./project-environment.nix;
  flakehub = ./services/flakehub;
  flakestry = ./services/flakestry.nix;
  garnix = ./services/garnix.nix;
  github = ./services/github.nix;
  # ./services/git-sync.nix
  # ./services/lorri.nix
  nix-cx = ./services/nix-ci.nix;
  renovate = ./services/renovate;
}
# // optional useNixpkgsModule ./misc/nixpkgs.nix
# // optional (!useNixpkgsModule) ./misc/nixpkgs-disabled.nix

