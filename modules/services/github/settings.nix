{
  config,
  lib,
  ...
}: let
  cfg = config.services.github;

  ## The Settings app’s documentation.
  appDocs = "https://github.com/repository-settings/app/blob/master/docs";

  pluginDocs = plugin: "${appDocs}/plugins/${plugin}.md";

  ## The app sends the `protection` records directly to GitHub, so these are the
  ## docs we need for that.
  protectedBranchDocs = "https://docs.github.com/en/rest/branches/branch-protection?apiVersion=2022-11-28#update-branch-protection";

  ## When the app supports more fields than what we’ve specified, this leaves
  ## the rest of the structure freeform.
  object = options:
    lib.types.submodule {
      freeformType = lib.types.anything;
      inherit options;
    };

  optional = type: attrs:
    lib.mkOption ({
        type = lib.types.nullOr type;
        default = null;
      }
      // attrs);

  namedRecords = lib.types.attrsOf (lib.types.attrsOf lib.types.anything);

  actorLists = let
    actors = subject:
      optional (lib.types.listOf lib.types.str) {
        description = "${subject} this applies to.";
      };
  in
    object {
      apps = actors "Slugs of the apps";
      teams = actors "Slugs of the teams";
      users = actors "Logins of the users";
    };

  pullRequestReviews = object {
    bypass_pull_request_allowances = optional actorLists {
      description = ''
        Who may merge without the reviews below.
      '';
    };
    dismiss_stale_reviews = optional lib.types.bool {
      description = ''
        Whether pushing a new commit withdraws the approvals the branch already
        has.
      '';
    };
    dismissal_restrictions = optional actorLists {
      description = ''
        Who may dismiss reviews.

        **NOTE**: Only an organization-owned repository can set this.
      '';
    };
    require_code_owner_reviews = optional lib.types.bool {
      description = ''
        Whether a code owner has to review any file they own.
      '';
    };
    require_last_push_approval = optional lib.types.bool {
      description = ''
        Whether the most recent push has to be approved by someone other than
        whoever pushed it.
      '';
    };
    required_approving_review_count = optional (lib.types.ints.between 0 6) {
      description = ''
        How many approvals a pull request needs. GitHub rejects anything above
        six.
      '';
    };
  };

  statusChecks = object {
    checks = lib.mkOption {
      type = lib.types.listOf (object {
        app_id = optional lib.types.int {
          description = ''
            The app the check has to come from. Unset lets GitHub infer it; `-1`
            takes the check from whichever app reports it.
          '';
        };
        context = lib.mkOption {
          type = lib.types.str;
          description = ''
            The name of the check.
          '';
        };
      });
      description = ''
        The checks that must pass, each naming the app it has to come from. An
        empty list requires none, and GitHub rejects a request that carries
        neither this nor `contexts`.

        **NOTE**: [GitHub’s reference](${protectedBranchDocs}) marks `contexts`
                  required, but accepts this instead – and a check without
                  `app_id` is exactly a `contexts` entry, so this can say
                  everything `contexts` can. `contexts` is therefore disallowed.
      '';
    };
    strict = lib.mkOption {
      type = lib.types.bool;
      description = ''
        Whether the branch has to be up to date with its base before merging.
      '';
    };
  };

  pushRestrictions = let
    ## Unlike everywhere else these three appear, GitHub insists on the users
    ## and the teams here – it answers ‘“teams”, “users” weren’t supplied’
    ## without them – so they’re sent as empty lists rather than left out.
    pushers = subject:
      lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        description = "${subject} that may push.";
      };
  in
    object {
      apps = optional (lib.types.listOf lib.types.str) {
        description = ''
          Slugs of the apps that may push.
        '';
      };
      teams = pushers "Slugs of the teams";
      users = pushers "Logins of the users";
    };

  ## NOTE: These four are declared rather than left to the freeform type because
  ##       GitHub requires them and so they need to be `null` instead of
  ##       omitted.
  ##
  ##     - https://github.com/repository-settings/app/blob/master/docs/plugins/branches.md
  ##     - https://docs.github.com/en/rest/branches/branch-protection?apiVersion=2022-11-28#update-branch-protection
  protection = object {
    enforce_admins = optional lib.types.bool {
      description = ''
        Whether the other restrictions also bind repository administrators.
      '';
    };
    required_pull_request_reviews = optional pullRequestReviews {
      description = ''
        Reviews that must be in place before merging.
      '';
    };
    required_status_checks = optional statusChecks {
      description = ''
        Checks that must pass before merging.
      '';
    };
    restrictions = optional pushRestrictions {
      description = ''
        Who may push to the branch.

        **NOTE**: Only an organization-owned repository can restrict pushes.
      '';
    };
  };

  branch = object {
    protection = optional protection {
      description = ''
        Branch protection, as [the app documents](${pluginDocs "branches"}), is
        passed directly to GitHub, so [GitHub’s docs](${protectedBranchDocs})
        are the ones that matter.

        - omitting the branch entirely leaves whatever protection GitHub
          currently has in place;
        - `null` _removes_ the branch’s protection;
        - `{}` enables protection without setting any values; and
        - anything else protects it as specified.

        **NOTE**: The app itself treats both `null` and `{}` as a removal, but
                  that doesn’t work here because of Nix’s merge semantics. We
                  don’t want a removal value to merge cleanly with a definition
                  like `protection.enforce_admins = true`, they should conflict
                  – as `null` does.

        Every setting other than the four above is optional, but “optional”
        doesn’t mean “preserved”: GitHub resets some to their defaults
        (`allow_force_pushes`) and leaves others alone
        (`required_conversation_resolution`). So specify every one you care
        about rather than relying on either behavior.
      '';
    };
  };
