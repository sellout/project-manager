{lib, pkgs, ...}: {
  project = {
    name = "project-manager";
    summary = "Home Manager, but for repos.";
    authors = [lib.maintainers.sellout];
    license = "MIT"; # Induced by this being basically a fork of Home Manager
    ## Packages to install in the devShells that reference projectConfiguration.
    packages = [
      ## language servers
      pkgs.nil # Nix
      pkgs.nodePackages.bash-language-server
    ];
  };

  imports = [
    ## tooling
    ./direnv.nix
    ./git.nix
    ./mustache.nix
    ./shellcheck.nix
    ./treefmt.nix
    ## services
    ./flakehub.nix
    ./garnix.nix
    ./github.nix
    ./renovate.nix
    ## editors
    ./editorconfig.nix
    ./emacs.nix
  ];
}
