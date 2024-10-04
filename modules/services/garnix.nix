{
  config,
  flaky,
  lib,
  pkgs,
  self,
  supportedSystems,
  ...
}:
with lib; let
  cfg = config.services.garnix;

  isUniversalAttr = value: lib.elem "*.*" value && lib.elem "*.*.*" value;

  buildOptions.options = {
    exclude = lib.mkOption {
      type = lib.pm.types.globList isUniversalAttr;
      default = [];
      description = ''
        A list of attributes with wildcards that garnix should skip.
      '';
    };
    include = lib.mkOption {
      type = lib.pm.types.globList isUniversalAttr;
      default = [];
      description = ''
        A list of attributes with wildcards that garnix should not skip.
      '';
    };
  };
  serverOptions.options = {
    configuration = lib.mkOption {
      type = lib.types.str;
      description = ''
        The name of the `nixosConfiguration` to deploy.
      '';
    };
    branch = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = ''
         This is set to either the branch name for an `on-branch` deployment, or
        `null` for `on-pull-request` deployment.
      '';
    };
  };
in {
  meta.maintainers = [maintainers.sellout];

  options.services.garnix = {
    enable = mkEnableOption "Garnix CI configuration";

    builds = mkOption {
      type = lib.types.attrsOf (lib.types.submodule buildOptions);
      default = {};
      description = ''
        Configuration written to {file}`$PROJECT_ROOT/garnix.yaml`.
        See <https://garnix.io/docs/yaml_config> for documentation.

        The structure here is different from the YAML. Instead of a “branch”
        field, this makes the branch names the keys of the attrSet, with `"*"`
        meaning “all branches”.
      '';
      example = lib.literalMD ''
        {
          "*" = {
            exclude = ["homeConfigurations.*"];
            include = [
              "*.x86_64-linux.*"
              "packages.aarch64-darwin.*"
              "defaultPackage.x86_64-linux"
              "devShell.x86_64-linux"
            ];
          };
          main.include = ["packages.*.release"];
        }
      '';
    };

    servers = mkOption {
      type = lib.types.listOf (lib.types.submodule serverOptions);
      default = [];
      description = ''
        Configuration written to {file}`$PROJECT_ROOT/garnix.yaml`.
        See <https://garnix.io/docs/yaml_config> and for documentation.
      '';
      example = lib.literalMD ''
        [
          {
            configuration = "example";
            branch = "main";
          }
          {configuration = "test";}
        ];
      '';
    };
  };

  config = mkIf (cfg.enable) {
    project.file."garnix.yaml".text = lib.pm.generators.toYAML {} {
      builds = lib.mapAttrsToList (branch: value:
        if branch == "*"
        then value
        else value // {inherit branch;})
      cfg.builds;
      servers =
        map ({
          configuration,
          branch,
        }: {
          inherit configuration;
          deployment =
            if branch == null
            then {type = "on-pull-request";}
            else {
              inherit branch;
              type = "on-branch";
            };
        })
        cfg.servers;
    };

    ## Can’t build un-sandboxed derivations on Garnix (see garnix-io/issues#33)
    services.garnix.builds."*" = {
      exclude =
        flaky.lib.forGarnixSystems supportedSystems (sys:
          map
          (name: "checks.${sys}.${name}")
          (builtins.attrNames
            self.projectConfigurations.${sys}.unsandboxedChecks))
        ++ ["devShells.*.lax-checks"];
    };
  };
}
