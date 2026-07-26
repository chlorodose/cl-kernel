KVER := "7.1"

LLVM 		?= 1
LLVM_IAS	?= 1
export LLVM
export LLVM_IAS

SUBMAKEOPTS	?= -j $(shell expr $(shell nproc) + 4) --load-average $(shell expr $(shell nproc) + 1)

TEST_KCONFIG ?= ./scripts/config \
	--enable UNICODE \
	--enable PCI --enable DRM \
	--enable MEMORY_HOTPLUG --enable MEMORY_HOTREMOVE \
	--enable ZONE_DEVICE --enable DEVICE_PRIVATE \
	--module ZFS \
	--module BCACHEFS_FS --enable BCACHEFS_QUOTA \
	--module NVIDIA --module NVIDIA_MODESET --module NVIDIA_DRM --module NVIDIA_UVM --module NVIDIA_PEERMEM

ROOT		:= $(realpath ..)

FOR_START	= rm -rf _$@ && git clone $(ROOT)/source/$@ _$@
FOR_END		= mv _$@ $@
GIT_APPLY	= git -C _$@ apply --rej
MAKE_IN		= make -C _$@
CD_AND		= cd _$@ &&

.PHONY: default
default: source.tar from-upstream.patch
	rm -f source.tar.zst from-upstream.patch.zst
	zstd -T0 --long --ultra -22 --progress source.tar from-upstream.patch

base:
	rm -rf _$@ && git clone ../source/kernel _$@
	$(MAKE_IN) defconfig
	$(CD_AND) $(TEST_KCONFIG)
	$(MAKE_IN) olddefconfig
	$(MAKE_IN) $(SUBMAKEOPTS)
	$(FOR_END)

nvidia:
	$(FOR_START)
	$(GIT_APPLY) \
		$(ROOT)/source/cachy/7.2/misc/nvidia/0002-fix-dsc-correct-RC-parameter-tables-to-match-VESA-DS.patch \
		$(ROOT)/files/nvidia/0001-Enable-in-tree-build.patch
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

kernel: base xanmod bcachefs zfs nvidia
	rm -rf _$@ && cp -a --reflink=auto base _$@
	git -C _$@ apply ../xanmod/xanmod-all.diff
	cd bcachefs && bash $(ROOT)/files/bcachefs/copy-builtin.sh ../_$@
	cd zfs && ./copy-builtin ../_$@
	cd nvidia && ./copy-builtin ../_$@
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