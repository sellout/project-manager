{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit
    (lib)
    concatStringsSep
    pm
    mkOption
    types
    ;

  dag = lib.pm.dag;

  result = let
    sorted = dag.topoSort config.tested.dag;
    data = map (e: "${e.name}:${e.data.name}") sorted.result;
  in
    concatStringsSep "\n" data + "\n";
in {
  options.tested.dag = mkOption {
    type = pm.types.dagOf (
      types.submodule (
        {dagName, ...}: {
          options.name = mkOption {type = types.str;};
          config.name = "dn-${dagName}";
        }
      )
    );
  };

  config = {
    tested.dag = {
      after = {};
      before = dag.entryBefore ["after"] {};
      between = dag.entryBetween ["after"] ["before"] {};
    };

    project.file."result.txt".text = result;

    nmt.script = ''
      assertFileContent \
        project-files/result.txt \
        ${pkgs.writeText "result.txt" ''
        before:dn-before
        between:dn-between
        after:dn-after
      ''}
    '';
  };
}
