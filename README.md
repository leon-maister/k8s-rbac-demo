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
- **K8s Context Check**: Validates the active `kubectl` context against the target safety variable.
- **Tooling Check**: Ensures `kubectl` and necessary binaries are available.

### 2. Namespace Management
- **Discovery**: Checks if `namespace-a` and `namespace-b` already exist.
- **Provisioning**: Automatically creates missing namespaces if they are not found.

### 3. Workload Orchestration (Pods)
- **Status Audit**: Checks for the presence of `mypod-a` and `mypod-b` in their respective namespaces.
- **Deployment**: Launches NGINX-based pods if they are missing.
- **Readiness**: Waits and validates that all pods have reached the `Running` state.

### 4. In-Pod Environment Verification
- **Akeyless CLI Audit**: Executes commands inside pods to verify Akeyless CLI installation and PATH configuration.

### 5. Akeyless Auth & RBAC Validation
- **Auth Method Verification**: Confirms that `/K8s/k8s-ns-rbac-demo` is active in Akeyless.
- **RBAC Audit**: Validates that the required roles (`Access_Namespace-A/B`) are correctly associated with the Auth Method.

## ⚙️ Configuration Variables
- **TARGET_CONTEXT**: The safe GKE/vCluster context for deployment.
- **AUTH_METHOD_NAME**: `/K8s/k8s-ns-rbac-demo`

## 🛠 Usage
1. Ensure you are logged into Akeyless CLI on your host.
2. Run the setup script:
```bash
chmod +x setup_demo_env.sh
./setup_demo_env.sh
```

## 🚀 Demo Walkthrough
Follow these steps to demonstrate the RBAC isolation:

### 1. Verify Infrastructure
Show that the environment is ready and isolated namespaces are created:
```bash
kubectl get ns
```

### 2. Enter Pod in Namespace A
Access the pod with the pre-configured Akeyless environment:
```bash
kubectl exec -it -n namespace-a mypod-a -- /bin/bash -c "source /root/.profile && exec /bin/bash"
```

---
**Maintained by**: [leon-maister](https://github.com/leon-maister)

<sub style="color: gray;">/home/keyless/k8s-rbac-demo | vcluster_my-vcluster_leon_gke_customer-success-391112_us-central1_customer-success-391112-gke-sandbox</sub>
