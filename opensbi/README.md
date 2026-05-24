# OpenSBI 1.8 Milk-V Vega
Original vendor version was at 0.7. Since then, OpenSBI has migrated to a more DTS-based approach. The DTS in this folder (or directly the patches) can be used on a vanilla OpenSBI 1.8 with no platform code changes needed.

The board has no bootrom (confirmed both via no references in the documentation, and by scanning all the address ranges).

Freeloader is the platform initialization code from the vendor, from the original repository with two changes: first we need to pass the DTS pointer to OpenSBI as per manual. Then, there's a registry write for UART initialization that was done in OpenSBI by the vendor. We moved it into freeloader to remove all the platform code from OpenSBI.