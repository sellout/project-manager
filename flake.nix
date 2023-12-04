{
  description = "A configuration for managing flake-based projects.";

  nixConfig = {
    ## https://github.com/NixOS/rfcs/blob/master/rfcs/0045-deprecate-url-syntax.md
    extra-experimental-features = ["no-url-literals"];
    extra-substituters = ["https://cache.garnix.io"];
    extra-trusted-public-keys = [
      "cache.garnix.io:CTFPyKSLcx5RMJKfLo5EEPUObbA78b0YQ2DTCJXqr9g="
    ];
    ## Isolate the build.
    registries = false;
    sandbox = "relaxed";
  };

  outputs = {
    bash-strict-mode,
    flake-schemas,
    flake-utils,
    flaky,
    nix-schema,
    nixpkgs-22_11,
    nixpkgs-23_05,
    nixpkgs-23_11,
    nixpkgs-unstable,
    self,
    treefmt-nix,
  }: let
    pname = "project-manager";

    supportedSystems = flake-utils.lib.defaultSystems;

    ## The Nixpkgs release to use internally for building Project Manager
    ## itself, regardless of the downstream package set.
    buildNixpkgs = nixpkgs-23_11;
  in
    {
      schemas =
        flake-schemas.schemas
        // import ./nix/schemas.nix {inherit flake-schemas;};

      lib = import ./nix/lib.nix {
        inherit bash-strict-mode treefmt-nix;
        project-manager = self;
      };

      overlays.default = final: prev: {
        project-manager = self.packages.${final.system}.project-manager;
      };

      ## All of the modules included in Project Manager. You generally don’t
      ## need to use this directly, as these modules are loaded by default.
      ##
      ## NB: Project Manager also loads some modules inherited from nixpkgs.
      ##     Those are not yet included in this set.
      projectModules = import ./modules/modules.nix;

      homeConfigurations =
        builtins.listToAttrs
        (builtins.map
          (flaky.lib.homeConfigurations.example
            "project-manager"
            self
            [({pkgs, ...}: {home.packages = [pkgs.project-manager];})])
          supportedSystems);
    }
    // flake-utils.lib.eachSystem supportedSystems
    (system: let
      pkgsFrom = nixpkgs:
        import nixpkgs {
          inherit system;
          overlays = [
            bash-strict-mode.overlays.default
            self.overlays.default
            (final: prev: {
              nix-schema = nix-schema.packages.${system}.nix.overrideAttrs (old: {
                doCheck = false;
                postInstall =
                  old.postInstall
                  + ''
                    mv $out/bin/nix $out/bin/nix-schema
                  '';
                doInstallCheck = false;
              });
            })
          ];
        };

      projectConfigurationsFor = pkgs:
        flaky.lib.projectConfigurations.default {inherit pkgs self;};
    in {
      packages = let
        releaseInfo = import ./release.nix;
        docs = import ./docs {
          inherit (releaseInfo) release isReleaseBranch;
          pkgs = pkgsFrom buildNixpkgs;
        };
      in {
        default = self.packages.${system}.project-manager;
        docs-html = docs.manual.html;
        docs-json = docs.options.json;
        docs-manpages = docs.manPages;
        project-manager =
          (pkgsFrom buildNixpkgs).callPackage ./project-manager {};
      };

      projectConfigurations = projectConfigurationsFor (pkgsFrom buildNixpkgs);

      devShells = self.projectConfigurations.${system}.devShells;

      # devShells = let
      #   pkgs = nixpkgs.legacyPackages.${system};
      #   tests = import ./tests {inherit pkgs;};
      # in
      #   tests.run;

      checks = let
        checksWith = nixpkgs:
          buildNixpkgs.lib.mapAttrs'
          (name:
            buildNixpkgs.lib.nameValuePair
            (name
              + "-"
              ## TODO: Can’t have dots in output names unil garnix-io/issues#30
              ##       is fixed.
              + builtins.replaceStrings
              ["."]
              ["_"]
              nixpkgs.lib.trivial.release))
          (projectConfigurationsFor (pkgsFrom nixpkgs)).checks;
      in
        self.projectConfigurations.${system}.checks
        // checksWith nixpkgs-22_11
        // checksWith nixpkgs-23_05
        // checksWith nixpkgs-23_11
        // checksWith nixpkgs-unstable;

      formatter = self.projectConfigurations.${system}.formatter;
    });

  inputs = {
    bash-strict-mode = {
      inputs = {
        flake-utils.follows = "flake-utils";
        flaky.follows = "flaky";
        nixpkgs.follows = "nixpkgs-23_11";
      };
      url = "github:sellout/bash-strict-mode";
    };

    ## TODO: Switch back to upstream once DeterminateSystems/flake-schemas#15 is
    ##       merged.
    flake-schemas.url = "github:sellout/flake-schemas/patch-1";

    flake-utils.url = "github:numtide/flake-utils";

    flaky = {
      inputs = {
        bash-strict-mode.follows = "bash-strict-mode";
        flake-utils.follows = "flake-utils";
        nixpkgs.follows = "nixpkgs-23_11";
        project-manager.follows = "";
      };
      url = "github:sellout/flaky";
    };

    ## Provides a version of `nix` that uses schemas. Helpful for validation.
    ## This should be simplified once either DeterminateSystems/flake-schemas#14
    ## or NixOS/nix#8892 is resolved.
    nix-schema = {
      inputs = {
        flake-schemas.follows = "flake-schemas";
        nixpkgs.follows = "nixpkgs-23_11";
      };
      url = "github:DeterminateSystems/nix/flake-schemas";
    };

    ## We test against each supported version of nixpkgs, but build against the
    ## latest stable release.
    nixpkgs-22_11.url = "github:NixOS/nixpkgs/release-22.11";
    nixpkgs-23_05.url = "github:NixOS/nixpkgs/release-23.05";
    nixpkgs-23_11.url = "github:NixOS/nixpkgs/release-23.11";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    treefmt-nix = {
      inputs.nixpkgs.follows = "nixpkgs-23_11";
      url = "github:numtide/treefmt-nix";
    };
  };
}
