#!/bin/bash

# export $(dbus-launch)
# chmod 777 /dev/vchiq

# startx -- :0 &
/usr/bin/X -s 0 dpms -nolisten tcp :0 &
# sleep 2

export DISPLAY=:0
# xset -dpms
# xset s off
# xset s noblank

# unclutter &

# chromium-browser http://www.quirksmode.org/html5/tests/video.html --no-sandbox --window-size=800,480 --start-fullscreen --start-maximized --kiosk --incognito --noerrdialogs --disable-translate --no-first-run --fast --fast-start --disable-infobars --disable-features=TranslateUI --process-per-site --num-raster-threads=4 --ignore-gpu-blacklist --enable-g-rasterization --enable-native-gpu-memory-buffers --enable-checker-imaging --disable-quic --enable-tcp-fast-open --disable-gpu-compositing --enable-fast-unload --enable-experimental-canvas-features --enable-scroll-prediction --enable-simple-cache-backend --answers-in-suggest --disable-session-crashed-bubble --touch-events=enabled --allow-running-insecure-content --use-gl=egl

chromium-browser http://www.quirksmode.org/html5/tests/video.html --no-sandbox --start-fullscreen --start-maximized --kiosk --incognito --noerrdialogs --disable-translate --no-first-run --fast --fast-start --disable-infobars --disable-features=TranslateUI --purge-memory-button --smooth-scrolling --no-pings --disable-background-mode --dns-prefetch-disable --ignore-gpu-blacklist --enable-gpu-rasterization --enable-native-gpu-memory-buffers --enable-lazy-image-loading --enable-lazy-frame-loading --enable-checker-imaging --enable-quic --enable-resource-prefetch --enable-tcp-fast-open --disable-gpu-compositing --enable-fast-unload --enable-experimental-canvas-features --enable-scroll-prediction --enable-scroll-anchoring --enable-tab-audio-muting --disable-background-video-track --enable-simple-cache-backend --answers-in-suggest --ppapi-flash-path=/usr/lib/chromium-browser/libpepflashplayer.so --ppapi-flash-args=enable_stage_stagevideo_auto=0 --ppapi-flash-version= --max-tiles-for-interest-area=512 --num-raster-threads=4 --default-tile-height=512
