{
  editorconfig = {
    enable = true;
    settings = {
      "*" = {
        charset = "utf-8";
        end_of_line = "lf";
        indent_size = 2;
        indent_style = "space";
        insert_final_newline = true;
        trim_trailing_whitespace = true;
        ## for shfmt
        binary_next_line = true;
        space_redirects = true;
        switch_case_indent = true;
      };
      "*.{diff,patch}".trim_trailing_whitespace = false;
      ## Lisps have a fairly consistent indentation style that doesn’t
      ## collapse well to a single value, so we let the editor do what it
      ## wants here.
      "*.{el,lisp}".indent_size = "unset";
    };
  };
}
