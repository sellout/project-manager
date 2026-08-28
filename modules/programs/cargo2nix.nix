{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.programs.cargo2nix;
in {
  options.programs.cargo2nix = {
    enable =
      lib.mkEnableOption
      "[cargo2nix](https://github.com/cargo2nix/cargo2nix#readme)";

    package = lib.mkPackageOption pkgs "cargo2nix" {};

    workspaceDirectory = lib.mkOption {
      type = lib.types.nullOr (lib.types.pathWith {});
      default = null;
      example = "./rust";
      description = ''
        Optional workspace directory (default value: ./).
      '';
    };

    completions = lib.mkOption {
      type =
        lib.types.nullOr
        (lib.types.enum ["bash" "elvish" "fish" "powershell" "zsh"]);
      default = null;
      example = "bash";
      description = ''
        Generate a completion script for the specified shell.

        __TODO__: Determine if this option can be specified multiple times, in
                  which case this should be a set of the enum.
      '';
    };

    file = lib.mkOption {
      type =
        lib.types.nullOr (lib.types.pathWith {});
      default = null;
      example = "./nix/Cargo.nix";
      description = ''
        Output to filepath (the default is ./Cargo.nix).
      '';
    };

    overwrite = lib.mkOption {
      type = lib.types.bool;
      default = false;
      example = true;
      description = ''
        Overwrite existing output filepath without prompting.

        __TODO__: If the persistence of this file is `repository`, then this
                 _must_ be true, as the file will always exist.
      '';
    };

    locked = lib.mkOption {
      type = lib.types.bool;
      default = false;
      example = true;
      description = ''
        Don't attempt to update the lockfile.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    ## TODO: Use real persistence settings for this file, but for now, just
    ##       treat it as `worktree`.
    programs = let
      cargoNix =
        if cfg.file != null
        then cfg.file
        else "./Cargo.nix";
    in {
      git.ignores = [cargoNix];
      treefmt.settings.global.excludes = [cargoNix];
    };

    project.devPackages = [cfg.package];

    ## TODO: Rather than generating a file directly into the tree, generate to
    ##       the Nix store and symlink or copy via `project.file`.
    project.activation.cargo2nix =
      ## This ensures that any Cargo.lock file produced by cargo will be in
      ## place when cargo2nix wants to generate its Nix files.
      lib.pm.dag.entryAfter ["writeBoundary" "cargo-generate-lockfile"] (let
        options =
          lib.optionals (cfg.completions != null)
          ["--completions" (lib.escapeShellArg cfg.completions)]
          ++ lib.optionals (cfg.file != null)
          ["--file" (lib.escapeShellArg cfg.file)]
          ++ lib.optional cfg.overwrite "--overwrite"
          ++ lib.optional cfg.locked "--locked"
          ++ lib.optional (cfg.file == false) "--stdout"
          ++ lib.optional (cfg.workspaceDirectory != null)
          (lib.escapeShellArg cfg.workspaceDirectory);
      in ''
        ${
          if cfg.file != null
          then "mkdir -p $(dirname ${lib.escapeShellArg cfg.file})"
          else ""
        }
        ${lib.getExe cfg.package} ${lib.concatStringsSep " " options}
      '');
  };
}
