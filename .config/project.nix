{config, pkgs, ...}: {
  project = {
    ## Manual file creation, for things that aren’t managed yet (and for modules
    ## to add files).
    file = {
      ".dir-locals.el" = {
        persistence = "store";
        text = ''
          ((nil
            (fill-column . 80)
            (indent-tabs-mode . nil)
            (projectile-project-configure-cmd . "nix flake update")
            (sentence-end-double-space . nil)))
        '';
      };
      ".editorconfig" = {
        persistence = "store";
        text = pkgs.lib.generators.toINIWithGlobalSection {} {
          ### This configures basic cross-editor formatting.
          ###
          ### See https://editorconfig.org/ for more info, and to see if your editor
          ### requires a plugin to take advantage of it.
          globalSection.root = true;
          sections = {
            "*" = {
              charset = "utf-8";
              end_of_line = "lf";
              indent_size = 2;
              indent_style = "space";
              insert_final_newline = true;
              trim_trailing_whitespace = true;
              ## for shfmt
              binary_next_line = true;
              space_redirects = true;
              switch_case_indent = true;
            };
            "*.{diff,patch}".trim_trailing_whitespace = false;
            ## Lisps have a fairly consistent indentation style that doesn’t
            ## collapse well to a single value, so we let the editor do what it
            ## wants here.
            "*.{el,lisp}".indent_size = "unset";
          };
        };
      };
      ".github/settings.yml".text = pkgs.lib.generators.toYAML {} {
        # These settings are synced to GitHub by https://probot.github.io/apps/settings/

        # See https://docs.github.com/en/rest/reference/repos#update-a-repository for all available settings.
        repository = {
          name = config.project.name;
          description = config.project.summary;
          # homepage = "https://example.github.io/";
          topics = ["development" "nix-flakes"];
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
          { name = "bug";
            color = "#d73a4a";
            description = "Something isn’t working";
          }
          { name = "documentation";
            color = "#0075ca";
            description = "Improvements or additions to documentation";
          }
          { name = "enhancement";
            color = "#a2eeef";
            description = "New feature or request";
          }
          { name = "good first issue";
            color = "#7057ff";
            description = "Good for newcomers";
          }
          { name = "help wanted";
            color = "#008672";
            description = "Extra attention is needed";
          }
          { name = "question";
            color = "#d876e3";
            description = "Further information is requested";
          }
        ];

        branches = [
          { name = "main";
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
          }
        ];
      };
      ".shellcheckrc" = {
        persistence = "store";
        text = ''
          ## -*- mode: sh -*-

          # Unicode quotes are good, and Shellcheck gets this wrong a lot.
          disable=SC1111,SC1112
        '';
      };
      "garnix.yaml".text = pkgs.lib.generators.toYAML {} {
        builds = {
          # TODO: Remove once garnix-io/garnix#285 is fixed.
          exclude =
            ["homeConfigurations.x86_64-darwin-${config.project.name}-example"];
          include = ["*.*" "*.*.*"];
        };
      };
      "renovate.json".text = pkgs.lib.generators.toJSON {} {
        "$schema" = "https://docs.renovatebot.com/renovate-schema.json";
        extends = ["config:base"];
        nix.enabled = true;
      };
    };
    name = "project-manager";
    ## Packages to install in the devShells that reference projectConfiguration.
    packages = [
      pkgs.nil
    ];
    summary = "Home Manager, but for repos.";
  };
  programs = {
    direnv = {
      auto-allow = true;
      enable = true;
      envrc.text = "use flake";
    };
    git = {
      # default is determined by whether there is a .git file/dir (and whether
      # it’s a file (worktree) or dir determines other things – like where hooks
      # are installed.
      enable = true;
      # automatically added to by
      config = {
        commit.template = {
          contents = "";
          path = ".config/git/template/commit.txt";
        };
      };
      hooks = {
        # post-commit = {
        #   auto-install = true;
        #   content = "";
        # };
      };
      ignores = [
        "/.direnv/"

        # Nix build
        "/result"
        "/source"
      ];
      ignoreRevs = [
      ];
    };
  };
  # services = {
  #   garnix = {
  #   };
  #   github = {
  #     apps = {
  #       renovate = {};
  #       settings = {};
  #     };
  #     pages = "";
  #     workflows = {};
  #   };
  # };
}
