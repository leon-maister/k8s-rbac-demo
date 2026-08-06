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

### 3. Workload Orchestration (Deployments)
- **Deployment Management**: Ensures the `mypod-a` and `mypod-b` Deployments each maintain one replica.
- **Automatic Recovery**: Kubernetes recreates Pods after deletion or cluster/vCluster disruption.
- **Dynamic Pod Names**: Deployment-managed Pod names are intentionally generated and must not be treated as fixed.

### 4. In-Pod Environment Verification
- **Dynamic Discovery**: Finds the current running Pod for each Deployment by label.
- **Akeyless CLI Audit**: Verifies the CLI inside each Pod and installs it non-interactively when missing.

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

### 1. UI Overview (Secrets & RBAC)
Before diving into the terminal, open the Akeyless Console to show the configuration:
- **Items**: Navigate to `/Demo/K8S-NS-Demo/` and show the secrets for **Namespace-A** and **Namespace-B**.
- **Users & Auth Methods**: Open `/K8s/k8s-ns-rbac-demo`.
- **Role Binding**: Explain how this Auth Method is linked to specific Roles. Point out that the access is governed by **Sub-Claims** (e.g., matching the Kubernetes Namespace), which determines which role is assigned to the session.

### 2. Verify Infrastructure
Show the namespaces, Deployments, and dynamically generated Pods:
```bash
echo "--- NAMESPACES ---" && kubectl get ns | grep -E '^namespace-a |^namespace-b ' && echo "" && echo "--- DEPLOYMENTS ---" && kubectl get deployments -n namespace-a && kubectl get deployments -n namespace-b && echo "" && echo "--- PODS ---" && kubectl get pods -A | grep -E '^namespace-a |^namespace-b '
```

### 3. Enter Pod in Namespace A
Access the current Pod through its Deployment with UTF-8 support and the pre-configured Akeyless environment:
```bash
kubectl exec -it -n namespace-a deploy/mypod-a -- /bin/bash -c "export LC_ALL=C.UTF-8 && export LANG=C.UTF-8 && source /root/.profile && exec /bin/bash"
```

### 4. Authenticate with Akeyless
Inside the pod, use the K8s Auth Method to log in:
```bash
TOKEN=$(akeyless auth --access-id p-ndm5ecusra7akm --access-type k8s --gateway-url http://34.30.91.46:8000/ --k8s-auth-config-name k8s-config-vcluster --json --jq-expression '.token')
export TOKEN
echo "$TOKEN"
```

### 5. Inspect Sub-Claims
Verify the claims within your session token (copy the token from the previous step):
```bash
akeyless describe-sub-claims --token $TOKEN
```

### 6. Access Secrets (RBAC Enforcement)
Demonstrate that access is restricted to the current namespace:

**Success**: Get secret for Namespace A:
```bash
akeyless get-secret-value --name /Demo/K8S-NS-Demo/Namespace-A/secret-namespace-A --token $TOKEN
```

**Failure**: Attempt to access secret for Namespace B (Access Denied):
```bash
akeyless get-secret-value --name /Demo/K8S-NS-Demo/Namespace-B/secret-namespace-B --token $TOKEN
```

---
**Maintained by**: [leon-maister](https://github.com/leon-maister)

<sub style="color: gray;">/home/keyless/k8s/k8s-rbac-demo | vcluster_my-vcluster_leon_gke_customer-success-391112_us-central1_customer-success-391112-gke-sandbox</sub>
