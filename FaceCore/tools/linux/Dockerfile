# Connect IQ SDK Manager, simulator and compiler on Linux hosts whose distro dropped
# webkit2gtk-4.0 / libjpeg8 (Debian 13). The SDK itself stays on the host in ~/.Garmin,
# mounted by ciq.sh; this image only carries the libraries and Java.
FROM ubuntu:22.04
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
        openjdk-17-jre-headless libwebkit2gtk-4.0-37 libjpeg8 libcurl4 libpng16-16 libgtk-3-0 libusb-1.0-0 \
        libsecret-1-0 libsm6 libxext6 libxrender1 libxtst6 libcanberra-gtk3-module dbus-x11 \
        ca-certificates fonts-dejavu-core xauth xvfb unzip \
    && rm -rf /var/lib/apt/lists/*
