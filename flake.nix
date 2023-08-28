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

  outputs = inputs:
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
      pkgs = import inputs.nixpkgs {inherit system;};

      format =
        (inputs.treefmt-nix.lib.evalModule pkgs {
          projectRootFile = "flake.nix";
          programs = {
            ## Nix formatter
            alejandra.enable = true;
            ## Shell linter
            # shellcheck.enable = true;
            ## Web/JSON/Markdown/TypeScript/YAML formatter
            prettier.enable = true;
            ## Shell formatter
            shfmt = {
              enable = true;
              ## NB: This has to be unset to allow the .editorconfig
              ##     settings to be used. See numtide/treefmt-nix#96.
              indent_size = null;
            };
          };
        })
        .config
        .build;
    in {
      packages = let
        pkgs = inputs.nixpkgs.legacyPackages.${system};
        releaseInfo = inputs.nixpkgs.lib.importJSON ./release.json;
        # docs = import ./docs {
        #   inherit pkgs;
        #   inherit (releaseInfo) release isReleaseBranch;
        # };
        pmPkg = pkgs.callPackage ./project-manager {path = toString ./.;};
      in {
        default = pmPkg;
        project-manager = pmPkg;

        # docs-html = docs.manual.html;
        # docs-json = docs.options.json;
        # docs-manpages = docs.manPages;
      };

      devShells.default = pkgs.mkShell {
        inputsFrom =
          builtins.attrValues inputs.self.checks.${system}
          ++ builtins.attrValues inputs.self.packages.${system};
      };
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
            [
              ./.config/project.nix
            ]
            ++ (
              if builtins.pathExists userConfig
              then [userConfig]
              else []
            );
        };

      formatter = format.wrapper;
    });

  inputs = {
    flake-utils.url = "github:numtide/flake-utils";

    ## Used to piggy-back on module definitions
    home-manager.url = "github:nix-community/home-manager/release-23.05";

    nixpkgs.url = "github:NixOS/nixpkgs/release-23.05";

    treefmt-nix = {
      inputs.nixpkgs.follows = "nixpkgs";
      url = "github:numtide/treefmt-nix";
    };
  };
}
