{
  services.github = {
    enable = true;

    settings = {
      branches.main.protection.enforce_admins = false;
      collaborators.someone.permission = "push";
      environments.production = {};
      labels.bug = {
        color = "#d73a4a";
        description = "Something isn’t working";
      };
      milestones."1.0" = {};
      repository = {
        private = false;
        topics = ["nix" "project-manager"];
      };
      rulesets.main.target = "branch";
      teams.maintainers.permission = "admin";
    };
  };

  nmt.script = ''
    assertFileExists "project-files/.github/settings.yml"
    assertFileContent "project-files/.github/settings.yml" ${./settings.yml}
  '';
}
