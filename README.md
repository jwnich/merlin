# Ray GKE Infrastructure

GitOps-based infrastructure for running Ray clusters, Mage pipelines, and Jupyter notebooks on Google Kubernetes Engine (GKE).

## 🚀 Quick Start

Deploy the development environment with a single command:

```bash
curl -sSL https://raw.githubusercontent.com/YOUR-USERNAME/ray-gke-infrastructure/main/deploy.sh | bash
```

Or clone and run locally:

```bash
git clone https://github.com/YOUR-USERNAME/ray-gke-infrastructure.git
cd ray-gke-infrastructure
chmod +x deploy.sh
./deploy.sh dev
```

## 📋 Prerequisites

- **GKE Autopilot cluster** (recommended) or Standard GKE cluster
- **kubectl** configured and connected to your cluster
- **kustomize** (optional - kubectl 1.21+ has built-in support)

### Connect to your GKE cluster:
```bash
gcloud container clusters get-credentials YOUR-CLUSTER-NAME --zone=YOUR-ZONE
```

## 🏗️ Architecture

This setup deploys three main components across isolated namespaces:

### Namespaces
- **`data-pipeline-dev`**: Mage orchestrator and pipeline execution pods
- **`ray-training-dev`**: Ray cluster for distributed ML training/inference  
- **`notebooks-dev`**: JupyterHub for interactive development

### Components
- **Ray Cluster**: Auto-scaling distributed computing with dashboard
- **Mage**: Data pipeline orchestration with Kubernetes execution
- **JupyterHub**: Multi-user notebook environment
- **Shared Storage**: GCS integration for datasets and artifacts

## 🎯 Use Cases

Perfect for:
- **Financial modeling** with ARIMA + bootstrapping
- **Memory-intensive** time series analysis
- **Parallel model training** across multiple datasets
- **Data pipeline orchestration** with Mage
- **Interactive development** with Jupyter notebooks

## 📁 Repository Structure

```
ray-gke-infrastructure/
├── deploy.sh                  # Main deployment script
├── base/                     # Base Kustomize configurations
│   ├── namespaces/          # Namespace definitions
│   ├── ray-cluster/         # Ray cluster base config
│   ├── mage/               # Mage pipeline orchestrator
│   └── notebooks/          # JupyterHub setup
├── overlays/               # Environment-specific customizations
│   ├── dev/               # Development environment
│   ├── staging/           # Staging environment  
│   └── prod/              # Production environment
└── examples/              # Sample jobs and pipelines
```

## 🔧 Customization

### Environment Configuration

Each environment in `overlays/` can customize:
- **Resource limits** and requests
- **Scaling parameters** (min/max replicas)  
- **Image tags** and versions
- **Storage configurations**
- **Network policies**

### Adding New Environments

```bash
cp -r overlays/dev overlays/my-env
# Edit overlays/my-env/kustomization.yaml
./deploy.sh my-env
```

### Scaling Ray Cluster

Edit `overlays/dev/ray-cluster-patch.yaml`:

```yaml
workerGroupSpecs:
- replicas: 5              # Initial workers
  minReplicas: 0           # Can scale to zero
  maxReplicas: 20          # Maximum workers
  template:
    spec:
      containers:
      - name: ray-worker
        resources:
          requests:
            cpu: "2"
            memory: "16Gi"  # Adjust for your datasets
```

## 🧪 Testing the Deployment

After deployment, test with the included sample job:

```bash
kubectl apply -f examples/test-job.yaml
kubectl logs job/ray-test-job -n ray-training-dev -f
```

## 📊 Monitoring and Access

### Ray Dashboard
```bash
kubectl port-forward svc/ray-dashboard-service 8265:8265 -n ray-training-dev
# Open http://localhost:8265
```

### JupyterHub (when deployed)
```bash
kubectl port-forward svc/jupyterhub 8000:80 -n notebooks-dev  
# Open http://localhost:8000
```

### Mage UI (when deployed)
```bash
kubectl port-forward svc/mage 6789:6789 -n data-pipeline-dev
# Open http://localhost:6789
```

## 🔍 Troubleshooting

### Check cluster status:
```bash
kubectl get pods -n ray-training-dev
kubectl get raycluster -n ray-training-dev
```

### View Ray cluster logs:
```bash
kubectl logs -l app.kubernetes.io/component=ray-head -n ray-training-dev
```

### Check resource usage:
```bash
kubectl top pods -n ray-training-dev
kubectl describe quota -n ray-training-dev
```

## 🛡️ Security

- **Workload Identity**: Secure access to GCP services
- **RBAC**: Role-based access control for Ray operations
- **Network Policies**: Namespace isolation
- **Resource Quotas**: Prevent resource exhaustion

## 🚧 Roadmap

- [ ] **Mage configuration** for Kubernetes execution
- [ ] **JupyterHub** with persistent storage
- [ ] **Monitoring stack** (Prometheus + Grafana)
- [ ] **CI/CD pipelines** for automated deployment
- [ ] **Production hardening** (security policies, backups)
