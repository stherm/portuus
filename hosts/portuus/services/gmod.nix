{
  outputs,
  config,
  constants,
  lib,
  ...
}:

let
  s = constants.services.gmod;
  secret = name: config.sops.secrets."gmod/${name}".path;
in
{
  imports = [ outputs.nixosModules.gmod ];

  services.gmod = {
    inherit (s) enable port;
    dataDir = "/data/gmod";
    hostname = "portuus TTT2";
    gamemode = "terrortown";
    map = "ttt_fastfood_a6";
    maxPlayers = 16;
    workshopCollection = "2042277791";
    serverPasswordFile = secret "server-password";
    rconPasswordFile = secret "rcon-password";
    mountCss = true;

    settings = {
      sv_region = 3;

      ttt_preptime_seconds = 20;
      ttt_firstpreptime = 60;
      ttt_posttime_seconds = 15;

      ttt_haste = true;
      ttt_haste_starting_minutes = 5;
      ttt_haste_minutes_per_death = "0.5";

      ttt_round_limit = 10;
      ttt_time_limit_minutes = 99;
      ttt_always_use_mapcycle = false;

      ttt_traitor_pct = "0.34";
      ttt_traitor_max = 33;
      ttt_detective_pct = "0.21";
      ttt_detective_max = 21;
      ttt_detective_min_players = 6;
      ttt_detective_karma_min = 500;

      ttt_killer_dna_range = 650;
      ttt_killer_dna_basetime = 90;

      ttt_voice_drain = false;
      ttt_voice_drain_normal = "0.2";
      ttt_voice_drain_admin = "0";
      ttt_voice_drain_recharge = "0.05";

      ttt_minimum_players = 2;
      ttt_postround_dm = true;
      ttt_dyingshot = false;
      ttt_no_nade_throw_during_prep = false;
      ttt_weapon_carrying = true;
      ttt_weapon_carrying_range = 75;
      ttt_teleport_telefrags = false;
      ttt_ragdoll_pinning = true;
      ttt_ragdoll_pinning_innocents = false;

      ttt_karma = true;
      ttt_karma_strict = true;
      ttt_karma_starting = 1000;
      ttt_karma_max = 1050;
      ttt_karma_ratio = "0.001";
      ttt_karma_kill_penalty = 15;
      ttt_karma_round_increment = 10;
      ttt_karma_clean_bonus = 20;
      ttt_karma_traitordmg_ratio = "0.0003";
      ttt_karma_traitorkill_bonus = 35;
      ttt_karma_low_autokick = false;
      ttt_karma_low_amount = 0;
      ttt_karma_low_ban = false;
      ttt_karma_low_ban_minutes = 1;
      ttt_karma_persist = false;
      ttt_karma_debugspam = false;
      ttt_karma_clean_half = "0.25";

      ttt_use_weapon_spawn_scripts = true;

      ttt_credits_starting = 3;
      ttt_credits_award_pct = "0.34";
      ttt_credits_award_size = 1;
      ttt_credits_award_repeat = true;
      ttt_credits_detectivekill = 1;

      ttt_det_credits_starting = 2;
      ttt_det_credits_traitorkill = 0;
      ttt_det_credits_traitordead = 1;

      ttt_spec_prop_control = true;
      ttt_spec_prop_base = 15;
      ttt_spec_prop_maxpenalty = -6;
      ttt_spec_prop_maxbonus = 16;
      ttt_spec_prop_force = 200;
      ttt_spec_prop_rechargetime = "0.5";

      ttt_idle_limit = 180;
      ttt_namechange_kick = true;
      ttt_namechange_bantime = 5;
      ttt_ban_type = "autodetect";

      ttt_detective_hats = false;
      ttt_playercolor_mode = 1;
      ttt_ragdoll_collide = false;
      ttt_bots_are_spectators = false;
      ttt_debug_preventwin = false;
      ttt_locational_voice = false;
      ttt_allow_discomb_jump = false;
      ttt_spawn_wave_interval = 0;
    };
  };

  sops.secrets = lib.mkIf s.enable {
    "gmod/server-password".owner = "gmod";
    "gmod/rcon-password".owner = "gmod";
  };
}
