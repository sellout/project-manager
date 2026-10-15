{
  services.github = {
    enable = true;

    settings = {
      branches.main.protection.enforce_admins = false;
      repository = {
        has_wiki = true;
        private = false;
        topics = ["nix" "project-manager"];
      };
    };
  };

  nmt.script = ''
    assertFileExists "project-files/.github/settings.yml"
    assertFileContent "project-files/.github/settings.yml" ${./settings.yml}
  '';
}
