# Architecture Diagrams

## Current (Classic) Architecture

```
┌──────────────┐
│  Developer   │
└──────┬───────┘
       │ manual deploy
       ▼
┌──────────────┐
│   Jenkins    │
│   Pipeline   │
└──────┬───────┘
       │ kubectl apply
       ▼
┌──────────────────────────────┐
│       EKS Cluster            │
│  ┌────────────────────────┐  │
│  │  Mario Deployment      │  │
│  │  (2 replicas)          │  │
│  │  sevenajay/mario:latest│  │
│  └────────────────────────┘  │
│  ┌────────────────────────┐  │
│  │  LoadBalancer Service  │  │
│  └────────────────────────┘  │
└──────────────────────────────┘

Problems:
❌ No version control for deployments
❌ Manual kubectl commands
❌ No security scanning
❌ No drift detection
❌ All-or-nothing deployment
❌ Difficult rollbacks
```

## Target (Modern GitOps) Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         DEVELOPER                               │
└───────────────────────┬─────────────────────────────────────────┘
                        │ git push
                        ▼
┌─────────────────────────────────────────────────────────────────┐
│                    GITHUB REPOSITORY                            │
│  ┌───────────────────┐         ┌────────────────────┐          │
│  │   App Repo        │         │   GitOps Repo      │          │
│  │   (Code)          │         │   (Manifests)      │          │
│  │   - Dockerfile    │         │   - base/          │          │
│  │   - Source code   │         │   - overlays/      │          │
│  └─────────┬─────────┘         └──────────┬─────────┘          │
└────────────┼────────────────────────────────┼──────────────────┘
             │                                │
             │ webhook                        │ poll (3min)
             ▼                                ▼
┌─────────────────────────┐      ┌──────────────────────────┐
│   GITHUB ACTIONS        │      │      ARGO CD             │
│   ┌─────────────────┐   │      │  ┌────────────────────┐  │
│   │ 1. Lint & Test  │   │      │  │  Git Sync          │  │
│   │ 2. Secret Scan  │   │      │  │        ↓           │  │
│   │ 3. SAST         │   │      │  │  Kustomize Build   │  │
│   │ 4. Build Image  │   │      │  │        ↓           │  │
│   │ 5. Scan Image   │   │      │  │  OPA Policy Check  │  │
│   │ 6. SBOM Gen     │   │      │  │        ↓           │  │
│   │ 7. Push ECR     │───┼──────┼─▶│  Apply to K8s      │  │
│   │ 8. Update Git   │   │      │  │        ↓           │  │
│   └─────────────────┘   │      │  │  Self-Heal (drift) │  │
└─────────────────────────┘      │  └────────────────────┘  │
                                 └────────────┬─────────────┘
                                              │ deploy
                                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                        EKS CLUSTER                              │
