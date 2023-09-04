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
      overlays.default = final: prev: {
        project-manager = inputs.self.packages.${final.system}.project-manager;
      };

      homeConfigurations =
        builtins.listToAttrs
        (builtins.map
          (inputs.flaky.lib.homeConfigurations.example pname inputs.self [])
          inputs.flake-utils.lib.defaultSystems);

      lib = {
        projectManagerConfiguration = {
          modules ? [],
          pkgs,
          lib ? pkgs.lib,
          extraSpecialArgs ? {},
          check ? true,
        }:
          import ./modules {
            inherit pkgs lib check extraSpecialArgs;
            configuration = {...}: {
              imports =
                modules ++ [{programs.project-manager.path = toString ./.;}];
            };
          };
      };
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
        home-manager.follows = "home-manager";
        nixpkgs.follows = "nixpkgs";
      };
      url = "github:sellout/flaky";
    };

    ## Used to piggy-back on module definitions
    home-manager = {
      inputs.nixpkgs.follows = "nixpkgs";
      url = "github:nix-community/home-manager/release-23.05";
    };

    nixpkgs.url = "github:NixOS/nixpkgs/release-23.05";
  };
}
