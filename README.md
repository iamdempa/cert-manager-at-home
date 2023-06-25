# cert-manager-at-home
Learning cert-manager TLS certificate setup

# 1. What to expect and not

I am using an `AWS EC2` instance and `Kubeadm` for installing a one node cluster. Since this repo targets on setting up the cert-manager, I will put the other tool installations to the minimum, hence putting those in a single block of code. Here I am using an Ubuntu instance, hence some commands can be subjected to the said Linux distro. You might have to find the relavent installtion steps/scripts for each distro of your choice accordingly. 

### Install `Docker` and `cri-dockerd`

Install [Docker](https://docs.docker.com/engine/install/)
```
# Update the apt package index and install packages to allow apt to use a repository over HTTPS
sudo apt-get update
sudo apt-get install ca-certificates curl gnupg

# Add Docker’s official GPG key:
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

# Use the following command to set up the repository:
echo \
  "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker engine
sudo apt-get update

sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```
Install [cri-dockerd](https://github.com/Mirantis/cri-dockerd)
```
# First Install golang as this needs to build the cri-docker binary
wget https://go.dev/dl/go1.20.5.linux-amd64.tar.gz

# untar the ball
rm -rf /usr/local/go && tar -C /usr/local -xzf go1.20.5.linux-amd64.tar.gz

# export the path
export PATH=$PATH:/usr/local/go/bin

# check if installed successfully
go version

# install make if not available
apt update && apt install make -y

# Install Cri-Dockerd
git clone https://github.com/Mirantis/cri-dockerd.git
cd cri-dockerd
make cri-dockerd
mkdir -p /usr/local/bin
install -o root -g root -m 0755 cri-dockerd /usr/local/bin/cri-dockerd
install packaging/systemd/* /etc/systemd/system
sed -i -e 's,/usr/bin/cri-dockerd,/usr/local/bin/cri-dockerd,' /etc/systemd/system/cri-docker.service
systemctl daemon-reload
systemctl enable cri-docker.service
systemctl enable --now cri-docker.socket
```

### Install `Kubeadm` and `Network-Plugin` set up the Cluster

Install [Kubeadm](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/)
```
# Update the apt package index and install packages needed to use the Kubernetes apt repository
sudo apt-get update
sudo apt-get install -y apt-transport-https ca-certificates curl

# Download the Google Cloud public signing key
curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-archive-keyring.gpg

# Add the Kubernetes apt repository
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list

# Update apt package index, install kubelet, kubeadm and kubectl, and pin their version
sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl
```

Install [Calico](https://docs.tigera.io/calico/latest/getting-started/kubernetes/self-managed-onprem/onpremises) - Here we are using Calico as our network addon. You are free to use your own 

```
curl https://raw.githubusercontent.com/projectcalico/calico/v3.26.1/manifests/calico.yaml -O

kubectl apply -f calico.yaml
```

### Install `Metallb` and `Cert-Manager` set up the Cluster

Install [Metallb](https://metallb.universe.tf/installation/)
```
# If you are using kube-proxy in IPVS mode, since Kubernetes v1.14.2 you have to enable strict ARP mode

kubectl edit configmap -n kube-system kube-proxy

# and set 
apiVersion: kubeproxy.config.k8s.io/v1alpha1
kind: KubeProxyConfiguration
mode: "ipvs"
ipvs:
  strictARP: true

# Install Metallb
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.13.10/config/manifests/metallb-native.yaml
```

Once the metallb installation is done, you need to populate a set of IP addresses/ranges/block so metallb can can handout IPs automatically. You can read about this from [here](https://metallb.universe.tf/configuration/#layer-2-configuration)

for the `spec.addresses` you can provide a range of IP addresses or a block of IP addresses (CIDR) within your `AWS subnet`. 

**Tip:** I am using this amazing [Tool](https://www.davidc.net/sites/default/subnets/subnets.html?network=172.16.0.0&mask=18&division=7.31) to subnet the CIDR block

```
# Defining The IPs To Assign To The Load Balancer Services. 

apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: first-pool
  namespace: metallb-system
spec:
  addresses:
  - 192.168.10.0/24

# Announce The Service IPs
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: example
  namespace: metallb-system
spec:
  ipAddressPools:
  - first-pool
```

Install [Cert-Manager](https://cert-manager.io/docs/installation/)

```
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.12.0/cert-manager.yaml
```


# 2. Generate the CA Key and Certificate 

```bash
openssl genrsa -out ca.key 4096
```

```bash
openssl req -new -x509 -sha256 -days 10950 -key ca.key -out ca.crt
```

# 2. Create CA secret and `cert-manager` ClusterIssuer/Issuer object

```
apiVersion: v1
kind: Secret
metadata:
  name: ca
  namespace: cert-manager
data:
  tls.crt: <BASE64-ENCODED-VALUE>
  tls.key: <BASE64-ENCODED-VALUE>
---
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: ca-issuer
  namespace: cert-manager
spec:
  ca:
    secretName: ca
```