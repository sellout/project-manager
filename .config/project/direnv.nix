{...}: {
  programs.direnv = {
    enable = true;
    auto-allow = true;
    commit-envrc = false;
    envrc.text = "use flake";
  };
}
