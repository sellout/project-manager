{
  bash-strict-mode,
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.programs.project-manager;
in {
  meta.maintainers = [maintainers.sellout];

  options = {
    programs.project-manager = {
      enable = mkEnableOption (lib.mdDoc "Project Manager");

      package = mkOption {
        type = types.package;
        default = pkgs.callPackage ../../project-manager {
          inherit (bash-strict-mode.packages.${pkgs.system}) bash-strict-mode;
        };
        description = lib.mdDoc ''
          The current Package Manager package.
        '';
      };

      path = mkOption {
        type = types.nullOr types.str;
        default = null;
        example = "$PROJECT_ROOT/devel/project-manager";
        description = lib.mdDoc ''
          The default path to use for Project Manager. When
          `null`, then the {file}`project-manager`
          channel and {file}`$PROJECT_ROOT/.config/nixpkgs/project-manager`
          will be attempted.
        '';
      };
    };
  };

  config = mkIf cfg.enable {
    project.devPackages = [config.programs.project-manager.package];
  };
}
