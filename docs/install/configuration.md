---
title: Configuration Options
---

## Configuration File

The primary way to configure RKE2 is through its config file. Command line arguments and environment variables are also available, but RKE2 is installed as a systemd service and thus these are not as easy to leverage.

By default, RKE2 will launch with the values present in the YAML file located at `/etc/rancher/rke2/config.yaml`.

:::note
The RKE2 config file needs to be created manually. You can do that by running `touch /etc/rancher/rke2/config.yaml` as a privileged user. If the configuration is changed after starting RKE2, the service must be restarted to apply the new configuration.
:::

An example of a basic `server` config file is below:

```yaml
write-kubeconfig-mode: "0644"
tls-san:
  - "foo.local"
node-label:
  - "foo=bar"
  - "something=amazing"
debug: true
```

The configuration file parameters map directly to CLI arguments, with repeatable CLI arguments being represented as YAML lists. Boolean flags are represented as `true` or `false` in the YAML file.

An identical configuration using solely CLI arguments is shown below to demonstrate this:

```bash
rke2 server \
  --write-kubeconfig-mode "0644"    \
  --tls-san "foo.local"             \
  --node-label "foo=bar"            \
  --node-label "something=amazing"  \
  --debug
```

It is also possible to use both a configuration file and CLI arguments.  In these situations, values will be loaded from both sources, but CLI arguments will take precedence. For repeatable arguments such as `--node-label`, the CLI arguments will overwrite all values in the list.

Finally, the location of the config file can be changed either through the cli argument `--config FILE, -c FILE`, or the environment variable `$RKE2_CONFIG_FILE`.

### Multiple Config Files

Multiple configuration files are supported. By default, configuration files are read from `/etc/rancher/rke2/config.yaml` and `/etc/rancher/rke2/config.yaml.d/*.yaml` in alphabetical order. 

By default, the last value found for a given key will be used. A `+` can be appended to the key to append the value to the existing string or slice, instead of replacing it. All occurrences of this key in subsequent files will also require a `+` to prevent overwriting the accumulated value.

An example of multiple config files is below:

```yaml
# config.yaml
token: boop
node-label:
  - foo=bar
  - bar=baz


# config.yaml.d/test1.yaml
write-kubeconfig-mode: 600
node-taint:
  - alice=bob:NoExecute

# config.yaml.d/test2.yaml
write-kubeconfig-mode: 777
node-label:
  - other=what
  - foo=three
node-taint+:
  - charlie=delta:NoSchedule
```

This results in a final configuration of:

```yaml
write-kubeconfig-mode: 777
token: boop
node-label:
  - other=what
  - foo=three
node-taint:
  - alice=bob:NoExecute
  - charlie=delta:NoSchedule
```

## Kubelet configuration
:::info Version Gate
The drop-in directory for kubelet configuration files or the config file (options 1 and 2 below) are only available in v1.32 and above. For lower minors, you should use the kubelet args directly (option number 3 below)
:::

