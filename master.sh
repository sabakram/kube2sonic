#!/bin/bash
#
# Kubernetes Master Node Setup Script

set -euxo pipefail

# Variables
KUBERNETES_VERSION="1.22.2-00"

# Install Docker
sudo apt-get update
sudo apt-get install -y docker.io
docker --version
sudo systemctl start docker
sudo systemctl enable docker

# Disable swap
sudo swapoff -a
sudo sed -i '/ swap / s/^/#/' /etc/fstab

# Set up the IPV4 bridge
cat <<EOF | sudo tee /etc/modules-load.d/containerd.conf
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter

# Setup Sysctl params
cat <<EOF | sudo tee /etc/sysctl.d/kubernetes.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF

sudo sysctl --system

# Add the Cgroup driver configuration for Docker
cat <<EOF | sudo tee /etc/docker/daemon.json
{
    "exec-opts": ["native.cgroupdriver=systemd"]
}
EOF

sudo systemctl daemon-reload
sudo systemctl restart docker


# Install kubelet, kubeadm, and kubectl
sudo apt-get update -y

sudo apt-get install -y gpg-agent
sudo apt-get install -y apt-transport-https curl gpg-agent

# Add Kubernetes repository
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
sudo sh -c 'cat <<EOF >/etc/apt/sources.list.d/kubernetes.list
deb https://apt.kubernetes.io/ kubernetes-xenial main
EOF'

sudo apt-get update
sudo apt-get install -y kubelet="$KUBERNETES_VERSION" kubeadm="$KUBERNETES_VERSION" kubectl="$KUBERNETES_VERSION" kubernetes-cni=0.8.7-00
sudo apt-mark hold kubelet kubeadm kubectl

# Intialize Master

sudo kubeadm init --pod-network-cidr=10.244.0.0/16 --kubernetes-version=v1.22.2 --v=5
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
# Apply CNI-Network Addons
kubectl apply -f https://github.com/weaveworks/weave/releases/download/v2.8.1/weave-daemonset-k8s.yaml  
