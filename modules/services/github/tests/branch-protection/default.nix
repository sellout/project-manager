## Exercise the various branch protection behaviors.
{
  services.github = {
    enable = true;

    settings = {
      branches = {
        ## GitHub replaces the protection record wholesale and requires all four
        ## elements, so the three left unset here are sent as `null` rather than
        ## omitted.
        configured.protection.enforce_admins = true;
        ## Beyond the four, an unset setting is left out rather than sent as
        ## `null` – so this record should carry neither the five review settings
        ## it doesn’t mention nor an `app_id` on its check.
        detailed.protection = {
          required_pull_request_reviews.required_approving_review_count = 2;
          required_status_checks = {
            checks = [{context = "NixCI";}];
            strict = false;
          };
          restrictions.users = ["sellout"];
        };
        ## Protected, while requiring none of the four.
        defaults.protection = {};
        ## Protection removed.
        removed.protection = null;
      };
      repository.private = false;
    };
  };

  test.asserts.warnings.expected = [
    "`services.github.settings.branches.removed.protection` is null, which _removes_ whatever protection `removed` currently has. If you meant to leave it alone, drop the branch."
  ];

  nmt.script = ''
    assertFileExists "project-files/.github/settings.yml"
    assertFileContent "project-files/.github/settings.yml" ${./settings.yml}
  '';
}
