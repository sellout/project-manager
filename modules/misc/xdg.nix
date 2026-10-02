## This module implements a pseudo-XDG file-system layout. It’s XDG base
## directories, but using `$PROJECT_ROOT` instead of `$HOME`.
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

        We don’t put Project Manager-generated files here, but we point tools at
        this location for automatically-regenerated files. See
        `programs.direnv.layoutDir` for an example.
      '';
    };

    cacheFile = lib.mkOption {
      type = fileType "xdg.cacheFile" "{var}`xdg.cacheDir`" cfg.cacheDir;
      default = {};
      description = ''
        Attribute set of files to link into the project's XDG cache directory.

        This generally shouldn’t be used for generated files, because they won’t
        be automatically regenerated if deleted.
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

        This should be used whenever files that can be relocated need to be
        included in the worktree, as it reduces clutter. See the Git and Vale
        modules for examples.
      '';
    };

    stateDir = lib.mkOption {
      type = lib.types.str;
      default = ".local/state";
      description = ''
        Path to directory holding application states, relative to PROJECT_ROOT.

        Generated files generally don’t wind up here, because this is for files
        that are modified during development – logs, build artifacts, etc.
      '';
    };

    stateFile = lib.mkOption {
      type =
        fileType "xdg.stateFile" "<varname>xdg.stateDir</varname>" cfg.dataDir;
      default = {};
      description = ''
        Attribute set of files to link into the project's XDG
        state directory.

        This shouldn’t be used for generated files.
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
