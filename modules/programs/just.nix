{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.programs.just;

  projectDirectory = config.project.projectDirectory;

  fileContents =
    (import ../lib/file-type.nix {
      inherit projectDirectory lib pkgs;
      commit-by-default = config.project.commit-by-default;
    })
    .fileContents;
in {
  options.programs.just = {
    enable = lib.mkEnableOption (lib.mdDoc "just (https://github.com/casey/just)");

    package = lib.mkPackageOptionMD pkgs "just" {};

    wrapProgram = lib.mkOption {
      type = lib.types.nullOr lib.types.bool;
      default = null;
      apply = p:
        if p == null
        then config.project.wrapPrograms
        else p;

      description = lib.mdDoc ''
        Whether to wrap the executable to work without a config file in the
        worktree or to produce the config file. If null, this falls back to
        {var}`config.project.wrapPrograms`.
      '';
    };

    recipes = lib.mkOption {
      type = fileContents "programs.just" "" projectDirectory "recipes";
      description = ''
        The justfile.
      '';
    };
  };

  config = lib.mkIf cfg.enable (let
    wrapped =
      if cfg.wrapProgram
      then let
        flags = [
          "--justfile '${config.project.file."justfile".storePath}'"
          "--working-directory '${config.project.projectDirectory}'"
        ];
      in
        cfg.package.overrideAttrs (old: {
          nativeBuildInputs = old.nativeBuildInputs ++ [pkgs.makeWrapper];

          postInstall =
            old.postInstall
            + ''
              wrapProgram "$out/bin/just" \
                --add-flags "${lib.concatStringsSep " " flags}"
            '';
        })
      else cfg.package;
  in {
    project = {
      file."justfile" =
        cfg.recipes
        // {
          minimum-persistence = lib.mkIf cfg.wrapProgram "store";
          target = "justfile";
        };

      packages = [wrapped];
    };
  });
}
