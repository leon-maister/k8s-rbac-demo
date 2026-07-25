# ==========================================
# Shared Configuration for K8s Authentication
# ==========================================

# Kubernetes Cluster Environment
TEST_NS="leon-k8-auth"
SA_NAME="gateway-token-reviewer"
SA_FILE="create_sa_gw_token_reviewer.yaml"
TOKEN_FILE="generate_token_for_sa.yaml"

# Akeyless Gateway Configuration
AUTH_METHOD_NAME="/K8s/k8s-ns-rbac-demo-vc"
GW_CONFIG_NAME="k8s-config-vcluster"
GW_URL="http://34.30.91.46:8000/api/v1"
ROLE_NAME="/K8sAccess"

# Logging Configurations
CREATE_LOG_FILE="create_k8s_auth.log"
CLEANUP_LOG_FILE="cleanup_k8s_auth.log"