in {
  meta.maintainers = [lib.maintainers.sellout];

  options.services.github = {
    settings = lib.mkOption {
      description = ''
        Declarative GitHub settings, as provided by [Probot’s Settings
        app](https://probot.github.io/apps/settings/), whose [configuration
        reference](${appDocs}/configuration.md) documents each section.

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

        An unset section is also not the same as an empty one. An empty section
        (except `branches` and `repository`) interprets an empty section as
        “remove all entries from GitHub”, whereas unset means “don’t modify the
        entries currently on GitHub”.
      '';
      type = lib.types.nullOr (lib.types.submodule {
        options = {
          branches = lib.mkOption {
            type = lib.types.attrsOf branch;
            default = {};
            description = ''
              [Branch-specific settings](${pluginDocs "branches"}), keyed on
              `name`. This is the one section where an empty value means the
              same as an unset one – see `services.github.settings`.
            '';
          };
          collaborators = optional namedRecords {
            description = ''
              [Users with access to the
              repository](${pluginDocs "collaborators"}), keyed on `username`.
            '';
          };
          environments = optional namedRecords {
            description = ''
              [Deployment environments](${pluginDocs "environments"}), keyed on
              `name`. Note that `deployment_branch_policy` deliberately differs
              from the shape GitHub’s own API takes.
            '';
          };
          labels = optional namedRecords {
            description = ''
              [Labels for issues & PRs](${pluginDocs "labels"}). `null` omits
              the section, which isn’t the same as an empty one – see
              `services.github.settings`.
            '';
          };
          milestones = optional namedRecords {
            description = ''
              [Milestones](${pluginDocs "milestones"}), keyed on `title`.
            '';
          };
          repository = lib.mkOption {
            description = ''
              [Settings that affect the entire
              repository](${pluginDocs "repository"}).
            '';
            ## NOTE: Both this and any setting computed from it have to be
            ##       declared options. Reading a freeform-typed setting forces
            ##       the merge of every other setting in `repository`, so
            ##       computing one of them from another that way is an
            ##       infinite recursion.
            type = object {
              private = lib.mkOption {
                type = lib.types.bool;
                description = ''
                  Whether the repository is private. Deliberately has no default
                  – guessing wrong in either direction is harmful.
                '';
              };
              has_wiki = optional lib.types.bool {
                description = ''
                  Whether the repository has a wiki. `null` leaves whatever
                  GitHub currently has alone.
                '';
              };
              topics = lib.mkOption {
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
          rulesets = optional namedRecords {
            description = ''
              [Rulesets](${pluginDocs "rulesets"}), keyed on `name`.

              **NOTE**: The app’s support for these is still under development,
                        and it warns to expect breaking changes to the shape.
                        See
                        [repository-settings/app#732](https://github.com/repository-settings/app/issues/732).
            '';
          };
          teams = optional namedRecords {
            description = ''
              [Teams with access to the repository](${pluginDocs "teams"}),
              keyed on `name` – which the app matches against the team’s
              _slug_, not its display name.
            '';
          };
        };
      });
      default = null;
    };
  };

  config = lib.mkIf cfg.enable (let
    declared =
      if cfg.settings == null
      then {}
      else cfg.settings;

    dropUnset = lib.filterAttrs (_: v: v != null);

    sections = dropUnset declared;

    ## Private repositories on the free plan don’t have access to a number of
    ## features, so GitHub rejects any attempt to configure them.
    restricted = cfg.plan == "free" && declared.repository.private or false;

    branchesWhere = pred:
      lib.attrNames (lib.filterAttrs (_: v: pred v.protection) (sections.branches or {}));

    protectedBranches = branchesWhere (p: p != null);

    unprotectedBranches = branchesWhere (p: p == null);

    ## Check that `contexts` isn’t set in addition to `checks`.
    contextsBranches =
      branchesWhere
      (p: p != null && p.required_status_checks != null && p.required_status_checks ? contexts);

    unavailable = feature: consequence: "${feature} isn’t available in a private repository on the “free” plan, so ${consequence}. Either correct `services.github.plan` (if the owning account is on a paid plan) or stop setting it here.";

    ## GitHub rejects these outright, which – as explained on
    ## `services.github.settings` – can take other settings down with them.
    requiresPaidPlan = feature: what: {
      assertion = restricted -> ! what;
      message = unavailable feature "GitHub will reject the request";
    };

    ## A null `repository` setting means “leave it alone”, which is spelled by
    ## omitting it. Nulls elsewhere – branch protection especially – are
    ## meaningful to GitHub, so this is deliberately not applied globally.
    dropUnsetRepositorySettings = settings:
      if settings ? repository
      then settings // {repository = dropUnset settings.repository;}
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

    ## When converting a record to a list, we need to know the name of the field
    ## to map the key to..
    keyField = {
      branches = "name";
      collaborators = "username";
      environments = "name";
      labels = "name";
      milestones = "title";
      rulesets = "name";
      teams = "name";
    };

    ## Coverts a structure like `{foo = {x = y;}; bar = {x = z;};}` to one like
    ## `[{name = "foo"; x = y;} {name = "bar"; x = z;}]`.
    attrsToNamedList = key:
      lib.mapAttrsToList (k: v:
        if v ? ${key}
        then v
        else v // {${key} = k;});

    restructureSections =
      lib.mapAttrs
      (section: value:
        if keyField ? ${section}
        then attrsToNamedList keyField.${section} value
        else value);

    dropUnsetProtectionSettings = value:
      if lib.isAttrs value
      then lib.mapAttrs (_: dropUnsetProtectionSettings) (dropUnset value)
      else if lib.isList value
      then map dropUnsetProtectionSettings value
      else value;

    dropUnsetProtection = settings:
      settings
      // {
        branches =
          lib.mapAttrs
          (_: branch:
            branch
            // lib.optionalAttrs (branch.protection != null) {
              protection = lib.mapAttrs (_: dropUnsetProtectionSettings) branch.protection;
            })
          settings.branches;
      };
  in {
    warnings =
      lib.optional (restricted && (declared.repository.has_wiki or null) == true)
      (unavailable
        "`services.github.settings.repository.has_wiki`"
        "GitHub will accept the request and silently ignore the field, leaving this permanently out of step with the repository")
      ++ map
      (branch: "`services.github.settings.branches.${branch}.protection` is null, which _removes_ whatever protection `${branch}` currently has. If you meant to leave it alone, drop the branch.")
      unprotectedBranches;

    assertions =
      [
        (requiresPaidPlan
          "branch protection (`services.github.settings.branches.*.protection`, set on ${lib.concatStringsSep ", " protectedBranches})"
          (protectedBranches != []))
        (requiresPaidPlan
          "`services.github.settings.rulesets`"
          (sections ? rulesets))
        (requiresPaidPlan
          "`services.github.settings.environments`"
          (sections ? environments))
      ]
      ++ map
      (branch: {
        assertion = false;
        message = "`services.github.settings.branches.${branch}.protection.required_status_checks.contexts` is set. Use `checks`: GitHub is deprecating `contexts`, and a check without `app_id` is the same.";
      })
      contextsBranches;

    programs.vale.excludes = let
      file = config.project.file.".github/settings.yml";
    in
      lib.optional
      (cfg.settings != null && file.in-worktree)
      "./${file.target}";

    project.file.".github/settings.yml" =
      lib.mkIf (cfg.settings != null)
      {
        text =
          lib.pm.generators.toYAML {}
          (restructureSections
            (dropUnsetProtection (concatTopics (dropUnsetRepositorySettings sections))));
      };
  });
}
