#!/bin/bash

sed -i '/^\[Service\]/a TimeoutStartSec=2sec' /etc/systemd/system/network-online.target.wants/systemd-networkd-wait-online.service
echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOa7ow9iAN+qN38VFEJFMDNm6VAmNHK6a1YQqZdhW22P jcjy@huangxunren" >> ~/.ssh/authorized_keys
echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIG0V0DslMyXVs8+VTXfkjw8bei8xaVvPWTlZek0/Mjtf wuchong@wc-macpro-2.local" >> ~/.ssh/authorized_keys

# cp -f startup-commands.service /etc/systemd/system/startup-commands.service
# systemctl daemon-reload
# systemctl start startup-commands.service
# systemctl enable startup-commands.service

kubeadm init --pod-network-cidr=10.244.0.0/16 --kubernetes-version=v1.30.8

#sleep 10s


mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

# wget https://s3.frp.tiusolution.com/k8s/packages/kube-flannel.yml
kubectl apply -f kube-flannel.yml
kubectl taint nodes --all node-role.kubernetes.io/control-plane-
# wget https://s3.frp.tiusolution.com/k8s/packages/helm -O /usr/local/bin/helm
cp helm /usr/local/bin/helm
chmod +x /usr/local/bin/helm
