{ config, lib, pkgs, ... }:

let
  # The NVIDIA driver loads a moment after OpenRGB starts at boot, so OpenRGB missed the graphics card's
  # lighting. This holds OpenRGB back until the card's I2C bus exists (at most 30 s).
  waitForGpu = pkgs.writeShellScript "openrgb-wait-for-gpu" ''
    for _ in $(seq 30); do
      grep -qs '^NVIDIA i2c adapter' /sys/bus/i2c/devices/i2c-*/name && exit 0
      sleep 1
    done
    echo "No NVIDIA I2C bus after 30 s; starting without the graphics card" >&2
  '';

  lightsOff = pkgs.writeShellApplication {
    name = "openrgb-lights-off";
    runtimeInputs = [ config.services.hardware.openrgb.package pkgs.coreutils pkgs.findutils pkgs.gawk pkgs.gnugrep pkgs.systemd ];
    text = builtins.readFile ./openrgb-lights-off.sh;
  };
in
{
  # Fan and pump speeds for the NZXT Kraken X cooler and Smart Device, with curves from processor and graphics temperatures (CoolerControl app).
  programs.coolercontrol.enable = true;
  # The board's own fan headers and sensors sit on its Nuvoton NCT6793D Super I/O chip, which CoolerControl reads and
  # drives through the kernel's nct6775 driver; nothing loads it by default (CoolerControl does not modprobe).
  boot.kernelModules = [ "nct6775" ];
  # This board (ROG MAXIMUS X HERO) is not on nct6775's ASUS WMI list, and its ACPI tables claim the chip's ports
  # (OpRegion \_GPE.HWM, 0x290-0x299), so the driver refuses the chip ("ACPI: OSL: Resource conflict") unless ACPI's
  # claims are made advisory. The cost: firmware code and the driver can now both touch the chip, so a reading can
  # rarely come out wrong. Remove both lines to go back.
  boot.kernelParams = [ "acpi_enforce_resources=lax" ];

  # RGB lighting for the ASUS board, G.Skill RAM, Razer keyboard, Logitech speakers and mouse, and the NZXT controllers (OpenRGB app).
  services.hardware.openrgb = {
    enable = true;
    motherboard = "intel";
  };
  systemd.services.openrgb.serviceConfig.ExecStartPre = "${waitForGpu}";
  # The server only runs at boot, until openrgb-lights-off below has turned the lights off: left running, it kept about
  # twelve threads waking every millisecond (11,400 wakeups a second) to drive lights that are off (audit PF-02). Nothing
  # but openrgb-lights-off starts it, so a switch cannot bring it back either. For the OpenRGB app, start it by hand:
  # sudo systemctl start openrgb (it then runs until stopped or the next boot).
  systemd.services.openrgb.wantedBy = lib.mkForce [ ];

  # At every boot, once OpenRGB has found the devices: all lighting off, the keyboard dim white (openrgb-lights-off.sh),
  # then the server stops.
  systemd.services.openrgb-lights-off = {
    description = "Turn off all RGB lighting, keyboard dim white";
    wantedBy = [ "multi-user.target" ];
    wants = [ "openrgb.service" ];  # not requires: stopping the server at the end must not stop this unit
    after = [ "openrgb.service" "coolercontrold.service" ];
    environment.QT_QPA_PLATFORM = "offscreen";  # OpenRGB is a Qt app; there is no screen at boot
    environment.HOME = "/run/openrgb-lights-off";  # OpenRGB writes a log under $HOME before anything else; without one it crashes
    restartIfChanged = false;  # a switch does not run it again (it re-blacked the lights at every switch)
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;  # "active" after boot, so a switch that starts multi-user.target does not re-run it
      ExecStart = lib.getExe lightsOff;
      # Once every light is off, stop the server ("+": as root despite DynamicUser; --no-block: do not wait on our own job).
      ExecStartPost = "+${pkgs.systemd}/bin/systemctl --no-block stop openrgb.service";
      DynamicUser = true;
      RuntimeDirectory = "openrgb-lights-off";  # its own throwaway OpenRGB settings folder
    };
  };

  # DPI, buttons and polling rate for the Logitech G502 (Piper app).
  services.ratbagd.enable = true;

  # The app for the mouse settings above.
  environment.systemPackages = [ pkgs.piper ];
}
