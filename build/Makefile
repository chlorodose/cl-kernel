LLVM 		?= 1
LLVM_IAS	?= 1
export LLVM
export LLVM_IAS

SUBMAKEOPTS	?= -j $(shell expr $(shell nproc) + 4) --load-average $(shell expr $(shell nproc) + 1)

TEST_KCONFIG ?= ./scripts/config \
	--enable UNICODE \
	--enable PCI --enable DRM \
	--module DRM_VALKYRIE_LCD --module NVIDIA_GPU_UNLOCK \
	--enable MEMORY_HOTPLUG --enable MEMORY_HOTREMOVE \
	--enable ZONE_DEVICE --enable DEVICE_PRIVATE \
	--module ZFS \
	--module AUFS_FS --enable AUFS_BRANCH_MAX_1023 \
	--enable AUFS_HNOTIFY --enable AUFS_HFSNOTIFY \
	--enable EXPORTFS --enable AUFS_EXPORT --enable AUFS_XATTR \
	--enable AUFS_RDU --enable AUFS_DIRREN --enable AUFS_SHWH \
	--module FUSE_FS --enable AUFS_BR_FUSE --module BLK_DEV_LOOP \
	--enable AUFS_FHSM --enable AUFS_BR_RAMFS --disable AUFS_DEBUG \
	--enable RUST --module BCACHEFS_FS --enable BCACHEFS_QUOTA \
	--module NVIDIA --module NVIDIA_MODESET --module NVIDIA_DRM --module NVIDIA_UVM --module NVIDIA_PEERMEM

ROOT		:= $(realpath ..)

FOR_START	= rm -rf _$@ && git -C $(ROOT)/source/$@ worktree add --force --detach "$$PWD/_$@" HEAD
FOR_END		= mv _$@ $@
GIT_APPLY	= git -C _$@ apply --rej
MAKE_IN		= make -C _$@
CD_AND		= cd _$@ &&

KVER		= $(shell make -s -C $(ROOT)/source/kernel kernelversion)
KVER_SUB	= $(shell echo $(KVER) | cut -d. -f1,2)

.PHONY: default
default: source.tar from-upstream.patch
	rm -f source.tar.zst from-upstream.patch.zst
	zstd -T0 --long --ultra -22 --progress source.tar from-upstream.patch

base:
	rm -rf _$@ && git -C ../source/kernel worktree add --force --detach "$$PWD/_$@" HEAD
	$(MAKE_IN) defconfig
	$(CD_AND) $(TEST_KCONFIG)
	$(MAKE_IN) olddefconfig
	$(MAKE_IN) $(SUBMAKEOPTS)
	$(FOR_END)

nvidia:
	$(FOR_START)
	$(GIT_APPLY) \
		$(ROOT)/files/nvidia/0001-Enable-in-tree-build.patch \
		$(ROOT)/files/nvidia/0002-Pass-dmem-cgroup-init-to-register-region.patch
	$(FOR_END)

gpu-unlock:
	$(FOR_START)
	$(GIT_APPLY) \
		$(ROOT)/files/gpu-unlock/0001-Add-kernel-builtin.patch
	$(FOR_END)

zfs: base
	$(FOR_START)
	$(CD_AND) sed -i 's/CDDL/GPL/' META # Do some evil thing
	$(CD_AND) sh autogen.sh
	$(CD_AND) ./configure --disable-nls --disable-rpath \
        --enable-linux-builtin --enable-linux-experimental --with-linux=../base
	$(CD_AND) find module include -type f -name '.gitignore' -exec rm {} \;
	$(FOR_END)
	
bcachefs:
	$(FOR_START)
	$(GIT_APPLY) $(ROOT)/files/bcachefs/0001-bcachefs-fix-compiler-warnings.patch
	$(FOR_END)

xanmod: base
	$(FOR_START)
	$(CD_AND) rm -rf CONFIGS localversion
	$(CD_AND) git diff $$(git -C ../base rev-parse HEAD) >xanmod-all.diff
	$(FOR_END)

kernel: base xanmod bcachefs zfs nvidia gpu-unlock
	rm -rf _$@ && cp -a --reflink=auto base _$@
	git -C _$@ apply ../xanmod/xanmod-all.diff
	git -C _$@ apply $(ROOT)/source/cachy/$(KVER_SUB)/misc/0001-aufs*.patch
	git -C _$@ apply $(ROOT)/files/cachy/0001-Fixup-aufs-m-missing-symbols.patch
	git -C _$@ apply $(ROOT)/files/kernel/0003-aufs-fix-error-path-initialization.patch
	b4 am -o . -n _kernel-mail 20261028174425.21704-1-ziaowang2007@gmail.com
	git -C _$@ apply ../_kernel-mail.mbx
	git -C _$@ apply $(ROOT)/files/kernel/0002-drm-valkyrie-lcd-fix-ratelimited-warning.patch
	git -C _$@ apply $(ROOT)/files/kernel/0004-drm-valkyrie-lcd-initialize-shadow-plane-state.patch
	rm -f _kernel-mail.mbx _kernel-mail.cover
	cd bcachefs && bash ./scripts/install-to-kernel.sh ../_$@
	cd zfs && ./copy-builtin ../_$@
	cd nvidia && ./copy-builtin ../_$@
	cd gpu-unlock/kernel && ./copy-builtin ../../_$@
	$(MAKE_IN) mrproper
	git -C _$@ clean -Xdf
	$(MAKE_IN) defconfig
	$(CD_AND) $(TEST_KCONFIG)
	$(MAKE_IN) olddefconfig
	$(MAKE_IN) $(SUBMAKEOPTS)
	$(MAKE_IN) mrproper
	git -C _$@ clean -Xdf
	git -C _$@ add .
	mv _$@ $@

source.tar: kernel
	tar --exclude=.git --transform "s/^kernel/linux-$$(make -C kernel kernelversion | grep -E '([0-9]*)\.([0-9]*)\.([0-9]*)')/" -cf source.tar kernel

from-upstream.patch: kernel
	git -C kernel diff --binary --cached >from-upstream.patch

clean:
	rm -rf _base base _bcachefs bcachefs _nvidia nvidia _xanmod xanmod _zfs zfs _kernel kernel source.tar from-upstream.patch
