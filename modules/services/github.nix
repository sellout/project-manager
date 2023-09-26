{
  config,
  lib,
  ...
}: let
  cfg = config.services.github;
in {
  meta.maintainers = [lib.maintainers.sellout];

  options.services.github = {
    enable = lib.mkEnableOption (lib.mdDoc "GitHub");

    settings = lib.mkOption {
      description = lib.mdDoc ''
        Declarative GitHub settings, as provided by [Probot’s Settings
        app](https://probot.github.io/apps/settings/).
      '';
      type = lib.types.attrs;
      default = {};
    };
  };

  config = lib.mkIf cfg.enable (let
    persistence = v:
      if
        (
          if v.commit-by-default == null
          then config.project.commit-by-default
          else v.commit-by-default
        )
      then "repository"
      else v.minimum-persistence;
    generatedAndCommitted =
      lib.filterAttrs (n: v: persistence v == "repository") config.project.file;
  in {
    programs.git = {
      ## TODO: This probably isn’t right – just because the user users git
      ##       doesn’t mean they want it managed by Nix – but we _do_ want to
      ##       manage .gitattributes here. Maybe we can just cause the text to
      ##       be appended?
      enable = true;

      attributes =
        lib.mapAttrsToList (n: v: "/" + v.target + " linguist-generated")
        generatedAndCommitted;
    };

    project.file = {
      ## This should always have at least one `linguist-generated` entry (for
      ## .gitattributes itself), so we always commit.
      ".gitattributes".commit-by-default = true;
      ".github/settings.yml".text =
        lib.mkIf (cfg.settings != {})
        (lib.generators.toYAML {} cfg.settings);
    };
  });
}
