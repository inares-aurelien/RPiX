##########################################
#### WARNING: this is a test version  ####
##########################################

# DOCKER_BUILDKIT=1 docker build --progress=plain -t rpix .
# docker run --privileged --rm -it -p 1234:1234/udp --device=/dev/dri/card0:/dev/dri/card0 --device=/dev/input/event0:/dev/input/event0 -v /var/run/dbus:/run/dbus --shm-size=350MB --tmpfs /run --tmpfs /var/log --tmpfs /tmp --log-driver=none --entrypoint /bin/bash rpix

FROM arm32v7/alpine:edge

# COPY tmp/qemu-arm-static /bin/qemu-arm-static

RUN echo -e "\n\n\n***** Update & Upgrade *****\n" && apk --no-cache upgrade

RUN \
     echo -e "\n\n\n***** Install base packages *****\n" \
 &&  apk --no-cache add sudo wget nano gcc g++ make cmake util-macros pkgconf zlib-dev freetype-dev fontconfig-dev \
            python3 libpthread-stubs linux-headers py-mako meson bison flex libunwind llvm7

# RUN apk add dbus mesa-dri-vc4 xorg-server-dev git bash
# dropbear mesa-gl xvfb x11vnc xsetroot xterm twm expect shadow
# build-base gcc wget git xorg-server-dev

WORKDIR /home/

ARG XORGPROTOVER=2018.4
ARG LIBXAUVER=1.0.9
ARG XCBPROTOVER=1.13
ARG LIBXCBVER=1.13.1
ARG LIBDRMVER=2.4.98
ARG XORGVER=1.20.4
ARG MESAVER=19.0.2

# ENV XORGNAME=xorg-server-$XORGVER
ARG CFLAGS="-mcpu=cortex-a53 -mfloat-abi=hard -mfpu=neon-fp-armv8 -mneon-for-64bits -Ofast"
ARG CXXFLAGS="-mcpu=cortex-a53 -mfloat-abi=hard -mfpu=neon-fp-armv8 -mneon-for-64bits -Ofast"
ARG CPPFLAGS="-mcpu=cortex-a53 -mfloat-abi=hard -mfpu=neon-fp-armv8 -mneon-for-64bits -Ofast"
ARG XORG_CONFIG="-q --prefix=/usr --sysconfdir=/etc --localstatedir=/var --datadir=/usr/lib"
# ENV TIMEFORMAT="Elapsed time: %2lR   |  CPU in user mode: %2lU  |  CPU in system mode: %2lS  |  CPU percentage: %P"

# https://git.busybox.net/busybox/tree/miscutils/time.c
ARG TIMEFORMAT="Elapsed time: %E   |  CPU in user mode: %u  |  CPU in system mode: %T  |  CPU percentage: %P"


RUN \
     echo -e "\n\n\n***** Build & Install Xorg Protocol Headers *****\n" \
 &&  wget -qO- https://xorg.freedesktop.org/archive/individual/proto/xorgproto-${XORGPROTOVER}.tar.bz2 | tar xj \
 &&  cd xorgproto-* \
 &&  ./configure $XORG_CONFIG \
 &&  time -f "$TIMEFORMAT" make -s install \
 &&  cd .. \
 &&  rm -rf xorgproto-*

 
RUN \
     echo -e "\n\n\n***** Build & Install X11 authorisation library (libXau) *****\n" \
 &&  wget -qO- https://www.x.org/releases/individual/lib/libXau-${LIBXAUVER}.tar.bz2 | tar xj \
 &&  cd libXau-* \
 &&  ./configure $XORG_CONFIG \
 &&  time -f "$TIMEFORMAT" make -s -j $(nproc --all) install \
 &&  cd .. \
 &&  rm -rf libXau-*


RUN \
     echo -e "\n\n\n***** Build & Install XML-XCB protocol (xcb-proto) *****\n" \
 # &&  apk --no-cache add python3 \
 &&  wget -qO- https://xcb.freedesktop.org/dist/xcb-proto-${XCBPROTOVER}.tar.bz2 | tar xj \
 &&  cd xcb-proto-* \
 &&  ./configure $XORG_CONFIG \
 &&  time -f "$TIMEFORMAT" make -s -j $(nproc --all) install \
 &&  cd .. \
 &&  rm -rf xcb-proto-*


RUN \
     echo -e "\n\n\n***** Build & Install X11 client-side library (libxcb) *****\n" \
 # &&  apk --no-cache add libpthread-stubs \
 &&  wget -qO- https://xcb.freedesktop.org/dist/libxcb-${LIBXCBVER}.tar.bz2 | tar xj \
 &&  cd libxcb-* \
 &&  ./configure $XORG_CONFIG --disable-screensaver --disable-xinerama --disable-xkb --disable-xtest --disable-devel-docs \
 &&  time -f "$TIMEFORMAT" make -s -j $(nproc --all) install \
 &&  cd .. \
 &&  rm -rf libxcb-*


