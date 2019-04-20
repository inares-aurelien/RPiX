# WARNING: this is a test version

# DOCKER_BUILDKIT=1 docker build --progress=plain -t rpix .
# docker run --privileged --rm -it -p 1234:1234/udp --device=/dev/dri/card0:/dev/dri/card0 --device=/dev/input/event0:/dev/input/event0 -v /var/run/dbus:/run/dbus --shm-size=350MB --tmpfs /run --tmpfs /var/log --tmpfs /tmp --log-driver=none --entrypoint /bin/bash rpix

FROM arm32v7/alpine:edge

COPY tmp/qemu-arm-static /usr/bin/qemu-arm-static

ENV XORGVER=1.20.4
ENV XORGNAME=xorg-server-$XORGVER

RUN apk update && apk --no-cache upgrade

RUN \
      apk --no-cache add bash sudo git wget nano \
          linux-headers build-base gcc g++ make \
          autoconf automake util-macros gettext libtool \
          libpthread-stubs eudev-dev libpciaccess-dev xmlto \               
          cmake raspberrypi-libs \
          font-misc-misc font-cursor-misc xkeyboard-config xkbcomp xinit libepoxy-dev libxfont2-dev mesa-dev eudev-dev libdrm-dev libepoxy-dev libpciaccess-dev openssl-dev libtool libx11-dev libxdamage-dev libxinerama-dev libxkbfile-dev libxkbui-dev libxv-dev libxxf86dga-dev libxxf86misc-dev perl pixman-dev util-macros wayland-dev wayland-protocols xcb-util-dev xcb-util-image-dev xcb-util-keysyms-dev xcb-util-renderutil-dev xcb-util-wm-dev xorgproto xtrans zlib-dev

# For libdrm
# For fbturbo
# For Userland

# RUN apk add dbus mesa-dri-vc4 xorg-server-dev

WORKDIR /home/

RUN \
     wget -qO- https://www.x.org/releases/individual/xserver/${XORGNAME}.tar.gz | tar xz \
 &&  cd xorg-server-* \
 &&  export CFLAGS="-mcpu=cortex-a53 -mfloat-abi=hard -mfpu=neon-fp-armv8 -mneon-for-64bits -Ofast -D_GNU_SOURCE" \
 &&  export CFLAGS="$CFLAGS -D__gid_t=gid_t -D__uid_t=uid_t" \
 &&  ./configure --prefix=/usr --sysconfdir=/etc/X11 --localstatedir=/var --with-xkb-path=/usr/share/X11/xkb --with-xkb-output=/var/lib/xkb --without-systemd-daemon --enable-composite --enable-config-udev --enable-dri --enable-dri2 --enable-glamor --enable-kdrive --enable-xace --enable-xcsecurity --enable-xephyr --enable-xnest --enable-xorg --enable-xres --enable-xv --enable-xwayland --disable-config-hal --disable-dmx --disable-systemd-logind --enable-install-setuid --with-os-vendor="${DISTRO_NAME:-Alpine Linux}" \
 &&  make -j 2 install \
 &&  cd .. \
 &&  rm -rf xorg-server-*

#patch hw/xfree86/common/compiler.h  < 'musl-arm-inb-outb.patch'
#wget https://github.com/kraj/poky/raw/master/meta/recipes-graphics/xorg-xserver/xserver-xorg/musl-arm-inb-outb.patch
#export CFLAGS="-mcpu=cortex-a53 -mfloat-abi=hard -mfpu=neon-fp-armv8 -mneon-for-64bits -Ofast -D__KERNEL_STRICT_NAMES"


RUN \
     echo -e "\n\n\n***** Build & Install fbturbo *****\n" \
 &&  git clone https://github.com/ssvb/xf86-video-fbturbo.git --depth=1 \
 &&  cd xf86-video-fbturbo/ \
 &&  autoreconf -vi \
 &&  ./configure --prefix=/usr \
 &&  time make -j $(nproc --all) install \
 &&  cd .. \
 &&  rm -rf xf86-video-fbturbo/


RUN \
     echo -e "\n\n\n***** Build & Install Userland *****\n" \
 &&  git clone https://github.com/raspberrypi/userland.git --depth=1 \
 &&  cd userland \
 &&  time ./buildme \
 &&  cd .. \
 &&  rm -rf userland
  # dropbear mesa-gl xvfb x11vnc xsetroot xterm twm expect shadow
# build-base gcc wget git xorg-server-dev


RUN \
     echo "\n\n\n***** Build & Install libdrm *****\n" \
 &&  git clone git://anongit.freedesktop.org/mesa/drm --depth=1 \
 &&  cd drm \
 &&  ./autogen.sh --prefix=/usr --libdir=/usr/lib/arm-linux-gnueabihf/ --disable-vmwgfx --disable-nouveau --disable-libkms --disable-intel --disable-radeon --disable-amdgpu --disable-freedreno --enable-udev \
 &&  make install \
 &&  cd .. \
 &&  rm -rf drm \


