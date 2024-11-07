{
  flake-utils,
  pkgsFor,
  self,
  treefmt-nix,
}: let
  project-manager = self;
in
  {
    self,
    modules ? [],
    pkgs,
    lib ? pkgs.lib,
    extraSpecialArgs ? {},
    check ? true,
    supportedSystems ? flake-utils.lib.defaultSystems,
  }:
    import ../../modules {
      inherit check extraSpecialArgs lib pkgs;
      configuration = {
        imports =
          modules
          ++ [
            {
              _module.args = {
                inherit
                  project-manager
                  self
                  supportedSystems
                  treefmt-nix
                  ;
                ## The pkgs used by Project Manager itself, also used in modules
                ## in certain cases.
                pmPkgs = pkgsFor pkgs.system;
              };
              programs.project-manager.path = toString ../.;
            }
          ];
      };
      modules = builtins.attrValues project-manager.projectModules;
    }
