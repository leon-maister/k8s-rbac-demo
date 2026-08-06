#!/bin/bash

# --- UTF-8 Safety ---
export LC_ALL=C.UTF-8
export LANG=C.UTF-8

# --- ANSI Color Codes ---
RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# --- CONFIGURATION ---
TARGET_CONTEXT="vcluster_my-vcluster_leon_gke_customer-success-391112_us-central1_customer-success-391112-gke-sandbox"
NAMESPACES=("namespace-a" "namespace-b")

# The Access ID from your K8s Auth Method (k8s-ns-rbac-demo)
AUTH_METHOD_NAME="/K8s/k8s-ns-rbac-demo-vc"
EXPECTED_ROLES=(
    "Demo/K8S/Namespace-Demo/Access_Namespace-A"
    "Demo/K8S/Namespace-Demo/Access_Namespace-B"
)

# Mapping deployments to namespaces
declare -A DEPLOYMENT_MAP
DEPLOYMENT_MAP["mypod-a"]="namespace-a"
DEPLOYMENT_MAP["mypod-b"]="namespace-b"

get_deployment_pod() {
    local deployment="$1"
    local namespace="$2"

    kubectl get pods \
        --namespace "$namespace" \
        --selector "app=$deployment" \
        --field-selector status.phase=Running \
        --sort-by=.metadata.creationTimestamp \
        --output jsonpath='{.items[-1].metadata.name}' \
        2>/dev/null
}

printf "${CYAN}--- Starting environment validation ---${NC}\n"

# --- 1. Check if kubectl is installed ---
if ! command -v kubectl &> /dev/null; then
    printf "${RED}ERROR: kubectl is not installed.${NC}\n"
    exit 1
fi

# --- 2. Validate Kubernetes Context ---
CURRENT_CONTEXT=$(kubectl config current-context)

if [ "$CURRENT_CONTEXT" != "$TARGET_CONTEXT" ]; then
    echo "--------------------------------------------------------"
    printf "${RED}ERROR: Wrong kubernetes context detected!${NC}\n"
    echo "Current context:  $CURRENT_CONTEXT"
    echo "Expected context: $TARGET_CONTEXT"
    printf "${RED}Execution stopped to prevent accidental changes.${NC}\n"
    echo "--------------------------------------------------------"
    exit 1
fi

printf "${GREEN}SUCCESS: Cluster context validated.${NC}\n"

# --- 3. Check and Create Namespaces ---
printf "${CYAN}--- Checking namespaces ---${NC}\n"

for ns in "${NAMESPACES[@]}"; do
    if kubectl get namespace "$ns" &> /dev/null; then
        printf "${GREEN}SUCCESS: Namespace '$ns' already exists.${NC}\n"
    else
        printf "${YELLOW}Namespace '$ns' not found. Creating...${NC}\n"
        kubectl create namespace "$ns"
        if [ $? -eq 0 ]; then
            printf "${GREEN}SUCCESS: Namespace '$ns' created.${NC}\n"
        else
            printf "${RED}ERROR: Failed to create namespace '$ns'.${NC}\n"
            exit 1
        fi
    fi
done

# --- 4. Check and Create Deployments ---
printf "${CYAN}--- Checking deployments ---${NC}\n"

for deployment in "${!DEPLOYMENT_MAP[@]}"; do
    ns=${DEPLOYMENT_MAP[$deployment]}

    if kubectl get deployment "$deployment" -n "$ns" &> /dev/null; then
        printf "${GREEN}SUCCESS: Deployment '$deployment' already exists in namespace '$ns'.${NC}\n"
    else
        printf "${YELLOW}Deployment '$deployment' not found in '$ns'. Creating...${NC}\n"
        kubectl create deployment "$deployment" --image=nginx --replicas=1 -n "$ns"

        if [ $? -eq 0 ]; then
            printf "${GREEN}SUCCESS: Deployment '$deployment' created.${NC}\n"
        else
            printf "${RED}ERROR: Failed to create deployment '$deployment'.${NC}\n"
            continue
        fi
    fi

    printf "${CYAN}Waiting for Deployment '$deployment' to have one Available replica...${NC}\n"
    if kubectl wait \
        --namespace "$ns" \
        --for=condition=Available \
        "deployment/$deployment" \
        --timeout=120s; then
        if kubectl wait \
            --namespace "$ns" \
            --selector "app=$deployment" \
            --for=condition=Ready \
            pod \
            --timeout=120s; then
            printf "${GREEN}SUCCESS: Deployment '$deployment' has one Available replica.${NC}\n"
        else
            printf "${RED}ERROR: Deployment '$deployment' has no Ready Pod.${NC}\n"
            continue
        fi
    else
        printf "${RED}ERROR: Deployment '$deployment' did not become Available.${NC}\n"
        continue
    fi
done

# --- 5. Check Akeyless CLI inside Pods ---
printf "${CYAN}--- Checking Akeyless CLI inside pods ---${NC}\n"

