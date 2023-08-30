{config, ...}: {
  services.garnix = {
    enable = true;
    builds = {
      # TODO: Remove once garnix-io/garnix#285 is fixed.
      exclude = ["homeConfigurations.x86_64-darwin-${config.project.name}-example"];
      include = ["*.*" "*.*.*"];
    };
  };
}
