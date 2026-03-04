#!/bin/bash
# Quick Start Script for Modern DevOps Workshop
# This script helps you set up the entire modern GitOps pipeline

set -e

echo "🚀 Modern DevOps Workshop - Quick Start"
echo "========================================"
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check prerequisites
check_prerequisites() {
    echo "📋 Checking prerequisites..."
    
    MISSING=()
    
    if ! command -v kubectl &> /dev/null; then
        MISSING+=("kubectl")
    fi
    
    if ! command -v helm &> /dev/null; then
        MISSING+=("helm")
    fi
    
    if ! command -v aws &> /dev/null; then
        MISSING+=("aws-cli")
    fi
    
    if ! command -v docker &> /dev/null; then
        MISSING+=("docker")
    fi
    
    if [ ${#MISSING[@]} -ne 0 ]; then
        echo -e "${RED}❌ Missing prerequisites: ${MISSING[*]}${NC}"
        echo "Please install missing tools and try again."
        exit 1
    fi
    
    echo -e "${GREEN}✅ All prerequisites installed${NC}"
}

# Setup EKS cluster
setup_eks() {
    echo ""
    echo "🏗️  Setting up EKS cluster..."
    
    cd EKS-TF
    
    # Check if terraform is initialized
    if [ ! -d ".terraform" ]; then
        echo "Initializing Terraform..."
        terraform init
    fi
    
    echo "Planning infrastructure..."
    terraform plan
    
    read -p "Apply Terraform changes? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        terraform apply -auto-approve
        echo -e "${GREEN}✅ EKS cluster created${NC}"
    else
        echo "Skipping Terraform apply"
    fi
    
    cd ..
    
    # Update kubeconfig
    echo "Updating kubeconfig..."
    aws eks update-kubeconfig --region ap-south-1 --name EKS_CLOUD
    
    echo -e "${GREEN}✅ Kubeconfig updated${NC}"
}

# Install Argo CD
install_argocd() {
    echo ""
    echo "🔄 Installing Argo CD..."
    
    kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
    
    kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
    
    echo "Waiting for Argo CD to be ready..."
    kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd
    
    # Get initial password
    ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
    
    echo -e "${GREEN}✅ Argo CD installed${NC}"
    echo -e "${YELLOW}📝 Argo CD Admin Password: ${ARGOCD_PASSWORD}${NC}"
    echo ""
    echo "To access Argo CD UI, run:"
    echo "  kubectl port-forward svc/argocd-server -n argocd 8080:443"
    echo "  Then visit: https://localhost:8080"
    echo "  Username: admin"
    echo "  Password: ${ARGOCD_PASSWORD}"
}

# Install OPA Gatekeeper
install_gatekeeper() {
    echo ""
    echo "🔒 Installing OPA Gatekeeper..."
    
    kubectl apply -f https://raw.githubusercontent.com/open-policy-agent/gatekeeper/release-3.14/deploy/gatekeeper.yaml
    
    echo "Waiting for Gatekeeper to be ready..."
    kubectl wait --for=condition=available --timeout=300s deployment/gatekeeper-audit -n gatekeeper-system
    kubectl wait --for=condition=available --timeout=300s deployment/gatekeeper-controller-manager -n gatekeeper-system
    
    echo -e "${GREEN}✅ OPA Gatekeeper installed${NC}"
    
    # Apply constraint templates
    echo "Applying constraint templates..."
    kubectl apply -f policies/k8s-require-resources.yaml
    kubectl apply -f policies/k8s-block-latest-tag.yaml
    kubectl apply -f policies/k8s-require-non-root.yaml
    
    sleep 5
    
    # Apply constraints
    echo "Applying constraints..."
    kubectl apply -f policies/production-constraints.yaml
    
    echo -e "${GREEN}✅ Policies configured${NC}"
}

# Install Istio
install_istio() {
    echo ""
    echo "🌐 Installing Istio..."
    
    # Check if istioctl is installed
    if ! command -v istioctl &> /dev/null; then
        echo "Installing istioctl..."
        curl -L https://istio.io/downloadIstio | sh -
        export PATH="$PATH:./istio-*/bin"
    fi
    
    istioctl install --set profile=default -y
    
    # Label production namespace
    kubectl create namespace production --dry-run=client -o yaml | kubectl apply -f -
    kubectl label namespace production istio-injection=enabled --overwrite
    
    echo -e "${GREEN}✅ Istio installed${NC}"
}

# Install Flagger
install_flagger() {
    echo ""
    echo "🎨 Installing Flagger..."
    
    helm repo add flagger https://flagger.app
    helm repo update
    
    kubectl apply -f https://raw.githubusercontent.com/fluxcd/flagger/main/artifacts/flagger/crd.yaml
    
    helm upgrade -i flagger flagger/flagger \
        --namespace=istio-system \
        --set crd.create=false \
        --set meshProvider=istio \
        --set metricsServer=http://prometheus.istio-system:9090
    
    echo -e "${GREEN}✅ Flagger installed${NC}"
}

# Install Prometheus & Grafana
install_monitoring() {
    echo ""
    echo "📊 Installing Prometheus & Grafana..."
    
    helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
    helm repo update
    
    helm install prometheus prometheus-community/kube-prometheus-stack \
        --namespace monitoring \
        --create-namespace \
        --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false
    
    echo "Waiting for Grafana to be ready..."
    kubectl wait --for=condition=available --timeout=300s deployment/prometheus-grafana -n monitoring
    
    GRAFANA_PASSWORD=$(kubectl get secret -n monitoring prometheus-grafana -o jsonpath="{.data.admin-password}" | base64 -d)
    
    echo -e "${GREEN}✅ Monitoring stack installed${NC}"
    echo -e "${YELLOW}📝 Grafana Admin Password: ${GRAFANA_PASSWORD}${NC}"
    echo ""
    echo "To access Grafana, run:"
    echo "  kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80"
    echo "  Then visit: http://localhost:3000"
    echo "  Username: admin"
    echo "  Password: ${GRAFANA_PASSWORD}"
}

# Create ECR repository
create_ecr() {
    echo ""
    echo "🐳 Creating ECR repository..."
    
    aws ecr create-repository \
        --repository-name mario \
        --region ap-south-1 \
        --image-scanning-configuration scanOnPush=true 2>/dev/null || echo "Repository already exists"
    
    ECR_URI=$(aws ecr describe-repositories \
        --repository-names mario \
        --region ap-south-1 \
        --query 'repositories[0].repositoryUri' \
        --output text)
    
    echo -e "${GREEN}✅ ECR repository created: ${ECR_URI}${NC}"
    
    # Update kustomization with ECR URI
    echo "Updating kustomization with ECR URI..."
    sed -i.bak "s|REPLACE_WITH_YOUR_ECR_URI|${ECR_URI}|g" gitops/base/kustomization.yaml
    rm gitops/base/kustomization.yaml.bak
}

# Deploy application via Argo CD
deploy_app() {
    echo ""
    echo "🚀 Deploying application..."
    
    # Update Argo CD app with correct repo
    read -p "Enter your GitHub username: " GITHUB_USER
    sed -i.bak "s|REPLACE_WITH_YOUR_USERNAME|${GITHUB_USER}|g" gitops/argo-apps/mario-production.yaml
    sed -i.bak "s|REPLACE_WITH_YOUR_USERNAME|${GITHUB_USER}|g" gitops/argo-apps/mario-dev.yaml
    rm gitops/argo-apps/*.bak
    
    # Apply Argo CD applications
    kubectl apply -f gitops/argo-apps/mario-production.yaml
    kubectl apply -f gitops/argo-apps/mario-dev.yaml
    
    echo -e "${GREEN}✅ Application deployed${NC}"
    echo ""
    echo "Monitor deployment with:"
    echo "  kubectl get application -n argocd"
    echo "  kubectl get pods -n production -w"
}

# Show summary
show_summary() {
    echo ""
    echo "=========================================="
    echo "🎉 Setup Complete!"
    echo "=========================================="
    echo ""
    echo "Next steps:"
    echo ""
    echo "1. Access Argo CD UI:"
    echo "   kubectl port-forward svc/argocd-server -n argocd 8080:443"
    echo "   https://localhost:8080"
    echo ""
    echo "2. Access Grafana:"
    echo "   kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80"
    echo "   http://localhost:3000"
    echo ""
    echo "3. View application:"
    echo "   kubectl get svc -n production"
    echo "   (Access the LoadBalancer URL)"
    echo ""
    echo "4. Trigger a deployment:"
    echo "   - Edit gitops/overlays/production/kustomization.yaml"
    echo "   - Update the image tag"
    echo "   - Commit and push"
    echo "   - Watch Argo CD sync automatically!"
    echo ""
    echo "📚 For detailed instructions, see: MODERN-DEVOPS-WORKSHOP.md"
}

# Main menu
main() {
    check_prerequisites
    
    echo ""
    echo "Select installation option:"
    echo "1) Full installation (recommended for first-time)"
    echo "2) Install EKS cluster only"
    echo "3) Install GitOps tools (Argo CD)"
    echo "4) Install Security tools (OPA Gatekeeper)"
    echo "5) Install Progressive delivery (Istio + Flagger)"
    echo "6) Install Monitoring (Prometheus + Grafana)"
    echo "7) Create ECR repository"
    echo "8) Deploy application"
    echo "9) Exit"
    echo ""
    read -p "Enter choice [1-9]: " choice
    
    case $choice in
        1)
            setup_eks
            install_argocd
            install_gatekeeper
            install_istio
            install_flagger
            install_monitoring
            create_ecr
            deploy_app
            show_summary
            ;;
        2)
            setup_eks
            ;;
        3)
            install_argocd
            ;;
        4)
            install_gatekeeper
            ;;
        5)
            install_istio
            install_flagger
            ;;
        6)
            install_monitoring
            ;;
        7)
            create_ecr
            ;;
        8)
            deploy_app
            ;;
        9)
            echo "Exiting..."
            exit 0
            ;;
        *)
            echo "Invalid option"
            exit 1
            ;;
    esac
}

main
