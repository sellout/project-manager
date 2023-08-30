{...}: {
  programs.direnv = {
    auto-allow = true;
    enable = true;
    envrc.text = "use flake";
  };
}
