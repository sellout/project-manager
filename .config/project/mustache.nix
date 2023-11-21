{config, lib, ...}: {
  project.file.".config/mustache.yaml" = {
    ## TODO: Should be able to make this `"store"`.
    minimum-persistence = "worktree";
    text = lib.pm.generators.toYAML {} {
      project = {
        inherit (config.project) name summary;
        description = "A configuration for managing flake-based projects.";
        repo = "sellout/project-manager";
        version = "0.1.0";
      };
      type.name = "nix";
    };
  };
}
