{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.services.garnix;
in {
  meta.maintainers = [maintainers.sellout];

  options.services.garnix = {
    enable = mkEnableOption (lib.mdDoc "Garnix CI configuration");

    builds = mkOption {
      type = lib.types.nullOr (lib.types.attrsOf (lib.types.listOf lib.types.str));
      default = null;
      description = lib.mdDoc ''
        Configuration written to {file}`$PROJECT_ROOT/garnix.yaml`.
        See <https://garnix.io/docs/yaml_config> for documentation.
      '';
      example = lib.literalMD ''
        {
          exclude = ["homeConfigurations.*"];
          include = [
            "*.x86_64-linux.*"
            "packages.aarch64-darwin.*"
            "defaultPackage.x86_64-linux"
            "devShell.x86_64-linux"
          ];
        };
      '';
    };
  };

  config = mkIf (cfg.enable) {
    project.file."garnix.yaml".text = lib.pm.generators.toYAML {} {
      inherit (cfg) builds;
    };

    ## Can’t build un-sandboxed derivations on Garnix (see garnix-io/issues#33)
    services.garnix.builds.exclude =
      map
      (name: "checks.*.${name}")
      (builtins.attrNames config.project.unsandboxedChecks)
      ++ ["devShells.*.lax-checks"];
  };
}
