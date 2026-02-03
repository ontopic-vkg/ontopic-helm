#!/bin/bash
# Deploy Ontopic Suite and configure Azure Application Gateway TCP backend
# This script re-applies the TCP configuration after each deployment since AGIC may remove it

set -e

# =============================================================================
# Configuration - Update these values for your environment
# =============================================================================
RESOURCE_GROUP=""           # Azure resource group containing Application Gateway
APP_GATEWAY_NAME=""         # Application Gateway name
AKS_RESOURCE_GROUP=""       # AKS resource group (if different from above)
AKS_CLUSTER_NAME=""         # AKS cluster name

# Helm configuration
HELM_RELEASE_NAME="ontopic-suite"
HELM_CHART="ontopic/ontopic-suite"
HELM_VALUES_FILE="values.yaml"
NAMESPACE="default"

# Application Gateway TCP configuration
BACKEND_POOL_NAME="postgres-backend"
BACKEND_SETTINGS_NAME="postgres-settings"
LISTENER_NAME="postgres-listener"
FRONTEND_PORT_NAME="postgres-frontend-port"
RULE_NAME="postgres-rule"
RULE_PRIORITY="100"

# Ports
POSTGRES_SERVICE_PORT="4300"        # Internal service port
POSTGRES_EXTERNAL_PORT="4300"       # External port on Application Gateway

# Kubernetes service name for ontopic-server
ONTOPIC_SERVER_SERVICE="ontopic-server"

# =============================================================================
# Validation
# =============================================================================
if [[ -z "$RESOURCE_GROUP" || -z "$APP_GATEWAY_NAME" ]]; then
    echo "Error: Please configure RESOURCE_GROUP and APP_GATEWAY_NAME at the top of this script"
    exit 1
fi

# =============================================================================
# Deploy Ontopic Suite
# =============================================================================
echo "Deploying Ontopic Suite..."

HELM_CMD="helm upgrade --install $HELM_RELEASE_NAME $HELM_CHART"
if [[ -n "$HELM_VALUES_FILE" && -f "$HELM_VALUES_FILE" ]]; then
    HELM_CMD="$HELM_CMD -f $HELM_VALUES_FILE"
fi
if [[ -n "$NAMESPACE" ]]; then
    HELM_CMD="$HELM_CMD -n $NAMESPACE"
fi

eval $HELM_CMD

# =============================================================================
# Wait for LoadBalancer IP
# =============================================================================
echo "Waiting for LoadBalancer IP..."

TIMEOUT=300
INTERVAL=5
ELAPSED=0

while [[ $ELAPSED -lt $TIMEOUT ]]; do
    LB_IP=$(kubectl get svc "$ONTOPIC_SERVER_SERVICE" -n "$NAMESPACE" -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")

    if [[ -n "$LB_IP" ]]; then
        echo "LoadBalancer IP: $LB_IP"
        break
    fi

    echo "Waiting for LoadBalancer IP... (${ELAPSED}s)"
    sleep $INTERVAL
    ELAPSED=$((ELAPSED + INTERVAL))
done

if [[ -z "$LB_IP" ]]; then
    echo "Error: Timed out waiting for LoadBalancer IP"
    exit 1
fi

# =============================================================================
# Configure Application Gateway TCP Backend
# =============================================================================
echo "Configuring Application Gateway TCP backend..."

# Get frontend IP name (use the first one)
FRONTEND_IP_NAME=$(az network application-gateway frontend-ip list \
    --gateway-name "$APP_GATEWAY_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --query "[0].name" -o tsv)

echo "Using frontend IP: $FRONTEND_IP_NAME"

# Create or update backend pool
echo "Creating/updating backend pool: $BACKEND_POOL_NAME"
az network application-gateway address-pool create \
    --gateway-name "$APP_GATEWAY_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --name "$BACKEND_POOL_NAME" \
    --servers "$LB_IP" \
    --only-show-errors || \
az network application-gateway address-pool update \
    --gateway-name "$APP_GATEWAY_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --name "$BACKEND_POOL_NAME" \
    --servers "$LB_IP" \
    --only-show-errors

# Create or update backend settings
echo "Creating/updating backend settings: $BACKEND_SETTINGS_NAME"
az network application-gateway settings create \
    --gateway-name "$APP_GATEWAY_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --name "$BACKEND_SETTINGS_NAME" \
    --port "$POSTGRES_SERVICE_PORT" \
    --protocol Tcp \
    --only-show-errors 2>/dev/null || \
az network application-gateway settings update \
    --gateway-name "$APP_GATEWAY_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --name "$BACKEND_SETTINGS_NAME" \
    --port "$POSTGRES_SERVICE_PORT" \
    --protocol Tcp \
    --only-show-errors 2>/dev/null || true

# Create frontend port (ignore error if exists)
echo "Creating frontend port: $FRONTEND_PORT_NAME"
az network application-gateway frontend-port create \
    --gateway-name "$APP_GATEWAY_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --name "$FRONTEND_PORT_NAME" \
    --port "$POSTGRES_EXTERNAL_PORT" \
    --only-show-errors 2>/dev/null || true

# Create or update listener
echo "Creating/updating listener: $LISTENER_NAME"
az network application-gateway listener create \
    --gateway-name "$APP_GATEWAY_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --name "$LISTENER_NAME" \
    --frontend-ip "$FRONTEND_IP_NAME" \
    --frontend-port "$FRONTEND_PORT_NAME" \
    --only-show-errors 2>/dev/null || true

# Create or update routing rule
echo "Creating/updating routing rule: $RULE_NAME"
az network application-gateway rule create \
    --gateway-name "$APP_GATEWAY_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --name "$RULE_NAME" \
    --listener "$LISTENER_NAME" \
    --address-pool "$BACKEND_POOL_NAME" \
    --settings "$BACKEND_SETTINGS_NAME" \
    --priority "$RULE_PRIORITY" \
    --only-show-errors 2>/dev/null || \
az network application-gateway rule update \
    --gateway-name "$APP_GATEWAY_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --name "$RULE_NAME" \
    --listener "$LISTENER_NAME" \
    --address-pool "$BACKEND_POOL_NAME" \
    --settings "$BACKEND_SETTINGS_NAME" \
    --priority "$RULE_PRIORITY" \
    --only-show-errors 2>/dev/null || true

# =============================================================================
# Done
# =============================================================================
APP_GW_IP=$(az network application-gateway frontend-ip show \
    --gateway-name "$APP_GATEWAY_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --name "$FRONTEND_IP_NAME" \
    --query "publicIPAddress.id" -o tsv 2>/dev/null)

if [[ -n "$APP_GW_IP" ]]; then
    PUBLIC_IP=$(az network public-ip show --ids "$APP_GW_IP" --query "ipAddress" -o tsv 2>/dev/null || echo "")
    if [[ -n "$PUBLIC_IP" ]]; then
        echo ""
        echo "============================================================================="
        echo "Deployment complete!"
        echo "PostgreSQL endpoint: $PUBLIC_IP:$POSTGRES_EXTERNAL_PORT"
        echo "============================================================================="
        exit 0
    fi
fi

echo ""
echo "============================================================================="
echo "Deployment complete!"
echo "PostgreSQL is available on Application Gateway port $POSTGRES_EXTERNAL_PORT"
echo "============================================================================="
