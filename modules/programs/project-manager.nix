{ config, lib, pkgs, ... }:

with lib;

let

  cfg = config.programs.project-manager;

in {
  meta.maintainers = [ maintainers.sellout ];

  options = {
    programs.project-manager = {
      enable = mkEnableOption "Project Manager";

      path = mkOption {
        type = types.nullOr types.str;
        default = null;
        example = "$PROJECT_ROOT/devel/project-manager";
        description = ''
          The default path to use for Project Manager. When
          `null`, then the {file}`project-manager`
          channel and {file}`$PROJECT_ROOT/.config/nixpkgs/project-manager`
          will be attempted.
        '';
      };
    };
  };

  config = mkIf (cfg.enable && !config.submoduleSupport.enable) {
    project.packages =
      [ (pkgs.callPackage ../../project-manager { inherit (cfg) path; }) ];
  };
}
