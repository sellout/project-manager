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
    enable = lib.mkEnableOption "GitHub";

    settings = lib.mkOption {
      description = ''
        Declarative GitHub settings, as provided by [Probot’s Settings
        app](https://probot.github.io/apps/settings/).
      '';
      type = lib.types.nullOr (lib.types.submodule {
        freeformType = lib.types.attrs;
        options = {
          branches = lib.mkOption {
            type = lib.types.attrsOf (lib.types.attrsOf lib.types.anything);
            default = {};
            description = ''
              Labels for issues & PRs.
            '';
          };
          labels = lib.mkOption {
            type = lib.types.attrsOf (lib.types.attrsOf lib.types.anything);
            default = {};
            description = ''
              Branch-specific settings.
            '';
          };
          repository = lib.mkOption {
            description = ''
              Settings that affect the entire repository.
            '';
            type = lib.types.submodule {
              freeformType = lib.types.anything;
              options.topics = lib.mkOption {
                default = [];
                type = lib.types.listOf lib.types.str;
                description = ''
                  A list of GitHub “topics”.
                '';
              };
            };
          };
        };
      });
      default = null;
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
    ## Have users provide a list of topics, then convert it into the comma-
    ## separated string expected by settings.yml.
    concatTopics = settings:
      if settings ? repository && settings.repository ? topics
      then
        settings
        // {
          repository =
            settings.repository
            // {topics = lib.concatStringsSep ", " settings.repository.topics;};
        }
      else settings;

    ## Coverts a structure like `{foo = {x = y;}; bar = {x = z;};}` to one like
    ## `[{name = "foo"; x = y;} {name = "bar"; x = z;}]`.
    attrsToNamedList = lib.mapAttrsToList (k: v:
      if v ? name
      then v
      else v // {name = k;});

    ## settings.yaml expects a list of branches, but that doesn’t have the most
    ## useful merge semantics. So we have an attrSet of branches, with the key
    ## being used as the name, if the name isn’t otherwise set.
    restructureBranches = settings:
      if settings ? branches
      then settings // {branches = attrsToNamedList settings.branches;}
      else settings;

    restructureLabels = settings:
      if settings ? labels
      then settings // {labels = attrsToNamedList settings.labels;}
      else settings;

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
        ".github/settings.yml" =
          lib.mkIf (cfg.settings != null)
          {
            text =
              lib.pm.generators.toYAML {}
              (restructureBranches (restructureLabels (concatTopics cfg.settings)));
          };
      }
      // cfg.workflow;
  });
}
