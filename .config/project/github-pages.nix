{lib, ...}: let
  defaultBranch = "main";
in {
  services.github = {
    settings.pages = {
      build_type = "workflow";
      source.branch = defaultBranch;
    };
    workflow."pages.yml".text = lib.pm.generators.toYAML {} {
      name = "Deploy generated docs to Pages";
      on = {
        ## Runs on pushes targeting the default branch
        push.branches = [defaultBranch];
        ## Allows you to run this workflow manually from the Actions tab
        workflow_dispatch = {};
      };

      ## Sets permissions of the GITHUB_TOKEN to allow deployment to GitHub Pages
      permissions = {
        contents = "read";
        pages = "write";
        id-token = "write";
      };

      ## Allow only one concurrent deployment, skipping runs queued between the run in-progress and latest queued.
      ## However, do NOT cancel in-progress runs as we want to allow these production deployments to complete.
      concurrency = {
        group = "pages";
        cancel-in-progress = false;
      };

      jobs = {
        build = {
          runs-on = "ubuntu-24.04";
          steps = [
            {
              name = "Checkout";
              uses = "actions/checkout@v6";
            }
            {
              name = "Setup Pages";
              uses = "actions/configure-pages@v4";
            }
            {
              uses = "cachix/install-nix-action@v24";
              "with".extra_nix_config = ''
                extra-trusted-public-keys = cache.garnix.io:CTFPyKSLcx5RMJKfLo5EEPUObbA78b0YQ2DTCJXqr9g=
                extra-substituters = https://cache.garnix.io
              '';
            }
            {
              run = ''
                nix build .#docs-html
                cp -r result/share/doc/project-manager ./_site
              '';
            }
            {
              name = "Upload artifact";
              uses = "actions/upload-pages-artifact@v3";
            }
          ];
        };
        deploy = {
          environment = {
            name = "github-pages";
            url = "\${{ steps.deployment.outputs.page_url }}";
          };
          runs-on = "ubuntu-24.04";
          needs = "build";
          steps = [
            {
              name = "Deploy to GitHub Pages";
              id = "deployment";
              uses = "actions/deploy-pages@v4";
            }
          ];
        };
      };
    };
  };
}
