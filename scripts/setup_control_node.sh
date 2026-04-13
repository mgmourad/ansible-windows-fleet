#!/bin/bash
# ============================================================
# Setup Ansible Control Node
# Run this on your Linux host (Ubuntu/Debian) or WSL2
# ============================================================

set -euo pipefail

echo "========================================="
echo "  Ansible Control Node Setup"
echo "========================================="

# Step 1: Install system dependencies
echo "[1/5] Installing system dependencies..."
sudo apt-get update -qq
sudo apt-get install -y -qq \
    python3 \
    python3-pip \
    python3-venv \
    sshpass \
    git \
    libkrb5-dev \
    krb5-user

# Step 2: Create virtual environment
echo "[2/5] Creating Python virtual environment..."
python3 -m venv ~/.ansible-venv
source ~/.ansible-venv/bin/activate

# Step 3: Install Ansible and dependencies
echo "[3/5] Installing Ansible and Windows dependencies..."
pip install --upgrade pip
pip install \
    ansible \
    ansible-lint \
    molecule \
    pywinrm \
    "pywinrm[credssp]" \
    requests \
    jinja2

# Step 4: Install Galaxy collections
echo "[4/5] Installing Ansible Galaxy collections..."
if [ -f "requirements.yml" ]; then
    ansible-galaxy collection install -r requirements.yml --force
else
    echo "  No requirements.yml found — installing core collections..."
    ansible-galaxy collection install ansible.windows
    ansible-galaxy collection install chocolatey.chocolatey
    ansible-galaxy collection install community.windows
    ansible-galaxy collection install community.general
fi

# Step 5: Verify
echo "[5/5] Verifying installation..."
echo "  Ansible version:  $(ansible --version | head -1)"
echo "  Python version:   $(python3 --version)"
echo "  pywinrm version:  $(pip show pywinrm | grep Version)"
echo ""
echo "========================================="
echo "  Setup Complete!"
echo "========================================="
echo ""
echo "Activate the virtual environment:"
echo "  source ~/.ansible-venv/bin/activate"
echo ""
echo "Test connectivity to a Windows host:"
echo "  ansible windows -m win_ping --ask-vault-pass"
