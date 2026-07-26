#!/bin/bash

# --- UTF-8 Safety ---
export LC_ALL=C.UTF-8
export LANG=C.UTF-8

# --- ANSI Color Codes (same as Setup Script) ---
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

# --- CONFIGURATION ---
source ./config.sh
LOG_FILE="$CREATE_LOG_FILE"
SECRET_NAME="sa-reviewer-token"
PROFILE_NAME="default"

# --- LOGGING SETUP ---
exec > >(tee -a "$LOG_FILE") 2>&1

printf "${CYAN}--- Script started at $(date) ---${NC}\n"
printf "${CYAN}--- Checking Environment ---${NC}\n"

if [ "$AKEYLESS_GATEWAY_URL" != "$GW_URL" ]; then

    printf "${RED}ERROR: Gateway URL mismatch detected.${NC}\n"
    echo "Environment variable AKEYLESS_GATEWAY_URL: $AKEYLESS_GATEWAY_URL"
    echo "Script variable GW_URL: $GW_URL"
    echo "Please update either the environment variable or the GW_URL value so they match."

    exit 1
fi

printf "${GREEN}SUCCESS: Gateway URL validated.${NC}\n"


CURRENT_CTX=$(kubectl config current-context)
printf "${CYAN}Active Kubernetes context:${NC} %s\n" "$CURRENT_CTX"


kubectl create namespace $TEST_NS --dry-run=client -o yaml | kubectl apply -f -

cat <<EOF > $SA_FILE
apiVersion: v1
kind: ServiceAccount
metadata:
  name: $SA_NAME
  namespace: $TEST_NS
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: role-tokenreview-binding-$TEST_NS
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: system:auth-delegator
subjects:
- kind: ServiceAccount
  name: $SA_NAME
  namespace: $TEST_NS
EOF


cat <<EOF > $TOKEN_FILE
apiVersion: v1
kind: Secret
metadata:
  name: $SECRET_NAME
  namespace: $TEST_NS
  annotations:
    kubernetes.io/service-account.name: $SA_NAME
type: kubernetes.io/service-account-token
EOF


printf "${CYAN}--- Applying Kubernetes manifests ---${NC}\n"

kubectl apply -f $SA_FILE
kubectl apply -f $TOKEN_FILE

sleep 5


# Extract Credentials
printf "${CYAN}--- Extracting cluster credentials ---${NC}\n"

SA_JWT_TOKEN=$(kubectl get secret $SECRET_NAME -n $TEST_NS --output='go-template={{.data.token | base64decode}}')
printf "${GREEN}Token extracted.${NC}\n"

CA_CERT=$(kubectl config view --raw --minify --flatten --output='jsonpath={.clusters[].cluster.certificate-authority-data}')
printf "${GREEN}CA certificate captured.${NC}\n"

K8S_HOST=$(kubectl config view --minify --output jsonpath='{.clusters[0].cluster.server}')
printf "${GREEN}Kubernetes host detected:${NC} %s\n" "$K8S_HOST"

K8S_ISSUER=$(kubectl get --raw /.well-known/openid-configuration | jq -r '.issuer' 2>/dev/null)

if [ -z "$K8S_ISSUER" ] || [ "$K8S_ISSUER" == "null" ]; then
    printf "${RED}ERROR: Failed to fetch K8S_ISSUER.${NC}\n"
    exit 1
fi

printf "${GREEN}Kubernetes issuer detected.${NC}\n"


# --- Create Akeyless Auth Method ---
printf "${CYAN}--- Creating Akeyless Auth Method ---${NC}\n"

AUTH_RESULT=$(akeyless create-auth-method-k8s --name "$AUTH_METHOD_NAME" --profile $PROFILE_NAME --json)

ACCESS_ID=$(echo $AUTH_RESULT | jq -r '.access_id')
PRV_KEY=$(echo $AUTH_RESULT | jq -r '.prv_key')

printf "${GREEN}SUCCESS: Auth Method created.${NC}\n"

echo "ACCESS_ID: $ACCESS_ID"
echo "PRV_KEY: $PRV_KEY"

printf "${CYAN}--- Checking if Akeyless Role '$ROLE_NAME' exists ---${NC}\n"

if ! akeyless get-role --name "$ROLE_NAME" --profile "$PROFILE_NAME" >/dev/null 2>&1; then
    printf "${YELLOW}Role '$ROLE_NAME' not found. Creating it...${NC}\n"
    akeyless create-role --name "$ROLE_NAME" --profile "$PROFILE_NAME"
    printf "${GREEN}SUCCESS: Role '$ROLE_NAME' created.${NC}\n"
	ROLE_CREATED=true
else
    printf "${GREEN}SUCCESS: Role '$ROLE_NAME' already exists.${NC}\n"
fi

akeyless assoc-role-am --role-name "$ROLE_NAME" --am-name "$AUTH_METHOD_NAME" --profile $PROFILE_NAME

printf "${GREEN}SUCCESS: Role associated with Auth Method.${NC}\n"


# --- Configure Akeyless Gateway ---
printf "${CYAN}--- Configuring Akeyless Gateway ---${NC}\n"

printf "\nConfiguring Kubernetes Authentication Config with the following parameters:\n"
printf "%-15s : %s\n" "Config Name" "$GW_CONFIG_NAME"
printf "%-15s : %s\n" "Gateway URL" "$GW_URL"


akeyless gateway-create-k8s-auth-config \
    --name "$GW_CONFIG_NAME" \
    --gateway-url "$GW_URL" \
    --access-id "$ACCESS_ID" \
    --signing-key "$PRV_KEY" \
    --k8s-host "$K8S_HOST" \
    --k8s-issuer "$K8S_ISSUER" \
    --k8s-ca-cert "$CA_CERT" \
    --token-reviewer-jwt "$SA_JWT_TOKEN" \
    --profile $PROFILE_NAME


if [ $? -eq 0 ]; then

    echo "--------------------------------------------------------"
    printf "${GREEN}SUCCESS! Log saved to %s${NC}\n" "$LOG_FILE"
    echo "--------------------------------------------------------"

	if [ "$ROLE_CREATED" = true ]; then
		echo "--------------------------------------------------------"
		printf "${YELLOW}ATTENTION: The role '$ROLE_NAME' was created automatically.${NC}\n"
		printf "${YELLOW}Please remember to set up the necessary permissions (rules) for this role,${NC}\n"
		printf "${YELLOW}otherwise applications will not be able to access secrets.${NC}\n"
		echo "Example: akeyless set-role-rule --role-name \"$ROLE_NAME\" --path \"/path/to/secrets/*\" --rule-type item-all --capability read"
		echo "--------------------------------------------------------"
	fi

else

    printf "${RED}ERROR: Gateway configuration failed.${NC}\n"
    exit 1

fi