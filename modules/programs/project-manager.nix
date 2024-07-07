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
          `null`, {file}`$PROJECT_ROOT/.config/nixpkgs/project-manager`
          will be attempted.
        '';
      };

      automaticallyExpireGenerations = mkOption {
        type = types.nullOr types.str;
        default = "now";
        example = "-30 days";
        description = lib.mdDoc ''
           If this is non-`null`, Project Manager will remove links to old
           generations during activation. This is akin to running
          `project-manager expire-generations {var}duration`. The default value
           is intended to leave no extra generations around, but a short value
           would allow for rollbacks. Be careful, though, as generations
           introduce GC roots, so it could result in a much larger Nix store.
        '';
      };
    };
  };

  config = mkIf cfg.enable {
    project.devPackages = [cfg.package];

    project.activation.automaticallyExpireGenerations =
      mkIf (cfg.automaticallyExpireGenerations != null)
      (pm.dag.entryAfter ["linkGeneration"] ''

        pm_expireGenerations ${lib.escapeShellArg cfg.automaticallyExpireGenerations}
      '');
  };
}
