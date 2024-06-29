{
  description = "A configuration for managing flake-based projects.";

  nixConfig = {
    extra-experimental-features = [
      ## https://github.com/NixOS/rfcs/blob/master/rfcs/0045-deprecate-url-syntax.md
      "no-url-literals"
      "recursive-nix"
    ];
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
    nixpkgs,
    nixpkgs-22_11,
    nixpkgs-23_05,
    nixpkgs-23_11,
    nixpkgs-24_05,
    nixpkgs-unstable,
    self,
    treefmt-nix,
  }: let
    pname = "project-manager";

    supportedSystems = flaky.lib.defaultSystems;
  in
    {
      schemas =
        flake-schemas.schemas
        // import ./nix/schemas.nix {inherit flake-schemas;};

      lib = import ./nix/lib.nix {
        inherit bash-strict-mode flake-utils supportedSystems treefmt-nix;
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
          ];
        };

      projectConfigurationsFor = pkgs:
        flaky.lib.projectConfigurations.default {
          inherit pkgs self supportedSystems;
        };
    in {
      packages = let
        releaseInfo = import ./release.nix;
        docs = import ./docs {
          inherit (releaseInfo) release isReleaseBranch;
          pkgs = pkgsFrom nixpkgs;
        };
      in {
        default = self.packages.${system}.project-manager;
        docs-html = docs.manual.html;
        docs-json = docs.options.json;
        docs-manpages = docs.manPages;
        project-manager =
          (pkgsFrom nixpkgs).callPackage ./project-manager {};
      };

      projectConfigurations = projectConfigurationsFor (pkgsFrom nixpkgs);

      devShells = let
        #   tests = import ./tests {inherit pkgs;};
      in
        self.projectConfigurations.${system}.devShells
        # // tests.run
        // {
          default =
            self.devShells.${system}.project-manager.overrideAttrs
            (old: {
              inputsFrom =
                old.inputsFrom
                or []
                ++ builtins.attrValues self.packages.${system};
            });
        };

      checks = let
        checksWith = nixpkgs:
          nixpkgs.lib.mapAttrs'
          (name:
            nixpkgs.lib.nameValuePair
            (name
              + "-"
              ## TODO: Can’t have dots in output names unil garnix-io/issues#30
              ##       is fixed.
              + builtins.replaceStrings
              ["."]
              ["_"]
              nixpkgs.lib.trivial.release))
          (projectConfigurationsFor (pkgsFrom nixpkgs)).checks;

        allChecks =
          removeAttrs
          (self.projectConfigurations.${system}.checks
            // checksWith nixpkgs-22_11
            // checksWith nixpkgs-23_05
            // checksWith nixpkgs-23_11
            // checksWith nixpkgs-24_05
            // checksWith nixpkgs-unstable)
          ## For some reason, nix-hash is failing with these versions.
          [
            "project-manager-files-22_11"
            "project-manager-files-23_05"
            "vale-22_11"
            "vale-23_05"
          ];
      in
        ## `basement`, a dependency of ShellCheck didn’t work on i686 in Nixpkgs
        #.#. 23.05.
        if system == "i686-linux"
        then removeAttrs allChecks ["formatter-23_05" "shellcheck-23_05"]
        else allChecks;

      formatter = self.projectConfigurations.${system}.formatter;
    });

  inputs = {
    bash-strict-mode = {
      inputs = {
        flake-utils.follows = "flake-utils";
        flaky.follows = "flaky";
        nixpkgs.follows = "nixpkgs";
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
        nixpkgs.follows = "nixpkgs";
        project-manager.follows = "";
      };
      url = "github:sellout/flaky";
    };

    ## The Nixpkgs release to use internally for building Project Manager
    ## itself, regardless of the downstream package set.
    nixpkgs.url = "github:NixOS/nixpkgs/release-23.11";

    ## We test against each supported version of nixpkgs, but build against the
    ## latest stable release.
    ## TODO: Split these into separate flakes a la
    ##       https://github.com/NixOS/nix/issues/4193#issuecomment-1228967251
    ##       once garnix-io/issues#27 is fixed.
    nixpkgs-22_11.url = "github:NixOS/nixpkgs/release-22.11";
    nixpkgs-23_05.url = "github:NixOS/nixpkgs/release-23.05";
    nixpkgs-23_11.url = "github:NixOS/nixpkgs/release-23.11";
    nixpkgs-24_05.url = "github:NixOS/nixpkgs/release-24.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    treefmt-nix = {
      inputs.nixpkgs.follows = "nixpkgs";
      url = "github:numtide/treefmt-nix";
    };
  };
}