# Change default shell from ash to bash
# SHELL ["/bin/bash", "-c"]
COPY xorglib.txt libpciaccess.patch /home/

RUN \
     echo -e "\n\n\n***** Build & Install Xorg Libraries *****\n" \
 # &&  apk --no-cache add zlib-dev freetype-dev fontconfig-dev \
 &&  mkdir -p /home/xorglib \
 # &&  echo -e "/usr/lib\n/lib/" > /etc/ld.so.conf \
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
 # &&  ldconfig /etc/ld.so.conf \
 &&  cd /home \
 &&  rm -rf xorglib


# libpthread-stubs linux-headers
RUN \
     echo -e "\n\n\n***** Build & Install Userspace interface to kernel DRM services (libdrm) *****\n" \
 &&  wget -qO- https://dri.freedesktop.org/libdrm/libdrm-${LIBDRMVER}.tar.bz2 | tar xj \
 &&  cd libdrm-* \
 &&  time ./configure -q --prefix=/usr --libdir=/usr/lib/arm-linux-gnueabihf/ --disable-vmwgfx --disable-nouveau --disable-libkms --disable-intel --disable-radeon --disable-amdgpu --disable-freedreno --enable-udev \
 &&  time make -s -j $(nproc --all) install \
 &&  cd .. \
 &&  rm -rf libdrm-*


# zlib-dev py-mako meson libdrm bison flex libunwind llvm7
RUN \
     echo -e "\n\n\n***** Build & Install Mesa *****\n" \
 # &&  pip3 install setuptools \
 # &&  pip3 install wheel \
 # &&  pip3 install mako \
 # &&  pip3 install meson \
 &&  wget -qO- ftp://ftp.freedesktop.org/pub/mesa/mesa-${MESAVER}.tar.xz | tar xJ \
 &&  cd mesa-* \
 &&  meson build --prefix=/usr --libdir=/usr/lib/arm-linux-gnueabihf/ -DLLVM_BUILD_TESTS=OFF -DLLVM_BUILD_DOCS=OFF -DLLVM_BUILD_EXAMPLES=OFF -DLLVM_INCLUDE_EXAMPLES=OFF -Dbuildtype=release -Dplatforms=x11,drm,surfaceless -Ddri-drivers= -Dgallium-drivers=vc4,v3d -Ddri3=false \
 &&  ninja -C build install \
 &&  cd .. \
 &&  rm -rf mesa \
 &&  rm mesa-${MESAVER}.tar.xz


# RUN \
     # wget -qO- https://www.x.org/releases/individual/xserver/${XORGNAME}.tar.gz | tar xz \
 # &&  cd xorg-server-* \
 # &&  wget https://github.com/kraj/poky/raw/master/meta/recipes-graphics/xorg-xserver/xserver-xorg/musl-arm-inb-outb.patch \
 # &&  patch hw/xfree86/common/compiler.h  < 'musl-arm-inb-outb.patch' \
 # &&  export CFLAGS="-mcpu=cortex-a53 -mfloat-abi=hard -mfpu=neon-fp-armv8 -mneon-for-64bits -Ofast -D_GNU_SOURCE -D__KERNEL_STRICT_NAMES" \
 # &&  ./configure --prefix=/usr --sysconfdir=/etc/X11 --localstatedir=/var --without-systemd-daemon --enable-composite --enable-config-udev --enable-dri --enable-dri2 --enable-glamor --enable-kdrive --enable-xvfb --enable-xorg --enable-xres --enable-xv --enable-xwayland --disable-config-hal --disable-dmx --disable-systemd-logind --enable-install-setuid --with-os-vendor="${DISTRO_NAME:-Alpine Linux}" \
 # &&  time make -j $(nproc --all) install \
 # &&  cd .. \
 # &&  rm -rf xorg-server-*

 # --with-xkb-path=/usr/share/X11/xkb --with-xkb-output=/var/lib/xkb
#export CFLAGS="-mcpu=cortex-a53 -mfloat-abi=hard -mfpu=neon-fp-armv8 -mneon-for-64bits -Ofast -D__KERNEL_STRICT_NAMES"


RUN \
     echo -e "\n\n\n***** Build & Install fbturbo *****\n" \
 # &&  git clone https://github.com/ssvb/xf86-video-fbturbo.git --depth=1 \
 &&  wget -qO- https://github.com/ssvb/xf86-video-fbturbo/archive/master.tar.gz | tar xz \
 &&  cd xf86-video-fbturbo-master \
 &&  autoreconf -vi \
 &&  ./configure -q --prefix=/usr \
 &&  time make V=0 -s -j $(nproc --all) install \
 &&  cd .. \
 &&  rm -rf xf86-video-fbturbo/


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

