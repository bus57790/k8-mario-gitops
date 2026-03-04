# Modern DevOps Workshop - Quick Reference Guide

## 🚀 Quick Start Commands

### Initial Setup
```bash
# Make scripts executable
chmod +x setup.sh validate.sh

# Run full setup (interactive)
./setup.sh

# Validate setup
./validate.sh
```

## 📋 Common Commands

### Argo CD
```bash
# Access Argo CD UI
kubectl port-forward svc/argocd-server -n argocd 8080:443
# Visit: https://localhost:8080

# Get admin password
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d

# Install Argo CD CLI
brew install argocd  # macOS
# or download from: https://github.com/argoproj/argo-cd/releases

# Login via CLI
argocd login localhost:8080 --username admin --insecure

# List applications
argocd app list

# Get application status
argocd app get mario-production

# Sync application
argocd app sync mario-production

# View application history
argocd app history mario-production

# Rollback to previous version
argocd app rollback mario-production <revision-id>
```

### Kubectl Basics
```bash
# Get all resources in production
kubectl get all -n production

# Watch pods
kubectl get pods -n production -w

# Describe deployment
kubectl describe deployment mario-deployment -n production

# View logs
kubectl logs -n production deployment/mario-deployment -f

# Get service URL
kubectl get svc -n production mario-service

# Scale deployment (will be reverted by GitOps)
kubectl scale deployment mario-deployment -n production --replicas=5

# Port forward to application
kubectl port-forward -n production svc/mario-service 8080:80
```

### GitOps Workflow
```bash
# 1. Update image tag in overlay
vim gitops/overlays/production/kustomization.yaml
# Change newTag to your new version

# 2. Test locally
kubectl kustomize gitops/overlays/production

# 3. Commit and push
git add gitops/overlays/production/kustomization.yaml
git commit -m "deploy: update to v1.2.0"
git push origin main

# 4. Watch Argo CD sync (auto within 3 minutes)
kubectl get application -n argocd mario-production -w

# OR force sync
argocd app sync mario-production
```

### OPA Gatekeeper
```bash
# List constraint templates
kubectl get constrainttemplates

# List constraints
kubectl get constraints

# Check specific constraint
kubectl get k8sblocklatesttag block-latest-tag -o yaml

# Test policy (should fail)
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: test-bad
  namespace: production
spec:
  replicas: 1
  selector:
    matchLabels:
      app: test
  template:
    metadata:
      labels:
        app: test
    spec:
      containers:
      - name: nginx
        image: nginx:latest  # Blocked!
EOF

# View policy violations
kubectl get constraints -o json | jq '.items[].status.violations'
```

### Canary Deployments with Flagger
```bash
# Get canary status
kubectl get canary -n production

# Describe canary
kubectl describe canary mario-canary -n production

# Watch canary progress
kubectl get canary -n production mario-canary -w

# Get canary events
kubectl get events -n production --sort-by='.lastTimestamp' | grep mario-canary

# Manual canary promotion (only in manual mode)
kubectl -n production annotate canary/mario-canary flagger.app/promote=true

# Rollback canary
kubectl -n production annotate canary/mario-canary flagger.app/rollback=true

# View Flagger logs
kubectl logs -n istio-system deployment/flagger -f
```

### Monitoring
```bash
# Access Grafana
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80
# Visit: http://localhost:3000

# Get Grafana password
kubectl get secret -n monitoring prometheus-grafana \
  -o jsonpath="{.data.admin-password}" | base64 -d

# Access Prometheus
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090
# Visit: http://localhost:9090

# Query from CLI
kubectl exec -n monitoring prometheus-kube-prometheus-prometheus-0 -- \
  wget -qO- http://localhost:9090/api/v1/query?query=up
```

### ECR Operations
```bash
# Login to ECR
aws ecr get-login-password --region ap-south-1 | \
  docker login --username AWS --password-stdin \
  <account-id>.dkr.ecr.ap-south-1.amazonaws.com

# List images
aws ecr describe-images \
  --repository-name mario \
  --region ap-south-1

# Build and push image
docker build -t mario:v1.0.0 .
docker tag mario:v1.0.0 <ecr-uri>:v1.0.0
docker push <ecr-uri>:v1.0.0

# Scan image
aws ecr start-image-scan \
  --repository-name mario \
  --image-id imageTag=v1.0.0 \
  --region ap-south-1

# Get scan results
aws ecr describe-image-scan-findings \
  --repository-name mario \
  --image-id imageTag=v1.0.0 \
  --region ap-south-1
```

### Istio
```bash
# Check Istio installation
istioctl version

# Verify Istio configuration
istioctl analyze -n production

# Get Istio proxy status
istioctl proxy-status

# View Istio configuration for a pod
istioctl proxy-config routes <pod-name> -n production

# Access Kiali (if installed)
istioctl dashboard kiali

# View mesh traffic
kubectl get virtualservices -n production
kubectl get destinationrules -n production
```

