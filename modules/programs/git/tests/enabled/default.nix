{
  programs.git.enable = true;

  nmt.script = ''
    assertFileExists project-files/.gitattributes
    assertFileContent project-files/.gitattributes ${./.gitattributes}
    assertFileExists project-files/.gitignore
    ## NB: We remove the leading “.” from the filename so that it doesn’t
    ##     actually ignore things.
    assertFileContent project-files/.gitignore ${./gitignore}
  '';
}
