define Package/base-files/install-target
	echo 'pi_preinit_ramfs_dir="/lib/wifi /mnt /vendor /ini /cfg /license /lib/firmware/qcn6432"' >> $(1)/lib/preinit/00_preinit.conf
	echo 'pi_overlay_partitions="cfg:/data:"' >> $(1)/lib/preinit/00_preinit.conf
endef
