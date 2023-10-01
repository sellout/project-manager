{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.github;

  projectDirectory = config.project.projectDirectory;

  fileType =
    (import ../lib/file-type.nix {
      inherit projectDirectory lib pkgs;
      commit-by-default = config.project.commit-by-default;
    })
    .fileType;
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

    workflow = lib.mkOption {
      description = lib.mdDoc ''
        Attribute set of GitHub workflows.
      '';
      default = {};
      type =
        fileType
        "services.github.workflow"
        ""
        (projectDirectory + "/.github/workflows");
    };
  };

  config = lib.mkIf cfg.enable (let
    generatedAndCommitted =
      lib.filterAttrs (n: v: v.persistence == "repository") config.project.file;
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

    project.file =
      {
        ## This should always have at least one `linguist-generated` entry (for
        ## .gitattributes itself), so we always commit.
        ".gitattributes".commit-by-default = true;
        ".github/settings.yml".text =
          lib.mkIf (cfg.settings != {})
          (lib.generators.toYAML {} cfg.settings);
      }
      // cfg.workflow;
  });
}