Following on from upstream behavior, kubelet configuration can be changed in different ways with a specific [order of precedence](https://kubernetes.io/docs/tasks/administer-cluster/kubelet-config-file/#kubelet-configuration-merging-order). 

RKE2 uses a default kubelet configuration which is stored under `/var/lib/rancher/rke2/agent/etc/kubelet.conf.d/00-rke2-defaults.conf`. If you would like to change the default configuration parameters, there are three ways to do so:

1. (Recommended) Drop a config file in `/var/lib/rancher/rke2/agent/etc/kubelet.conf.d/`
2. By using the flag `--kubelet-arg=config=$PATHTOFILE`, where `$PATHTOFILE` is the path to a file that includes kubelet config parameters (e.g. `/etc/rancher/rke2/kubelet.conf`) or the flag `--kubelet-arg=config-dir=$PATHTODIR`, where `$PATHTODIR` is the path to a directory which can include files that contain kubelet config parameters (e.g. `/etc/rancher/rke2/kubelet.conf.d`)
3. By using the flag `--kubelet-arg=$FLAG`, where `$FLAG` is a kubelet configuration parameter (e.g. `image-gc-high-threshold=100`).

### Legacy kubelet logging flags

RKE2 supports additional flags to configure kubelet logging that were previously supported by the kubelet itself. These flags are intercepted by RKE2, and control how RKE2 wraps logs written to stdout and stderr by the kubelet:

| Flag | Type | Description
| --------|------|------------
| `logtostderr` | bool | Controls whether log messages are written only to stderr (Default `false`)
| `alsologtostderr` | bool | Controls whether log messages are also written to stderr in addition to the specified log file (Default `false`)
| `stderrthreshold` | string | This flag is intercepted by RKE2, but not used (Default `FATAL`)
| `log-file` | string | Specifies the absolute path and filename where the component's log messages should be written (Default `/var/lib/rancher/rke2/agent/logs/kubelet.log`)
| `log-file-max-size` | int | Specifies the maximum size (in megabytes) a log file can reach before it is rotated (Default `50`)


## Configuring the Linux Installation Script

As mentioned in the [Quick-Start Guide](quickstart.md), you can use the installation script available at https://get.rke2.io to install RKE2 as a service.

The simplest form of this command is running, as root user or through `sudo`, as follows:

```sh
# curl -sfL https://get.rke2.io | sudo sh -
curl -sfL https://get.rke2.io | sh -
```

When using this method to install RKE2, the following environment variables can be used to configure the installation:

| Environment Variable | Description |
|-----------------------------|---------------------------------------------|
| `INSTALL_RKE2_VERSION` | Version of RKE2 to download from GitHub. Will attempt to download the latest release from the `stable` channel if not specified. `INSTALL_RKE2_CHANNEL` should also be set if installing on an RPM-based system and the desired version does not exist in the `stable` channel. |
| `INSTALL_RKE2_TYPE` | Type of systemd service to create, can be either "server" or "agent" Default is "server". |
| `INSTALL_RKE2_CHANNEL_URL` | Channel URL for fetching RKE2 download URL. Defaults to `https://update.rke2.io/v1-release/channels`. |
| `INSTALL_RKE2_CHANNEL` | Channel to use for fetching RKE2 download URL. Defaults to `stable`. Options include: `stable`, `latest`, `testing`. |
| `INSTALL_RKE2_METHOD` | Method of installation to use. Default is on RPM-based systems `rpm`, all else `tar`. |

This installation script is straight-forward and will do the following:

1. Obtain the desired version to install based on the above parameters. If no parameters are supplied, the latest official release will be used.
2. Determine and execute the installation method. There are two methods: rpm and tar. If the `INSTALL_RKE2_METHOD` variable is set, that will be respected, Otherwise, `rpm` will be used on operating systems that use this package management system. On all other systems, tar will be used. In the case of the tar method, the script will simply unpack the tar archive associated with the desired release. In the case of rpm, a yum repository will be set up and the rpm will be installed using yum.

## Configuring the Windows Installation Script
:::note 
Windows Support requires choosing Calico or Flannel as the CNI for the RKE2 cluster
:::

As mentioned in the [Quick-Start Guide](quickstart.md), you can use the installation script available at [https://github.com/rancher/rke2/blob/master/install.ps1](https://github.com/rancher/rke2/blob/master/install.ps1) to install RKE2 on a Windows Agent Node.

The simplest form of this command is as follows:

```powershell
Invoke-WebRequest -Uri https://raw.githubusercontent.com/rancher/rke2/master/install.ps1 -Outfile install.ps1
```

When using this method to install the Windows RKE2 agent, the following parameters can be passed to configure the installation script:

```console
SYNTAX

install.ps1 [[-Channel] <String>] [[-Method] <String>] [[-Type] <String>] [[-Version] <String>] [[-TarPrefix] <String>] [-Commit] [[-AgentImagesDir] <String>] [[-ArtifactPath] <String>] [[-ChannelUrl] <String>] [<CommonParameters>]

OPTIONS

-Channel           Channel to use for fetching RKE2 download URL (Default: "stable")
-Method            The installation method to use. Currently tar or choco installation supported. (Default: "tar")
-Type              Type of RKE2 service. Only the "agent" type is supported on Windows. (Default: "agent")
-Version           Version of rke2 to download from Github
-TarPrefix         Installation prefix when using the tar installation method. (Default: `C:/usr/local` unless `C:/usr/local` is read-only or has a dedicated mount point, in which case `C:/opt/rke2` is used instead)
-Commit            (experimental/agent) Commit of RKE2 to download from temporary cloud storage. If set, this forces `--Method=tar`. Intended for development purposes only.
-AgentImagesDir    Installation path for airgap images when installing from CI commit. (Default: `C:/var/lib/rancher/rke2/agent/images`)
-ArtifactPath      If set, the install script will use the local path for sourcing the `rke2.windows-$SUFFIX` and `sha256sum-$ARCH.txt` files rather than the downloading the files from GitHub. Disabled by default.
```

### Other Windows Installation Script Usage Examples
#### Install the Latest Version Instead of Stable

```powershell
Invoke-WebRequest -Uri https://raw.githubusercontent.com/rancher/rke2/master/install.ps1 -Outfile install.ps1
./install.ps1 -Channel Latest
```

#### Install the Latest Version using Tar Installation Method

```powershell
Invoke-WebRequest -Uri https://raw.githubusercontent.com/rancher/rke2/master/install.ps1 -Outfile install.ps1
./install.ps1 -Channel Latest -Method Tar
```


## Running the Binary Directly

As stated, the installation script is primarily concerned with configuring RKE2 to run as a service. If you choose to not use the script, you can run RKE2 simply by downloading the binary from our [release page](https://github.com/rancher/rke2/releases/latest), placing it on your path, and executing it. The important commands are:

Command | Description
--------|------------------
`rke2 server` | Run the RKE2 management server, which will also launch the Kubernetes control plane components such as the API server, controller-manager, and scheduler. Only Supported on Linux.
`rke2 agent` |  Run the RKE2 node agent. This will cause RKE2 to run as a worker node, launching the Kubernetes node services `kubelet` and `kube-proxy`. Supported on Linux and Windows.
`rke2 --help` | Shows a list of commands or help for one command

## More Info

For details on configuring the RKE2 server, refer to the [server configuration reference.](../reference/server_config.md)

For details on configuring the RKE2 agent, refer to the [agent configuration reference.](../reference/linux_agent_config.md)

For details on configuring the RKE2 Windows agent, refer to the [Windows agent configuration reference.](../reference/windows_agent_config.md)
