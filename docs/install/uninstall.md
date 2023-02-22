---
title: Uninstall
---

:::caution
Uninstalling RKE2 deletes the cluster data and all of the scripts.
:::

## Linux Uninstall

Depending on the method used to install RKE2, the uninstallation process varies.

### RPM Method

To uninstall RKE2 installed via the RPM method from your system, simply run the commands corresponding to the version of RKE2 you have installed, either as the root user or through `sudo`. This will shutdown RKE2 process, remove the RKE2 RPMs, and clean up files used by RKE2.

```bash
/usr/bin/rke2-uninstall.sh
```

### Tarball Method

To uninstall RKE2 installed via the Tarball method from your system, simply run the command below. This will terminate the process, remove the RKE2 binary, and clean up files used by RKE2.

```bash
/usr/local/bin/rke2-uninstall.sh
```


## Windows Uninstall

To uninstall the RKE2 Windows Agent installed via the tarball method from your system, simply run the command below. This will shutdown all RKE2 Windows processes, remove the RKE2 Windows binary, and clean up the files used by RKE2.

```powershell
c:/usr/local/bin/rke2-uninstall.ps1
```
