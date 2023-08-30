{...}: {
  imports = [
    ./editorconfig.nix
  ];

  project.file.".dir-locals.el" = {
    persistence = "store";
    text = ''
      ((nil
        (fill-column . 80)
        (indent-tabs-mode . nil)
        (projectile-project-configure-cmd . "nix flake update")
        (sentence-end-double-space . nil)))
    '';
  };
}
