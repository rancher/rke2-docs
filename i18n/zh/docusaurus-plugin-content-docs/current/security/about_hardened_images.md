---
title: 强化镜像
---

RKE2 强化镜像的漏洞会在构建时扫描，并支持额外的安全保护以减少潜在的漏洞：
* 镜像不是简单地从上游构建。镜像是在一个强化的最小基础镜像上从源头构建的，目前是 [SLE 基础容器镜像 (BCI)](https://www.suse.com/products/base-container-images/)。
* 任何用 Go 编写的二进制文件都使用符合 FIPS 140-2 标准的编译过程进行编译。有关此编译器的更多信息，请参阅[此处](../security/fips_support.md#使用-fips-兼容的-go-编译器)。

你可以通过镜像名称知道镜像是否已经过上述加强处理。RKE2 在每个版本中都会公布镜像列表。请参阅[此处](https://github.com/rancher/rke2/releases/download/v1.23.14%2Brke2r1/rke2-images-all.linux-amd64.txt)公布的镜像列表例子。

:::note
目前，RKE2 加强镜像是多架构的。只有 Linux 的 AMD64 架构是符合 FIPS 标准的。Windows 和 s390x 架构不符合 FIPS 标准。
:::