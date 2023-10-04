{
  programs.treefmt = {
    enable = true;
    programs = {
      ## Nix formatter
      alejandra.enable = true;
      ## Shell linter
      shellcheck.enable = true;
      ## Web/JSON/Markdown/TypeScript/YAML formatter
      prettier.enable = true;
      ## Shell formatter
      shfmt = {
        enable = true;
        ## NB: This has to be unset to allow the .editorconfig
        ##     settings to be used. See numtide/treefmt-nix#96.
        indent_size = null;
      };
    };
    settings.formatter = let
      includes = ["project-manager/project-manager"];
    in {
      shellcheck = {inherit includes;};
      shfmt = {inherit includes;};
    };
  };
}
