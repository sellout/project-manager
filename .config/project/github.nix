{
  config,
  lib,
  ...
}: {
  services.github = {
    enable = true;

    settings = {
      # These settings are synced to GitHub by https://probot.github.io/apps/settings/

      # See https://docs.github.com/en/rest/reference/repos#update-a-repository for all available settings.
      repository = {
        name = config.project.name;
        description = config.project.summary;
        homepage = "https://sellout.github.io/${config.project.name}";
        topics = ["development" "hacktoberfest" "nix-flakes"];
        private = false;
        has_issues = true;
        has_projects = false;
        has_wiki = true;
        has_downloads = false;
        default_branch = "main";
        allow_squash_merge = false;
        allow_merge_commit = true;
        allow_rebase_merge = false;
        delete_branch_on_merge = true;
        merge_commit_title = "PR_TITLE";
        merge_commit_message = "PR_BODY";
        enable_automated_security_fixes = true;
        enable_vulnerability_alerts = true;
      };

      labels = [
        {
          name = "bug";
          color = "#d73a4a";
          description = "Something isn’t working";
        }
        {
          name = "documentation";
          color = "#0075ca";
          description = "Improvements or additions to documentation";
        }
        {
          name = "enhancement";
          color = "#a2eeef";
          description = "New feature or request";
        }
        {
          name = "good first issue";
          color = "#7057ff";
          description = "Good for newcomers";
        }
        {
          name = "hacktoberfest-accepted";
          color = "#ff7518"; # pumpkin
          description = "Indicates acceptance for Hacktoberfest criteria, even if not merged yet";
        }
        {
          name = "help wanted";
          color = "#008672";
          description = "Extra attention is needed";
        }
        {
          name = "question";
          color = "#d876e3";
          description = "Further information is requested";
        }
        {
          name = "spam";
          color = "#ffc0cb"; #pink
          description = "Topic created in bad faith. Services like Hacktoberfest use this to identify bad actors.";
        }
      ];

      branches = {
        main = {
          # https://docs.github.com/en/rest/branches/branch-protection?apiVersion=2022-11-28#update-branch-protection
          protection = {
            required_pull_request_reviews = null;
            required_status_checks = {
              strict = false;
              contexts = [
                "check format [aarch64-darwin]"
                "check format [aarch64-linux]"
                "check format [x86_64-linux]"
                "devShell default [aarch64-darwin]"
                "devShell default [aarch64-linux]"
                "devShell default [x86_64-linux]"
              ];
            };
            enforce_admins = true;
            required_linear_history = false;
            allow_force_pushes = false;
            restrictions.apps = [];
          };
        };
      };
    };

    workflow."pages.yml".text = lib.generators.toYAML {} {
      name = "Deploy generated docs to Pages";
      on = {
        # Runs on pushes targeting the default branch
        push.branches = ["main"];
        # Allows you to run this workflow manually from the Actions tab
        workflow_dispatch = {};
      };

      # Sets permissions of the GITHUB_TOKEN to allow deployment to GitHub Pages
      permissions = {
        contents = "read";
        pages = "write";
        id-token = "write";
      };

      # Allow only one concurrent deployment, skipping runs queued between the run in-progress and latest queued.
      # However, do NOT cancel in-progress runs as we want to allow these production deployments to complete.
      concurrency = {
        group = "pages";
        cancel-in-progress = false;
      };

      jobs = {
        build = {
          runs-on = "ubuntu-latest";
          steps = [
            { name = "Checkout";
              uses = "actions/checkout@v4";
            }
            { name = "Setup Pages";
              uses = "actions/configure-pages@v3";
            }
            { uses = "cachix/install-nix-action@v23";
              "with".extra_nix_config = ''
                extra-trusted-public-keys = cache.garnix.io:CTFPyKSLcx5RMJKfLo5EEPUObbA78b0YQ2DTCJXqr9g=
                extra-substituters = https://cache.garnix.io
              '';
            }
            { run = ''
                nix build .#docs-html
                cp -r result/share/doc/project-manager ./_site
              '';
            }
            { name = "Upload artifact";
              uses = "actions/upload-pages-artifact@v2";
            }
          ];
        };
        deploy = {
          environment = {
            name = "github-pages";
            url = "\${{ steps.deployment.outputs.page_url }}";
          };
          runs-on = "ubuntu-latest";
          needs = "build";
          steps = [
            { name = "Deploy to GitHub Pages";
              id = "deployment";
              uses = "actions/deploy-pages@v2";
            }
          ];
        };
      };
    };
  };
}
