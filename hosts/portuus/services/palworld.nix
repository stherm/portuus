{
  outputs,
  config,
  constants,
  ...
}:

let
  s = constants.services.palworld;
in
{
  imports = [ outputs.nixosModules.palworld ];

  sops.secrets = {
    "palworld/server-password" = {
      owner = "palworld";
      restartUnits = [ "palworld.service" ];
    };
    "palworld/admin-password" = {
      owner = "palworld";
      restartUnits = [ "palworld.service" ];
    };
  };

  services.palworld = {
    enable = true;
    inherit (s) port;
    serverPasswordFile = config.sops.secrets."palworld/server-password".path;
    adminPasswordFile = config.sops.secrets."palworld/admin-password".path;

    settings = {
      ServerName = "Portuus Palworld";
      ServerDescription = "Portuus Palworld-Server";
      ServerPlayerMaxNum = 32;
      CoopPlayerMaxNum = 12;

      RandomizerSeed = "";
      bIsRandomizerPalLevelRandom = false;

      DayTimeSpeedRate = 1.0;
      NightTimeSpeedRate = 1.0;
      ExpRate = 1.5;
      PalCaptureRate = 1.0;
      PalSpawnNumRate = 1.0;

      PalDamageRateAttack = 1.0;
      PalDamageRateDefense = 1.0;
      PlayerDamageRateAttack = 1.0;
      PlayerDamageRateDefense = 1.0;

      PlayerStomachDecreaceRate = 1.0;
      PlayerStaminaDecreaceRate = 1.0;
      PlayerAutoHPRegeneRate = 1.0;
      PlayerAutoHpRegeneRateInSleep = 5.0;

      PalStomachDecreaceRate = 0.5;
      PalStaminaDecreaceRate = 1.0;
      PalAutoHPRegeneRate = 1.0;
      PalAutoHpRegeneRateInSleep = 5.0;

      BuildObjectHpRate = 1.0;
      BuildObjectDamageRate = 1.0;
      BuildObjectDeteriorationDamageRate = 0.0;

      CollectionDropRate = 1.2;
      CollectionObjectHpRate = 1.2;
      CollectionObjectRespawnSpeedRate = 1.0;
      EnemyDropItemRate = 1.3;

      bEnablePlayerToPlayerDamage = false;
      bEnableFriendlyFire = false;
      bEnableInvaderEnemy = true;
      bActiveUNKO = false;
      bEnableAimAssistPad = true;
      bEnableAimAssistKeyboard = false;

      DropItemMaxNum = 5000;
      DropItemMaxNum_UNKO = 100;
      DropItemAliveMaxHours = 2.0;

      BaseCampMaxNum = 128;
      BaseCampWorkerMaxNum = 20;
      BaseCampMaxNumInGuild = 10;

      bAutoResetGuildNoOnlinePlayers = false;
      AutoResetGuildTimeNoOnlinePlayers = 72.0;
      GuildPlayerMaxNum = 20;
      GuildRejoinCooldownMinutes = 0;

      PalEggDefaultHatchingTime = 0.5;
      WorkSpeedRate = 1.0;
      AutoSaveSpan = 30.0;

      bIsMultiplay = true;
      bIsPvP = false;
      bHardcore = false;
      bPalLost = false;
      bCharacterRecreateInHardcore = false;

      bCanPickupOtherGuildDeathPenaltyDrop = false;
      bEnableNonLoginPenalty = true;

      bEnableFastTravel = true;
      bEnableFastTravelOnlyBaseCamp = false;
      bIsStartLocationSelectByMap = true;

      bExistPlayerAfterLogout = false;
      bEnableDefenseOtherGuildPlayer = false;
      bInvisibleOtherGuildBaseCampAreaFX = false;
      bBuildAreaLimit = false;

      ItemWeightRate = 0.5;

      bAllowClientMod = true;

      RCONEnabled = false;
      RCONPort = 25575;

      Region = "";

      bUseAuth = true;
      BanListURL = "https://b.palworldgame.com/api/banlist.txt";

      RESTAPIEnabled = false;
      RESTAPIPort = 8212;

      bShowPlayerList = false;
      ChatPostLimitPerMinute = 30;

      bIsUseBackupSaveData = true;
      bIsShowJoinLeftMessage = true;

      SupplyDropSpan = 180;
      EnablePredatorBossPal = true;

      MaxBuildingLimitNum = 0;
      ServerReplicatePawnCullDistance = 15000.0;

      bAllowGlobalPalboxExport = true;
      bAllowGlobalPalboxImport = false;

      EquipmentDurabilityDamageRate = 0.5;
      ItemContainerForceMarkDirtyInterval = 1.0;
      ItemCorruptionMultiplier = 1.0;

      BlockRespawnTime = 5.0;
      RespawnPenaltyDurationThreshold = 0.0;
      RespawnPenaltyTimeScale = 2.0;

      bDisplayPvPItemNumOnWorldMap_BaseCamp = false;
      bDisplayPvPItemNumOnWorldMap_Player = false;

      AdditionalDropItemWhenPlayerKillingInPvPMode = "PlayerDropItem";
      AdditionalDropItemNumWhenPlayerKillingInPvPMode = 1;
      bAdditionalDropItemWhenPlayerKillingInPvPMode = false;

      bAllowEnhanceStat_Health = true;
      bAllowEnhanceStat_Attack = true;
      bAllowEnhanceStat_Stamina = true;
      bAllowEnhanceStat_Weight = true;
      bAllowEnhanceStat_WorkSpeed = true;
    };

    rawSettings = {
      Difficulty = "None";
      RandomizerType = "None";
      DeathPenalty = "Item";
      LogFormatType = "Text";
      CrossplayPlatforms = "(Steam,Xbox,PS5,Mac)";
      DenyTechnologyList = "";
    };
  };

  # no openFirewall needed: traffic comes via edge stream proxy over the
  # Tailnet, and synix trusts the tailscale interface
}
