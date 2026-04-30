# k8s-setup

离线安装 Kubernetes `v1.30.8`（Ubuntu `22.04`）的一体化资源包。

## 1. 支持范围

- 操作系统：Ubuntu 22.04（amd64）
- Kubernetes 版本：1.30.8
- 容器运行时：containerd 1.7.24 + runc
- 网络插件清单：Flannel / Calico / Canal（脚本默认使用 Flannel）
- 场景：离线（无公网）或弱网环境

## 2. 全部项目文件

> 以下为仓库中（排除 `.git`）的全部文件：

```text
.codex
.github/workflows/release.yml
README.md
calico.yaml
canal.yaml
cni-plugins-linux-amd64-v1.6.1.tgz
config.toml
containerd-1.7.24-linux-amd64.tar.gz
containerd.service
deb/apt-transport-https_2.4.12_all.deb
deb/conntrack_1%3a1.4.6-2build2_amd64.deb
deb/cri-tools_1.30.1-1.1_amd64.deb
deb/ebtables_2.0.11-4build2_amd64.deb
deb/ethtool_1%3a5.16-1_amd64.deb
deb/k9s_linux_amd64.deb
deb/kubeadm_100year.deb
deb/kubectl_1.30.8-1.1_amd64.deb
deb/kubelet_1.30.8-1.1_amd64.deb
deb/kubernetes-cni_1.4.0-1.1_amd64.deb
deb/make_4.3-4.1build1_amd64.deb
deb/socat_1.7.4.1-3ubuntu4_amd64.deb
export.sh
helm
hostname.sh
import.sh
init.sh
init.yaml
k8s_setup_cn.sh
kube-flannel.yml
kubelet.service
runc.amd64
```

## 3. 文件作用速览

- `k8s_setup_cn.sh`：系统参数调优、安装 containerd/runc/CNI、离线安装 `deb/*.deb`、启动 kubelet。
- `init.sh`：执行 `kubeadm init`（`v1.30.8`）、部署 Flannel、去除控制平面污点、安装本地 `helm`。
- `import.sh`：从 `export/*.tar` 批量导入镜像到 containerd。
- `export.sh`：从 containerd 批量导出镜像到 `export/*.tar`。
- `hostname.sh`：将主机名改为 `jcjy-ai-xxx`。
- `kube-flannel.yml` / `calico.yaml` / `canal.yaml`：CNI 清单（默认脚本用 Flannel）。
- `containerd-1.7.24-linux-amd64.tar.gz`、`runc.amd64`、`cni-plugins-linux-amd64-v1.6.1.tgz`：运行时核心离线二进制。
- `config.toml`、`containerd.service`：containerd 配置与 systemd 单元。
- `deb/*.deb`：kubeadm/kubelet/kubectl/cri-tools/kubernetes-cni 等离线安装包。
- `init.yaml`：kubeadm 配置模板（包含占位 IP，需要自行替换后再使用）。
- `kubelet.service`：仓库中的额外 service 文件（当前脚本默认不启用它）。

## 4. 离线安装步骤（推荐顺序）

> 建议在全新 Ubuntu 22.04 主机执行，并使用 `root` 用户。

### 4.1 赋予执行权限

```bash
chmod +x k8s_setup_cn.sh init.sh import.sh export.sh hostname.sh
```

### 4.2 （可选）先改主机名

```bash
sudo ./hostname.sh
```

### 4.3 安装系统依赖与 Kubernetes 组件

```bash
sudo ./k8s_setup_cn.sh
```

### 4.4 导入离线镜像（如果你已准备 export 目录）

```bash
sudo ./import.sh
```

### 4.5 初始化集群

```bash
sudo ./init.sh
```

### 4.6 验证

```bash
kubectl get nodes -o wide
kubectl get pods -A
crictl images
```

## 5. CNI 选择

当前 `init.sh` 默认执行：

```bash
kubectl apply -f kube-flannel.yml
```

如果改用 Calico 或 Canal：

```bash
# 二选一，不要混用
kubectl apply -f calico.yaml
# 或
kubectl apply -f canal.yaml
```

同时请保证 `kubeadm init` 的 `--pod-network-cidr` 与所选 CNI 配置匹配。

## 6. 镜像导出/导入说明

### 6.1 在有网机器导出

```bash
sudo ./export.sh
# 生成 export/*.tar
```

### 6.2 复制到离线机器并导入

```bash
# 确保当前目录存在 export/*.tar
sudo ./import.sh
```

## 7. 注意事项

- `init.sh` 会追加两条固定 SSH 公钥到 `~/.ssh/authorized_keys`，使用前请确认符合你的安全策略。
- `init.yaml` 中 `11.11.11.3333` 为占位值（且不是合法 IPv4），不能直接用于生产。
- `config.toml` 包含私有镜像仓库与认证配置（含 `harbor.local` 账户密码），落地前请按实际环境替换。
- `k8s_setup_cn.sh` 对 `/etc/sysctl.conf`、`/etc/security/limits.conf`、防火墙状态有较多修改，建议在专用节点执行。
- 若 `import.sh` 报错 `export` 目录不存在，请先准备并解压镜像包。

## 8. 常见排查

- kubelet 未就绪：
  ```bash
  systemctl status kubelet --no-pager
  journalctl -u kubelet -n 200 --no-pager
  ```
- containerd 异常：
  ```bash
  systemctl status containerd --no-pager
  journalctl -u containerd -n 200 --no-pager
  ```
- 集群初始化后 Pod 不起：
  ```bash
  kubectl get pods -A -o wide
  kubectl describe pod <pod-name> -n <namespace>
  ```

## 9. 已确认的软件版本

- Kubernetes: `kubeadm/kubelet/kubectl 1.30.8-1.1`
- cri-tools: `1.30.1-1.1`
- kubernetes-cni: `1.4.0-1.1`
- containerd: `1.7.24`
- CNI plugins: `1.6.1`
- Flannel 清单镜像：`flannel v0.26.2`、`flannel-cni-plugin v1.6.0-flannel1`
- Calico/Canal 清单镜像：`calico v3.29.7`
