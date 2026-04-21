#!/bin/bash

# ------------------------ 1. Disable Swap and SELinux -----------------------

swapoff -a
sed -i /^[^#]*swap*/s/^/\#/g /etc/fstab

# See https://github.com/kubernetes/website/issues/14457
if [ -f /etc/selinux/config ]; then
  sed -ri 's/SELINUX=enforcing/SELINUX=disabled/' /etc/selinux/config
fi
# for ubuntu: sudo apt install selinux-utils
# for centos: yum install selinux-policy
if command -v setenforce &> /dev/null
then
  setenforce 0
  getenforce
fi

# ------------------------ 2. System Module Settings && IPTables and Connection Tracking ----------------------------

timedatectl set-timezone Asia/Shanghai

modinfo br_netfilter > /dev/null 2>&1
if [ $? -eq 0 ]; then
   modprobe br_netfilter
   mkdir -p /etc/modules-load.d
   echo 'br_netfilter' > /etc/modules-load.d/k8s-br_netfilter.conf
fi

modinfo overlay > /dev/null 2>&1
if [ $? -eq 0 ]; then
   modprobe overlay
   echo 'overlay' >> /etc/modules-load.d/k8s-br_netfilter.conf
fi

modprobe ip_vs
modprobe ip_vs_rr
modprobe ip_vs_wrr
modprobe ip_vs_sh

cat > /etc/modules-load.d/kube_proxy-ipvs.conf << EOF
ip_vs
ip_vs_rr
ip_vs_wrr
ip_vs_sh
EOF

modprobe nf_conntrack_ipv4 1>/dev/null 2>/dev/null
if [ $? -eq 0 ]; then
   echo 'nf_conntrack_ipv4' >> /etc/modules-load.d/kube_proxy-ipvs.conf
else
   modprobe nf_conntrack
   echo 'nf_conntrack' >> /etc/modules-load.d/kube_proxy-ipvs.conf
fi
sysctl -p

# ------------------------ 3. Network Settings (Sysctl) ------------------------

echo 'net.core.netdev_max_backlog = 65535' >> /etc/sysctl.conf
echo 'net.core.rmem_max = 33554432' >> /etc/sysctl.conf
echo 'net.core.wmem_max = 33554432' >> /etc/sysctl.conf
echo 'net.core.somaxconn = 32768' >> /etc/sysctl.conf
echo 'net.bridge.bridge-nf-call-arptables = 1' >> /etc/sysctl.conf
echo 'vm.max_map_count = 262144' >> /etc/sysctl.conf
echo 'vm.swappiness = 0' >> /etc/sysctl.conf
echo 'vm.overcommit_memory = 1' >> /etc/sysctl.conf
echo 'fs.inotify.max_user_instances = 524288' >> /etc/sysctl.conf
echo 'fs.inotify.max_user_watches = 10240001' >> /etc/sysctl.conf
echo 'fs.pipe-max-size = 4194304' >> /etc/sysctl.conf
echo 'fs.aio-max-nr = 262144' >> /etc/sysctl.conf
echo 'kernel.pid_max = 65535' >> /etc/sysctl.conf
echo 'kernel.watchdog_thresh = 5' >> /etc/sysctl.conf
echo 'kernel.hung_task_timeout_secs = 5' >> /etc/sysctl.conf
# add for ipv4
echo 'net.ipv4.ip_forward = 1' >> /etc/sysctl.conf
echo 'net.bridge.bridge-nf-call-ip6tables = 1' >> /etc/sysctl.conf
echo 'net.ipv4.ip_local_reserved_ports = 30000-32767' >> /etc/sysctl.conf
echo 'net.ipv4.tcp_max_syn_backlog = 1048576' >> /etc/sysctl.conf
echo 'net.ipv4.neigh.default.gc_thresh1 = 512' >> /etc/sysctl.conf
echo 'net.ipv4.neigh.default.gc_thresh2 = 2048' >> /etc/sysctl.conf
echo 'net.ipv4.neigh.default.gc_thresh3 = 4096' >> /etc/sysctl.conf
echo 'net.ipv4.tcp_retries2 = 15' >> /etc/sysctl.conf
echo 'net.ipv4.tcp_max_tw_buckets = 1048576' >> /etc/sysctl.conf
echo 'net.ipv4.tcp_max_orphans = 65535' >> /etc/sysctl.conf
echo 'net.ipv4.udp_rmem_min = 131072' >> /etc/sysctl.conf
echo 'net.ipv4.udp_wmem_min = 131072' >> /etc/sysctl.conf
echo 'net.ipv4.conf.all.rp_filter = 1' >> /etc/sysctl.conf
echo 'net.ipv4.conf.default.rp_filter = 1' >> /etc/sysctl.conf
echo 'net.ipv4.conf.all.arp_accept = 1' >> /etc/sysctl.conf
echo 'net.ipv4.conf.default.arp_accept = 1' >> /etc/sysctl.conf
echo 'net.ipv4.conf.all.arp_ignore = 1' >> /etc/sysctl.conf
echo 'net.ipv4.conf.default.arp_ignore = 1' >> /etc/sysctl.conf

# disable ipv6
echo 'net.ipv6.conf.all.disable_ipv6 = 1' >> /etc/sysctl.conf
echo 'net.ipv6.conf.default.disable_ipv6 = 1' >> /etc/sysctl.conf
echo 'net.ipv6.conf.lo.disable_ipv6 = 1' >> /etc/sysctl.conf

# ------------------------ 4. Tweaks for Specific Networking Configurations -----

#See https://help.aliyun.com/document_detail/118806.html#uicontrol-e50-ddj-w0y
sed -r -i  "s@#{0,}?net.bridge.bridge-nf-call-arptables ?= ?(0|1)@net.bridge.bridge-nf-call-arptables = 1@g" /etc/sysctl.conf
sed -r -i  "s@#{0,}?vm.max_map_count ?= ?([0-9]{1,})@vm.max_map_count = 262144@g" /etc/sysctl.conf
sed -r -i  "s@#{0,}?vm.swappiness ?= ?([0-9]{1,})@vm.swappiness = 0@g" /etc/sysctl.conf
sed -r -i  "s@#{0,}?fs.inotify.max_user_instances ?= ?([0-9]{1,})@fs.inotify.max_user_instances = 524288@g" /etc/sysctl.conf
sed -r -i  "s@#{0,}?kernel.pid_max ?= ?([0-9]{1,})@kernel.pid_max = 65535@g" /etc/sysctl.conf
sed -r -i "s@#{0,}?vm.overcommit_memory ?= ?(0|1|2)@vm.overcommit_memory = 0@g" /etc/sysctl.conf
sed -r -i  "s@#{0,}?fs.inotify.max_user_watches ?= ?([0-9]{1,})@fs.inotify.max_user_watches = 524288@g" /etc/sysctl.conf
sed -r -i  "s@#{0,}?fs.pipe-max-size ?= ?([0-9]{1,})@fs.pipe-max-size = 4194304@g" /etc/sysctl.conf
sed -r -i  "s@#{0,}?net.core.netdev_max_backlog ?= ?([0-9]{1,})@net.core.netdev_max_backlog = 65535@g" /etc/sysctl.conf
sed -r -i  "s@#{0,}?net.core.rmem_max ?= ?([0-9]{1,})@net.core.rmem_max = 33554432@g" /etc/sysctl.conf
sed -r -i  "s@#{0,}?net.core.wmem_max ?= ?([0-9]{1,})@net.core.wmem_max = 33554432@g" /etc/sysctl.conf
sed -r -i  "s@#{0,}?net.core.somaxconn ?= ?([0-9]{1,})@net.core.somaxconn = 32768@g" /etc/sysctl.conf
sed -r -i  "s@#{0,}?fs.aio-max-nr ?= ?([0-9]{1,})@fs.aio-max-nr = 262144@g" /etc/sysctl.conf
sed -r -i  "s@#{0,}?kernel.watchdog_thresh ?= ?([0-9]{1,})@kernel.watchdog_thresh = 5@g" /etc/sysctl.conf
sed -r -i  "s@#{0,}?kernel.hung_task_timeout_secs ?= ?([0-9]{1,})@kernel.hung_task_timeout_secs = 5@g" /etc/sysctl.conf
sed -r -i "s@#{0,}?net.ipv4.tcp_tw_recycle ?= ?(0|1|2)@net.ipv4.tcp_tw_recycle = 0@g" /etc/sysctl.conf
sed -r -i "s@#{0,}?net.ipv4.tcp_tw_reuse ?= ?(0|1)@net.ipv4.tcp_tw_reuse = 0@g" /etc/sysctl.conf
sed -r -i "s@#{0,}?net.ipv4.conf.all.rp_filter ?= ?(0|1|2)@net.ipv4.conf.all.rp_filter = 1@g" /etc/sysctl.conf
sed -r -i "s@#{0,}?net.ipv4.conf.default.rp_filter ?= ?(0|1|2)@net.ipv4.conf.default.rp_filter = 1@g" /etc/sysctl.conf
sed -r -i  "s@#{0,}?net.ipv4.ip_forward ?= ?(0|1)@net.ipv4.ip_forward = 1@g" /etc/sysctl.conf
sed -r -i  "s@#{0,}?net.bridge.bridge-nf-call-iptables ?= ?(0|1)@net.bridge.bridge-nf-call-iptables = 1@g" /etc/sysctl.conf
sed -r -i  "s@#{0,}?net.ipv4.ip_local_reserved_ports ?= ?([0-9]{1,}-{0,1},{0,1}){1,}@net.ipv4.ip_local_reserved_ports = 30000-32767@g" /etc/sysctl.conf
sed -r -i  "s@#{0,}?net.ipv4.tcp_max_syn_backlog ?= ?([0-9]{1,})@net.ipv4.tcp_max_syn_backlog = 1048576@g" /etc/sysctl.conf
sed -r -i  "s@#{0,}?net.ipv4.neigh.default.gc_thresh1 ?= ?([0-9]{1,})@net.ipv4.neigh.default.gc_thresh1 = 512@g" /etc/sysctl.conf
sed -r -i  "s@#{0,}?net.ipv4.neigh.default.gc_thresh2 ?= ?([0-9]{1,})@net.ipv4.neigh.default.gc_thresh2 = 2048@g" /etc/sysctl.conf
sed -r -i  "s@#{0,}?net.ipv4.neigh.default.gc_thresh3 ?= ?([0-9]{1,})@net.ipv4.neigh.default.gc_thresh3 = 4096@g" /etc/sysctl.conf
sed -r -i "s@#{0,}?net.ipv4.conf.eth0.arp_accept ?= ?(0|1)@net.ipv4.conf.eth0.arp_accept = 1@g" /etc/sysctl.conf
sed -r -i  "s@#{0,}?net.ipv4.tcp_retries2 ?= ?([0-9]{1,})@net.ipv4.tcp_retries2 = 15@g" /etc/sysctl.conf
sed -r -i  "s@#{0,}?net.ipv4.tcp_max_tw_buckets ?= ?([0-9]{1,})@net.ipv4.tcp_max_tw_buckets = 1048576@g" /etc/sysctl.conf
sed -r -i  "s@#{0,}?net.ipv4.tcp_max_orphans ?= ?([0-9]{1,})@net.ipv4.tcp_max_orphans = 65535@g" /etc/sysctl.conf
sed -r -i  "s@#{0,}?net.ipv4.udp_rmem_min ?= ?([0-9]{1,})@net.ipv4.udp_rmem_min = 131072@g" /etc/sysctl.conf
sed -r -i  "s@#{0,}?net.ipv4.udp_wmem_min ?= ?([0-9]{1,})@net.ipv4.udp_wmem_min = 131072@g" /etc/sysctl.conf
sed -r -i  "s@#{0,}?net.ipv4.conf.all.arp_ignore ?= ??(0|1|2)@net.ipv4.conf.all.arp_ignore = 1@g" /etc/sysctl.conf
sed -r -i  "s@#{0,}?net.ipv4.conf.default.arp_ignore ?= ??(0|1|2)@net.ipv4.conf.default.arp_ignore = 1@g" /etc/sysctl.conf

tmpfile="$$.tmp"
awk ' !x[$0]++{print > "'$tmpfile'"}' /etc/sysctl.conf
mv $tmpfile /etc/sysctl.conf


# ------------------------ 5. Security Limit ------------------------------------

# ulimit
echo "* soft nofile 1048576" >> /etc/security/limits.conf
echo "* hard nofile 1048576" >> /etc/security/limits.conf
echo "* soft nproc 65536" >> /etc/security/limits.conf
echo "* hard nproc 65536" >> /etc/security/limits.conf
echo "* soft memlock unlimited" >> /etc/security/limits.conf
echo "* hard memlock unlimited" >> /etc/security/limits.conf
echo "root soft nofile 1048576" >> /etc/security/limits.conf
echo "root hard nofile 1048576" >> /etc/security/limits.conf
echo "root soft nproc 65536" >> /etc/security/limits.conf
echo "root hard nproc 65536" >> /etc/security/limits.conf
echo "root soft memlock unlimited" >> /etc/security/limits.conf
echo "root hard memlock unlimited" >> /etc/security/limits.conf

sed -r -i  "s@#{0,}?\* soft nofile ?([0-9]{1,})@\* soft nofile 1048576@g" /etc/security/limits.conf
sed -r -i  "s@#{0,}?\* hard nofile ?([0-9]{1,})@\* hard nofile 1048576@g" /etc/security/limits.conf
sed -r -i  "s@#{0,}?\* soft nproc ?([0-9]{1,})@\* soft nproc 65536@g" /etc/security/limits.conf
sed -r -i  "s@#{0,}?\* hard nproc ?([0-9]{1,})@\* hard nproc 65536@g" /etc/security/limits.conf
sed -r -i  "s@#{0,}?\* soft memlock ?([0-9]{1,}([TGKM]B){0,1}|unlimited)@\* soft memlock unlimited@g" /etc/security/limits.conf
sed -r -i  "s@#{0,}?\* hard memlock ?([0-9]{1,}([TGKM]B){0,1}|unlimited)@\* hard memlock unlimited@g" /etc/security/limits.conf
sed -r -i "s@#{0,}?root soft nofile ?([0-9]{1,})@root soft nofile 1048576@g" /etc/security/limits.conf
sed -r -i "s@#{0,}?root hard nofile ?([0-9]{1,})@root hard nofile 1048576@g" /etc/security/limits.conf
sed -r -i "s@#{0,}?root soft nproc ?([0-9]{1,})@root soft nproc 65536@g" /etc/security/limits.conf
sed -r -i "s@#{0,}?root hard nproc ?([0-9]{1,})@root hard nproc 65536@g" /etc/security/limits.conf
sed -r -i "s@#{0,}?root soft memlock ?([0-9]{1,}([TGKM]B){0,1}|unlimited)@root soft memlock unlimited@g" /etc/security/limits.conf
sed -r -i "s@#{0,}?root hard memlock ?([0-9]{1,}([TGKM]B){0,1}|unlimited)@root hard memlock unlimited@g" /etc/security/limits.conf

tmpfile="$$.tmp"
awk ' !x[$0]++{print > "'$tmpfile'"}' /etc/security/limits.conf
mv $tmpfile /etc/security/limits.conf

# set systemctl default max lock memory 
sed -i 's/^#DefaultLimitMEMLOCK=.*/DefaultLimitMEMLOCK=8388608/' /etc/systemd/system.conf
systemctl daemon-reexec


# ------------------------ 6. Firewall Configurations ---------------------------

if systemctl is-active firewalld --quiet; then
  systemctl stop firewalld 1>/dev/null 2>/dev/null
  systemctl disable firewalld 1>/dev/null 2>/dev/null
fi
if systemctl is-active ufw --quiet; then
  systemctl stop ufw 1>/dev/null 2>/dev/null
  systemctl disable ufw 1>/dev/null 2>/dev/null
fi

sysctl --system
# wget https://s3.frp.tiusolution.com/k8s/packages/containerd-1.7.20-linux-amd64.tar.gz
tar Cxzvf /usr/local containerd-1.7.24-linux-amd64.tar.gz
# wget https://s3.frp.tiusolution.com/k8s/packages/runc.amd64
install -m 755 runc.amd64 /usr/local/sbin/runc
# wget https://s3.frp.tiusolution.com/k8s/packages/cni-plugins-linux-amd64-v1.5.1.tgz
mkdir -p /opt/cni/bin
tar Cxzvf /opt/cni/bin cni-plugins-linux-amd64-v1.6.1.tgz
mkdir /etc/containerd
# containerd config default | tee /etc/containerd/config.toml
# sed -i 's/SystemdCgroup \= false/SystemdCgroup \= true/g' /etc/containerd/config.toml
cp -f config.toml /etc/containerd/config.toml
# curl -L https://s3.frp.tiusolution.com/k8s/packages/containerd.service -o /etc/systemd/system/containerd.service
cp containerd.service /etc/systemd/system/containerd.service
systemctl daemon-reload
systemctl restart containerd
systemctl enable --now containerd
# systemctl status containerd



# Installing kubeadm, kubelet and kubectl
# apt-get update
# apt-get install -y apt-transport-https ca-certificates curl

# Download the Google Cloud public signing key:
# mkdir -p -m 755 /etc/apt/keyrings
# curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.30/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg


# # Add the Kubernetes apt repository:
# echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://mirrors.ustc.edu.cn/kubernetes/core:/stable:/v1.30/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list


# # Update apt package index, install kubelet, kubeadm and kubectl, and pin their version:
# apt-get update
# apt-get install -y kubelet kubeadm kubectl

# # apt-mark hold will prevent the package from being automatically upgraded or removed.
# apt-mark hold kubelet kubeadm kubectl
# wget https://s3.frp.tiusolution.com/k8s/packages/kubeadm
# wget https://s3.frp.tiusolution.com/k8s/packages/kubectl
# wget https://s3.frp.tiusolution.com/k8s/packages/kubelet
dpkg -i deb/*.deb

echo 'runtime-endpoint: unix:///run/containerd/containerd.sock' > /etc/crictl.yaml
echo 'alias k="kubectl"' >> /root/.bashrc
# wget https://s3.frp.tiusolution.com/k8s/packages/kubelet.service
#cp kubelet.service /lib/systemd/system/kubelet.service
# # Enable and start kubelet service
systemctl daemon-reload
systemctl start kubelet
systemctl enable kubelet.service
