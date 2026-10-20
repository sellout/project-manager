## The same settings as `github-free-plan-restrictions`, but on a plan that can
## actually use them, so none of the assertions should fire.
{
  services.github = {
    enable = true;
    plan = "pro";

    settings = {
      repository = {
        private = true;
        has_wiki = true;
        topics = ["nix" "project-manager"];
      };
      branches.main.protection.enforce_admins = false;
    };
  };

  nmt.script = ''
    assertFileExists "project-files/.github/settings.yml"
    assertFileContent "project-files/.github/settings.yml" \
      ${./settings.yml}
  '';
}
