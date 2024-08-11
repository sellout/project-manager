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
    nixpkgs-unstable,
    self,
    treefmt-nix,
  }: let
    pname = "project-manager";

    supportedSystems = flaky.lib.defaultSystems;

    pkgsFor = system:
      import nixpkgs {
        inherit system;
        overlays = [
          bash-strict-mode.overlays.default
          flaky.overlays.dependencies
          self.overlays.default
        ];
      };
  in
    {
      schemas =
        flake-schemas.schemas
        // import ./nix/schemas.nix {inherit flake-schemas;};

      templates = import ./templates;

      lib = import ./nix/lib.nix {
        inherit bash-strict-mode flake-utils pkgsFor treefmt-nix;
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
          (flaky.lib.homeConfigurations.example self
            [({pkgs, ...}: {home.packages = [pkgs.project-manager];})])
          supportedSystems);
    }
    // flake-utils.lib.eachSystem supportedSystems
    (system: let
      projectConfigurationsFor = pkgs:
        flaky.lib.projectConfigurations.default {
          inherit pkgs self supportedSystems;
        };

      pkgs = pkgsFor system;
    in {
      packages = let
        releaseInfo = import ./release.nix;
        docs = import ./docs {
          inherit pkgs self;
          inherit (releaseInfo) release isReleaseBranch;
        };
      in {
        default = self.packages.${system}.project-manager;
        docs-html = docs.manual.html;
        docs-json = docs.options.json;
        docs-manpages = docs.manPages;
        project-manager = pkgs.callPackage ./project-manager {
          inherit (releaseInfo) release;
        };
      };

      projectConfigurations = projectConfigurationsFor pkgs;

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
        checksWith = nixpkgs: overlay:
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
          (projectConfigurationsFor (import nixpkgs {
            inherit system;
            overlays = [overlay];
          }))
          .checks;
        allChecks =
          self.projectConfigurations.${system}.checks
          // checksWith nixpkgs-22_11 (_: _: {})
          // checksWith nixpkgs-23_05 (final: prev: {
            haskellPackages = prev.haskellPackages.extend (hfinal: hprev:
              if final.system == "i686-linux"
              then {
                ## This is a dependency of ShellCheck. This patch is cobbled
                ## together from haskell-foundation/foundation#573.
                basement =
                  final.haskell.lib.appendPatch hprev.basement
                  (final.fetchpatch {
                    name = "basement-i686-ghc-9.4.patch";
                    url = "https://github.com/haskell-foundation/foundation/pull/573/commits/38be2c93acb6f459d24ed6c626981c35ccf44095.patch";
                    sha256 = "17kz8glfim29vyhj8idw8bdh3id5sl9zaq18zzih3schfvyjppj7";
                    stripLen = 1;
                    ## FIXME: This doesn’t seem to modify the patch, so it
                    ##        doesn’t actually work.
                    postFetch = ''
                      sed -i 's/+#if __GLASGOW_HASKELL__ >= 904/+#if __GLASGOW_HASKELL__ >= 902/g' "$out"
                    '';
                  });
              }
              else {});
          })
          // checksWith nixpkgs-23_11 (final: prev: {
            haskellPackages = prev.haskellPackages.extend (hfinal: hprev:
              if final.system == "i686-linux"
              then {
                pandoc_3_1_9 = final.haskell.lib.dontCheck hprev.pandoc_3_1_9;
              }
              else {});
          })
          ## This is covered by the version used to build Project Manager
          # // checksWith nixpkgs-24_05 (_: _: {})
          // checksWith nixpkgs-unstable (final: prev: {
            haskellPackages = prev.haskellPackages.extend (hfinal: hprev:
              if final.system == "i686-linux"
              then {
                unordered-containers =
                  final.haskell.lib.dontCheck
                  hprev.unordered-containers;
              }
              else {});
          });
      in
        ## FIXME: Because the basement override isn’t working.
        if system == "i686-linux"
        then removeAttrs allChecks ["formatter-23_05" "shellcheck-23_05"]
        else allChecks;

      formatter = self.projectConfigurations.${system}.formatter;
    });

  inputs = {
    ## Flaky should generally be the source of truth for its inputs.
    flaky = {
      inputs.project-manager.follows = "";
      url = "github:sellout/flaky";
    };

    bash-strict-mode.follows = "flaky/bash-strict-mode";
    flake-utils.follows = "flaky/flake-utils";
    ## The Nixpkgs release to use internally for building Project Manager
    ## itself, regardless of the downstream package set.
    nixpkgs.follows = "flaky/nixpkgs";

    ## TODO: Switch back to upstream once DeterminateSystems/flake-schemas#15 is
    ##       merged.
    flake-schemas.url = "github:sellout/flake-schemas/patch-1";

    ## We test against each supported version of nixpkgs, but build against the
    ## latest stable release.
    ## TODO: Split these into separate flakes a la
    ##       https://github.com/NixOS/nix/issues/4193#issuecomment-1228967251
    ##       once garnix-io/issues#27 is fixed.
    nixpkgs-22_11.url = "github:NixOS/nixpkgs/release-24.05";
    nixpkgs-23_05.url = "github:NixOS/nixpkgs/release-23.05";
    nixpkgs-23_11.url = "github:NixOS/nixpkgs/release-23.11";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    treefmt-nix = {
      inputs.nixpkgs.follows = "nixpkgs";
      url = "github:numtide/treefmt-nix";
    };
  };
}
