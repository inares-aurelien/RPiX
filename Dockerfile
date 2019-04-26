# syntax=docker/dockerfile:1.0.0-experimental

##########################################
#### WARNING: this is a test version  ####
##########################################

# DOCKER_BUILDKIT=1 docker build --progress=plain -t rpix .
# docker run --privileged --rm -it -p 1234:1234/udp --device=/dev/dri/card0:/dev/dri/card0 --device=/dev/input/event0:/dev/input/event0 -v /var/run/dbus:/run/dbus --shm-size=350MB --tmpfs /run --tmpfs /var/log --tmpfs /tmp --log-driver=none --entrypoint /bin/bash rpix

FROM arm32v7/alpine:edge

ARG XORGPROTOVER=2018.4
ARG LIBXAUVER=1.0.9
ARG XCBPROTOVER=1.13
ARG LIBXCBVER=1.13.1
ARG LIBDRMVER=2.4.98
ARG XORGVER=1.20.4
ARG MESAVER=19.0.2
ARG XSERVERVER=1.19.7
ARG FBDEVVER=0.5.0
ARG WAYLANDVER=1.17.0
ARG WAYLANDPROTOVER=1.17
ARG LIBEPOXY=1.5.3

# https://git.busybox.net/busybox/tree/miscutils/time.c
ARG TIMEFORMAT="Elapsed time: %E   |  CPU in user mode: %u  |  CPU in system mode: %T  |  CPU percentage: %P"

# ENV XORGNAME=xorg-server-$XORGVER
ARG CFLAGS="-mcpu=cortex-a53 -mfloat-abi=hard -mfpu=neon-fp-armv8 -mneon-for-64bits -Ofast"
ARG CXXFLAGS="-mcpu=cortex-a53 -mfloat-abi=hard -mfpu=neon-fp-armv8 -mneon-for-64bits -Ofast"
ARG CPPFLAGS="-mcpu=cortex-a53 -mfloat-abi=hard -mfpu=neon-fp-armv8 -mneon-for-64bits -Ofast"
ARG XORG_CONFIG="-q --prefix=/usr --libdir=/usr/lib/ --sysconfdir=/etc --localstatedir=/var --datadir=/usr/lib"
# ENV TIMEFORMAT="Elapsed time: %2lR   |  CPU in user mode: %2lU  |  CPU in system mode: %2lS  |  CPU percentage: %P"


# COPY tmp/qemu-arm-static /bin/qemu-arm-static

RUN \
     echo -e "\n\n\n***** Update & Upgrade *****\n" \
 &&  apk --no-cache upgrade \
 \
 &&  echo -e "\n\n\n***** Install base packages *****\n" \
 &&  apk --no-cache add wget nano chromium

# RUN apk add dbus mesa-dri-vc4 xorg-server-dev git dbus-x11
# dropbear mesa-gl xvfb x11vnc xsetroot xterm twm expect shadow
# build-base gcc wget git xorg-server-dev libepoxy-dev

# TODO dbus-x11 instal libX11

WORKDIR /home/



# Change default shell from ash to bash
# SHELL ["/bin/bash", "-c"]
# COPY xorglib.txt libpciaccess.patch types.h.patch start_chrome.sh /home/
COPY start_chrome.sh /bin/

RUN --mount=type=bind,target=/home/,source=/home/,rw \
     echo -e "\n\n\n***** Install packages for compiling *****\n" \
 &&  pwd && ls -alhR \
 &&  apk --no-cache add bash sudo gcc g++ make cmake util-macros pkgconf zlib-dev freetype-dev fontconfig-dev \
            python3 libpthread-stubs linux-headers py-mako meson bison flex llvm7 autoconf automake libtool \
            libffi-dev libxml2-dev pixman-dev eudev-dev openssl-dev xkeyboard-config xkbcomp \
 \
 &&  echo -e "\n\n\n***** Build & Install Xorg Protocol Headers (xorgproto) *****\n" \
 &&  wget -qO- https://xorg.freedesktop.org/archive/individual/proto/xorgproto-${XORGPROTOVER}.tar.bz2 | tar xj \
 &&  cd xorgproto-* \
 &&  ./configure $XORG_CONFIG \
 &&  time -f "$TIMEFORMAT" make V=0 -s install \
 &&  cd .. \
 &&  rm -rf xorgproto-* \
 \
 &&  echo -e "\n\n\n***** Build & Install X11 authorisation library (libXau) *****\n" \
 &&  wget -qO- https://www.x.org/releases/individual/lib/libXau-${LIBXAUVER}.tar.bz2 | tar xj \
 &&  cd libXau-* \
 &&  ./configure $XORG_CONFIG \
 &&  time -f "$TIMEFORMAT" make V=0 -s -j $(nproc --all) install \
 &&  cd .. \
 &&  rm -rf libXau-* \
 \
