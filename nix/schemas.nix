{flake-schemas}: {
  projectConfigurations = {
    version = 1;
    doc = ''
      The `projectConfigurations` flake output defines project configurations.
    '';
    inventory = output:
      flake-schemas.lib.mkChildren (builtins.mapAttrs (system: project: {
          forSystems = [system];
          what = "Project Manager configuration for this flake’s project";
          derivation = project.activationPackage;
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
      flake-schemas.lib.mkChildren (builtins.mapAttrs (moduleName: module: {
          what = "Project Manager module";
        })
        output);
  };
}
