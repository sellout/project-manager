{
  config,
  lib,
  ...
}: let
  cfg = config.services.renovate;
in {
  meta.maintainers = [lib.maintainers.sellout];

  options.services.renovate = {
    enable = lib.mkEnableOption (lib.mdDoc "Renovate");

    settings = lib.mkOption {
      type = lib.types.attrs;
      default = {};
      description = lib.mdDoc ''
        Configuration written to {file}`$PROJECT_ROOT/renovate.json`.
        See <https://docs.renovatebot.com/> for documentation.
      '';
    };
  };

  config = lib.mkIf (cfg.enable) {
    project.file."renovate.json".text = lib.generators.toJSON {} ({
        "$schema" = "https://docs.renovatebot.com/renovate-schema.json";
        extends = ["config:base"];
        nix.enabled = true;
      }
      // cfg.settings);
  };
}
