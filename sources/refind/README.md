# rEFInd staging

This directory contains the portable Warehouse-13 rEFInd configuration and
the recolored `rEFInd-lesbian-singularity` theme derived from the supplied
Digital Void archive.

The staging directory includes a firmware-safe, uncompressed 24-bit
`background.bmp` generated from the supplied 1920x1080 `refindconnect`
wallpaper. It is copied together with the theme by the explicit `--refind`
installer step.

The boot entry deliberately omits `volume`: rEFInd and Debian's shim are kept
on the same ESP, avoiding VM-specific PARTUUIDs after Rescuezilla migration.
