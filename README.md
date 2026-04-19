# K8s RBAC & CLI Demo Setup

This repository contains automation to prepare a Kubernetes environment for RBAC demonstrations and Akeyless CLI validation.

### 🎯 Project Goal
**The primary goal of this project is to automate the deployment of a multi-namespace environment to demonstrate Akeyless RBAC and CLI capabilities.**

## 📂 Core Components
| File | Function |
| :--- | :--- |
| setup_demo_env.sh | **Setup**: Validates context, creates namespaces, deploys pods, and checks Akeyless CLI. |

## 🏗️ Setup Scope (setup_demo_env.sh)
The `setup_demo_env.sh` script automates the following steps:

### 1. Environment Validation
- **Safety Check**: Validates the active Kubernetes context to prevent accidental changes in Production.
- **Tool Check**: Ensures `kubectl` is installed and accessible.

### 2. Kubernetes Resource Provisioning
- **Namespaces**: Creates multiple isolated namespaces (`namespace-a`, `namespace-b`).
- **Pods**: Launches NGINX pods in each namespace to serve as CLI targets.
- **Mapping**: Automatically maps specific pods to their respective namespaces.

### 3. Akeyless CLI Validation
- **Status Check**: Verifies if pods are in `Running` state.
- **CLI Check**: Executes inside the pod to verify if the Akeyless CLI is installed and configured in the PATH.
- **Interactive Guide**: Provides manual installation steps if the CLI is missing.

## ⚙️ Configuration Variables
The following variables are defined within the script:

### Kubernetes Settings
- **TARGET_CONTEXT**: `vcluster_my-vcluster_leon_gke_customer-success-391112_us-central1_customer-success-391112-gke-sandbox`
- **NAMESPACES**: `("namespace-a" "namespace-b")`
- **POD_MAP**: Mapping of pod names to their designated namespaces.

## 🚀 Usage
1. Ensure your Kubernetes context is set correctly.
2. Run the setup script:
```bash
chmod +x setup_demo_env.sh
./setup_demo_env.sh
```

---
**Maintained by**: [leon-maister](https://github.com/leon-maister)

<sub style="color: gray;">/home/keyless/k8s-rbac-demo | vcluster_my-vcluster_leon_gke_customer-success-391112_us-central1_customer-success-391112-gke-sandbox</sub>
