#!/bin/bash

# This script provides common customization options for the ISO
# 
# Usage: Copy this file to config.sh and make changes there.  Keep this file (default_config.sh) as-is
#   so that subsequent changes can be easily merged from upstream.  Keep all customiations in config.sh

# The version of Ubuntu to generate.
# 26.04 LTS codename is "resolute" (Resolute Raccoon), released April 2026.
export TARGET_UBUNTU_VERSION="resolute"

# The Ubuntu Mirror URL. It's better to change for faster download.
# More mirrors see: https://launchpad.net/ubuntu/+archivemirrors
export TARGET_UBUNTU_MIRROR="http://us.archive.ubuntu.com/ubuntu/"

# The packaged version of the Linux kernel to install on target image.
# linux-generic always resolves to the latest generic kernel meta-package
# available for the target release at build time.
export TARGET_KERNEL_PACKAGE="linux-generic"

# The file (no extension) of the ISO containing the generated disk image,
# the volume id, and the hostname of the live environment are set from this name.
export TARGET_NAME="ubuntu-from-scratch"

# The text label shown in GRUB for booting into the live environment
export GRUB_LIVEBOOT_LABEL="Try Ubuntu FS without installing"

# The text label shown in GRUB for starting installation
export GRUB_INSTALL_LABEL="Install Ubuntu FS"

# Packages to be removed from the target system after installation completes succesfully
export TARGET_PACKAGE_REMOVE="
    ubiquity \
    casper \
    discover \
    laptop-detect \
    os-prober \
"

