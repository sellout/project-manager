{
  programs.shellcheck = {
    enable = true;
    settings.source = ./shellcheckrc;
  };
}
