{...}: {
  project.file.".dir-locals.el" = {
    minimum-persistence = "worktree";
    text = ''
      ((nil
        (fill-column . 80)
        (indent-tabs-mode . nil)
        (projectile-project-configure-cmd . "nix flake update")
        (sentence-end-double-space . nil)))
    '';
  };
}