## 🔧 Troubleshooting Commands

### Argo CD Not Syncing
```bash
# Force refresh
argocd app get mario-production --refresh --hard

# Check application details
kubectl get application -n argocd mario-production -o yaml

# View Argo CD logs
kubectl logs -n argocd deployment/argocd-application-controller
kubectl logs -n argocd deployment/argocd-repo-server
kubectl logs -n argocd deployment/argocd-server
```

### Pod Debugging
```bash
# Describe pod
kubectl describe pod <pod-name> -n production

# View logs
kubectl logs <pod-name> -n production

# Previous logs (after crash)
kubectl logs <pod-name> -n production --previous

# Execute into pod
kubectl exec -it <pod-name> -n production -- /bin/sh

# View events
kubectl get events -n production --sort-by='.lastTimestamp'
```

### Image Pull Issues
```bash
# Create ECR secret
kubectl create secret docker-registry ecr-secret \
  --docker-server=<account-id>.dkr.ecr.ap-south-1.amazonaws.com \
  --docker-username=AWS \
  --docker-password=$(aws ecr get-login-password --region ap-south-1) \
  --namespace=production

# Verify secret
kubectl get secret ecr-secret -n production -o yaml
```

### Canary Stuck
```bash
# Check metrics availability
kubectl exec -it -n istio-system \
  deployment/prometheus -- \
  wget -qO- http://prometheus.istio-system:9090/api/v1/query?query=up

# Reset canary
kubectl delete canary -n production mario-canary
kubectl apply -f gitops/overlays/production/canary.yaml

# Check Flagger logs
kubectl logs -n istio-system deployment/flagger -f
```

## 📊 Useful Queries

### Prometheus Queries
```promql
# Request rate
rate(istio_requests_total{destination_service="mario-service.production.svc.cluster.local"}[1m])

# Success rate
sum(rate(istio_requests_total{destination_service="mario-service.production.svc.cluster.local",response_code=~"2.."}[1m])) / 
sum(rate(istio_requests_total{destination_service="mario-service.production.svc.cluster.local"}[1m])) * 100

# Request duration (p99)
histogram_quantile(0.99, 
  rate(istio_request_duration_milliseconds_bucket{destination_service="mario-service.production.svc.cluster.local"}[1m])
)

# Pod CPU usage
rate(container_cpu_usage_seconds_total{namespace="production",pod=~"mario-.*"}[5m])

# Pod memory usage
container_memory_usage_bytes{namespace="production",pod=~"mario-.*"}
```

## 🎯 Testing Scenarios

### Test Policy Enforcement
```bash
# Should fail - :latest tag
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: test-latest
  namespace: production
spec:
  replicas: 1
  selector:
    matchLabels:
      app: test
  template:
    metadata:
      labels:
        app: test
    spec:
      containers:
      - name: nginx
        image: nginx:latest
EOF

# Should fail - no resources
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: test-no-resources
  namespace: production
spec:
  replicas: 1
  selector:
    matchLabels:
      app: test
  template:
    metadata:
      labels:
        app: test
    spec:
      containers:
      - name: nginx
        image: nginx:1.21
EOF

# Should fail - runs as root
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: test-root
  namespace: production
spec:
  replicas: 1
  selector:
    matchLabels:
      app: test
  template:
    metadata:
      labels:
        app: test
    spec:
      containers:
      - name: nginx
        image: nginx:1.21
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 200m
            memory: 256Mi
EOF
```

### Test GitOps Reconciliation
```bash
# Manually change deployment
kubectl scale deployment mario-deployment -n production --replicas=10

# Wait 3 minutes - Argo CD will reconcile back to desired state
kubectl get deployment mario-deployment -n production -w
```

### Test Canary Deployment
```bash
# Update image tag
vim gitops/overlays/production/kustomization.yaml
# Change newTag to a new version

git add gitops/overlays/production/kustomization.yaml
git commit -m "deploy: canary test v1.2.0"
git push

# Watch canary progression
watch kubectl get canary -n production mario-canary
```

## 📚 Additional Resources

- Workshop Guide: [MODERN-DEVOPS-WORKSHOP.md](MODERN-DEVOPS-WORKSHOP.md)
- Argo CD Docs: https://argo-cd.readthedocs.io/
- Flagger Docs: https://docs.flagger.app/
- OPA Gatekeeper: https://open-policy-agent.github.io/gatekeeper/
- Istio Docs: https://istio.io/latest/docs/

---

**Need Help?**
- Check troubleshooting section in main workshop guide
- Review validation script output: `./validate.sh`
- Check pod logs and events
