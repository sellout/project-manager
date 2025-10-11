{
  editorconfig = {
    enable = true;
    settings = {
      "*" = {
        charset = "utf-8";
        end_of_line = "lf";
        trim_trailing_whitespace = true;
        insert_final_newline = true;
        max_line_width = 78;
        indent_style = "space";
        indent_size = 2;
      };
      "*.rs" = {
        indent_size = 4;
      };
    };
  };

  nmt.script = ''
    assertFileExists "project-files/.editorconfig"
    assertFileContent "project-files/.editorconfig" ${./editorconfig}
  '';
}
