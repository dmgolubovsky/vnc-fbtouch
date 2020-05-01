# Synth Host with VNC access to video (but sound goes by wires)

from ubuntu:18.04 as base-ubuntu

run cp /etc/apt/sources.list /etc/apt/sources.list~
run sed -Ei 's/^# deb-src /deb-src /' /etc/apt/sources.list
run apt -y update
run apt install -y --no-install-recommends software-properties-common apt-utils
run add-apt-repository -y ppa:apt-fast/stable
run apt -y update
run env DEBIAN_FRONTEND=noninteractive apt-get -y install apt-fast
run echo debconf apt-fast/maxdownloads string 16 | debconf-set-selections
run echo debconf apt-fast/dlflag boolean true | debconf-set-selections
run echo debconf apt-fast/aptmanager string apt-get | debconf-set-selections

run echo "MIRRORS=( 'http://archive.ubuntu.com/ubuntu, http://de.archive.ubuntu.com/ubuntu, http://ftp.halifax.rwth-aachen.de/ubuntu, http://ftp.uni-kl.de/pub/linux/ubuntu, http://mirror.informatik.uni-mannheim.de/pub/linux/distributions/ubuntu/' )" >> /etc/apt-fast.conf

run apt-fast -y update && apt-fast -y upgrade

from base-ubuntu as ardour

run apt-fast install -y libboost-dev libasound2-dev libglibmm-2.4-dev libsndfile1-dev
run apt-fast install -y libcurl4-gnutls-dev libarchive-dev liblo-dev libtag-extras-dev
run apt-fast install -y vamp-plugin-sdk librubberband-dev libudev-dev libnfft3-dev
run apt-fast install -y libaubio-dev libxml2-dev libusb-1.0-0-dev
run apt-fast install -y libpangomm-1.4-dev liblrdf0-dev libsamplerate0-dev
run apt-fast install -y libserd-dev libsord-dev libsratom-dev liblilv-dev
run apt-fast install -y libgtkmm-2.4-dev libsuil-dev libjack-jackd2-dev libcwiid-dev

run apt-fast install -y wget curl

run mkdir /build-ardour
workdir /build-ardour
run wget http://archive.ubuntu.com/ubuntu/pool/universe/a/ardour/ardour_5.12.0-3.dsc
run wget http://archive.ubuntu.com/ubuntu/pool/universe/a/ardour/ardour_5.12.0.orig.tar.bz2
run wget http://archive.ubuntu.com/ubuntu/pool/universe/a/ardour/ardour_5.12.0-3.debian.tar.xz

run dpkg-source -x ardour_5.12.0-3.dsc

workdir /tmp
run curl https://waf.io/waf-1.6.11.tar.bz2 | tar xj
workdir waf-1.6.11

run patch -p1 < /build-ardour/ardour-5.12.0/tools/waflib.patch
run ./waf-light -v --make-waf --tools=misc,doxygen,/build-ardour/ardour-5.12.0/tools/autowaf.py --prelude=''
run cp ./waf /build-ardour/ardour-5.12.0/waf

workdir /build-ardour/ardour-5.12.0
run ./waf configure --no-phone-home --with-backend=jack
run ./waf build -j4
run ./waf install
run apt-fast install -y chrpath rsync unzip
run ln -sf /bin/false /usr/bin/curl
workdir tools/linux_packaging
run ./build --public --strip some
run ./package --public --singlearch

from base-ubuntu as vncsvr

# Install Ardour from the previously created bundle.

run mkdir -p /install-ardour
workdir /install-ardour
copy --from=ardour /build-ardour/ardour-5.12.0/tools/linux_packaging/Ardour-5.12.0-dbg-x86_64.tar .
run tar xvf Ardour-5.12.0-dbg-x86_64.tar
workdir Ardour-5.12.0-dbg-x86_64

# Install some libs that were not picked by bundlers - mainly X11 related.

run apt -y install gtk2-engines-pixbuf libxfixes3 libxinerama1 libxi6 libxrandr2 libxcursor1 libsuil-0-0
run apt -y install libxcomposite1 libxdamage1 liblzo2-2 libkeyutils1 libasound2 libgl1 libusb-1.0-0

# First time it will fail because one library was not copied properly.

run ./.stage2.run || true

# Copy the missing libraries

