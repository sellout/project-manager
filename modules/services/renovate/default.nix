{
  config,
  lib,
  ...
}: let
  cfg = config.services.renovate;
in {
  meta.maintainers = [lib.maintainers.sellout];

  options.services.renovate = {
    enable = lib.mkEnableOption "Renovate";

    settings = lib.mkOption {
      type = lib.types.attrsOf lib.types.anything;
      default = {};
      description = ''
        Configuration written to {file}`$PROJECT_ROOT/renovate.json`.
        See <https://docs.renovatebot.com/> for documentation.
      '';
    };
  };

  config = lib.mkIf cfg.enable (let
    ## Renovate looks in multiple places for the configuration, so, when
    ## possible, we hide it in a directory that will already exist.
    location =
      if config.services.github.enable
      then ".github"
      else ".";
  in {
    programs.vale.excludes = let
      file = config.project.file."${location}/renovate.json";
    in
      lib.optional file.in-worktree "./${file.target}";

    project.file."${location}/renovate.json".text = lib.pm.generators.toJSON {} ({
        "$schema" = "https://docs.renovatebot.com/renovate-schema.json";
        extends = ["config:recommended"];
        nix.enabled = true;
      }
      // cfg.settings);
  });
}
