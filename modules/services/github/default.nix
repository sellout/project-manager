{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.github;

  projectDirectory = config.project.projectDirectory;

  fileType =
    (import ../../lib/file-type.nix {
      inherit projectDirectory lib pkgs;
      commit-by-default = config.project.commit-by-default;
    })
    .fileType;
in {
  meta.maintainers = [lib.maintainers.sellout];

  options.services.github = {
    enable = lib.mkEnableOption "GitHub";

    plan = lib.mkOption {
      type = lib.types.enum ["free" "pro" "team" "enterprise"];
      default = "free";
      description = ''
        The GitHub plan of the account that owns this repository. A number of
        features are unavailable to _private_ repositories on the “free” plan.
        GitHub either rejects the attempt to configure them – which, as
        explained on `services.github.settings`, can take out other settings
        that would otherwise have applied – or returns success and silently
        ignores the field, leaving the declared configuration permanently out of
        step with reality. `has_wiki` is the latter; branch protection is the
        former.

        This allows them to be caught at build time instead.
      '';
    };

    runners.latest = lib.mkOption {
      description = ''
        Encodes the latest runners as specified by
        https://docs.github.com/en/actions/reference/runners/github-hosted-runners#standard-github-hosted-runners-for-public-repositories.
        This is meant to be a static version of those, so you don’t get breakage
        in PRs that don’t explicitly update the Project Manager version.
      '';
      readOnly = true;
      default = {
        linux-x64 = "ubuntu-26.04";
        windows-x64 = "windows-2025";
        linux-arm64 = "ubuntu-26.04-arm";
        windows-arm64 = "windows-11-arm";
        macos-intel = "macos-26-intel";
        macos-arm64 = "macos-26";
      };
    };

    workflow = lib.mkOption {
      description = ''
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
        lib.mapAttrs'
        (_: v: {
          name = "/" + v.target;
          value.linguist-generated = true;
        })
        generatedAndCommitted;
    };

    project.file =
      {
        ## This should always have at least one `linguist-generated` entry (for
        ## .gitattributes itself), so we always commit.
        ".gitattributes".commit-by-default = true;
      }
      // cfg.workflow;
  });
}
