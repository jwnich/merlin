#!/bin/bash

# Ray GKE Infrastructure Deployment Script
# Usage: ./deploy.sh [environment] [github-repo-url]

set -euo pipefail

# Configuration
ENVIRONMENT=${1:-dev}
REPO_URL=${2:-"git@github.com:jwnich/ray-gke-infrastructure.git"}
TEMP_DIR="/tmp/ray-gke-deploy-$$"
RAY_OPERATOR_VERSION="v1.1.1"
# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}ℹ️  $1${NC}"
}

log_warn() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check kubectl
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl is not installed"
        exit 1
    fi
    
    # Check cluster connection
    if ! kubectl cluster-info &> /dev/null; then
        log_error "Not connected to Kubernetes cluster"
        log_info "Run: gcloud container clusters get-credentials CLUSTER-NAME --zone=ZONE"
        exit 1
    fi
    
    # Check kustomize
    if ! command -v kustomize &> /dev/null; then
        log_warn "kustomize not found, using kubectl (requires kubectl 1.21+)"
        KUSTOMIZE_CMD="kubectl apply -k"
    else
        KUSTOMIZE_CMD="kustomize build"
    fi
    
    log_info "Prerequisites check passed ✅"
}

install_ray_operator() {
    log_info "Installing Ray Operator..."
    
    if kubectl get crd rayclusters.ray.io &> /dev/null; then
        log_info "Ray Operator already installed ✅"
        return
    fi
    
    kubectl create -k "github.com/ray-project/kuberay/ray-operator/config/default?ref=${RAY_OPERATOR_VERSION}&timeout=90s"
    
    log_info "Waiting for Ray Operator to be ready..."
    kubectl wait --for=condition=available --timeout=300s deployment/kuberay-operator -n ray-system
    
    log_info "Ray Operator installed ✅"
}

clone_and_deploy() {
    local environment=$1
    
    log_info "Cloning infrastructure repository..."
    
    # Clean up any existing temp directory
    rm -rf "$TEMP_DIR"
    
    # Clone the repository
    git clone "$REPO_URL" "$TEMP_DIR"
    cd "$TEMP_DIR"
    
    # Check if environment overlay exists
    if [[ ! -d "overlays/$environment" ]]; then
        log_error "Environment '$environment' not found in overlays/"
        log_info "Available environments: $(ls overlays/ | tr '\n' ' ')"
        exit 1
    fi
    
    log_info "Deploying $environment environment..."
    
    # Deploy using Kustomize
    if [[ "$KUSTOMIZE_CMD" == "kustomize build" ]]; then
        kustomize build "overlays/$environment" | kubectl apply -f -
    else
        kubectl apply -k "overlays/$environment"
    fi
    
    log_info "Deployment submitted ✅"
}

wait_for_deployment() {
    log_info "Waiting for Ray cluster to be ready..."
    
    # Wait for Ray head pod
    kubectl wait --for=condition=ready --timeout=300s pod -l app.kubernetes.io/component=ray-head -n ray-training-dev
    
    log_info "Ray cluster is ready ✅"
}

show_status() {
    local environment=$1
    
    log_info "Deployment Status:"
    echo ""
    
    echo "📊 Namespaces:"
    kubectl get namespaces | grep -E "(data-pipeline|ray-training|notebooks)" || true
    echo ""
    
    echo "🎯 Ray Cluster:"
    kubectl get raycluster -n ray-training-dev || true
    echo ""
    
    echo "🐳 Pods:"
    kubectl get pods -n ray-training-dev || true
    echo ""
    
    echo "🌐 Services:"
    kubectl get svc -n ray-training-dev || true
    echo ""
    
    log_info "Access Ray Dashboard:"
    echo "kubectl port-forward svc/ray-dashboard-service 8265:8265 -n ray-training-dev"
    echo "Then open: http://localhost:8265"
    echo ""
    
    log_info "Test the deployment:"
    echo "kubectl apply -f $TEMP_DIR/examples/test-job.yaml"
}

cleanup() {
    if [[ -d "$TEMP_DIR" ]]; then
        log_info "Cleaning up temporary files..."
        rm -rf "$TEMP_DIR"
    fi
}

main() {
    local environment=$1
    
    log_info "🚀 Starting Ray GKE Infrastructure Deployment"
    log_info "Environment: $environment"
    log_info "Repository: $REPO_URL"
    echo ""
    
    # Set up cleanup trap
    trap cleanup EXIT
    
    # Main deployment flow
    check_prerequisites
    install_ray_operator
    clone_and_deploy "$environment"
    wait_for_deployment
    show_status "$environment"
    
    log_info "🎉 Deployment completed successfully!"
    log_info "Check the status above and access the Ray dashboard to get started."
}

# Help text
if [[ "${1:-}" == "-h" ]] || [[ "${1:-}" == "--help" ]]; then
    echo "Ray GKE Infrastructure Deployment"
    echo ""
    echo "Usage: $0 [environment] [github-repo-url]"
    echo ""
    echo "Arguments:"
    echo "  environment      Environment to deploy (default: dev)"
    echo "  github-repo-url  GitHub repository URL (default: YOUR-USERNAME/ray-gke-infrastructure)"
    echo ""
    echo "Examples:"
    echo "  $0                                    # Deploy dev environment"
    echo "  $0 staging                           # Deploy staging environment"
    echo "  $0 dev https://github.com/user/repo  # Deploy with custom repo"
    echo ""
    echo "Prerequisites:"
    echo "  - kubectl connected to GKE cluster"
    echo "  - kustomize (optional, kubectl 1.21+ has built-in support)"
    echo "  - git"
    exit 0
fi

# Run main function with all arguments
main "$ENVIRONMENT"
