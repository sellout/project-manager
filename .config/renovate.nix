{pkgs, ...}: {
  project.file."renovate.json".text = pkgs.lib.generators.toJSON {} {
    "$schema" = "https://docs.renovatebot.com/renovate-schema.json";
    extends = ["config:base"];
    nix.enabled = true;
  };
}
