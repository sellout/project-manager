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

  outputs = inputs: {
    lib = {
      projectManagerConfiguration =
        { modules ? [ ],
          pkgs,
          lib ? pkgs.lib,
          extraSpecialArgs ? { },
          check ? true
        }:
        import ./modules {
          inherit pkgs lib check extraSpecialArgs;
          configuration = { ... }: {
            imports =
              modules ++ [{ programs.project-manager.path = toString ./.; }];
          };
        };
    };
  }
  // inputs.flake-utils.lib.eachSystem inputs.flake-utils.lib.defaultSystems
    (system: let
      pkgs = import inputs.nixpkgs {inherit system;};

    in {
      projectConfigurations = let
        userConfig = ./.config/user/project.nix;
      in inputs.self.lib.projectManagerConfiguration {
        inherit pkgs;

        modules = [
          ./.config/project.nix
        ] ++ (if builtins.pathExists userConfig then [userConfig] else []);
      };
    });

  inputs = {
    flake-utils.url = "github:numtide/flake-utils";

    ## Used to piggy-back on module definitions
    home-manager.url = "github:nix-community/home-manager/release-23.05";

    nixpkgs.url = "github:NixOS/nixpkgs/release-23.05";
  };
}
