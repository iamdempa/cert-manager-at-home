#!/bin/bash

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