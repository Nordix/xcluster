# Xcluster/ovl - lspci

Adds `lspci` and the hw database.

Example;
```
vm-002 ~ # lspci
00:00.0 Host bridge: Intel Corporation 440FX - 82441FX PMC [Natoma] (rev 02)
00:01.0 ISA bridge: Intel Corporation 82371SB PIIX3 ISA [Natoma/Triton II]
00:01.1 IDE interface: Intel Corporation 82371SB PIIX3 IDE [Natoma/Triton II]
00:01.3 Bridge: Intel Corporation 82371AB/EB/MB PIIX4 ACPI (rev 03)
00:02.0 VGA compatible controller: Device 1234:1111 (rev 02)
00:03.0 Ethernet controller: Red Hat, Inc. Virtio network device
00:04.0 Ethernet controller: Red Hat, Inc. Virtio network device
00:05.0 Ethernet controller: Red Hat, Inc. Virtio network device
00:06.0 Ethernet controller: Red Hat, Inc. Virtio network device
00:07.0 Ethernet controller: Red Hat, Inc. Virtio network device
00:08.0 Unclassified device [00ff]: Red Hat, Inc. Virtio RNG
00:09.0 SCSI storage controller: Red Hat, Inc. Virtio block device
00:0a.0 SCSI storage controller: Red Hat, Inc. Virtio block device
```

