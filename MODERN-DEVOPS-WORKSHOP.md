# 🚀 Modern DevOps/DevSecOps Workshop
## Upgrading k8s-mario from Classic Jenkins Pipeline to GitOps

> **Workshop Duration:** 6-8 hours  
> **Difficulty Level:** Intermediate to Advanced  
> **Prerequisites:** AWS Account, kubectl, Terraform, Docker, Git

---

## 📋 Table of Contents

1. [Workshop Overview](#workshop-overview)
2. [Current State Analysis](#current-state-analysis)
3. [Target Architecture](#target-architecture)
4. [Module 1: Repository Restructuring](#module-1-repository-restructuring)
5. [Module 2: GitOps with Argo CD](#module-2-gitops-with-argo-cd)
6. [Module 3: Security & Policy-as-Code](#module-3-security--policy-as-code)
7. [Module 4: Progressive Delivery with Flagger](#module-4-progressive-delivery-with-flagger)
8. [Module 5: Observability & Monitoring](#module-5-observability--monitoring)
9. [Module 6: CI/CD Pipeline Modernization](#module-6-cicd-pipeline-modernization)
10. [Module 7: Testing & Validation](#module-7-testing--validation)
11. [Troubleshooting Guide](#troubleshooting-guide)
12. [Best Practices & Next Steps](#best-practices--next-steps)

---

## 🎯 Workshop Overview

### What You'll Learn

- Transform a classic pipeline into a modern GitOps workflow
- Implement shift-left security practices
- Deploy progressive delivery strategies (Canary/Blue-Green)
- Enforce policy-as-code with OPA
- Build event-driven, immutable deployments
- Implement auto-rollback and reconciliation

### What You'll Build

```
┌─────────────────────────────────────────────────────────────┐
│                    MODERN PIPELINE FLOW                     │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  Git Push → GitHub Actions (CI) → Security Scans           │
│      ↓                                                      │
│  Build & Tag Image → Push to ECR (Immutable)              │
│      ↓                                                      │
│  Update Manifest → GitOps Repo Commit                      │
│      ↓                                                      │
│  Argo CD Sync → Policy Gates (OPA) → Canary Deploy        │
│      ↓                                                      │
│  Metrics Analysis → Auto Promote/Rollback                  │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

## 🔍 Current State Analysis

### Your Existing Setup

**Infrastructure:**
- EKS cluster provisioned via Terraform
- Default VPC with public subnets
- t2.medium nodes (1-2 instances)
- LoadBalancer service

**Application:**
- Mario game (sevenajay/mario:latest)
- 2 replicas
- Direct kubectl deployment

**Pain Points:**
- ❌ No GitOps (manual kubectl apply)
- ❌ Using `:latest` tag (not immutable)
- ❌ No security scanning
- ❌ No canary/blue-green deployment
- ❌ No policy enforcement
- ❌ Manual rollbacks
- ❌ Config drift possible

---

## 🎯 Target Architecture

### Modern Stack

| Component | Tool | Purpose |
|-----------|------|---------|
| **GitOps** | Argo CD | Declarative, Git-driven deployments |
| **CI/CD** | GitHub Actions | Build, test, scan pipeline |
| **Security** | Trivy, OPA | Image scanning, policy enforcement |
| **Progressive Delivery** | Flagger | Canary deployments with metrics |
| **Service Mesh** | Istio | Traffic management, observability |
| **Monitoring** | Prometheus + Grafana | Metrics and dashboards |
| **Registry** | AWS ECR | Immutable image storage |
| **Secrets** | External Secrets Operator | Secure secrets management |

### Architecture Diagram

```
┌──────────────────────────────────────────────────────────────────┐
│                          DEVELOPER                               │
└────────────────┬─────────────────────────────────────────────────┘
                 │ git push
                 ▼
┌──────────────────────────────────────────────────────────────────┐
│                   GITHUB REPOSITORY                              │
│  ┌─────────────────┐        ┌──────────────────┐               │
│  │  App Repo       │        │  GitOps Repo     │               │
│  │  (Source Code)  │        │  (Manifests)     │               │
│  └────────┬────────┘        └────────┬─────────┘               │
└───────────┼──────────────────────────┼──────────────────────────┘
            │                          │
            │ webhook                  │ watch
            ▼                          ▼
┌──────────────────────┐    ┌──────────────────────┐
│  GITHUB ACTIONS      │    │    ARGO CD           │
│  ┌────────────────┐  │    │  ┌────────────────┐  │
│  │ 1. Lint        │  │    │  │ Git Sync       │  │
│  │ 2. Test        │  │    │  │      ↓         │  │
│  │ 3. SAST        │  │    │  │ OPA Policy     │  │
│  │ 4. Build Image │  │    │  │      ↓         │  │
│  │ 5. Scan Image  │  │    │  │ Apply K8s      │  │
│  │ 6. Push ECR    │  │    │  └────────────────┘  │
│  │ 7. Update Repo │  │    └──────────┬───────────┘
│  └────────────────┘  │               │
└──────────────────────┘               │ deploy
                                       ▼
┌──────────────────────────────────────────────────────────────────┐
│                       EKS CLUSTER                                │
│  ┌────────────────┐  ┌────────────────┐  ┌──────────────────┐  │
│  │  Istio         │→ │  Flagger       │→ │  App Pods        │  │
│  │  (Traffic)     │  │  (Canary)      │  │  (Mario)         │  │
│  └────────────────┘  └────────────────┘  └──────────────────┘  │
│  ┌────────────────┐  ┌────────────────┐                        │
│  │  Prometheus    │  │  Gatekeeper    │                        │
│  │  (Metrics)     │  │  (Policies)    │                        │
│  └────────────────┘  └────────────────┘                        │
└──────────────────────────────────────────────────────────────────┘
```

---

## 📦 Module 1: Repository Restructuring

### Step 1.1: Create GitOps Repository Structure

The modern approach separates **application code** from **deployment manifests**.

**Directory Structure:**
```
k8s-mario/
├── app/                          # Application source (if you have it)
├── infrastructure/               # Terraform for EKS
│   └── EKS-TF/
├── gitops/                       # GitOps manifests (NEW)
│   ├── base/                     # Base Kustomize configs
│   │   ├── kustomization.yaml
│   │   ├── deployment.yaml
│   │   └── service.yaml
│   ├── overlays/                 # Environment-specific
│   │   ├── dev/
│   │   │   └── kustomization.yaml
│   │   ├── staging/
│   │   │   └── kustomization.yaml
│   │   └── production/
│   │       ├── kustomization.yaml
│   │       └── canary.yaml
│   └── argo-apps/                # Argo CD Applications
│       └── mario-app.yaml
├── .github/
│   └── workflows/
│       ├── ci-pipeline.yaml      # CI Pipeline
│       └── security-scan.yaml    # Security scanning
├── policies/                     # OPA Policies (NEW)
│   └── deployment-policies.rego
└── docs/
    └── runbooks/
```

**Action Items:**

```bash
# Create the new directory structure
cd /Users/trdr/Documents/k8s-mario

mkdir -p gitops/base
mkdir -p gitops/overlays/{dev,staging,production}
mkdir -p gitops/argo-apps
mkdir -p .github/workflows
mkdir -p policies
mkdir -p docs/runbooks
```

### Step 1.2: Convert to Kustomize Base

**Why Kustomize?**
- Declarative, template-free configuration
- Environment overlays without duplication
- Native kubectl support
- GitOps best practice

**Create base/kustomization.yaml:**

```yaml
# gitops/base/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

metadata:
  name: mario-base

resources:
  - deployment.yaml
  - service.yaml

commonLabels:
  app: mario
  managed-by: argocd

images:
  - name: mario-game
    newName: <AWS_ACCOUNT_ID>.dkr.ecr.ap-south-1.amazonaws.com/mario
    newTag: latest  # Will be overridden by environment

configMapGenerator:
  - name: mario-config
    literals:
      - APP_NAME=mario
      - ENVIRONMENT=base
```

**Create base/deployment.yaml (improved):**

```yaml
# gitops/base/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mario-deployment
  annotations:
    app.kubernetes.io/version: "1.0.0"
spec:
  replicas: 2
  selector:
    matchLabels:
      app: mario
  template:
    metadata:
      labels:
        app: mario
        version: stable
      annotations:
        prometheus.io/scrape: "true"
        prometheus.io/port: "8080"
    spec:
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        fsGroup: 1000
      containers:
      - name: mario-container
        image: mario-game  # Reference, replaced by Kustomize
        imagePullPolicy: Always
        ports:
        - containerPort: 80
          name: http
          protocol: TCP
        resources:
          requests:
            memory: "128Mi"
            cpu: "250m"
          limits:
            memory: "256Mi"
            cpu: "500m"
        livenessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 5
          periodSeconds: 5
        securityContext:
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: false
          capabilities:
            drop:
              - ALL
```

**Create base/service.yaml:**

```yaml
# gitops/base/service.yaml
apiVersion: v1
kind: Service
metadata:
  name: mario-service
spec:
  type: LoadBalancer
  selector:
    app: mario
  ports:
    - protocol: TCP
      port: 80
      targetPort: 80
      name: http
```

### Step 1.3: Create Environment Overlays

**Production Overlay with Canary:**

```yaml
# gitops/overlays/production/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: production

bases:
  - ../../base

patchesStrategicMerge:
  - deployment-patch.yaml

images:
  - name: mario-game
    newTag: v1.0.0  # Immutable tag

replicas:
  - name: mario-deployment
    count: 3

configMapGenerator:
  - name: mario-config
    behavior: merge
    literals:
      - ENVIRONMENT=production
```

**Production Deployment Patch:**

```yaml
# gitops/overlays/production/deployment-patch.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mario-deployment
spec:
  template:
    spec:
      containers:
      - name: mario-container
        resources:
          requests:
            memory: "256Mi"
            cpu: "500m"
          limits:
            memory: "512Mi"
            cpu: "1000m"
```

**Dev Overlay (simpler):**

```yaml
# gitops/overlays/dev/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: dev

bases:
  - ../../base

images:
  - name: mario-game
    newTag: dev-latest

replicas:
  - name: mario-deployment
    count: 1

configMapGenerator:
  - name: mario-config
    behavior: merge
    literals:
      - ENVIRONMENT=dev
```

### Step 1.4: Validation

```bash
# Test Kustomize build
kubectl kustomize gitops/overlays/production

# Validate YAML
kubectl kustomize gitops/overlays/production | kubectl apply --dry-run=client -f -
```

**✅ Checkpoint 1:** You should now have a properly structured GitOps repository.

---

## 🔄 Module 2: GitOps with Argo CD

### Step 2.1: Install Argo CD on EKS

**Prerequisites:**
- EKS cluster running
- kubectl configured

```bash
# Create namespace
kubectl create namespace argocd

# Install Argo CD
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for pods to be ready
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-server -n argocd --timeout=300s

# Get initial admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
# Save this password!

# Port-forward to access UI
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Access at: https://localhost:8080
# Username: admin
# Password: (from above command)
```

### Step 2.2: Configure Argo CD CLI (Optional but Recommended)

```bash
# Install Argo CD CLI (macOS)
brew install argocd

# Login
argocd login localhost:8080 --username admin --password <your-password> --insecure

# Change password
argocd account update-password
```

### Step 2.3: Create Argo CD Application

**Create application manifest:**

```yaml
# gitops/argo-apps/mario-app.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: mario-production
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  
  source:
    repoURL: https://github.com/<YOUR-USERNAME>/k8s-mario.git
    targetRevision: main
    path: gitops/overlays/production
  
  destination:
    server: https://kubernetes.default.svc
    namespace: production
  
  syncPolicy:
    automated:
      prune: true      # Delete resources not in Git
      selfHeal: true   # Auto-sync on drift detection
      allowEmpty: false
    syncOptions:
      - CreateNamespace=true
      - PrunePropagationPolicy=foreground
      - PruneLast=true
    retry:
      limit: 5
      backoff:
        duration: 5s
        factor: 2
        maxDuration: 3m

  # Health assessment
  ignoreDifferences:
    - group: apps
      kind: Deployment
      jsonPointers:
        - /spec/replicas  # Ignore if HPA is managing replicas
```

**Apply the application:**

```bash
# Create production namespace
kubectl create namespace production

# Deploy Argo CD Application
kubectl apply -f gitops/argo-apps/mario-app.yaml

# Watch sync status
argocd app get mario-production

# Or via kubectl
kubectl get application -n argocd mario-production -w
```

### Step 2.4: Create Development Environment Application

```yaml
# gitops/argo-apps/mario-dev.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: mario-dev
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/<YOUR-USERNAME>/k8s-mario.git
    targetRevision: develop  # Different branch for dev
    path: gitops/overlays/dev
  destination:
    server: https://kubernetes.default.svc
    namespace: dev
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

### Step 2.5: GitOps Workflow

**The New Deployment Process:**

```bash
# 1. Developer makes changes
git checkout -b feature/new-mario-level

# 2. Update image tag in overlay
# Edit: gitops/overlays/production/kustomization.yaml
# Change: newTag: v1.1.0

# 3. Commit and push
git add gitops/overlays/production/kustomization.yaml
git commit -m "feat: deploy mario v1.1.0"
git push origin feature/new-mario-level

# 4. Create PR → Merge to main

# 5. Argo CD auto-syncs (within 3 minutes)
# OR manual sync:
argocd app sync mario-production

# 6. Monitor deployment
argocd app get mario-production --refresh
kubectl get pods -n production -w
```

### Step 2.6: Rollback with GitOps

```bash
# Rollback is just a git revert!
git revert HEAD
git push origin main

# Argo CD auto-syncs to previous state
```

**✅ Checkpoint 2:** Your application is now deployed via GitOps with automatic reconciliation.

---

## 🔒 Module 3: Security & Policy-as-Code

### Step 3.1: Install OPA Gatekeeper

**OPA Gatekeeper** enforces policies at admission time.

```bash
# Install Gatekeeper
kubectl apply -f https://raw.githubusercontent.com/open-policy-agent/gatekeeper/release-3.14/deploy/gatekeeper.yaml

# Verify installation
kubectl get pods -n gatekeeper-system
```

### Step 3.2: Create Constraint Templates

**Template 1: Require Resource Limits**

```yaml
# policies/k8s-require-resources.yaml
apiVersion: templates.gatekeeper.sh/v1
kind: ConstraintTemplate
metadata:
  name: k8srequiredresources
spec:
  crd:
    spec:
      names:
        kind: K8sRequiredResources
  targets:
    - target: admission.k8s.gatekeeper.sh
      rego: |
        package k8srequiredresources

        violation[{"msg": msg}] {
          container := input.review.object.spec.template.spec.containers[_]
          not container.resources.limits
          msg := sprintf("Container '%v' has no resource limits defined", [container.name])
        }

        violation[{"msg": msg}] {
          container := input.review.object.spec.template.spec.containers[_]
          not container.resources.requests
          msg := sprintf("Container '%v' has no resource requests defined", [container.name])
        }
```

**Template 2: Block Latest Tag**

```yaml
# policies/k8s-block-latest-tag.yaml
apiVersion: templates.gatekeeper.sh/v1
kind: ConstraintTemplate
metadata:
  name: k8sblocklatesttag
spec:
  crd:
    spec:
      names:
        kind: K8sBlockLatestTag
  targets:
    - target: admission.k8s.gatekeeper.sh
      rego: |
        package k8sblocklatesttag

        violation[{"msg": msg}] {
          container := input.review.object.spec.template.spec.containers[_]
          image := container.image
          endswith(image, ":latest")
          msg := sprintf("Container '%v' uses :latest tag, which is not allowed", [container.name])
        }

        violation[{"msg": msg}] {
          container := input.review.object.spec.template.spec.containers[_]
          image := container.image
          not contains(image, ":")
          msg := sprintf("Container '%v' has no tag specified (defaults to :latest)", [container.name])
        }
```

**Template 3: Require Non-Root User**

```yaml
# policies/k8s-require-non-root.yaml
apiVersion: templates.gatekeeper.sh/v1
kind: ConstraintTemplate
metadata:
  name: k8srequirenonroot
spec:
  crd:
    spec:
      names:
        kind: K8sRequireNonRoot
  targets:
    - target: admission.k8s.gatekeeper.sh
      rego: |
        package k8srequirenonroot

        violation[{"msg": msg}] {
          not input.review.object.spec.template.spec.securityContext.runAsNonRoot
          msg := "Deployment must set runAsNonRoot to true"
        }
```

### Step 3.3: Apply Constraints

```yaml
# policies/production-constraints.yaml
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: K8sRequiredResources
metadata:
  name: must-have-resources
spec:
  match:
    kinds:
      - apiGroups: ["apps"]
        kinds: ["Deployment"]
    namespaces:
      - production
---
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: K8sBlockLatestTag
metadata:
  name: block-latest-tag
spec:
  match:
    kinds:
      - apiGroups: ["apps"]
        kinds: ["Deployment"]
    namespaces:
      - production
      - staging
---
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: K8sRequireNonRoot
metadata:
  name: require-non-root
spec:
  match:
    kinds:
      - apiGroups: ["apps"]
        kinds: ["Deployment"]
    namespaces:
      - production
```

**Apply policies:**

```bash
# Apply constraint templates
kubectl apply -f policies/k8s-require-resources.yaml
kubectl apply -f policies/k8s-block-latest-tag.yaml
kubectl apply -f policies/k8s-require-non-root.yaml

# Apply constraints
kubectl apply -f policies/production-constraints.yaml

# Test the policy
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: test-bad-deployment
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
        image: nginx:latest  # Should be blocked!
EOF

# Expected: Error from Gatekeeper
```

### Step 3.4: Image Scanning with Trivy

**Install Trivy in CI pipeline (covered in Module 6):**

```yaml
# .github/workflows/security-scan.yaml (preview)
- name: Run Trivy vulnerability scanner
  uses: aquasecurity/trivy-action@master
  with:
    image-ref: '${{ env.ECR_REGISTRY }}/${{ env.ECR_REPOSITORY }}:${{ github.sha }}'
    format: 'sarif'
    output: 'trivy-results.sarif'
    severity: 'CRITICAL,HIGH'
    exit-code: '1'  # Fail on high/critical vulnerabilities
```

**✅ Checkpoint 3:** Policies are enforced at admission time, blocking insecure configurations.

---

## 🎨 Module 4: Progressive Delivery with Flagger

### Step 4.1: Install Istio (Service Mesh)

Flagger requires a service mesh for traffic shifting.

```bash
# Download Istio
curl -L https://istio.io/downloadIstio | sh -
cd istio-*
export PATH=$PWD/bin:$PATH

# Install Istio with minimal profile
istioctl install --set profile=default -y

# Enable sidecar injection for production namespace
kubectl label namespace production istio-injection=enabled

# Verify
kubectl get pods -n istio-system
```

### Step 4.2: Install Flagger

```bash
# Add Flagger Helm repository
helm repo add flagger https://flagger.app

# Install Flagger with Istio support
kubectl apply -f https://raw.githubusercontent.com/fluxcd/flagger/main/artifacts/flagger/crd.yaml

helm upgrade -i flagger flagger/flagger \
  --namespace=istio-system \
  --set crd.create=false \
  --set meshProvider=istio \
  --set metricsServer=http://prometheus.istio-system:9090

# Install Grafana for visualization (optional)
helm upgrade -i flagger-grafana flagger/grafana \
  --namespace=istio-system \
  --set url=http://prometheus.istio-system:9090
```

### Step 4.3: Create Canary Resource

```yaml
# gitops/overlays/production/canary.yaml
apiVersion: flagger.app/v1beta1
kind: Canary
metadata:
  name: mario-canary
  namespace: production
spec:
  # Target deployment
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: mario-deployment
  
  # Service configuration
  service:
    port: 80
    targetPort: 80
    name: mario-service
    
  # Progressive traffic shifting
  analysis:
    # Schedule interval
    interval: 1m
    
    # Max traffic percentage routed to canary
    threshold: 5
    
    # Number of checks before rollout
    maxWeight: 50
    
    # Increment step percentage
    stepWeight: 10
    
    # Metrics for validation
    metrics:
    - name: request-success-rate
      thresholdRange:
        min: 99
      interval: 1m
    
    - name: request-duration
      thresholdRange:
        max: 500
      interval: 1m
    
    # Webhooks for notifications (optional)
    webhooks:
    - name: load-test
      url: http://flagger-loadtester.production/
      timeout: 5s
      metadata:
        type: cmd
        cmd: "hey -z 1m -q 10 -c 2 http://mario-service.production/"
```

**Update production kustomization to include canary:**

```yaml
# gitops/overlays/production/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: production

bases:
  - ../../base

resources:
  - canary.yaml  # Add this line

# ... rest of the file
```

### Step 4.4: Trigger Canary Deployment

```bash
# Update image tag
# Edit gitops/overlays/production/kustomization.yaml
# Change newTag to new version

# Commit and push
git add gitops/overlays/production/kustomization.yaml
git commit -m "feat: canary deploy v1.2.0"
git push

# Watch canary progress
kubectl -n production get canary mario-canary -w

# Detailed events
kubectl -n production describe canary mario-canary

# Expected output shows traffic shift: 0% → 10% → 20% → 50%
```

### Step 4.5: Automated Rollback on Failure

Flagger automatically rolls back if metrics fail:

```bash
# Simulate failure (if you have a /error endpoint)
# The canary will automatically rollback if success rate < 99%

# Monitor rollback
kubectl -n production get canary mario-canary -w

# Status will show: Progressing → Failed → Routing all traffic to primary
```

**✅ Checkpoint 4:** Canary deployments with automatic promotion and rollback are active.

---

## 📊 Module 5: Observability & Monitoring

### Step 5.1: Install Prometheus & Grafana

```bash
# Add Prometheus Helm repo
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# Install kube-prometheus-stack
helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace \
  --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false

# Verify
kubectl get pods -n monitoring
```

### Step 5.2: Create ServiceMonitor for Mario App

```yaml
# gitops/overlays/production/servicemonitor.yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: mario-metrics
  namespace: production
spec:
  selector:
    matchLabels:
      app: mario
  endpoints:
  - port: http
    interval: 30s
    path: /metrics  # If your app exposes metrics
```

### Step 5.3: Access Grafana

```bash
# Get Grafana password
kubectl get secret -n monitoring prometheus-grafana -o jsonpath="{.data.admin-password}" | base64 -d

# Port-forward
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80

# Access: http://localhost:3000
# Username: admin
# Password: (from above)
```

### Step 5.4: Import Flagger Dashboard

1. Go to Grafana → Dashboards → Import
2. Enter dashboard ID: `15170` (Flagger Canary dashboard)
3. Select Prometheus data source
4. Click Import

**✅ Checkpoint 5:** Full observability stack is running with canary metrics.

---

## 🔧 Module 6: CI/CD Pipeline Modernization

### Step 6.1: Create ECR Repository

```bash
# Create ECR repository
aws ecr create-repository \
  --repository-name mario \
  --region ap-south-1 \
  --image-scanning-configuration scanOnPush=true

# Get repository URI
aws ecr describe-repositories \
  --repository-names mario \
  --region ap-south-1 \
  --query 'repositories[0].repositoryUri' \
  --output text

# Save this URI!
```

### Step 6.2: GitHub Actions CI Pipeline

```yaml
# .github/workflows/ci-pipeline.yaml
name: CI/CD Pipeline

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

env:
  AWS_REGION: ap-south-1
  ECR_REPOSITORY: mario
  KUSTOMIZE_VERSION: 4.5.7

jobs:
  security-scan:
    name: Security Scanning
    runs-on: ubuntu-latest
    
    steps:
    - name: Checkout code
      uses: actions/checkout@v3
    
    - name: Run Trivy vulnerability scanner in repo mode
      uses: aquasecurity/trivy-action@master
      with:
        scan-type: 'fs'
        scan-ref: '.'
        format: 'sarif'
        output: 'trivy-results.sarif'
        severity: 'CRITICAL,HIGH'
    
    - name: Upload Trivy results to GitHub Security
      uses: github/codeql-action/upload-sarif@v2
      with:
        sarif_file: 'trivy-results.sarif'
    
    - name: Run secret scan
      uses: trufflesecurity/trufflehog@main
      with:
        path: ./
        base: main
        head: HEAD

  build-and-push:
    name: Build and Push Image
    runs-on: ubuntu-latest
    needs: security-scan
    if: github.ref == 'refs/heads/main'
    
    outputs:
      image-tag: ${{ steps.meta.outputs.tags }}
    
    steps:
    - name: Checkout code
      uses: actions/checkout@v3
    
    - name: Configure AWS credentials
      uses: aws-actions/configure-aws-credentials@v2
      with:
        aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
        aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
        aws-region: ${{ env.AWS_REGION }}
    
    - name: Login to Amazon ECR
      id: login-ecr
      uses: aws-actions/amazon-ecr-login@v1
    
    - name: Extract metadata (tags, labels)
      id: meta
      uses: docker/metadata-action@v4
      with:
        images: ${{ steps.login-ecr.outputs.registry }}/${{ env.ECR_REPOSITORY }}
        tags: |
          type=sha,prefix={{branch}}-
          type=semver,pattern={{version}}
          type=semver,pattern={{major}}.{{minor}}
    
    - name: Build Docker image
      uses: docker/build-push-action@v4
      with:
        context: .
        push: false
        tags: ${{ steps.meta.outputs.tags }}
        labels: ${{ steps.meta.outputs.labels }}
        load: true
    
    - name: Scan image with Trivy
      uses: aquasecurity/trivy-action@master
      with:
        image-ref: ${{ steps.meta.outputs.tags }}
        format: 'table'
        exit-code: '1'
        severity: 'CRITICAL,HIGH'
    
    - name: Push image to ECR
      uses: docker/build-push-action@v4
      with:
        context: .
        push: true
        tags: ${{ steps.meta.outputs.tags }}
        labels: ${{ steps.meta.outputs.labels }}
    
    - name: Generate SBOM
      uses: anchore/sbom-action@v0
      with:
        image: ${{ steps.meta.outputs.tags }}
        format: spdx-json
        output-file: sbom.spdx.json
    
    - name: Upload SBOM
      uses: actions/upload-artifact@v3
      with:
        name: sbom
        path: sbom.spdx.json

  update-gitops:
    name: Update GitOps Repo
    runs-on: ubuntu-latest
    needs: build-and-push
    
    steps:
    - name: Checkout code
      uses: actions/checkout@v3
      with:
        token: ${{ secrets.GITHUB_TOKEN }}
    
    - name: Setup Kustomize
      uses: imranismail/setup-kustomize@v2
      with:
        kustomize-version: ${{ env.KUSTOMIZE_VERSION }}
    
    - name: Update image tag
      run: |
        cd gitops/overlays/production
        kustomize edit set image mario-game=${{ needs.build-and-push.outputs.image-tag }}
    
    - name: Commit and push
      run: |
        git config user.name "GitHub Actions"
        git config user.email "actions@github.com"
        git add gitops/overlays/production/kustomization.yaml
        git commit -m "chore: update image to ${{ needs.build-and-push.outputs.image-tag }}"
        git push
```

### Step 6.3: GitHub Secrets Configuration

Add these secrets to your GitHub repository:

```bash
# Go to: Settings → Secrets and variables → Actions → New repository secret

AWS_ACCESS_KEY_ID: <your-access-key>
AWS_SECRET_ACCESS_KEY: <your-secret-key>
```

### Step 6.4: Create Dockerfile (if not exists)

If your Mario app doesn't have a Dockerfile:

```dockerfile
# Dockerfile
FROM nginx:alpine

# Copy static files
COPY . /usr/share/nginx/html/

# Non-root user
RUN chown -R nginx:nginx /usr/share/nginx/html && \
    chown -R nginx:nginx /var/cache/nginx && \
    chown -R nginx:nginx /var/log/nginx && \
    touch /var/run/nginx.pid && \
    chown -R nginx:nginx /var/run/nginx.pid

USER nginx

EXPOSE 8080

CMD ["nginx", "-g", "daemon off;"]
```

**✅ Checkpoint 6:** Full CI/CD with security scanning and GitOps update is complete.

---

## ✅ Module 7: Testing & Validation

### Step 7.1: End-to-End Test Workflow

```bash
# 1. Make a change
echo "<!-- New feature -->" >> index.html
git add index.html
git commit -m "feat: add new feature"
git push

# 2. Watch GitHub Actions
# Go to: https://github.com/<your-repo>/actions

# 3. Monitor Argo CD sync
argocd app get mario-production --refresh

# 4. Watch Canary rollout
kubectl -n production get canary mario-canary -w

# 5. Verify application
kubectl get svc -n production
# Access LoadBalancer URL
```

### Step 7.2: Test Policy Enforcement

```bash
# Try to deploy with :latest tag (should fail)
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: test-violation
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

# Expected: Admission webhook denied
```

### Step 7.3: Test GitOps Reconciliation

```bash
# Manually change a deployment
kubectl -n production scale deployment mario-deployment --replicas=5

# Wait 3 minutes
# Argo CD will detect drift and restore to desired state (replicas=3)

# Verify
kubectl get deployment -n production mario-deployment
```

### Step 7.4: Test Rollback

```bash
# Deploy a "bad" version
# Edit gitops/overlays/production/kustomization.yaml
# Change newTag to: bad-version

git add gitops/overlays/production/kustomization.yaml
git commit -m "deploy: bad version"
git push

# Canary will fail health checks and auto-rollback
kubectl -n production describe canary mario-canary

# OR manual Git rollback
git revert HEAD
git push
```

**✅ Checkpoint 7:** All systems tested and validated.

---

## 🔧 Troubleshooting Guide

### Issue 1: Argo CD Not Syncing

```bash
# Check Argo CD application status
kubectl get application -n argocd mario-production -o yaml

# Check Argo CD logs
kubectl logs -n argocd deployment/argocd-application-controller

# Force refresh
argocd app get mario-production --refresh --hard

# Manual sync
argocd app sync mario-production --force
```

### Issue 2: Gatekeeper Blocking Deployment

```bash
# Check constraints
kubectl get constraints

# Check violations
kubectl get k8sblocklatesttag block-latest-tag -o yaml

# Disable constraint temporarily
kubectl delete constraint block-latest-tag

# Re-enable after fixing
kubectl apply -f policies/production-constraints.yaml
```

### Issue 3: Canary Stuck in Progressing

```bash
# Check Flagger logs
kubectl logs -n istio-system deployment/flagger -f

# Check metrics availability
kubectl -n production exec -it deployment/mario-deployment -- wget -O- http://prometheus.istio-system:9090/api/v1/query?query=up

# Reset canary
kubectl -n production delete canary mario-canary
kubectl apply -f gitops/overlays/production/canary.yaml
```

### Issue 4: Image Pull Errors from ECR

```bash
# Check ECR authentication
aws ecr get-login-password --region ap-south-1 | docker login --username AWS --password-stdin <account-id>.dkr.ecr.ap-south-1.amazonaws.com

# Create/update image pull secret
kubectl create secret docker-registry ecr-secret \
  --docker-server=<account-id>.dkr.ecr.ap-south-1.amazonaws.com \
  --docker-username=AWS \
  --docker-password=$(aws ecr get-login-password --region ap-south-1) \
  --namespace=production

# Add to deployment
# spec.template.spec.imagePullSecrets:
# - name: ecr-secret
```

### Issue 5: Istio Sidecar Not Injecting

```bash
# Check namespace label
kubectl get namespace production --show-labels

# Re-label if needed
kubectl label namespace production istio-injection=enabled --overwrite

# Restart deployments
kubectl rollout restart deployment -n production
```

---

## 📚 Best Practices & Next Steps

### Security Best Practices

1. **✅ Never use `:latest` tags** → Use immutable SHA or semver tags
2. **✅ Scan images in CI** → Block vulnerabilities before deploy
3. **✅ Enforce policies** → OPA Gatekeeper for admission control
4. **✅ Least privilege** → Use RBAC, non-root containers
5. **✅ Secrets management** → Use External Secrets Operator or AWS Secrets Manager
6. **✅ Network policies** → Isolate namespaces
7. **✅ SBOM generation** → Track dependencies

### GitOps Best Practices

1. **✅ Separate repos** → App code vs. manifests
2. **✅ Environment branches** → `main` = prod, `develop` = dev
3. **✅ Immutable artifacts** → Build once, promote everywhere
4. **✅ Declarative config** → Everything in Git
5. **✅ Auto-sync with caution** → Use for dev, manual approval for prod
6. **✅ Structured commits** → Conventional commits for clarity

### Next Steps to Enhance

#### 1. **Add Multi-Cluster Support**

```yaml
# Argo CD ApplicationSet for multiple clusters
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: mario-multi-cluster
spec:
  generators:
  - list:
      elements:
      - cluster: production
        url: https://prod-cluster
      - cluster: dr
        url: https://dr-cluster
  template:
    metadata:
      name: 'mario-{{cluster}}'
    spec:
      source:
        repoURL: https://github.com/your-org/k8s-mario
        path: 'gitops/overlays/{{cluster}}'
      destination:
        server: '{{url}}'
```

#### 2. **Implement Feature Flags**

```bash
# Install Flagd
kubectl apply -f https://raw.githubusercontent.com/open-feature/flagd/main/config/deployments/kubernetes/flagd-deployment.yaml

# Use feature flags for progressive rollouts
```

#### 3. **Add Cost Monitoring**

```bash
# Install Kubecost
helm install kubecost kubecost/cost-analyzer \
  --namespace kubecost \
  --create-namespace
```

#### 4. **Implement Disaster Recovery**

```bash
# Install Velero for backup
helm install velero vmware-tanzu/velero \
  --namespace velero \
  --create-namespace \
  --set configuration.provider=aws \
  --set configuration.backupStorageLocation.bucket=mario-backups \
  --set configuration.backupStorageLocation.config.region=ap-south-1
```

#### 5. **Add External Secrets**

```bash
# Install External Secrets Operator
helm install external-secrets external-secrets/external-secrets \
  --namespace external-secrets-system \
  --create-namespace
```

#### 6. **Implement Continuous Verification**

```bash
# Install Keptn for automated quality gates
kubectl apply -f https://github.com/keptn/keptn/releases/download/0.19.0/keptn-installer.yaml
```

---

## 📊 Comparison: Before vs After

| Aspect | **Classic Pipeline** | **Modern GitOps Pipeline** |
|--------|---------------------|---------------------------|
| **Deployment** | Manual `kubectl apply` | Argo CD auto-sync |
| **Rollback** | Manual, error-prone | `git revert` |
| **Security** | None | Trivy scan + OPA policies |
| **Drift** | Undetected | Auto-corrected |
| **Releases** | All-or-nothing | Canary with auto-rollback |
| **Observability** | Basic logs | Prometheus + Grafana |
| **Image Tags** | `:latest` | Immutable SHA tags |
| **Environments** | Rebuild per env | Promote same artifact |
| **Audit Trail** | None | Full Git history |
| **MTTR** | Hours | Minutes |

---

## 🎓 Workshop Conclusion

### What You've Accomplished

✅ **GitOps with Argo CD** → Git as single source of truth  
✅ **Security** → Shift-left scanning + policy enforcement  
✅ **Progressive Delivery** → Canary deployments with Flagger  
✅ **Observability** → Prometheus + Grafana metrics  
✅ **Immutable Artifacts** → ECR with SHA tags  
✅ **Automated Rollbacks** → Metric-based failure detection  
✅ **Infrastructure as Code** → Terraform for EKS  
✅ **Policy as Code** → OPA Gatekeeper for compliance  

### Knowledge Check

Can you answer these?

1. What happens if you manually change a deployment in production?
2. How does Argo CD detect configuration drift?
3. What triggers a canary rollback?
4. How do you rollback a deployment in GitOps?
5. What prevents deploying images with `:latest` tag?

<details>
<summary>View Answers</summary>

1. Argo CD's `selfHeal` will revert it back to Git state within 3 minutes
2. Argo CD polls Git every 3 minutes and compares with cluster state
3. If request-success-rate < 99% or request-duration > 500ms
4. `git revert` the commit and push - Argo CD auto-syncs
5. OPA Gatekeeper constraint `K8sBlockLatestTag`

</details>

### Certification Paths

- **Certified Kubernetes Administrator (CKA)**
- **Certified Kubernetes Security Specialist (CKS)**
- **GitOps Certified Associate** (CNCF)
- **Istio Certified Associate**

### Additional Resources

- [Argo CD Documentation](https://argo-cd.readthedocs.io/)
- [Flagger Documentation](https://docs.flagger.app/)
- [OPA Gatekeeper Policy Library](https://open-policy-agent.github.io/gatekeeper-library/)
- [CNCF GitOps Working Group](https://github.com/cncf/tag-app-delivery)

---

## 📝 Final Lab Exercise

**Challenge:** Deploy a second application using everything you've learned.

**Requirements:**
1. Create a new app in the same cluster
2. Use GitOps for deployment
3. Enforce at least 3 OPA policies
4. Implement canary deployment
5. Add Prometheus metrics
6. Create a CI pipeline with security scanning

**Time:** 2-3 hours

---

**🎉 Congratulations!** You've successfully upgraded from a classic pipeline to a modern, production-ready GitOps DevSecOps workflow!

---

**Workshop Version:** 1.0.0  
**Last Updated:** March 2026  
**Maintainer:** DevOps Training Team
