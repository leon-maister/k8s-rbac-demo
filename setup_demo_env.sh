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

# Mapping pods to namespaces
declare -A POD_MAP
POD_MAP["mypod-a"]="namespace-a"
POD_MAP["mypod-b"]="namespace-b"

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

# --- 4. Check and Run Pods ---
printf "${CYAN}--- Checking pods ---${NC}\n"

for pod in "${!POD_MAP[@]}"; do
    ns=${POD_MAP[$pod]}
    
    if kubectl get pod "$pod" -n "$ns" &> /dev/null; then
        printf "${GREEN}SUCCESS: Pod '$pod' is already present in namespace '$ns'.${NC}\n"
    else
        printf "${YELLOW}Pod '$pod' not found in '$ns'. Launching...${NC}\n"
        kubectl run "$pod" --image=nginx -n "$ns"
        
        if [ $? -eq 0 ]; then
            printf "${GREEN}SUCCESS: Pod '$pod' launched.${NC}\n"
        else
            printf "${RED}ERROR: Failed to launch pod '$pod'.${NC}\n"
            continue
        fi
    fi
done

# --- 5. Check Akeyless CLI inside Pods ---
printf "${CYAN}--- Checking Akeyless CLI inside pods ---${NC}\n"
sleep 5

for pod in "${!POD_MAP[@]}"; do
    ns=${POD_MAP[$pod]}
    
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
        printf "${RED}WARNING: Akeyless CLI is NOT found or NOT working inside '$pod'.${NC}\n"
        echo "--------------------------------------------------------"
        printf "${YELLOW}To install and CONFIGURE it manually, follow these steps:${NC}\n"
        printf "1. Enter the pod:\n"
        printf "${CYAN}kubectl exec --stdin=true --namespace $ns --tty=true $pod -- /bin/bash${NC}\n\n"
        
        printf "2. Download and prepare the binary:\n"
        printf "${CYAN}curl -o akeyless https://akeyless-cli.s3.us-east-2.amazonaws.com/cli/latest/production/cli-linux-amd64 && chmod +x akeyless${NC}\n\n"
        
        printf "3. Run initial setup and follow these interactive prompts:\n"
        printf "${CYAN}./akeyless --help${NC}\n"
        printf "   - Would you like to configure a profile? (Y/n) -> Type ${GREEN}n${NC}\n"
        printf "   - Please type your answer: (Default: vault.akeyless.io) -> Press ${GREEN}ENTER${NC}\n"
        printf "   - Would you like to move 'akeyless' binary to: /root/.akeyless/bin/akeyless? (Y/n) -> Type ${GREEN}Y${NC}\n"
        printf "   - Would you like to add '/root/.akeyless/bin' To user PATH environment variable? (Y/n) -> Type ${GREEN}Y${NC}\n\n"
        
        printf "4. IMPORTANT: Apply changes to your current session:\n"
        printf "${CYAN}source /root/.profile${NC}\n\n"

        printf "5. Verify installation:\n"
        printf "${CYAN}akeyless --version${NC}\n"
        echo "--------------------------------------------------------"
    fi
done