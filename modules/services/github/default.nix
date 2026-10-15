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

    settings = lib.mkOption {
      description = ''
        Declarative GitHub settings, as provided by [Probot’s Settings
        app](https://probot.github.io/apps/settings/).

        The app gives no feedback when GitHub rejects something, so it’s easy to
        end up with a partially-applied configuration. Knowing its request
        ordering can help determine where a bug in the config may be.

        - every section other than `branches` is applied concurrently, so the
          order they appear in doesn’t matter, and a failure in one can’t
          prevent another from being attempted;

        - the `repository` section is applied sequentially – first most of the
          settings are applied together, then `topics`, `vulnerability-alerts`,
          and finally `automated-security-fixes` – so a failure at any of those
          skips the ones after it; and

        - `branches` is applied only once every other section has succeeded, so
          _any_ failure elsewhere means branch protection is never requested at
          all.

        Consequently, a single field GitHub won’t accept in `repository` can
        silently take out the topics, the security settings, _and_ all of the
        branch protection. See `lib/settings.js` and `lib/plugins/repository.js`
        in [the app](https://github.com/repository-settings/app) for the
        implementation.
      '';
      type = lib.types.nullOr (lib.types.submodule {
        freeformType = lib.types.attrs;
        options = {
          branches = lib.mkOption {
            type = lib.types.attrsOf (lib.types.attrsOf lib.types.anything);
            default = {};
            description = ''
              Branch-specific settings.
            '';
          };
          labels = lib.mkOption {
            type = lib.types.attrsOf (lib.types.attrsOf lib.types.anything);
            default = {};
            description = ''
              Labels for issues & PRs.
            '';
          };
          repository = lib.mkOption {
            description = ''
              Settings that affect the entire repository.
            '';
            type = lib.types.submodule {
              freeformType = lib.types.anything;

              ## NOTE: Both this and any setting computed from it have to be
              ##       declared options. Reading a freeform-typed setting forces
              ##       the merge of every other setting in `repository`, so
              ##       computing one of them from another that way is an
              ##       infinite recursion.
              options.private = lib.mkOption {
                type = lib.types.bool;
                description = ''
                  Whether the repository is private. Deliberately has no default
                  – guessing wrong in either direction is harmful.
                '';
              };
              options.has_wiki = lib.mkOption {
                type = lib.types.nullOr lib.types.bool;
                default = null;
                description = ''
                  Whether the repository has a wiki. `null` leaves whatever
                  GitHub currently has alone.
                '';
              };
              options.topics = lib.mkOption {
                default = [];
                type = lib.types.listOf lib.types.str;
                description = ''
                  A list of GitHub “topics”.

                  **NOTE**: An empty list leaves any existing topics in place
                            rather than removing them, since the app skips the
                            request when the generated value is empty.
                '';
              };
            };
          };
        };
      });
      default = null;
    };

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
    declared =
      if cfg.settings == null
      then {}
      else cfg.settings;

    ## Private repositories on the free plan don’t have access to a number of
    ## features, so GitHub rejects any attempt to configure them.
    restricted = cfg.plan == "free" && declared.repository.private or false;

    protectedBranches =
      lib.attrNames
      (lib.filterAttrs (_: v: v ? protection) (declared.branches or {}));

    unavailable = feature: consequence: "${feature} isn’t available in a private repository on the “free” plan, so ${consequence}. Either correct ‘services.github.plan’ (if the owning account is on a paid plan) or stop setting it here.";

    ## GitHub rejects these outright, which – as explained on
    ## ‘services.github.settings’ – can take other settings down with them.
    requiresPaidPlan = feature: what: {
      assertion = restricted -> ! what;
      message = unavailable feature "GitHub will reject the request";
    };

    ## A null `repository` setting means “leave it alone”, which is spelled by
    ## omitting it. Nulls elsewhere – branch protection especially – are
    ## meaningful to GitHub, so this is deliberately not applied globally.
    dropUnsetRepositorySettings = settings:
      if settings ? repository
      then
        settings
        // {
          repository = lib.filterAttrs (_: v: v != null) settings.repository;
        }
      else settings;

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
    warnings =
      lib.optional (restricted && (declared.repository.has_wiki or null) == true)
      (unavailable
        "‘services.github.settings.repository.has_wiki’"
        "GitHub will accept the request and silently ignore the field, leaving this permanently out of step with the repository");

    assertions = [
      (requiresPaidPlan
        "branch protection (‘services.github.settings.branches.*.protection’, set on ${lib.concatStringsSep ", " protectedBranches})"
        (protectedBranches != []))
      (requiresPaidPlan
        "‘services.github.settings.rulesets’"
        (declared ? rulesets))
      (requiresPaidPlan
        "‘services.github.settings.environments’"
        (declared ? environments))
    ];

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
              (restructureBranches (restructureLabels
                  (concatTopics (dropUnsetRepositorySettings cfg.settings))));
          };
      }
      // cfg.workflow;
  });
}
