{flake-schemas}: let
  ## Stolen from DeterminateSystems/flake-schemas, which should export it in its
  ## lib.
  checkDerivation = drv: drv.type or null == "derivation" && drv ? drvPath;
in {
  projectConfigurations = {
    version = 1;
    doc = ''
      The `projectConfigurations` flake output defines project configurations.
    '';
    inventory = output:
      flake-schemas.lib.mkChildren (builtins.mapAttrs (system: project: let
          forSystems = [system];
        in {
          inherit forSystems;
          what = "Project Manager configuration for this flake’s project";
          children = {
            activationPackage = {
              inherit forSystems;
              shortDescription = project.activationPackage.meta.description;
              derivation = project.activationPackage;
              evalChecks.isDerivation = checkDerivation project.activationPackage;
              what = "package";
              isFlakeCheck = false;
            };
            checks = flake-schemas.lib.mkChildren (builtins.mapAttrs (checkName: check: {
                inherit forSystems;
                shortDescription = check.meta.description or "";
                derivation = check;
                evalChecks.isDerivation = checkDerivation check;
                what = "CI test";
                isFlakeCheck = true;
              })
              project.checks);
            devShells = flake-schemas.lib.mkChildren (builtins.mapAttrs (shellName: shell: {
                inherit forSystems;
                shortDescription = shell.meta.description;
                derivation = shell;
                evalChecks.isDerivation = checkDerivation shell;
                what = "development environment";
                isFlakeCheck = false;
              })
              project.devShells);
            formatter = {
              inherit forSystems;
              shortDescription = project.formatter.meta.description or "";
              derivation = project.formatter;
              evalChecks.isDerivation = checkDerivation project.formatter;
              what = "Nix code formatter";
              isFlakeCheck = false;
            };
            filterRepositoryPersistedExcept = {
              shortDescription = project.option.filterRepositoryPersistedExcept.description;
              what = "source filter";
              isFlakeCheck = false;
            };
            filterRepositoryPersisted = {
              shortDescription = project.option.filterRepositoryPersisted.description;
              what = "source filter";
              isFlakeCheck = false;
            };
            cleanRepositoryPersistedExcept = {
              shortDescription = project.option.cleanRepositoryPersistedExcept.description;
              what = "source filter";
              isFlakeCheck = false;
            };
            cleanRepositoryPersisted = {
              shortDescription = project.option.cleanRepositoryPersisted.description;
              what = "source filter";
              isFlakeCheck = false;
            };
          };
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
