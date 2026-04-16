#!/bin/bash
# Tool installer for the k8s-mario-v2 GitOps workshop

set -e

echo "Installing workshop tools..."

# Install Terraform
sudo apt install wget -y
wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install terraform -y

# Install kubectl
sudo apt update
sudo apt install curl -y
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
rm -f kubectl

# Install AWS CLI
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
sudo apt-get install unzip -y
unzip awscliv2.zip
sudo ./aws/install
rm -rf awscliv2.zip aws/

# Install Docker
sudo apt update
sudo apt install docker.io -y
sudo usermod -aG docker $USER

# Install Helm
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-4
chmod 700 get_helm.sh
./get_helm.sh
rm -f get_helm.sh

# Install GitHub CLI (gh) — v2.32.0+ required for `gh variable` support
(type -p wget >/dev/null || (sudo apt update && sudo apt-get install wget -y)) \
  && sudo mkdir -p -m 755 /etc/apt/keyrings \
  && wget -qO- https://cli.github.com/packages/githubcli-archive-keyring.gpg \
     | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null \
  && sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg \
  && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] \
     https://cli.github.com/packages stable main" \
     | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
  && sudo apt update \
  && sudo apt install gh -y

# If gh was already installed via a different source, upgrade it so `gh variable` works
GH_VERSION=$(gh --version 2>/dev/null | head -1 | grep -oP '\d+\.\d+\.\d+' | head -1)
GH_MAJOR=$(echo "$GH_VERSION" | cut -d. -f1)
GH_MINOR=$(echo "$GH_VERSION" | cut -d. -f2)
if [ -n "$GH_MAJOR" ] && { [ "$GH_MAJOR" -lt 2 ] || { [ "$GH_MAJOR" -eq 2 ] && [ "$GH_MINOR" -lt 32 ]; }; }; then
  echo "gh CLI $GH_VERSION is too old (need 2.32.0+). Upgrading..."
  sudo apt update && sudo apt install gh -y
fi

echo ""
echo "All tools installed. Verify with:"
echo "  docker --version && aws --version && kubectl version --client && terraform --version && gh --version"
echo ""
echo "NOTE: Log out and back in (or run 'newgrp docker') for Docker group membership to take effect."

