{config, ...}: {
  services.garnix = {
    enable = true;
    builds = {
      exclude = [
        ## TODO: This check requires Internet access.
        "checks.*.project-manager-files"
        # TODO: Remove once garnix-io/garnix#285 is fixed.
        "homeConfigurations.x86_64-darwin-${config.project.name}-example"
      ];
      include = ["*.*" "*.*.*"];
    };
  };
}
