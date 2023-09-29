{lib, ...}: {
  project.file.".config/mustache.yaml" = {
    ## TODO: Should be able to make this `"store"`.
    minimum-persistence = "worktree";
    text = lib.generators.toYAML {} {
      project = {
        description = "A configuration for managing flake-based projects.";
        name = "project-manager";
        repo = "sellout/project-manager";
        summary = "Home Manager, but for repos.";
        version = "0.1.0";
      };
      type.name = "bash";
    };
  };
}
