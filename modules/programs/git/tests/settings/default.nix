{
  programs.git = {
    enable = true;
    attributes = [
      "/some-file linguist-generated"
      "*.pdf diff=pdf"
      "meh important=100"
      "*.bin -diff important=50"
    ];

    includes = [
      {path = "~/some-extra/git/config.inc";}
      {
        path = "~/some-extra/git/conditional.inc";
        condition = "gitdir:~/src/dir";
      }
    ];

    ignores = [
      "/.locally-generated"
      "/.cache"
    ];
  };

  ## NB: We remove the leading “.” from the filename so that it doesn’t
  ##     actually ignore things.
  nmt.script = ''
    assertFileExists "project-files/.git/config"
    assertFileContent "project-files/.git/config" ${./git/config}
    assertFileExists "project-files/.gitattributes"
    assertFileContent "project-files/.gitattributes" ${./.gitattributes}
    assertFileExists "project-files/.gitignore"
    assertFileContent "project-files/.gitignore" ${./gitignore}
  '';
}
