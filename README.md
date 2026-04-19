# K8s RBAC & CLI Demo Setup

This repository contains automation to prepare a Kubernetes environment for RBAC demonstrations and Akeyless CLI validation.

### 🎯 Project Goal
**The primary goal of this project is to automate the deployment of a multi-namespace environment and validate Akeyless RBAC configurations based on Sub-Claims.**

## 📂 Core Components
| File | Function |
| :--- | :--- |
| setup_demo_env.sh | **Orchestrator**: Validates K8s context, checks Akeyless RBAC, creates namespaces, and verifies CLI inside pods. |

## 🏗️ Setup Scope (setup_demo_env.sh)
The script automates the following critical steps:

### 1. Environment & Context Validation
- **K8s Context**: Prevents execution in the wrong cluster.
- **Akeyless Auth Method**: Verifies that `/K8s/k8s-ns-rbac-demo` exists and is accessible.

### 2. RBAC & Sub-Claims Verification
- **Role Association**: Checks if required roles are linked to the Auth Method.
- **Roles Checked**:
  - `Demo/K8S/Namespace-Demo/Access_Namespace-A`
  - `Demo/K8S/Namespace-Demo/Access_Namespace-B`

### 3. Kubernetes Resource Provisioning
- **Namespaces**: Isolated environments (`namespace-a`, `namespace-b`).
- **Pods**: NGINX targets for CLI validation.

### 4. Akeyless CLI Verification
- **Runtime Check**: Source profile and check version inside running pods.
- **Interactive Guide**: Provides clear instructions if the CLI is missing.

## ⚙️ Configuration Variables
- **TARGET_CONTEXT**: The safe GKE/vCluster context for deployment.
- **AUTH_METHOD_NAME**: `/K8s/k8s-ns-rbac-demo`

## 🚀 Usage
1. Ensure you are logged into Akeyless CLI on your host.
2. Run the setup script:
```bash
chmod +x setup_demo_env.sh
./setup_demo_env.sh
```

---
**Maintained by**: [leon-maister](https://github.com/leon-maister)

<sub style="color: gray;">/home/keyless/k8s-rbac-demo | vcluster_my-vcluster_leon_gke_customer-success-391112_us-central1_customer-success-391112-gke-sandbox</sub>
