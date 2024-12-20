{
  config,
  lib,
  pkgs,
  pmPkgs,
  self,
  treefmt-nix,
  ...
}: let
  cfg = config.programs.treefmt;
in {
  options.programs.treefmt = {
    enable = lib.mkEnableOption "treefmt";

    package = lib.mkPackageOption pkgs "treefmt" {};

    projectRootFile = lib.mkOption {
      type = lib.types.str;
      default = "flake.nix";
      description = ''
        The file to use to identify the root of the project for formatting.
      '';
    };

    programs = lib.mkOption {
      type = lib.types.attrsOf lib.types.attrs;
      default = {};
      description = ''
        Configuration for treefmt formatters. See
        https://github.com/numtide/treefmt-nix#configuration for details.
      '';
    };

    settings = lib.mkOption {
      type = lib.types.attrsOf lib.types.attrs;
      default = {};
      description = ''
        Settings for treefmt. See
        https://github.com/numtide/treefmt-nix#configuration for details.
      '';
    };
  };

  config = lib.mkIf cfg.enable (let
    newExcludes = lib.mapAttrsToList (k: v: v.target) (lib.filterAttrs (k: v: v.persistence == "repository") config.project.file);
    format = treefmt-nix.lib.evalModule pmPkgs {
      inherit (cfg) package projectRootFile programs;
      settings =
        cfg.settings
        // {
          global.excludes =
            (cfg.settings.global.excludes or []) ++ newExcludes;
        };
    };
  in {
    project = {
      checks.formatter = format.config.build.check self;
      formatter = format.config.build.wrapper;
      devPackages = [format.config.build.wrapper];
    };
  });
}
