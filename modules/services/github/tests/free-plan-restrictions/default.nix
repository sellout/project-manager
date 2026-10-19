## Everything configured here needs a paid plan in order to be set on a private
## repository, so each one should produce an assertion.
let
  unavailable = consequence: "isn’t available in a private repository on the “free” plan, so ${consequence}. Either correct `services.github.plan` (if the owning account is on a paid plan) or stop setting it here.";

  rejected = unavailable "GitHub will reject the request";

  ignored = unavailable "GitHub will accept the request and silently ignore the field, leaving this permanently out of step with the repository";
in {
  services.github = {
    enable = true;

    settings = {
      repository = {
        private = true;
        has_wiki = true;
      };
      branches.main.protection.enforce_admins = false;
      environments.production = {};
      rulesets.main.target = "branch";
    };
  };

  test.asserts = {
    ## `has_wiki` is only ineffective, not rejected, so it warns instead.
    warnings.expected = [
      "`services.github.settings.repository.has_wiki` ${ignored}"
    ];

    assertions.expected = [
      "branch protection (`services.github.settings.branches.*.protection`, set on main) ${rejected}"
      "`services.github.settings.rulesets` ${rejected}"
      "`services.github.settings.environments` ${rejected}"
    ];
  };
}
