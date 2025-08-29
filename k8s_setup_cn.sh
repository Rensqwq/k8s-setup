#!/bin/bash
# common.sh
# copy this script and run in all master and worker nodes
#i1) Switch to root user [ sudo -i]

#2) Disable swap & add kernel settings

swapoff -a
sed -i '/swap/d' /etc/fstab


#3) Add  kernel settings & Enable IP tables(CNI Prerequisites)

cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

modprobe overlay
modprobe br_netfilter

cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward = 1
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1
EOF

sysctl --system

#4) Install containerd run time

#To install containerd, first install its dependencies.

# apt-get update -y
# apt-get install ca-certificates curl gnupg lsb-release -y

# apt-get update -y

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

echo 'runtime-endpoint: unix:///var/run/containerd/containerd.sock' > /etc/crictl.yaml

# wget https://s3.frp.tiusolution.com/k8s/packages/kubelet.service
#cp kubelet.service /lib/systemd/system/kubelet.service
# # Enable and start kubelet service
systemctl daemon-reload
systemctl start kubelet
systemctl enable kubelet.service
