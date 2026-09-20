{
  description = "A configuration for managing flake-based projects.";

  nixConfig = {
    ## NB: This is a consequence of using `self.pkgsLib.runEmptyCommand`, which
    ##     allows us to sandbox derivations that otherwise can’t be.
    allow-import-from-derivation = true;
    extra-substituters = ["https://sellout.cachix.org"];
    extra-trusted-public-keys = [
      "sellout.cachix.org-1:v37cTpWBEycnYxSPAgSQ57Wiqd3wjljni2aC0Xry1DE="
    ];
    ## WAIT: This should be `"fatal"`, but NixOS/nixpkgs#544986.
    lint-absolute-path-literals = "ignore";
    lint-short-path-literals = "fatal";
    lint-url-literals = "fatal";
    ## Isolate the build.
    sandbox = "relaxed";
    use-registries = false;
  };

  ## The flake isn’t a Nix expression, so it’s clearer to keep `outputs` (which
  ## is) in a separate file.
  outputs = inputs: import .config/flake/outputs.nix inputs;

  inputs = {
    ## Flaky should generally be the source of truth for its inputs.
    flaky = {
      inputs.project-manager.follows = "";
      url = "github:sellout/flaky";
    };

    flake-utils.follows = "flaky/flake-utils";
    ## The Nixpkgs release to use internally for building Project Manager
    ## itself, regardless of the downstream package set.
    nixpkgs.follows = "flaky/nixpkgs";
    systems.follows = "flaky/systems";

    ## TODO: Switch back to upstream once DeterminateSystems/flake-schemas#15 is
    ##       merged.
    flake-schemas.url = "github:sellout/flake-schemas/patch-1";

    ## We test against each supported version of nixpkgs, but build against the
    ## latest stable release.
    ## TODO: Split these into separate flakes a la
    ##       https://github.com/NixOS/nix/issues/4193#issuecomment-1228967251
    ##       once garnix-io/issues#27 is fixed.
    nixpkgs-22_11.url = "github:NixOS/nixpkgs/release-22.11";
    nixpkgs-23_05.url = "github:NixOS/nixpkgs/release-23.05";
    nixpkgs-23_11.url = "github:NixOS/nixpkgs/release-23.11";
    nixpkgs-24_05.url = "github:NixOS/nixpkgs/release-24.05";
    nixpkgs-24_11.url = "github:NixOS/nixpkgs/release-24.11";
    nixpkgs-25_05.url = "github:NixOS/nixpkgs/release-25.05";
    nixpkgs-25_11.url = "github:NixOS/nixpkgs/release-25.11";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    treefmt-nix = {
      inputs.nixpkgs.follows = "nixpkgs";
      url = "github:numtide/treefmt-nix";
    };
  };
}
