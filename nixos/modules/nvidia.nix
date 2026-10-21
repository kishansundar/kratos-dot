{ config, ... }:

# GTX 1070 (Pascal). The default NVIDIA driver (595) no longer supports Pascal;
# 580 is NVIDIA's last branch for it, with security fixes until Aug 2028.
{
  services.xserver.videoDrivers = [ "nvidia" ];

  hardware.graphics = {
    enable = true;
    enable32Bit = true;   # 32-bit apps and games
  };

  hardware.nvidia = {
    package = config.boot.kernelPackages.nvidiaPackages.legacy_580;
    open = false;               # the open kernel modules need Turing (RTX 20) or newer
    modesetting.enable = true;  # required for mango and every Wayland compositor
    nvidiaSettings = true;
  };
  # No acpid, which the NVIDIA module turns on for its X driver's power and lid events; mango runs on Wayland (audit D11).
  services.acpid.enable = false;

  # mango (wlroots) on the NVIDIA driver.
  environment.sessionVariables = {
    GBM_BACKEND = "nvidia-drm";
    __GLX_VENDOR_LIBRARY_NAME = "nvidia";
    WLR_NO_HARDWARE_CURSORS = "1";  # otherwise the pointer can be invisible or flicker
  };
}
