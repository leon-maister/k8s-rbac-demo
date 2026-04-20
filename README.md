# K8s RBAC Demo Setup

This repository contains automation to prepare a Kubernetes environment for RBAC demonstrations and Akeyless validation.

### 🎯 Project Goal
**The primary goal of this project is to automate the deployment of a multi-namespace environment and validate Akeyless RBAC configurations based on Sub-Claims.**

## 📂 Core Components
| File | Function |
| :--- | :--- |
| setup_demo_env.sh | **Orchestrator**: Executes environment validation, resource provisioning, and Akeyless RBAC auditing. |

## 🏗️ Setup Scope (setup_demo_env.sh)
The script executes the following workflow:

### 1. Environment Validation
- **K8s Context Check**: Validates the active `kubectl` context.
- **Tooling Check**: Ensures `kubectl` and necessary binaries are available.

### 2. Namespace Management
- **Discovery & Provisioning**: Manages `namespace-a` and `namespace-b`.

### 3. Workload Orchestration (Pods)
- **Deployment**: Ensures `mypod-a` and `mypod-b` are running.

### 4. In-Pod Environment Verification
- **Akeyless CLI Audit**: Verifies installation inside pods.

### 5. Akeyless Auth & RBAC Validation
- **RBAC Audit**: Validates roles associated with `/K8s/k8s-ns-rbac-demo`.

## ⚙️ Configuration Variables
- **TARGET_CONTEXT**: The safe GKE/vCluster context.
- **AUTH_METHOD_NAME**: `/K8s/k8s-ns-rbac-demo`

## 🛠 Usage
1. Ensure you are logged into Akeyless CLI on your host.
2. Run the setup script:
```bash
chmod +x setup_demo_env.sh
./setup_demo_env.sh
```

## 🚀 Demo Walkthrough

### 1. Verify Infrastructure
Show specific namespaces and pods with clean formatting:
```bash
echo "--- NAMESPACES ---" && kubectl get ns | grep -E '^namespace-a |^namespace-b ' && echo "" && echo "--- PODS ---" && kubectl get pods -A | grep -E '^namespace-a |^namespace-b '
```

### 2. Enter Pod in Namespace A
Access the pod with UTF-8 support and pre-configured Akeyless environment:
```bash
kubectl exec -it -n namespace-a mypod-a -- /bin/bash -c "export LC_ALL=C.UTF-8 && export LANG=C.UTF-8 && source /root/.profile && exec /bin/bash"
```

---
**Maintained by**: [leon-maister](https://github.com/leon-maister)

<sub style="color: gray;">/home/keyless/k8s-rbac-demo | vcluster_my-vcluster_leon_gke_customer-success-391112_us-central1_customer-success-391112-gke-sandbox</sub>
