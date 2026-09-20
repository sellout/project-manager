{
  project.file."meh".text = ''
    Hello. A file.
  '';

  nmt.script = ''
    assertFileExists "project-files/meh"
    assertFileContent "project-files/meh" ${./meh}
  '';
}
