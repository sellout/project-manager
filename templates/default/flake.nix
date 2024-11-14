{
  description = "{{project.summary}}";

  nixConfig = {
    registries = false;
    sandbox = "relaxed";
  };

  outputs = {
    flake-utils,
    nixpkgs,
    project-manager,
    self,
  }:
    flake-utils.lib.eachDefaultSystem (system: let
      pkgs = import nixpkgs {inherit system;};
    in {
      ## This is the line that sets up Project Manager for your project. It
      ## expects to find the configuration in .config/project/default.nix, which
      ## is a Nix module.
      projectConfigurations = project-manager.lib.defaultConfiguration {
        inherit pkgs self;

        ## Specify any additional project configuration modules here, for
        ## example, ones from another flake.
        modules = [
          # some-other-input.projectModules.someModule
        ];

        ## Optionally use `extraSpecialArgs` to pass through arguments to
        ## project.nix.
      };

      devShells =
        ## Project Manager provides some devShells, but not the default. The
        ## `project-manager` devShell contains the packages included in the
        ## project configuration (.config/project/default.nix).
        self.projectConfigurations.${system}.devShells
        // {
          ## An easy way to create a default devShell is to override
          ## `devShells.project-manager` and add the inputs from your other
          ## derivations. This should have all the build dependencies for your
          ## packages & checks, but also the packages from the project
          ## configuration.
          default =
            self.projectConfigurations.${system}.devShells.project-manager.overrideAttrs
            (old: {
              inputsFrom =
                old.inputsFrom
                or []
                ++ builtins.attrValues self.checks.${system} or {}
                ++ builtins.attrValues self.packages.${system} or {};
            });
        };

      ## If you’ve configured a formatter via your project configuration, this
      ## enables it for the flake – `nix fmt` will run this formatter across the
      ## project.
      formatter = self.projectConfigurations.${system}.formatter;

      ## Project Manager provides a number of its own checks – ones to ensure
      ## any generated files are up-to-date, ones that ensure the formatter has
      ## been run, etc. Project modules can also add their own checks – e.g.,
      ## the Vale module adds a style check for English prose.
      checks = self.projectConfigurations.${system}.checks;
    });

  inputs = {
    flake-utils.url = "github:numtide/flake-utils";

    nixpkgs.url = "github:nixos/nixpkgs/release-24.11";

    project-manager = {
      url = "github:sellout/project-manager";
      ## It’s generally not helpful to set Project Manager’s nixpkgs to match
      ## your own. Project Manager distinguishes between the Nixpkgs it uses
      ## internally and the Nixpkgs used for your configuration. That allows
      ## Project Manager to support many different releases of Nixpkgs on a
      ## single develoment path.
      # inputs.nixpkgs.follows = "nixpkgs";
    };
  };
}
