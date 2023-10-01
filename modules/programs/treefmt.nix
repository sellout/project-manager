{
  config,
  lib,
  pkgs,
  treefmt-nix,
  ...
}: let
  cfg = config.programs.treefmt;
in {
  options.programs.treefmt = {
    enable = lib.mkEnableOption (lib.mdDoc "treefmt");

    package = lib.mkPackageOptionMD pkgs "treefmt" {
      default = ["treefmt"];
    };

    projectRootFile = lib.mkOption {
      type = lib.types.str;
      default = "flake.nix";
      description = lib.mdDoc ''
        The file to use to identify the root of the project for formatting.
      '';
    };

    programs = lib.mkOption {
      type = lib.types.attrs;
      default = {};
      description = lib.mdDoc ''
        Configuration for treefmt formatters. See
        https://github.com/numtide/treefmt-nix#configuration for details.
      '';
    };

    settings = lib.mkOption {
      type = lib.types.attrs;
      default = {};
      description = lib.mdDoc ''
        Settings for treefmt. See
        https://github.com/numtide/treefmt-nix#configuration for details.
      '';
    };
  };

  config = lib.mkIf cfg.enable (let
    newExcludes = lib.mapAttrsToList (k: v: v.target) (lib.filterAttrs (k: v: v.minimum-persistence == "repository") config.project.file);
    format = treefmt-nix.lib.evalModule pkgs {
      inherit (cfg) projectRootFile programs;
      settings =
        cfg.settings
        // {
          global =
            if cfg.settings ? global
            then
              cfg.settings.global
              // {
                excludes =
                  (
                    if cfg.settings.global ? excludes
                    then cfg.settings.global.excludes
                    else []
                  )
                  ++ newExcludes;
              }
            else {excludes = newExcludes;};
        };
    };
  in {
    project = {
      checkFunctions.formatter = format.config.build.check;
      formatter = format.config.build.wrapper;
      packages = [cfg.package];
    };
  });
}