# Package customisation function.  Update this function to customize packages
# present on the installed system.
function customize_image() {

    # ------------------------------------------------------------------
    # 0. Prereqs for adding third-party apt repos (needed before anything
    #    below that isn't in Ubuntu's own archive: Docker, Node)
    # ------------------------------------------------------------------
    apt-get install -y \
        ca-certificates \
        curl \
        gnupg \
        lsb-release \
        software-properties-common \
        apt-transport-https

    # ------------------------------------------------------------------
    # 1. Desktop environment
    # ------------------------------------------------------------------
    apt-get install -y \
        plymouth-themes \
        ubuntu-gnome-desktop \
        ubuntu-gnome-wallpapers

    # ------------------------------------------------------------------
    # 2. C / C++ build toolchain (all from Ubuntu's own repo = latest
    #    for this release, no third-party PPA needed)
    # ------------------------------------------------------------------
    apt-get install -y \
        build-essential \
        gcc \
        g++ \
        clang \
        lld \
        lldb \
        cmake \
        ninja-build \
        meson \
        gdb \
        valgrind \
        ccache \
        autoconf \
        automake \
        libtool \
        pkg-config \
        make \
        patchelf \
        git \
        git-lfs \
        python3 \
        python3-pip \
        python3-venv \
        python3-dev

    # ------------------------------------------------------------------
    # 3. Rust (apt-packaged rustc/cargo -- current Ubuntu releases track
    #    a reasonably recent stable Rust; this keeps everything "apt only")
    # ------------------------------------------------------------------
    apt-get install -y \
        rustc \
        cargo \
        rust-gdb

    # ------------------------------------------------------------------
    # 4. Docker CE, latest, from Docker's official apt repo (Ubuntu's own
    #    "docker.io" package lags upstream Docker releases significantly,
    #    so we add Docker's repo instead of using docker.io)
    # ------------------------------------------------------------------
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
    chmod a+r /etc/apt/keyrings/docker.asc
    echo \
        "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
        ${TARGET_UBUNTU_VERSION} stable" \
        > /etc/apt/sources.list.d/docker.list

    apt-get update
    # If Docker hasn't published a repo for this codename yet, this
    # install will fail loudly here -- if that happens, change
    # "${TARGET_UBUNTU_VERSION}" above to "noble" (24.04) as a
    # compatible fallback and re-run.
    apt-get install -y \
        docker-ce \
        docker-ce-cli \
        containerd.io \
        docker-buildx-plugin \
        docker-compose-plugin

    # ------------------------------------------------------------------
    # 5. Node.js latest LTS + npm, from NodeSource's official apt repo
    #    (Ubuntu's bundled nodejs is old; NodeSource keeps this current
    #    and it's still installed via apt)
    # ------------------------------------------------------------------
    curl -fsSL https://deb.nodesource.com/setup_lts.x | bash -
    apt-get install -y nodejs

    # ------------------------------------------------------------------
    # 6. uv, bun, opencode -- none of these are packaged in apt at all
    #    (they're too new / not distro-packaged), so this is the one
    #    place we use each tool's official installer script instead.
    #    All three are pointed at system-wide locations so they work for
    #    whichever user account ubiquity creates at install time, not
    #    just /root.
    # ------------------------------------------------------------------
    curl -LsSf https://astral.sh/uv/install.sh | env UV_INSTALL_DIR=/usr/local/bin sh

    curl -fsSL https://bun.sh/install | BUN_INSTALL=/opt/bun bash
    ln -sf /opt/bun/bin/bun  /usr/local/bin/bun
    ln -sf /opt/bun/bin/bunx /usr/local/bin/bunx

    OPENCODE_INSTALL_DIR=/usr/local/bin bash -c "$(curl -fsSL https://opencode.ai/install)"

    # ------------------------------------------------------------------
    # 7. Media: ffmpeg, mpv, vlc (all in Ubuntu universe/multiverse,
    #    already enabled in sources.list by this project)
    # ------------------------------------------------------------------
    apt-get install -y \
        ffmpeg \
        mpv \
        vlc \
        vlc-plugin-base

    # ------------------------------------------------------------------
    # 8. Common build dependencies shared by Chromium / WebKitGTK /
    #    Firefox source builds. This is a solid baseline, NOT a complete
    #    substitute for each project's own bootstrap script -- once you
    #    clone the actual source trees, still run:
    #      Chromium:  ./build/install-build-deps.sh
    #      WebKitGTK: ./Tools/gtk/install-dependencies
    #      Firefox:   ./mach bootstrap
    #    those scripts self-update against the exact current requirement
    #    list for whatever revision you've checked out.
    # ------------------------------------------------------------------
    apt-get install -y \
        bison flex gperf nasm yasm \
        libglib2.0-dev libgtk-3-dev libgtk-4-dev \
        libnss3-dev libnspr4-dev \
        libxss1 libxtst6 libxrandr2 \
        libasound2-dev libpulse-dev \
        libpangocairo-1.0-0 libatk1.0-dev libatk-bridge2.0-dev \
        libcups2-dev libdrm-dev \
        libxcomposite-dev libxdamage-dev libxfixes-dev libxkbcommon-dev \
        mesa-common-dev libgl1-mesa-dev libgbm-dev \
        libavahi-client-dev libwebp-dev libjpeg-dev libpng-dev \
        zlib1g-dev libicu-dev libxml2-dev libxslt1-dev \
        libsqlite3-dev libcurl4-openssl-dev libssl-dev \
        ruby perl

    # ------------------------------------------------------------------
    # 9. General system + productivity CLI tools
    #    (WizTree analog: ncdu + baobab. Everything-search analog: fd + rg)
    # ------------------------------------------------------------------
    apt-get install -y \
        terminator \
        tmux \
        zsh \
        fzf \
        tree \
        jq \
        ripgrep \
        fd-find \
        bat \
        eza \
        htop \
        btop \
        ncdu \
        baobab \
        neofetch \
        rsync \
        unzip \
        zip \
        p7zip-full \
        openssh-client \
        openssh-server \
        net-tools \
        wget \
        vim \
        nano \
        less \
        gnome-tweaks \
        clamav-daemon

    # ------------------------------------------------------------------
    # 10. Passwordless sudo for whatever user ubiquity creates at install
    #     time (ubiquity puts that user in the 'sudo' group by default,
    #     so granting NOPASSWD to the group covers them automatically).
    #     Comment this whole block out if you'd rather keep sudo asking
    #     for a password.
    # ------------------------------------------------------------------
    mkdir -p /etc/sudoers.d
    echo '%sudo ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/090-nopasswd-sudo
    chmod 0440 /etc/sudoers.d/090-nopasswd-sudo

    # ------------------------------------------------------------------
    # purge
    # ------------------------------------------------------------------
    apt-get purge -y \
        transmission-gtk \
        transmission-common \
        gnome-mahjongg \
        gnome-mines \
        gnome-sudoku \
        aisleriot \
        hitori
}

# Used to version the configuration.  If breaking changes occur, manual
# updates to this file from the default may be necessary.
export CONFIG_FILE_VERSION="0.4"