# python3
 &&  echo -e "\n\n\n***** Build & Install XML-XCB protocol (xcb-proto) *****\n" \
 &&  wget -qO- https://xcb.freedesktop.org/dist/xcb-proto-${XCBPROTOVER}.tar.bz2 | tar xj \
 &&  cd xcb-proto-* \
 &&  ./configure $XORG_CONFIG \
 &&  time -f "$TIMEFORMAT" make V=0 -s -j $(nproc --all) install \
 &&  cd .. \
 &&  rm -rf xcb-proto-* \
 \
# libpthread-stubs python3
 &&  echo -e "\n\n\n***** Build & Install X11 client-side library (libxcb) *****\n" \
 &&  wget -qO- https://xcb.freedesktop.org/dist/libxcb-${LIBXCBVER}.tar.bz2 | tar xj \
 &&  cd libxcb-* \
 &&  ./configure $XORG_CONFIG --disable-screensaver --disable-xinerama --enable-xkb --disable-xtest --without-doxygen \
 &&  time -f "$TIMEFORMAT" make V=0 -s -j $(nproc --all) install \
 &&  cd .. \
 &&  rm -rf libxcb-* \
 \
# zlib-dev freetype-dev fontconfig-dev
 &&  echo -e "\n\n\n***** Build & Install Xorg Libraries *****\n" \
 &&  mkdir -p /home/xorglib \
 &&  for package in $(grep -v '^#' /home/xorglib.txt) ; do \
       packagedir=${package%.tar.bz2} \
       && echo -e "\n\n---- $packagedir ----\n" \
       && echo "Downloading ..." \
       && wget -qcO- https://www.x.org/pub/individual/lib/$package | tar xj -C /home/xorglib \
       && cd /home/xorglib/$packagedir \
       && echo "Configuring ..." \
       && case $packagedir in \
         libxshmfence* ) \
           ./configure $XORG_CONFIG CFLAGS="$CFLAGS -D_GNU_SOURCE" \
         ;; \
 \
         libpciaccess* ) \
           patch src/linux_sysfs.c < /home/libpciaccess.patch && \
           ./configure $XORG_CONFIG \
         ;; \
 \
         libICE* ) \
           ./configure $XORG_CONFIG ICE_LIBS=-lpthread \
         ;; \
 \
         libXfont2-[0-9]* ) \
           ./configure $XORG_CONFIG --disable-devel-docs \
         ;; \
 \
         libXt-[0-9]* ) \
           ./configure $XORG_CONFIG --with-appdefaultdir=/etc/X11/app-defaults \
         ;; \
 \
         libXpm* ) \
           ac_cv_search_gettext=no ./configure $XORG_CONFIG \
         ;; \
 \
         * ) \
           ./configure $XORG_CONFIG \
         ;; \
       esac \
       && echo "Compiling ..." \
       && time make V=0 -s -j $(nproc --all) install > /dev/null || break ; \
     done \
 &&  cd /home \
 &&  rm -rf xorglib \
 \
# libpthread-stubs linux-headers
 &&  echo -e "\n\n\n***** Build & Install Userspace interface to kernel DRM services (libdrm) *****\n" \
 &&  wget -qO- https://dri.freedesktop.org/libdrm/libdrm-${LIBDRMVER}.tar.bz2 | tar xj \
 &&  cd libdrm-* \
 &&  time ./configure -q --prefix=/usr --libdir=/usr/lib/ --disable-vmwgfx --disable-nouveau --disable-libkms --disable-intel --disable-radeon --disable-amdgpu --disable-freedreno --enable-udev \
 &&  time make V=0 -s -j $(nproc --all) install \
 &&  cd .. \
 &&  rm -rf libdrm-* \
 \
# zlib-dev py-mako meson libdrm bison flex libunwind-dev llvm7 gettext
 &&  echo -e "\n\n\n***** Build & Install Mesa *****\n" \
 &&  apk --no-cache add gettext \
 &&  wget -qO- ftp://ftp.freedesktop.org/pub/mesa/mesa-${MESAVER}.tar.xz | tar xJ \
 &&  cd mesa-* \
 &&  meson build --prefix=/usr --libdir=/usr/lib/ -Dbuildtype=release -Dplatforms=x11,drm,surfaceless -Ddri-drivers= -Dgallium-drivers=vc4,v3d,swrast -Ddri3=false \
 &&  ninja -j 2 -C build install \
 &&  cd .. \
 &&  rm -rf mesa* \
 \
