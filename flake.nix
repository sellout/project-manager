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
    sandbox = true;
  };

  outputs = inputs: let
    pname = "project-manager";
  in
    {
      lib = {
        projectManagerConfiguration = {
          modules ? [],
          pkgs,
          lib ? pkgs.lib,
          extraSpecialArgs ? {},
          check ? true,
        }:
          import ./modules {
            inherit check extraSpecialArgs lib pkgs;
            configuration = {...}: {
              imports =
                modules ++ [{programs.project-manager.path = toString ./.;}];
            };
            modules = builtins.attrValues inputs.self.projectModules;
          };
      };

      overlays.default = final: prev: {
        project-manager = inputs.self.packages.${final.system}.project-manager;
      };

      ## All of the modules included in Project Manager. You generally don’t
      ## need to use this directly, as these modules are loaded by default.
      ##
      ## NB: Project Manager also loads some modules inherited from nixpkgs.
      ##     Those are not yet included in this set.
      projectModules = import ./modules/modules.nix;
    }
    // inputs.flake-utils.lib.eachSystem inputs.flake-utils.lib.defaultSystems
    (system: let
      pkgs = import inputs.nixpkgs {
        inherit system;
        overlays = [inputs.self.overlays.default];
      };

      format = inputs.flaky.lib.format pkgs {
        ## TODO: This should be populated automatically
        settings.global.excludes = ["garnix.yaml" "renovate.json"];
      };
    in {
      packages = let
        releaseInfo = inputs.nixpkgs.lib.importJSON ./release.json;
        # docs = import ./docs {
        #   inherit pkgs;
        #   inherit (releaseInfo) release isReleaseBranch;
        # };
      in {
        default = inputs.self.packages.${system}.project-manager;
        project-manager =
          pkgs.callPackage ./project-manager {path = toString ./.;};

        # docs-html = docs.manual.html;
        # docs-json = docs.options.json;
        # docs-manpages = docs.manPages;
      };

      devShells.default =
        inputs.flaky.lib.devShells.default pkgs inputs.self [
          pkgs.project-manager
        ] ''
          project-manager switch --flake .#${system}
        '';

      # devShells = let
      #   pkgs = inputs.nixpkgs.legacyPackages.${system};
      #   tests = import ./tests {inherit pkgs;};
      # in
      #   tests.run;

      projectConfigurations = let
        userConfig = ./.config/user/project.nix;
      in
        inputs.self.lib.projectManagerConfiguration {
          inherit pkgs;

          modules =
            [./.config/project.nix]
            ++ (
              if builtins.pathExists userConfig
              then [userConfig]
              else []
            );
        };

      checks.format = format.check inputs.self;

      formatter = format.wrapper;
    });

  inputs = {
    flake-utils.url = "github:numtide/flake-utils";

    flaky = {
      inputs = {
        flake-utils.follows = "flake-utils";
        nixpkgs.follows = "nixpkgs";
      };
      url = "github:sellout/flaky";
    };

    nixpkgs.url = "github:NixOS/nixpkgs/release-23.05";
  };
}
