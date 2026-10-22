{ pkgs, lib, ... }:

# mpv, set up for this machine: the GTX 1070 decodes and scales, the PG279Q shows 1440p at 144 Hz.
# Measured here on 2026-10-14: 1080p takes 4.1 ms per frame, 720p 3.4 ms and 4K HEVC 10-bit 6.1 ms, with no dropped frames.
let
  # Upscaler for luma (brightness detail), any ratio, with anti-ringing; runs only when the video is upscaled.
  # Commit b3f0a59 (2024-01-11) is the newest in bjin/mpv-prescalers.
  ravu = pkgs.fetchurl {
    url = "https://raw.githubusercontent.com/bjin/mpv-prescalers/b3f0a59d68f33b7162051ea5970a5169558f0ea2/gather/ravu-zoom-ar-r3.hook";
    hash = "sha256-Au+3dQtuw21Zb4eqT6rdeXYesYiqAX/6aIbJ460/9ms=";
  };
  # Chroma (colour) upscaler that predicts colour from the sharper luma; better and cheaper than KrigBilateral here.
  # Commit 066dff9 (2026-08-15) is the newest in Artoriuz/glsl-chroma-from-luma-prediction.
  cfl = pkgs.fetchurl {
    url = "https://raw.githubusercontent.com/Artoriuz/glsl-chroma-from-luma-prediction/066dff964b83aa34e893de25d590874bf8c8e94f/CfL_Prediction.glsl";
    hash = "sha256-+dEtONS6tNnbJmtZgsgfrcqQc5YhLiL9iywcovMXtxY=";
  };
  # Downscaler for videos bigger than the screen (4K); runs only when downscaling.
  ssimDownscaler = "${pkgs.mpv-shim-default-shaders}/share/mpv-shim-default-shaders/shaders/SSimDownscaler.glsl";

  # Flips the picture on the GPU. The hflip/vflip filters would copy every frame back from NVDEC to the CPU.
  flip = name: pos: pkgs.writeText "${name}.glsl" ''
    //!HOOK MAIN
    //!BIND HOOKED
    //!DESC ${name}
    vec4 hook() { return HOOKED_tex(${pos}); }
  '';
  hflip = flip "hflip" "vec2(1.0 - HOOKED_pos.x, HOOKED_pos.y)";
  vflip = flip "vflip" "vec2(HOOKED_pos.x, 1.0 - HOOKED_pos.y)";

  # Video types mpv opens by default (Celluloid used to).
  videoTypes = [
    "video/mp4" "video/x-matroska" "video/matroska" "video/webm" "video/quicktime" "video/x-msvideo"
    "video/vnd.avi" "video/mpeg" "video/x-flv" "video/x-ms-wmv" "video/ogg" "video/3gpp" "video/mp2t"
  ];
in
{
  environment.systemPackages = [
    # mpris: media keys and playerctl control mpv; uosc: modern controls; thumbfast: thumbnails on the seek bar.
    (pkgs.mpv.override { scripts = with pkgs.mpvScripts; [ mpris uosc thumbfast ]; })
  ];

  # mpv reads /etc/mpv/mpv.conf first, then ~/.config/mpv/mpv.conf, so personal changes can go in the second.
  environment.etc."mpv/mpv.conf".text = ''
    # Renderer: libplacebo (gpu-next) on Vulkan, the best-supported path for NVIDIA on Wayland.
    vo=gpu-next
    gpu-api=vulkan
    gpu-context=waylandvk

    # Decoding on the GTX 1070's NVDEC chip (H.264, HEVC 8/10-bit, VP9, MPEG-2, VC-1), passed to Vulkan without a copy.
    # Vulkan Video is the second choice. AV1 has no decoder on this card, so it falls back to the CPU.
    hwdec=nvdec,vulkan

    # Scaling. The shaders switch themselves on only when they apply.
    profile=high-quality
    glsl-shaders-append=${ravu}
    glsl-shaders-append=${cfl}
    glsl-shaders-append=${ssimDownscaler}
    dscale=mitchell
    linear-downscaling=no
    deband=yes

    # Smooth motion at 144 Hz: play in step with the screen and blend frames instead of juddering.
    video-sync=display-resample
    interpolation=yes
    tscale=oversample

    # Online video: up to 1440p, and not AV1, so the GPU decodes it instead of the CPU.
    ytdl-format=bestvideo[height<=?1440][vcodec!^=av01]+bestaudio/best

    # uosc draws the controls and the window bar.
    osc=no
    osd-bar=no
    border=no

    # Playback. mpv doesn't remember where a video stopped (no watch_later files), so nothing records what was played.
    keep-open=yes
    save-position-on-quit=no
    sub-auto=fuzzy
    slang=en,eng
    volume-max=150
  '';

  # Read only while ~/.config/mpv/input.conf doesn't exist. Alt+v replaces the default secondary-subtitle toggle.
  environment.etc."mpv/input.conf".text = ''
    Alt+h no-osd change-list glsl-shaders toggle ${hflip}; show-text "Flip horizontal"
    Alt+v no-osd change-list glsl-shaders toggle ${vflip}; show-text "Flip vertical"
  '';

  xdg.mime.defaultApplications = lib.genAttrs videoTypes (_: "mpv.desktop");
}