for deployment in "${!DEPLOYMENT_MAP[@]}"; do
    ns=${DEPLOYMENT_MAP[$deployment]}
    pod=$(get_deployment_pod "$deployment" "$ns")

    if [ -z "$pod" ]; then
        printf "${YELLOW}WARNING: No running Pod found for Deployment '$deployment' in namespace '$ns'. Skipping CLI check.${NC}\n"
        continue
    fi

    printf "Checking pod ${CYAN}$pod${NC} in namespace ${CYAN}$ns${NC}...\n"

    # Check if pod is actually running
    POD_STATUS=$(kubectl get pod "$pod" -n "$ns" -o jsonpath='{.status.phase}')
    if [ "$POD_STATUS" != "Running" ]; then
        printf "${YELLOW}WARNING: Pod '$pod' is in state '$POD_STATUS'. Skipping CLI check.${NC}\n"
        continue
    fi

    # Execute check: source profile and then check version
    if kubectl exec -n "$ns" "$pod" -- /bin/bash -c "source /root/.profile && akeyless --version" &> /dev/null; then
        VERSION=$(kubectl exec -n "$ns" "$pod" -- /bin/bash -c "source /root/.profile && akeyless --version" | head -n 1)
        printf "${GREEN}SUCCESS: Akeyless CLI is active inside '$pod'.${NC}\n"
        printf "${CYAN}Info: $VERSION${NC}\n"
    else
        printf "${YELLOW}Akeyless CLI is not available inside '$pod'. Installing...${NC}\n"

        if ! kubectl exec -n "$ns" "$pod" -- /bin/bash -c '
            set -e

            install_dir="/root/.akeyless/bin"
            profile_file="/root/.profile"
            path_line="export PATH=\"/root/.akeyless/bin:\$PATH\""
            download_url="https://akeyless-cli.s3.us-east-2.amazonaws.com/cli/latest/production/cli-linux-amd64"

            mkdir -p "$install_dir"
            temporary_file=$(mktemp "$install_dir/.akeyless.XXXXXX")
            trap "rm -f \"$temporary_file\"" EXIT

            curl --fail --silent --show-error --location \
                --output "$temporary_file" \
                "$download_url"
            chmod +x "$temporary_file"
            mv "$temporary_file" "$install_dir/akeyless"
            trap - EXIT

            touch "$profile_file"
            if ! grep -Fqx "$path_line" "$profile_file"; then
                printf "%s\n" "$path_line" >> "$profile_file"
            fi
        '; then
            printf "${RED}ERROR: Failed to install Akeyless CLI inside '$pod'.${NC}\n"
            exit 1
        fi

        if kubectl exec -n "$ns" "$pod" -- /bin/bash -c "source /root/.profile && akeyless --version" &> /dev/null &&
            VERSION_OUTPUT=$(kubectl exec -n "$ns" "$pod" -- /bin/bash -c "source /root/.profile && akeyless --version"); then
            VERSION=${VERSION_OUTPUT%%$'\n'*}
            printf "${GREEN}SUCCESS: Akeyless CLI installed inside '$pod'.${NC}\n"
            printf "${CYAN}Info: $VERSION${NC}\n"
        else
            printf "${RED}ERROR: Akeyless CLI verification failed inside '$pod'.${NC}\n"
            exit 1
        fi
    fi

  # --- 6. Validate Akeyless Auth Method & RBAC ---
printf "${CYAN}--- Validating Akeyless Auth Method & RBAC ---${NC}\n"

METHOD_DATA=$(akeyless auth-method get --name "$AUTH_METHOD_NAME" --json 2>/dev/null)

if [ $? -ne 0 ]; then
    printf "${RED}ERROR: Auth Method '$AUTH_METHOD_NAME' not found.${NC}\n"
    exit 1
fi
printf "${GREEN}SUCCESS: Auth Method '$AUTH_METHOD_NAME' verified.${NC}\n"

printf "${CYAN}Checking associated RBAC roles...${NC}\n"

for role in "${EXPECTED_ROLES[@]}"; do
    # Search specifically in the auth_method_roles_assoc array
    # We use sub-string matching or exact matching to find the role_name
    IS_PRESENT=$(echo "$METHOD_DATA" | jq -r --arg ROLE "$role" '.auth_method_roles_assoc[]? | select(.role_name == $ROLE) | .role_name')

    if [ "$IS_PRESENT" == "$role" ]; then
        printf "${GREEN}SUCCESS: Role '$role' is correctly associated.${NC}\n"
    else
        printf "${RED}ERROR: Critical RBAC missing! Role '$role' is NOT associated.${NC}\n"
        printf "${YELLOW}Found in JSON: Use exact path and case (K8S vs K8s).${NC}\n"
        exit 1
    fi
done

printf "${GREEN}SUCCESS: All Akeyless RBAC requirements met.${NC}\n"

done