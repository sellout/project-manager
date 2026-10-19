## Make sure `contexts` is rejected.
{
  services.github = {
    enable = true;

    settings = {
      branches.main.protection.required_status_checks = {
        checks = [{context = "NixCI";}];
        contexts = ["NixCI"];
        strict = false;
      };
      repository.private = false;
    };
  };

  test.asserts.assertions.expected = [
    "`services.github.settings.branches.main.protection.required_status_checks.contexts` is set. Use `checks`: GitHub is deprecating `contexts`, and a check without `app_id` is the same."
  ];
}
