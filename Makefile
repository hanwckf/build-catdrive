KERNEL_BSP := https://github.com/hanwckf/linux-marvell/releases/download
RELEASE_TAG = v2019-9-16-1
DTB := armada-3720-catdrive.dtb

DTB_URL := $(KERNEL_BSP)/$(RELEASE_TAG)/$(DTB)
KERNEL_URL := $(KERNEL_BSP)/$(RELEASE_TAG)/Image
KMOD_URL := $(KERNEL_BSP)/$(RELEASE_TAG)/modules.tar.xz

TARGETS := debian archlinux alpine ubuntu

DL := dl
DL_KERNEL := $(DL)/kernel/$(RELEASE_TAG)
OUTPUT := output

CURL := curl -O -L
download = ( mkdir -p $(1) && cd $(1) ; $(CURL) $(2) )

help:
	@echo "Usage: make build_[system1]=y build_[system2]=y build"
	@echo "available system: $(TARGETS)"

build: $(TARGETS)

clean: $(TARGETS:%=%_clean)
	rm -f $(RESCUE_ROOTFS)

dl_kernel: $(DL_KERNEL)/$(DTB) $(DL_KERNEL)/Image $(DL_KERNEL)/modules.tar.xz

$(DL_KERNEL)/$(DTB):
	$(call download,$(DL_KERNEL),$(DTB_URL))

$(DL_KERNEL)/Image:
	$(call download,$(DL_KERNEL),$(KERNEL_URL))

$(DL_KERNEL)/modules.tar.xz:
	$(call download,$(DL_KERNEL),$(KMOD_URL))

ALPINE_BRANCH := v3.10
ALPINE_VERSION := 3.10.4
ALPINE_PKG := alpine-minirootfs-$(ALPINE_VERSION)-aarch64.tar.gz
RESCUE_ROOTFS := tools/rescue/rescue-alpine-catdrive-$(ALPINE_VERSION)-aarch64.tar.xz

ifneq ($(TRAVIS),)
ALPINE_URL_BASE := http://dl-cdn.alpinelinux.org/alpine/$(ALPINE_BRANCH)/releases/aarch64
else
ALPINE_URL_BASE := https://mirrors.tuna.tsinghua.edu.cn/alpine/$(ALPINE_BRANCH)/releases/aarch64
endif

alpine_dl: dl_kernel $(DL)/$(ALPINE_PKG)

$(DL)/$(ALPINE_PKG):
	$(call download,$(DL),$(ALPINE_URL_BASE)/$(ALPINE_PKG))

alpine_clean:

$(RESCUE_ROOTFS):
	@[ ! -f $(RESCUE_ROOTFS) ] && make rescue

rescue: alpine_dl
	sudo BUILD_RESCUE=y ./build-alpine.sh release $(DL)/$(ALPINE_PKG) $(DL_KERNEL) -

ifeq ($(build_alpine),y)
alpine: alpine_dl $(RESCUE_ROOTFS)
	sudo ./build-alpine.sh release $(DL)/$(ALPINE_PKG) $(DL_KERNEL) $(RESCUE_ROOTFS)

else
alpine:
endif

ARCHLINUX_PKG := ArchLinuxARM-aarch64-latest.tar.gz
ifneq ($(TRAVIS),)
ARCHLINUX_URL_BASE := http://os.archlinuxarm.org/os
else
ARCHLINUX_URL_BASE := https://mirrors.tuna.tsinghua.edu.cn/archlinuxarm/os
endif

archlinux_dl: dl_kernel $(DL)/$(ARCHLINUX_PKG)

$(DL)/$(ARCHLINUX_PKG):
	$(call download,$(DL),$(ARCHLINUX_URL_BASE)/$(ARCHLINUX_PKG))

archlinux_clean:
	rm -f $(DL)/$(ARCHLINUX_PKG)

ifeq ($(build_archlinux),y)
archlinux: archlinux_dl $(RESCUE_ROOTFS)
	sudo ./build-archlinux.sh release $(DL)/$(ARCHLINUX_PKG) $(DL_KERNEL) $(RESCUE_ROOTFS)
else
archlinux:
endif

UBUNTU_PKG := ubuntu-base-18.04.4-base-arm64.tar.gz
ifneq ($(TRAVIS),)
UBUNTU_URL_BASE := http://cdimage.ubuntu.com/ubuntu-base/releases/bionic/release
else
UBUNTU_URL_BASE := https://mirrors.tuna.tsinghua.edu.cn/ubuntu-cdimage/ubuntu-base/releases/bionic/release
endif

ubuntu_dl: dl_kernel $(DL)/$(UBUNTU_PKG)

$(DL)/$(UBUNTU_PKG):
	$(call download,$(DL),$(UBUNTU_URL_BASE)/$(UBUNTU_PKG))

ubuntu_clean:

ifeq ($(build_ubuntu),y)
ubuntu: ubuntu_dl $(RESCUE_ROOTFS)
	sudo ./build-ubuntu.sh release $(DL)/$(UBUNTU_PKG) $(DL_KERNEL) $(RESCUE_ROOTFS)
else
ubuntu:
endif

ifeq ($(build_debian),y)
debian: dl_kernel $(RESCUE_ROOTFS)
	sudo ./build-debian.sh release - $(DL_KERNEL) $(RESCUE_ROOTFS)

else
debian:
endif
debian_clean:
