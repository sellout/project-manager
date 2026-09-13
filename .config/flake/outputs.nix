{
  flake-schemas,
  flake-utils,
  flaky,
  nixpkgs,
  nixpkgs-22_11,
  nixpkgs-23_05,
  nixpkgs-23_11,
  nixpkgs-24_05,
  nixpkgs-24_11,
  nixpkgs-25_05,
  nixpkgs-25_11,
  nixpkgs-unstable,
  self,
  systems,
  treefmt-nix,
}: let
  pname = "project-manager";

  supportedSystems = import systems;

  pkgsFor = system:
    nixpkgs.legacyPackages.${system}.appendOverlays [flaky.overlays.default];

  releaseInfo = import ../../release.nix;

  localPackages = pkgs: {
    project-manager = pkgs.callPackage ../../project-manager {
      inherit (releaseInfo) release;
    };
  };
in
  {
    schemas =
      flake-schemas.schemas
      // import ../../nix/schemas.nix {inherit flake-schemas;};

    templates = import ../../templates;

    lib = import ../../nix/lib {inherit flake-utils pkgsFor self treefmt-nix;};

    overlays = {
      default =
        nixpkgs.lib.composeExtensions
        flaky.overlays.default
        self.overlays.local;

      local = final: prev:
        {
          lib =
            prev.lib
            // {
              projectConfiguration = self.lib.configuration;
              defaultProjectConfiguration = self.lib.defaultConfiguration;
            };
        }
        // localPackages final;
    };

    ## All of the modules included in Project Manager. You generally don’t
    ## need to use this directly, as these modules are loaded by default.
    ##
    ## NB: Project Manager also loads some modules inherited from nixpkgs.
    ##     Those are not yet included in this set.
    projectModules = import ../../modules/modules.nix;

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
      flaky.lib.projectConfigurations.nix {
        inherit pkgs self supportedSystems;
      };

    pkgs = pkgsFor system;
  in {
    apps.tests = flake-utils.lib.mkApp {drv = self.checks.${system}.tests;};

    packages = let
      docs = import ../../docs {
        inherit pkgs self;
        inherit (releaseInfo) release isReleaseBranch;
      };
    in
      localPackages pkgs
      // {
        default = self.packages.${system}.project-manager;
        docs-html = docs.manual.html;
        docs-json = docs.options.json;
        docs-manpages = docs.manPages;
      };

    projectConfigurations = projectConfigurationsFor pkgs;

    devShells =
      self.projectConfigurations.${system}.devShells
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
      ## x86_64-darwin isn’t supported from Nixpkgs 26.11 on.
        if
          nixpkgs.lib.versionOlder nixpkgs.lib.trivial.release "26.11"
          || system != "x86_64-darwin"
        then
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
          (projectConfigurationsFor
            (nixpkgs.legacyPackages.${system}.appendOverlays [overlay]))
          .checks
        else {};
      allChecks =
        self.projectConfigurations.${system}.checks
        // checksWith nixpkgs-22_11 (_: _: {})
        // checksWith nixpkgs-23_05 (final: prev: {
          haskellPackages = prev.haskellPackages.extend (hfinal: hprev:
            if final.stdenv.hostPlatform.system == "i686-linux"
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
            if final.stdenv.hostPlatform.system == "i686-linux"
            then {
              pandoc_3_1_9 = final.haskell.lib.dontCheck hprev.pandoc_3_1_9;
            }
            else {});
        })
        // checksWith nixpkgs-24_05 (final: prev: {
          haskellPackages = prev.haskellPackages.extend (hfinal: hprev:
            if final.stdenv.hostPlatform.system == "i686-linux"
            then {
              pandoc_3_1_9 = final.haskell.lib.dontCheck hprev.pandoc_3_1_9;
              unordered-containers =
                final.haskell.lib.dontCheck
                hprev.unordered-containers;
            }
            else {});
        })
        // checksWith nixpkgs-24_11 (_: _: {})
        // checksWith nixpkgs-25_05 (_: _: {})
        // checksWith nixpkgs-25_11 (_: _: {})
        ## This is covered by the version used to build Project Manager
        # // checksWith nixpkgs-26_05 (_: _: {})
        // checksWith nixpkgs-unstable (_: _: {})
        ## TODO: Run tests against all support Nixpkgs versions.
        // {
          tests = pkgs.writeShellScriptBin "tests" ''
            exec env PATH="${pkgs.fzf}/bin:$PATH" \
              ${nixpkgs.lib.getExe pkgs.python3} ${self}/testing/tests.py "$@"
          '';
        };
    in
      ## FIXME: Because the basement override isn’t working.
      if system == "i686-linux"
      then removeAttrs allChecks ["formatter-23_05" "shellcheck-23_05"]
      else allChecks;

    formatter = self.projectConfigurations.${system}.formatter;
  })
