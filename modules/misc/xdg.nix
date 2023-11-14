{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.xdg;

  fileType =
    (import ../lib/file-type.nix {
      inherit lib pkgs;
      inherit (config.project) commit-by-default projectDirectory;
    })
    .fileType;
in {
  meta.maintainers = [lib.maintainers.sellout];

  options.xdg = {
    cacheDir = lib.mkOption {
      type = lib.types.str;
      default = ".cache";
      description = ''
        Path to directory holding application caches, relative to PROJECT_ROOT.
      '';
    };

    ## TODO: Maybe add a project option as to whether non-store persisted files
    ##       should be placed in `xdg.cacheDir` when possible. Otherwise it
    ##       would default to their standard locations. But we then need to be
    ##       able to indicate in `fileType` whether a file is relocatable, and
    ##       make sure the target & store paths are kept up-to-date.
    cacheFile = lib.mkOption {
      type = fileType "xdg.cacheFile" "{var}`xdg.cacheDir`" cfg.cacheDir;
      default = {};
      description = ''
        Attribute set of files to link into the project's XDG
        cache directory.

        This should be used whenever files need to be included in the worktree,
        but we can control where they are located. It removes clutter from the
        worktree.
      '';
    };

    configDir = lib.mkOption {
      type = lib.types.str;
      default = ".config";
      description = ''
        Path to directory holding application configurations, relative to
        PROJECT_ROOT.
      '';
    };

    configFile = lib.mkOption {
      type = fileType "xdg.configFile" "{var}`xdg.configDir`" cfg.configDir;
      default = {};
      description = ''
        Attribute set of files to link into the project's XDG
        configuration directory.
      '';
    };

    dataDir = lib.mkOption {
      type = lib.types.str;
      default = ".local/share";
      description = ''
        Path to directory holding application data, relative to PROJECT_ROOT.
      '';
    };

    dataFile = lib.mkOption {
      type =
        fileType "xdg.dataFile" "<varname>xdg.dataDir</varname>" cfg.dataDir;
      default = {};
      description = ''
        Attribute set of files to link into the project's XDG
        data directory.
      '';
    };

    stateDir = lib.mkOption {
      type = lib.types.str;
      default = ".local/state";
      description = ''
        Path to directory holding application states, relative to PROJECT_ROOT.
      '';
    };
  };

  config = {
    project.file = lib.mkMerge [
      (lib.mapAttrs'
        (name: file: lib.nameValuePair "${cfg.cacheDir}/${name}" file)
        cfg.cacheFile)
      (lib.mapAttrs'
        (name: file: lib.nameValuePair "${cfg.configDir}/${name}" file)
        cfg.configFile)
      (lib.mapAttrs'
        (name: file: lib.nameValuePair "${cfg.dataDir}/${name}" file)
        cfg.dataFile)
    ];
  };
}
