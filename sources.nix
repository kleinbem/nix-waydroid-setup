# Sources for Waydroid setup
# Assets fetched at build time (cached, reproducible)
{ pkgs }:

{
  # Libhoudini - ARM translation for x86_64 (Android 11)
  houdini = pkgs.fetchzip {
    url = "https://github.com/supremegamers/vendor_intel_proprietary_houdini/archive/81f2a51ef539a35aead396ab7fce2adf89f46e88.zip";
    hash = "sha256-I6G0aaHFIMSOeh1rtlTfjbwSNX1wpSXhNSVcbBrNNQs=";
  };

  # Widevine DRM L3 (Android 11 x86_64)
  widevine = pkgs.fetchzip {
    url = "https://github.com/supremegamers/vendor_google_proprietary_widevine-prebuilt/archive/48d1076a570837be6cdce8252d5d143363e37cc1.zip";
    hash = "sha256-ry+LKhhYPcqPliqPSWkFABmulGMeWbLdQlEa9acoEj8=";
  };

  # Magisk Delta APK
  magisk = pkgs.fetchurl {
    url = "https://github.com/mistrmochov/magiskdeltaorig/raw/main/app-release.apk";
    hash = "sha256-o8N8QXK2zn/fvMyypgjvhLCiZ9eq73wYMEetzrhJTIA=";
  };
}
