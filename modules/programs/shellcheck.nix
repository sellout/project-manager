{
  config,
  lib,
  pkgs,
  pmPkgs,
  self,
  ...
}: let
  cfg = config.programs.shellcheck;

  directiveModule = lib.types.submodule {
    options = {
      disable = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        description = ''
          Prevent ShellCheck from processing one or more warnings. A
          hyphen-separated range of errors can also be specified, handy when
          disabling things for the entire file. An alias `all` is available
          instead of specifying 0-9999 to disable all checks.
        '';
      };

      enable = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        description = ''
          Enables an optional check (since 0.7.0). To see a list of optional
          checks with examples, run shellcheck --list-optional. See
          https://github.com/koalaman/shellcheck/wiki/optional for more
          information.
        '';
      };

      external-sources = lib.mkOption {
        type = lib.types.nullOr lib.types.bool;
        default = null;
        description = ''
          Set whether or not to follow arbitrary file paths in source statements.
        '';
      };

      source-path = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        description = ''
          Give ShellCheck a path in which to search for sourced files. The special
          value `source-path=SCRIPTDIR` will search in the current script's
          directory, and it can be used as a relative path like
          `source-path=SCRIPTDIR/../lib`. To support the common pattern of
          `. "$CONFIGDIR/mylib.sh"`, ShellCheck strips one leading, dynamic
          section before trying to locate the rest.
        '';
      };

      shell = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = ''
          Specify the shell for a script (similar to the shebang, if you for any
          reason don't want to add one).
        '';
      };
    };
  };
in {
  options.programs.shellcheck = {
    enable = lib.mkEnableOption "ShellCheck";

    package = lib.mkPackageOption pkgs "ShellCheck" {
      default = ["shellcheck"];
    };

    wrapProgram = lib.mkOption {
      type = lib.types.nullOr lib.types.bool;
      default = null;
      apply = p:
        if p == null
        then config.project.wrapPrograms
        else p;

      description = ''
        Whether to wrap the executable to work without a config file in the
        worktree or to produce the config file. If null, this falls back to
        {var}`config.project.wrapPrograms`.
      '';
    };

    directives = lib.mkOption {
      type = directiveModule;
      default = {};
      description = ''
        Shellcheck directives allow you to control how shellcheck works.
      '';
    };
  };

  config = lib.mkIf cfg.enable (let
    disabled = builtins.concatStringsSep "," cfg.directives.disable;
    enabled = builtins.concatStringsSep "," cfg.directives.enable;
    source-paths = builtins.concatStringsSep "," cfg.directives.source-path;

    wrapped =
      if cfg.wrapProgram
      then let
        flags = lib.concatStringsSep " " (builtins.concatLists [
          (
            if cfg.directives.disable == []
            then []
            else ["--exclude=${disabled}"]
          )
          (
            if cfg.directives.enable == []
            then []
            else ["--enable=${enabled}"]
          )
          (
            if cfg.directives.external-sources == null
            then []
            else ["--external-sources"]
          )
          (
            if cfg.directives.source-path == []
            then []
            else ["--source-path=${source-paths}"]
          )
          (
            if cfg.directives.shell == null
            then []
            else ["--shell=${cfg.directives.shell}"]
          )
        ]);
      in
        cfg.package.overrideAttrs (old: {
          # NB: This seems to get reset by `overrideAttrs`.
          inherit (old) meta;

          nativeBuildInputs = old.nativeBuildInputs ++ [pkgs.makeWrapper];

          ## NB: The shellcheck derivation doesn’t call any pre/post hooks.
          installPhase =
            old.installPhase
            + ''
              wrapProgram "$bin/bin/shellcheck" --add-flags "${flags}"
            '';
        })
      else cfg.package;
  in {
    project = {
      checks.shellcheck =
        pmPkgs.runStrictCommand "shellcheck" {
          nativeBuildInputs = [wrapped];
          src =
            config.project.cleanRepositoryPersistedExcept [".shellcheckrc"] self;
        } ''
          shellcheck "$src/project-manager/project-manager"
          mkdir -p "$out"
        '';

      file.".shellcheckrc" = lib.mkIf (!cfg.wrapProgram) {
        text = lib.concatLines (lib.concatLists [
          ["# This file was generated by Project Manager."]
          (
            if cfg.directives.disable == []
            then []
            else ["disable=${disabled}"]
          )
          (
            if cfg.directives.enable == []
            then []
            else ["enable=${enabled}"]
          )
          (
            if cfg.directives.external-sources == null
            then []
            else ["external-sources=${cfg.directives.external-sources}"]
          )
          (
            if cfg.directives.source-path == []
            then []
            else ["source-path=${source-paths}"]
          )
          (
            if cfg.directives.shell == null
            then []
            else ["shell=${cfg.directives.shell}"]
          )
        ]);
      };

      devPackages = [wrapped];
    };

    programs.treefmt.programs.shellcheck.package = wrapped;
  });
}
