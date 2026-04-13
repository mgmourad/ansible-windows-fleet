# 🖥️ ansible-windows-fleet

**Enterprise-grade Windows endpoint fleet automation using Ansible, AWX, and Jenkins.**

Automates software deployment, registry enforcement, user lifecycle management, Windows Update compliance, and PowerShell DSC integration across a Windows endpoint fleet — orchestrated through a Jenkins → AWX pipeline.

---

## 🏗️ Architecture

```md
┌─────────────────────────────────────────────────────────────┐
│                     JENKINS SERVER                          │
│         (Pipeline trigger + orchestration)                  │
│         Runs on: Docker container on Linux host             │
└──────────────┬──────────────────────────────────────────────┘
               │ Triggers via API call
               ▼
┌─────────────────────────────────────────────────────────────┐
│                     AWX (Ansible Tower OSS)                 │
│         (Inventory, credentials, job templates)             │
│         Runs on: K3s cluster (AWX Operator)                 │
└──────────────┬──────────────────────────────────────────────┘
               │ Executes playbooks via
               ▼
┌─────────────────────────────────────────────────────────────┐
│                   ANSIBLE CONTROL NODE                      │
│         (Built into AWX containers)                         │
│         Playbooks → Roles → Vault-encrypted vars            │
└──────────────┬──────────────────────────────────────────────┘
               │ WinRM (HTTPS/5986)
               ▼
┌─────────────────────────────────────────────────────────────┐
│              WINDOWS ENDPOINT FLEET                         │
│    ┌──────────┐  ┌──────────┐  ┌───────────┐                │
│    │  Win11   │  │  Win11   │  │ Win Server│                │
│    │  VM #1   │  │  VM #2   │  │  2022 VM  │                │
│    └──────────┘  └──────────┘  └───────────┘                │
│    (Software, Registry, Users, Updates, DSC)                │
└─────────────────────────────────────────────────────────────┘
```

## 🎯 What This Automates

| Role | Description |
|------|-------------|
| **software_deploy** | Installs Chocolatey, deploys/updates packages fleet-wide |
| **registry_config** | Enforces registry policies with before/after snapshots |
| **user_management** | Creates service accounts, audits admin group membership |
| **windows_updates** | Scans for missing updates, optionally installs with deferred reboot |
| **dsc_integration** | Configures PowerShell DSC — NuGet, PSGallery, modules, LCM, service enforcement |

## 🛠️ Tech Stack

- **Ansible** — Configuration management and orchestration
- **AWX** — Ansible Tower (open-source) for job scheduling and API
- **Jenkins** — CI/CD pipeline trigger
- **WinRM** — Windows Remote Management over HTTPS
- **PowerShell DSC** — Desired State Configuration enforcement
- **Chocolatey** — Windows package management
- **Ansible Vault** — Encrypted secrets management
- **K3s** — Lightweight Kubernetes for AWX hosting

## 🚀 Quick Start

### 1. Set up the Ansible control node
```bash
chmod +x scripts/setup_control_node.sh
./scripts/setup_control_node.sh
```

### 2. Bootstrap Windows VMs
```powershell
# On each Windows VM (as Administrator):
Set-ExecutionPolicy Bypass -Scope Process -Force
.\scripts\Configure-WinRMForAnsible.ps1
```

### 3. Configure credentials
```bash
# Edit vault file with real credentials
ansible-vault edit group_vars/windows/vault.yml
```

### 4. Test connectivity
```bash
ansible windows -m win_ping --ask-vault-pass
```

### 5. Run the fleet
```bash
# Dry run
ansible-playbook playbooks/site.yml --check --ask-vault-pass

# Full enforcement
ansible-playbook playbooks/site.yml --ask-vault-pass
```

## 📁 Project Structure

```
ansible-windows-fleet/
├── ansible.cfg                    # Ansible project settings
├── requirements.yml               # Galaxy collection dependencies
├── Jenkinsfile                    # CI/CD pipeline definition
├── docker-compose.jenkins.yml     # Jenkins container setup
├── inventories/                   # Target host definitions
│   ├── dev/hosts.yml              # Home lab hosts
│   └── prod/hosts.yml             # Production template
├── group_vars/                    # Group-level variables
│   ├── all/main.yml               # Global variables
│   └── windows/
│       ├── main.yml               # Windows packages, registry, users, updates, DSC
│       └── vault.yml              # Encrypted secrets
├── host_vars/                     # Per-host overrides
│   └── win11-vm01.yml
├── roles/                         # Reusable automation roles
│   ├── software_deploy/           # Chocolatey package management
│   ├── registry_config/           # Registry policy enforcement
│   ├── user_management/           # Local user lifecycle
│   ├── windows_updates/           # Windows Update compliance
│   └── dsc_integration/           # PowerShell DSC convergence
├── playbooks/                     # Orchestration playbooks
│   ├── site.yml                   # Full fleet enforcement
│   ├── deploy_software.yml        # Software-only deployment
│   ├── compliance_check.yml       # Read-only compliance scan
│   └── integration_test.yml       # End-to-end state validation
├── scripts/                       # Bootstrap & utilities
│   ├── Configure-WinRMForAnsible.ps1
│   ├── setup_control_node.sh
│   └── generate_compliance_report.py
└── docs/                          # Execution guides

```

## 🔑 Key Design Decisions

1. **WinRM HTTPS over SSH** — Native Windows remote management, no OpenSSH dependency
2. **NTLM for dev, Kerberos for prod** — Practical security progression
3. **Before/after registry snapshots** — Audit trail for compliance
4. **Deferred reboot via scheduled task** — Avoids disrupting active user sessions
5. **Molecule with delegated driver** — Tests against real Windows VMs (no Docker for Windows)
6. **AWX over direct Ansible CLI** — Centralized credentials, job scheduling, API for Jenkins

## 📊 Metrics

| Metric | Value |
|--------|-------|
| Endpoints managed | 3 (scalable) |
| Configuration checks per run | 50+ |
| Manual RDP sessions eliminated | 100% |
| Playbook execution time (full fleet) | ~8 minutes |
| Roles | 5 |
| Total automation files | 43+ |

## 📝 Lessons Learned

- **WinRM self-signed certs are fragile** — The bootstrap script must handle cert rotation and listener recreation idempotently
- **DSC and Ansible can coexist** — Use Ansible for orchestration, DSC for continuous drift remediation
- **Registry snapshots are essential** — Without before/after comparison, you can't prove compliance
- **AWX Operator on K3s is production-viable** — Simpler than full K8s, sufficient for home lab and small teams
- **Vault discipline matters early** — Encrypting secrets from day one prevents accidental exposure in Git history

## 📄 License

MIT License — See [LICENSE](LICENSE) for details.

## 👤 Author

Mohammed Mourad — Endpoint Automation → DevOps Engineer

[GitHub](https://github.com/<your-username>) | [LinkedIn](https://linkedin.com/in/<your-profile>)
