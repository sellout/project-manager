let
  ## These should be available via flake-schemas (see
  ## DeterminateSystems/flake-schemas#10).
  mkChildren = children: {inherit children;};
in {
  projectConfigurations = {
    version = 1;
    doc = ''
      The `projectConfigurations` flake output defines project configurations.
    '';
    inventory = output:
      mkChildren (builtins.mapAttrs (system: project: {
          what = "Project Manager configuration for this flake’s project";
          derivation = project.config.activationPackage;
        })
        output);
  };

  projectModules = {
    version = 1;
    doc = ''
      Defines “project modules” analogous to `nixosModules` or
      `homeModules`, but scoped to a single project (often some VCS repo).
    '';
    inventory = output:
      mkChildren (builtins.mapAttrs (moduleName: module: {
          what = "Project Manager module";
        })
        output);
  };
}
