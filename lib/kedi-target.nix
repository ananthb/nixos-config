{
  config,
  lib,
  ...
}: let
  inherit (lib) mkOption types;

  targetName = config.machines.serviceTarget.name;

  stripServiceSuffix = name:
    if lib.hasSuffix ".service" name
    then lib.removeSuffix ".service" name
    else name;

  normalize = names: lib.unique (map stripServiceSuffix names);

  cfg = config.my-services;

  manualUnits = normalize (cfg.restartUnits or []);
  autoUnits = normalize (
    lib.attrNames (lib.filterAttrs (_name: enabled: enabled) (cfg.kediTargets or {}))
  );
  excludedUnits = normalize (cfg.restartUnitsExclude or []);

  finalUnits = lib.subtractLists excludedUnits (manualUnits ++ autoUnits);

  unitNames = map (name: "${name}.service") finalUnits;
in {
  options.my-services = {
    kediTargets = mkOption {
      type = types.attrsOf types.bool;
      default = {};
      description = "Attrset of systemd service names to include in ${targetName}.target when set to true.";
    };

    restartUnits = mkOption {
      type = types.listOf types.str;
      default = [];
      description = "Extra systemd service units to include in ${targetName}.target (names without .service).";
    };

    restartUnitsExclude = mkOption {
      type = types.listOf types.str;
      default = [];
      description = "Systemd service units to exclude from ${targetName}.target (names without .service).";
    };
  };

  config = {
    systemd.targets.${targetName} = {
      description = "${targetName} services";
      wants = unitNames;
    };
  };
}
