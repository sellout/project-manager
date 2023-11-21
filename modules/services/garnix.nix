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
          "*" = {
            charset = "utf-8";
            end_of_line = "lf";
            trim_trailing_whitespace = true;
            insert_final_newline = true;
            max_line_width = 78;
            indent_style = "space";
            indent_size = 4;
          };
        };
      '';
    };
  };

  config = mkIf (cfg.enable) {
    project.file."garnix.yaml".text = lib.pm.generators.toYAML {} {
      inherit (cfg) builds;
    };
  };
}
