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

    locked = lib.mkOption {
      type = lib.types.bool;
      default = false;
      example = true;
      description = ''
        Don't attempt to update the lockfile.
      '';
    };

    packageFun = lib.mkOption {
      type = lib.types.package;
      readOnly = true;
      description = ''
        A package containing the Cargo.nix file. This is used to reference the
        generated file in the flake.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    ## TODO: Use real persistence settings for this file, but for now, just
    ##       treat it as `worktree`.
    programs.cargo2nix.packageFun = let
      options =
        lib.optionals (cfg.completions != null)
        ["--completions" (lib.escapeShellArg cfg.completions)]
        ++ ["--file" "$out"]
        ++ lib.optional cfg.locked "--locked"
        ++ lib.optional (cfg.workspaceDirectory != null)
        (lib.escapeShellArg cfg.workspaceDirectory);
    in
      pkgs.runCommand "Cargo.nix" {} ''
        ${lib.getExe cfg.package} ${lib.concatStringsSep " " options}
      '';

    project.devPackages = [cfg.package];
  };
}