│                                                                 │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │                ISTIO SERVICE MESH                        │  │
│  │  ┌────────────┐  ┌────────────┐  ┌────────────┐        │  │
│  │  │  Gateway   │─▶│ VirtualSvc │─▶│DestRule    │        │  │
│  │  └────────────┘  └────────────┘  └────────────┘        │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                 │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │                FLAGGER (Canary Controller)               │  │
│  │  Traffic: Primary ──▶ 100% → 90% → 80% → 50% ──▶ Canary │  │
│  │           ↓           ↓      ↓      ↓      ↓         ↓   │  │
│  │        Metrics    Success? Success? Success? ALL OK?    │  │
│  │           ↓           ↓      ↓      ↓      ↓         ↓   │  │
│  │        Analyze     Next   Next   Next   Promote  OR     │  │
│  │                    Step   Step   Step            Rollback│  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                 │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │            APPLICATION WORKLOADS                         │  │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  │  │
│  │  │ Mario-Primary│  │ Mario-Canary │  │ Mario-Service│  │  │
│  │  │ (v1.0.0)     │  │ (v1.1.0)     │  │ (LoadBalancer│  │  │
│  │  │ 3 replicas   │  │ 1 replica    │  │              │  │  │
│  │  └──────────────┘  └──────────────┘  └──────────────┘  │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                 │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │            SECURITY & POLICY                             │  │
│  │  ┌──────────────┐  ┌──────────────┐                     │  │
│  │  │ Gatekeeper   │  │ Network      │                     │  │
│  │  │ (OPA)        │  │ Policies     │                     │  │
│  │  │ - No :latest │  │              │                     │  │
│  │  │ - Resources  │  │              │                     │  │
│  │  │ - Non-root   │  │              │                     │  │
│  │  └──────────────┘  └──────────────┘                     │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                 │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │            OBSERVABILITY                                 │  │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  │  │
│  │  │ Prometheus   │◀─│ ServiceMonitor│─▶│  Grafana    │  │  │
│  │  │ (Metrics)    │  │              │  │  (Dashboards)│  │  │
│  │  └──────────────┘  └──────────────┘  └──────────────┘  │  │
│  └──────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

## Data Flow Diagrams

### CI Pipeline Flow

```
┌──────────────┐
│ git push     │
└──────┬───────┘
       │
       ▼
┌─────────────────────────────┐
│ GitHub Actions Triggered    │
└──────┬──────────────────────┘
       │
       ▼
┌─────────────────────────────┐
│ Job 1: Security Scan        │
│ • Trivy filesystem scan     │
│ • Secret detection          │
│ • Upload to GitHub Security │
└──────┬──────────────────────┘
       │ parallel
       ▼
┌─────────────────────────────┐
│ Job 2: Lint & Test          │
│ • Validate Kubernetes YAML  │
│ • Kustomize build test      │
│ • Kubeval validation        │
└──────┬──────────────────────┘
       │ both pass
       ▼
┌─────────────────────────────┐
│ Job 3: Build & Push         │
│ • Generate SHA tag          │
│ • Docker build              │
│ • Trivy image scan          │
│ • Push to ECR               │
│ • Generate SBOM             │
└──────┬──────────────────────┘
       │
       ▼
┌─────────────────────────────┐
│ Job 4: Update GitOps        │
│ • Checkout repo             │
│ • Update kustomization      │
│ • Git commit & push         │
└──────┬──────────────────────┘
       │
       ▼
┌─────────────────────────────┐
│ Argo CD detects change      │
└─────────────────────────────┘
```

### Deployment Flow (GitOps)

```
┌─────────────────────────────┐
│ Git commit pushed           │
└──────┬──────────────────────┘
       │
       ▼
┌─────────────────────────────┐
│ Argo CD polls Git (3min)    │
│ OR webhook triggers         │
└──────┬──────────────────────┘
       │
       ▼
┌─────────────────────────────┐
│ Detect change in manifest   │
└──────┬──────────────────────┘
       │
       ▼
┌─────────────────────────────┐
│ Generate K8s resources      │
│ (Kustomize build)           │
└──────┬──────────────────────┘
       │
       ▼
┌─────────────────────────────┐
│ Compare with cluster state  │
└──────┬──────────────────────┘
       │
    ┌──┴──┐
    │     │
 No │     │ Yes
Change    Change
    │     │
    ▼     ▼
  Skip  ┌─────────────────────────────┐
        │ Run pre-sync hooks          │
        └──────┬──────────────────────┘
               │
               ▼
        ┌─────────────────────────────┐
        │ OPA Gatekeeper validation   │
        │ (Admission webhook)         │
        └──────┬──────────────────────┘
               │
            ┌──┴──┐
         Pass│    │Fail
             │    │
             ▼    ▼
        ┌─────┐ ┌────────────┐
        │Apply│ │Block deploy│
        │to K8s│ │Show error │
        └──┬──┘ └────────────┘
           │
           ▼
    ┌─────────────────────────────┐
    │ Flagger detects new version │
    └──────┬──────────────────────┘
           │
           ▼
    ┌─────────────────────────────┐
    │ Start canary deployment     │
    │ • Create canary pods        │
    │ • Route 10% traffic         │
    └──────┬──────────────────────┘
           │
           ▼
    ┌─────────────────────────────┐
    │ Metrics analysis (1 min)    │
    │ • Success rate > 99%?       │
    │ • Latency < 500ms?          │
    └──────┬──────────────────────┘
           │
        ┌──┴──┐
     Pass│    │Fail
        │     │
        ▼     ▼
    ┌────┐  ┌──────────┐
    │Next│  │Rollback  │
    │Step│  │to primary│
    └─┬──┘  └──────────┘
      │
      ▼
   Repeat until 50%
      │
      ▼
    ┌─────────────────────────────┐
    │ All checks pass             │
    │ Promote canary to primary   │
    │ Terminate old version       │
    └─────────────────────────────┘
```

### Rollback Flow

```
┌─────────────────────────────┐
│ Developer: git revert HEAD  │
│ git push                    │
└──────┬──────────────────────┘
       │
       ▼
┌─────────────────────────────┐
│ Argo CD detects revert      │
└──────┬──────────────────────┘
       │
       ▼
┌─────────────────────────────┐
│ Apply previous manifest     │
│ Image tag: v1.0.0 (old)     │
└──────┬──────────────────────┘
       │
       ▼
┌─────────────────────────────┐
│ Flagger canary rollout      │
│ New = old version           │
│ Traffic: 10%→20%→50%→100%  │
└──────┬──────────────────────┘
       │
       ▼
┌─────────────────────────────┐
│ Rollback complete           │
│ Time: ~5 minutes            │
└─────────────────────────────┘
```

### Policy Enforcement Flow

```
┌─────────────────────────────┐
│ kubectl apply deployment    │
└──────┬──────────────────────┘
       │
       ▼
┌─────────────────────────────┐
│ K8s API Server receives     │
└──────┬──────────────────────┘
       │
       ▼
┌─────────────────────────────┐
│ Admission webhook intercept │
│ (Gatekeeper)                │
└──────┬──────────────────────┘
       │
       ▼
┌─────────────────────────────┐
│ Load matching constraints:  │
│ • K8sBlockLatestTag         │
│ • K8sRequiredResources      │
│ • K8sRequireNonRoot         │
└──────┬──────────────────────┘
       │
       ▼
┌─────────────────────────────┐
│ Evaluate Rego policies      │
└──────┬──────────────────────┘
       │
    ┌──┴──┐
    │     │
 Pass│    │Fail
    │     │
    ▼     ▼
┌─────┐ ┌────────────────────────┐
│Allow│ │ Reject with message:   │
│     │ │ "Container uses :latest│
│     │ │  tag, not allowed"     │
└──┬──┘ └────────────────────────┘
   │
   ▼
┌─────────────────────────────┐
│ Create deployment in K8s    │
└─────────────────────────────┘
```

## Component Interaction Matrix

```
┌──────────────┬──────┬──────┬──────┬──────┬──────┬──────┐
│ Component    │ArgCD │ OPA  │Flgr  │Istio │Prom  │ ECR  │
├──────────────┼──────┼──────┼──────┼──────┼──────┼──────┤
│ Argo CD      │  -   │ Resp │ Sync │  -   │  -   │ Pull │
├──────────────┼──────┼──────┼──────┼──────┼──────┼──────┤
│ OPA Gate     │  -   │  -   │  -   │  -   │  -   │  -   │
├──────────────┼──────┼──────┼──────┼──────┼──────┼──────┤
│ Flagger      │  -   │  -   │  -   │ Ctrl │ Query│  -   │
├──────────────┼──────┼──────┼──────┼──────┼──────┼──────┤
│ Istio        │  -   │  -   │  -   │  -   │ Exp  │  -   │
├──────────────┼──────┼──────┼──────┼──────┼──────┼──────┤
│ Prometheus   │  -   │  -   │ Read │ Scrp │  -   │  -   │
├──────────────┼──────┼──────┼──────┼──────┼──────┼──────┤
│ GitHub Act   │ Updt │  -   │  -   │  -   │  -   │ Push │
└──────────────┴──────┴──────┴──────┴──────┴──────┴──────┘

Legend:
Resp = Respects  Sync = Syncs with   Ctrl = Controls
Query = Queries  Exp = Exposes       Pull = Pulls from
Scrp = Scrapes   Updt = Updates      Push = Pushes to
Read = Reads from
```

## Timeline Visualization

```
Day 0: Classic Pipeline
│
├─ Manual deployments
├─ No version control
├─ High MTTR (hours)
│

Day 1-2: Workshop Modules 1-3
│
├─ GitOps repository structure
├─ Argo CD installation
├─ Policy enforcement
│
│  Benefits unlocked:
│  ✓ Git as source of truth
│  ✓ Drift detection
│  ✓ Security policies
│

Day 3-4: Workshop Modules 4-5
│
├─ Istio service mesh
├─ Flagger canary deployments
├─ Prometheus & Grafana
│
│  Benefits unlocked:
│  ✓ Progressive delivery
│  ✓ Auto rollback
│  ✓ Metrics-driven
│

Day 5-6: Workshop Modules 6-7
│
├─ GitHub Actions CI/CD
├─ Security scanning
├─ End-to-end testing
│
│  Benefits unlocked:
│  ✓ Automated builds
│  ✓ Shift-left security
│  ✓ SBOM generation
│

Day 7: Production Ready
│
├─ Full GitOps workflow
├─ Canary with auto-rollback
├─ MTTR reduced to minutes
│
│  Final state:
│  ✓ World-class DevOps
│  ✓ Production-grade security
│  ✓ Observable system
```

---

**Diagrams Purpose:**
- Understand the before/after architecture
- Visualize component interactions
- See data flows through the system
- Track your progress through the workshop
