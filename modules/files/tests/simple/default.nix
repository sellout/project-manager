{
  project.file."meh".text = ''
    This is a very simple file.
  '';

  nmt.script = ''
    assertFileExists "project-files/meh"
    assertFileContent "project-files/meh" ${./meh}
  '';
}
