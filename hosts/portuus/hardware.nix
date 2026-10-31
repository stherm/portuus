{
  config,
  lib,
  modulesPath,
  ...
}:

{
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

  boot = {
    initrd = {
      availableKernelModules = [
        "xhci_pci"
        "ahci"
        "usb_storage"
        "sd_mod"
      ];
      kernelModules = [ ];
    };
    kernelModules = [ "kvm-amd" ];
    extraModulePackages = [ ];
  };

  fileSystems = {
    "/" = {
      device = "rpool/root";
      fsType = "zfs";
    };

    "/home" = {
      device = "rpool/home";
      fsType = "zfs";
    };

    "/nix" = {
      device = "rpool/nix";
      fsType = "zfs";
    };

    "/tmp" = {
      device = "rpool/tmp";
      fsType = "zfs";
    };

    "/var" = {
      device = "rpool/var";
      fsType = "zfs";
    };

    "/boot" = {
      device = "/dev/disk/by-label/BOOT1";
      fsType = "vfat";
      options = [
        "fmask=0077"
        "dmask=0077"
      ];
    };

    "/data" = {
      device = "dpool/data";
      fsType = "zfs";
    };

    "/data/attic" = {
      device = "dpool/data/attic";
      fsType = "zfs";
    };

    "/data/audiobooks" = {
      device = "dpool/data/audiobooks";
      fsType = "zfs";
    };

    "/data/backup" = {
      device = "dpool/data/backup";
      fsType = "zfs";
    };

    "/data/charbogen" = {
      device = "dpool/data/charbogen";
      fsType = "zfs";
    };

    "/data/forgejo" = {
      device = "dpool/data/forgejo";
      fsType = "zfs";
    };

    "/data/immich" = {
      device = "dpool/data/immich";
      fsType = "zfs";
    };

    "/data/jellyfin" = {
      device = "dpool/data/jellyfin";
      fsType = "zfs";
    };

    "/data/jirafeau" = {
      device = "dpool/data/jirafeau";
      fsType = "zfs";
    };

    "/data/mail" = {
      device = "dpool/data/mail";
      fsType = "zfs";
    };

    "/data/matrix-synapse" = {
      device = "dpool/data/matrix-synapse";
      fsType = "zfs";
    };

    "/data/maubot" = {
      device = "dpool/data/maubot";
      fsType = "zfs";
    };

    "/data/nextcloud" = {
      device = "dpool/data/nextcloud";
      fsType = "zfs";
    };
  };

  swapDevices = [
    { device = "/dev/disk/by-label/SWAP1"; }
    { device = "/dev/disk/by-label/SWAP2"; }
  ];

  systemd.services.zfs-import-dpool.restartIfChanged = false;

  networking.useDHCP = lib.mkDefault true;

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
