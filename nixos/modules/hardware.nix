{ lib, pkgs, ... }:

{
  # Hardware support for the desktop (i7-8700K + GTX 1070); the GPU is in nvidia.nix.
  # Maximus X: on-board Realtek Wi-Fi + Bluetooth module. Both need firmware files
  # from linux-firmware, which NixOS only installs when this is on. It also turns on
  # the Intel CPU microcode updates in hardware-configuration.nix.
  hardware.enableRedistributableFirmware = true;
  hardware.bluetooth.enable = true;          # manage with bluetoothctl

  # The Wi-Fi card (RTL8822BE, rtw88 driver) without its deep power saving and PCIe link power states, which dropped the
  # access point's beacons (audit NET-01; NetworkManager's power saving is off in configuration.nix). The regulatory
  # domain is India's, where the machine is, instead of whatever country the access point announces (it flipped between
  # the world default and DE). Applies after a reboot: the modules load at boot.
  boot.extraModprobeConfig = ''
    options rtw88_core disable_lps_deep=y
    options rtw88_pci disable_aspm=y
    options cfg80211 ieee80211_regdom=IN
  '';
  services.power-profiles-daemon.enable = true;
  services.udisks2.enable = true;            # USB drives and SD cards
  services.fwupd.enable = true;              # firmware updates (sysupdate lists them)

  # Tools for looking at the hardware.
  environment.systemPackages = with pkgs; [
    lm_sensors      # sensors: temperatures, fans and voltages from every hwmon driver (the board's nct6775 too)
    pciutils        # lspci
    usbutils        # lsusb
    smartmontools   # smartctl: health of the three Samsung SSDs
  ];

  # Watch the SSDs' health (SMART) and say so the moment one degrades: a desktop notification (through
  # systembus-notify, a user service; any local user could send one, and kishan is the only one) and a wall message.
  # A short self-test each Sunday at 03:00 (the machine never sleeps), for faults the counters alone miss.
  services.smartd = {
    enable = true;
    defaults.autodetected = "-a -s S/../../7/03";
    notifications.systembus-notify.enable = true;
  };

  # Kratos never sleeps: it is reached from afar through Tailscale and RustDesk.
  systemd.sleep.settings.Sleep = {
    AllowSuspend = "no";
    AllowHibernation = "no";
    AllowHybridSleep = "no";
    AllowSuspendThenHibernate = "no";
  };

  # Wake-on-LAN would need the wired port (Intel I219-V, enp0s31f6), which has no cable; the Wi-Fi card has no WoWLAN.
  # With a cable: networking.interfaces.enp0s31f6.wakeOnLan.enable = true, and in the BIOS "Power On By PCI-E" on, ErP off.

  # Compressed swap kept in memory, used first (priority 5); the 34 GiB swap partition only takes what does not fit.
  zramSwap.enable = true;
  # That partition, encrypted with a new random key at every boot (audit D5): what lands in swap (passwords, keys, the
  # clipboard history) is unreadable once the machine is off. In place of hardware-configuration.nix's plain entry. Named by
  # its partition id, which stays; the swap's own id changes at every boot. Hibernation, which this rules out, is off anyway.
  swapDevices = lib.mkForce [
    {
      device = "/dev/disk/by-partuuid/2162c236-252d-4edf-af61-c41f8abb6e15"; # nvme0n1p3
      randomEncryption.enable = true;
    }
  ];

  # Sound.
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    jack.enable = true;
  };
}
