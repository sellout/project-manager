{...}: {
  project.file.".shellcheckrc" = {
    persistence = "store";
    text = ''
      ## -*- mode: sh -*-

      # Unicode quotes are good, and Shellcheck gets this wrong a lot.
      disable=SC1111,SC1112
    '';
  };
}
