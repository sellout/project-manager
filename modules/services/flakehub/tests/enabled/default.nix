{
  services = {
    flakehub = {
      enable = true;
      name = "sellout/example";
    };
    github.enable = true;
  };

  nmt.script = ''
    assertFileExists "project-files/.github/workflows/flakehub-publish.yml"
    assertFileContent "project-files/.github/workflows/flakehub-publish.yml" \
      ${./.github/workflows/flakehub-publish.yml}
  '';
}