run cp /usr/lib/x86_64-linux-gnu/gtk-2.0/2.10.0/engines/libpixmap.so Ardour_x86_64-5.12.0-dbg/lib
run cp /usr/lib/x86_64-linux-gnu/suil-0/libsuil_x11_in_gtk2.so Ardour_x86_64-5.12.0-dbg/lib
run cp /usr/lib/x86_64-linux-gnu/suil-0/libsuil_qt5_in_gtk2.so Ardour_x86_64-5.12.0-dbg/lib

# It will ask questions, say no.

run echo -ne "n\nn\nn\nn\nn\n" | ./.stage2.run

# Delete the unpacked bundle

run rm -rf /install-ardour

run env DEBIAN_FRONTEND=noninteractive apt install -y tigervnc-standalone-server tigervnc-xorg-extension
run apt-fast install -y xterm less
run apt-fast install -y x11-apps
run apt-fast install -y mesa-utils

run env DEBIAN_FRONTEND=noninteractive apt-fast install -y xinit alsa-utils locales libturbojpeg0-dev
run env DEBIAN_FRONTEND=noninteractive apt-fast install -y xfce4 dbus-x11 --no-install-recommends
run env DEBIAN_FRONTEND=noninteractive apt-fast install -y adwaita-icon-theme-full xfce4-terminal wget

run env DEBIAN_FRONTEND=noninteractive apt-fast install -y apt-transport-https gpgv 
run wget https://launchpad.net/~kxstudio-debian/+archive/kxstudio/+files/kxstudio-repos_10.0.3_all.deb
run dpkg -i kxstudio-repos_10.0.3_all.deb

run apt-fast -y update

run env DEBIAN_FRONTEND=noninteractive apt-fast install -y cadence zynaddsubfx carla \
        hydrogen hydrogen-data hydrogen-drumkits qtractor kxstudio-meta-audio-plugins-lv2 \
        qmidiarp kxstudio-meta-all \
        kxstudio-meta-audio-applications guitarix-lv2 avw.lv2 ir.lv2 lv2vocoder \
        kxstudio-meta-audio-plugins kxstudio-meta-audio-plugins-collection \
        vim alsa-utils zita-ajbridge zenity mda-lv2 padthv1-lv2 samplv1-lv2 \
        so-synth-lv2 swh-lv2 synthv1-lv2 whysynth wsynth-dssi xsynth-dssi phasex \
        iem-plugin-suite-vst hydrogen-drumkits hydrogen-data guitarix-common

workdir /tmp

run wget https://musical-artifacts.com/artifacts/133/drumkits.tar.bz2

workdir /usr/share/hydrogen/data

run tar xjvf /tmp/drumkits.tar.bz2

run rm  /tmp/drumkits.tar.bz2

run add-apt-repository ppa:mscore-ubuntu/mscore3-stable
run apt-fast -y update
run apt-fast -y install musescore3

# Install docker client only

env docker_url=https://download.docker.com/linux/static/stable/x86_64
env docker_version=18.03.1-ce

run env DEBIAN_FRONTEND=noninteractive apt-fast install -y curl

run curl -fsSL $docker_url/docker-$docker_version.tgz | \
    tar zxvf - --strip 1 -C /usr/bin docker/docker


run locale-gen en_US.UTF-8

copy --from=vnc-fbtouch_evs /espvs /espvs

run apt-fast -y install libnotify-bin notify-osd vim zenity libsonic0 sox strace \
                        html2text net-tools geany zip unzip systemd

workdir /

add xvnc@.service /lib/systemd/system
add xvnc@.socket /lib/systemd/system
add scores.path /lib/systemd/system
add scores.service /lib/systemd/system
add fbcfg /fbcfg
add fbstyle /fbstyle
add usrbin /usr/bin
run systemctl enable xvnc@0.socket
run systemctl enable xvnc@1.socket
run systemctl disable avahi-daemon.service
run ln -sf /usr/share/zoneinfo/America/New_York /etc/localtime
## Finally clean up

run apt-fast clean
run apt-get clean autoclean
run apt-get autoremove -y
run rm -rf /usr/share/fluxbox/styles
run rm -rf /var/lib/apt
run rm -rf /var/lib/dpkg
run rm -rf /var/lib/cache
run rm -rf /var/lib/log
run rm -rf /tmp/*

from scratch
copy --from=vncsvr / / 

env PATH=/bin:/usr/bin:/usr/local/bin:/espvs/bin

