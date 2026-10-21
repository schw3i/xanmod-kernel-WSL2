
# WSL compatibility patches

- `.`: patches shared by MAIN and LTS.
- `MAIN/`: patches for the current MAIN source series, Linux 7.2.
- `LTS/`: patches for the LTS source series, Linux 6.18.

`scripts/apply-patches.py` combines the common patches with the selected branch's patches and applies them in filename order.

New XanMod kernel series can require patch updates. A rejected patch stops setup and prevents the workflow from publishing a kernel without its WSL compatibility changes.