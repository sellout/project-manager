{pkgs, ...}: {
  project = {
    name = "project-manager";
    summary = "Home Manager, but for repos.";
    license = "MIT"; # Induced by this being basically a fork of Home Manager
    ## Packages to install in the devShells that reference projectConfiguration.
    packages = [
      pkgs.nil
      pkgs.nodePackages.bash-language-server
    ];
  };

  imports = [
    ./direnv.nix
    ./editorconfig.nix
    ./emacs.nix
    ./garnix.nix
    ./git.nix
    ./github.nix
    ./renovate.nix
    ./shellcheck.nix
  ];
}
