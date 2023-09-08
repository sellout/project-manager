{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.programs.direnv;

  projectDirectory = config.project.projectDirectory;

  fileContents =
    (import ../lib/file-type.nix {
      inherit projectDirectory lib pkgs;
    })
    .fileContents;
in {
  meta.maintainers = [maintainers.sellout];

  options.programs.direnv = {
    enable = mkEnableOption "direnv, the environment switcher";

    auto-allow = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Whether running project-manager will implicitly run `direnv allow` for
        the user.
      '';
    };

    commit-envrc = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Whether .envrc should be committed to the repo or only available
        locally. If this is false, then users will have to run `project-manager`
        before direnv will work.
      '';
    };

    envrc = mkOption {
      type = fileContents "programs.direnv.envrc" "" projectDirectory;
      description = ''
        The .envrc file. The `target` is ignored.
      '';
    };
  };

  config = mkIf cfg.enable {
    # project.packages = [ pkgs.direnv ];

    programs.git.ignores = ["/.direnv/"];
    programs.mercurial.ignoresRooted = [".direnv/**"];

    project = {
      activation.direnv = mkIf cfg.auto-allow (pm.dag.entryAfter ["onFilesChange"] ''
        ${pkgs.direnv}/bin/direnv allow
      '');

      file.".envrc" =
        cfg.envrc
        // {
          target = ".envrc";
          minimum-persistence = "worktree";
          ## See direnv/direnv#1160.
          broken-symlink = true;
          commit-by-default = cfg.commit-envrc;
        };
    };
  };
}
