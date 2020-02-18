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

from base-ubuntu as vncsvr

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
        hydrogen hydrogen-data hydrogen-drumkits qtractor kxstudio-meta-audio-plugins-lv2

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

run apt-fast -y install libnotify-bin notify-osd vim zenity libsonic0 sox strace html2text net-tools geany

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

