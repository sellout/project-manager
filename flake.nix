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
      ## This output’s schema may be in flux. See NixOS/nix#8892.
      schemas = inputs.flake-schemas.schemas // import ./nix/schemas.nix;

      lib = import ./nix/lib.nix {
        inherit (inputs) bash-strict-mode self treefmt-nix;
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
    in {
      packages = let
        releaseInfo = import ./release.nix;
        docs = import ./docs {
          inherit pkgs;
          inherit (releaseInfo) release isReleaseBranch;
        };
      in {
        default = inputs.self.packages.${system}.project-manager;
        docs-html = docs.manual.html;
        docs-json = docs.options.json;
        docs-manpages = docs.manPages;
        project-manager = pkgs.callPackage ./project-manager {};
      };

      devShells.default = inputs.self.projectConfigurations.${system}.devShell;

      # devShells = let
      #   pkgs = inputs.nixpkgs.legacyPackages.${system};
      #   tests = import ./tests {inherit pkgs;};
      # in
      #   tests.run;

      projectConfigurations =
        inputs.self.lib.defaultConfiguration ./. {inherit pkgs;};

      checks = inputs.self.projectConfigurations.${system}.checks inputs.self;

      formatter = inputs.self.projectConfigurations.${system}.formatter;
    });

  inputs = {
    bash-strict-mode = {
      inputs = {
        flake-utils.follows = "flake-utils";
        nixpkgs.follows = "nixpkgs";
      };
      url = "github:sellout/bash-strict-mode";
    };

    flake-schemas.url = "github:DeterminateSystems/flake-schemas/support-nixos-modules";

    flake-utils.url = "github:numtide/flake-utils";

    nixpkgs.url = "github:NixOS/nixpkgs/release-23.05";

    treefmt-nix = {
      inputs.nixpkgs.follows = "nixpkgs";
      url = "github:numtide/treefmt-nix";
    };
  };
}
