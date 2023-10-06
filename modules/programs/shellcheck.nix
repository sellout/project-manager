{
  bash-strict-mode,
  config,
  lib,
  pkgs,
  self,
  ...
}: let
  cfg = config.programs.shellcheck;

  projectDirectory = config.project.projectDirectory;

  fileContents =
    (import ../lib/file-type.nix {
      inherit projectDirectory lib pkgs;
      commit-by-default = config.project.commit-by-default;
    })
    .fileContents;
in {
  options.programs.shellcheck = {
    enable = lib.mkEnableOption (lib.mdDoc "ShellCheck");

    package = lib.mkPackageOptionMD pkgs "ShellCheck" {
      default = ["shellcheck"];
    };

    settings = lib.mkOption {
      type = fileContents "programs.shellcheck" "" projectDirectory "settings";
      description = lib.mdDoc ''
        The .shellcheckrc file. The `target` is ignored.
      '';
    };
  };

  config = lib.mkIf cfg.enable (let
    wrapped = cfg.package.overrideAttrs (old: {
      ## TODO: Extract out the bit that manages all the
      ##       (sym)linking/copying, so we can use it consistently.
      postBuild = ''
        wrapProgram shellcheck \
          --run "trap \"rm ${config.project.file.".shellcheckrc".target}\"" EXIT
          --run "cp ${config.project.file.".shellcheckrc".source}" ${config.project.file.".shellcheckrc".target}"
      '';
    });
  in {
    project = {
      checks.shellcheck = bash-strict-mode.lib.checkedDrv pkgs (pkgs.runCommand "shellcheck" {
          nativeBuildInputs = [wrapped];
          src = config.project.cleanRepositoryPersisted self;
        }
        ''
          ${wrapped}/bin/shellcheck "$src/project-manager/project-manager"
          mkdir -p "$out"
        '');

      file.".shellcheckrc" =
        cfg.settings
        // {
          target = ".shellcheckrc";
          # minimum-persistence = "store";
        };

      packages = [cfg.package]; # [wrapped];
    };
  });
}