# libffi-dev libxml2-dev
 &&  echo -e "\n\n\n***** Build & Install Wayland *****\n" \
 # &&  apk --no-cache add libffi-dev libxml2-dev \
 &&  wget -qO- https://wayland.freedesktop.org/releases/wayland-${WAYLANDVER}.tar.xz | tar xJ \
 &&  cd wayland-* \
 &&  ./configure --prefix=/usr --disable-static --disable-documentation \
 &&  make install \
 &&  cd .. \
 &&  rm -rf wayland* \
 \
 &&  echo -e "\n\n\n***** Build & Install Wayland protocols *****\n" \
 # &&  apk --no-cache add gettext \
 &&  wget -qO- https://wayland.freedesktop.org/releases/wayland-protocols-${WAYLANDPROTOVER}.tar.xz | tar xJ \
 &&  cd wayland-protocols* \
 &&  ./configure --prefix=/usr \
 &&  make install \
 &&  cd .. \
 &&  rm -rf wayland* \
 \
 &&  echo -e "\n\n\n***** Build & Install libepoxy *****\n" \
 &&  wget -qO- https://github.com/anholt/libepoxy/releases/download/${LIBEPOXY}/libepoxy-${LIBEPOXY}.tar.xz | tar xJ \
 &&  cd libepoxy-* \
 &&  mkdir _build && cd _build \
 &&  meson \
 &&  ninja -j 4 install \
 &&  cd ../.. \
 &&  rm -rf libepoxy-* \
 \
# pixman-dev eudev-dev openssl-dev
 &&  echo -e "\n\n\n***** Build & Install Xorg Server *****\n" \
 # &&  apk --no-cache add pixman-dev eudev-dev openssl-dev libepoxy-dev \
 &&  wget -qO- ftp://ftp.x.org/pub/individual/xserver/xorg-server-${XSERVERVER}.tar.bz2 | tar xj \
 &&  cd xorg-server-* \
 &&  patch /usr/include/sys/types.h < /home/types.h.patch \
 &&  ./configure --prefix=/usr --libdir=/usr/lib/ --sysconfdir=/etc/X11 --localstatedir=/var --with-fontrootdir=/usr/share/fonts/X11/ --without-systemd-daemon --enable-composite --enable-config-udev --enable-dri --enable-dri2 --enable-glamor --enable-kdrive --enable-xvfb --enable-xorg --enable-xres --enable-xv --enable-xwayland --enable-kdrive-evdev --disable-config-hal --disable-dmx --disable-systemd-logind --disable-unit-tests --disable-selective-werror --disable-devel-docs --disable-xinerama --disable-screensaver --enable-install-setuid --with-os-vendor="${DISTRO_NAME:-Alpine Linux}" \
 &&  time make V=0 -s -j 2 install \
 &&  cd .. \
 &&  rm -rf xorg-server* \
 \
# Need xorg-server macros
# autoconf automake gettext libtool
 &&  echo -e "\n\n\n***** Build & Install fbturbo *****\n" \
 # &&  apk --no-cache add autoconf automake gettext libtool \
 &&  wget -qO- https://github.com/ssvb/xf86-video-fbturbo/archive/master.tar.gz | tar xz \
 &&  cd xf86-video-fbturbo-master \
 &&  autoreconf -vi \
 &&  ./configure -q --prefix=/usr \
 &&  time make V=0 -s -j $(nproc --all) install \
 &&  cd .. \
 &&  rm -rf xf86-video-fbturbo* \
 \
 &&  echo -e "\n\n\n***** Build & Install fbdev *****\n" \
 # &&  apk --no-cache add autoconf automake gettext libtool \
 &&  wget -qO- https://www.x.org/archive/individual/driver/xf86-video-fbdev-${FBDEVVER}.tar.bz2 | tar xj \
 &&  cd xf86-video-fbdev* \
 &&  ./configure $XORG_CONFIG \
 &&  time make V=0 -s -j $(nproc --all) install \
 &&  cd .. \
 &&  rm -rf xf86-video-fbdev* \
 \
 &&  chmod 777 /bin/start_chrome.sh \
 \
 &&  echo "\n\n\n***** Clean  *****\n" \
 &&  apk --no-cache del bash sudo gcc g++ make cmake util-macros pkgconf zlib-dev freetype-dev fontconfig-dev \
            python3 libpthread-stubs linux-headers py-mako meson bison flex llvm7 autoconf automake libtool \
            libffi-dev libxml2-dev pixman-dev eudev-dev openssl-dev xkeyboard-config xkbcomp \
 &&  rm -rf /usr/share/doc/ \
 &&  rm -rf /usr/share/man/
 


 COPY 10-modules.conf /usr/share/X11/xorg.conf.d/

# COPY userland.patch /home/
# RUN \
     # echo -e "\n\n\n***** Build & Install Userland *****\n" \
##  &&  git clone https://github.com/raspberrypi/userland.git --depth=1 \
 # &&  wget -qO- https://github.com/raspberrypi/userland/archive/master.tar.gz | tar xz \
 # &&  cd userland-master \
 # &&  patch host_applications/linux/CMakeLists.txt < /home/userland.patch \
##  &&  time ./buildme \
 # &&  mkdir -p build/ \
 # &&  cd build/ \
 # &&  cmake -DCMAKE_BUILD_TYPE=release -DARM64=OFF .. \
 # &&  time -f "$TIMEFORMAT" make V=0 -s -j $(nproc --all) install \
 # &&  cd /home \
 # &&  rm -rf userland

CMD [ "sh" ]


