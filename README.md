
# Ruby GitOps Pipeline

GitOps-based CI/CD pipeline for Ruby applications using modern Kubernetes tools including ArgoCD, Tekton, and automated database management with StatefulSets.

## 🎯 Overview

This project demonstrates a complete GitOps workflow for Ruby applications with:
- **GitOps Deployment**: ArgoCD for automated application deployment
- **CI/CD Pipeline**: Tekton for build and test automation
- **Database Management**: PostgreSQL with StatefulSets and automated backups
- **Rolling Deployments**: Zero-downtime deployment strategies
- **Monitoring Integration**: Prometheus and Grafana for observability

## 🏗️ Architecture

```
Developer Push → GitHub → Tekton Pipeline → Container Registry
                    ↓
ArgoCD Sync ← Kubernetes Cluster ← GitOps Repository
    ↓
Ruby Application + PostgreSQL StatefulSet
```

## ✨ Features

- **GitOps Workflow**: Declarative configuration management
- **Automated Testing**: Unit tests, integration tests, and security scans
- **Database State Management**: PostgreSQL with persistent volumes
- **Rolling Deployment Strategy**: Zero-downtime deployments
- **Secrets Management**: Kubernetes secrets with external-secrets operator
- **Monitoring & Logging**: Complete observability stack
- **Backup & Recovery**: Automated database backups to S3

## 🛠️ Tech Stack

- **Application**: Ruby on Rails 7.x
- **Database**: PostgreSQL 14
- **Container**: Docker, Kubernetes
- **CI/CD**: Tekton Pipelines
- **GitOps**: ArgoCD
- **Monitoring**: Prometheus, Grafana
- **Storage**: Persistent Volumes, S3
- **Security**: RBAC, Network Policies, Security Contexts

## 📁 Project Structure

```
ruby-gitops-pipeline/
├── app/
│   ├── Gemfile
│   ├── Dockerfile
│   ├── config/
│   ├── app/
│   ├── db/
│   └── spec/
├── k8s/
│   ├── base/
│   │   ├── deployment.yaml
│   │   ├── service.yaml
│   │   ├── statefulset.yaml
│   │   └── configmap.yaml
│   ├── overlays/
│   │   ├── development/
│   │   ├── staging/
│   │   └── production/
│   └── argocd/
│       └── application.yaml
├── tekton/
│   ├── pipelines/
│   ├── tasks/
│   ├── triggers/
│   └── resources/
├── monitoring/
│   ├── prometheus/
│   ├── grafana/
│   └── alerts/
├── scripts/
│   ├── backup.sh
│   ├── restore.sh
│   └── migrate.sh
└── README.md
```

## 🚀 Quick Start

### Prerequisites
- Kubernetes cluster (1.21+)
- ArgoCD installed
- Tekton Pipelines installed
- Container registry access
- Git repository access

### 1. Setup ArgoCD Application
```bash
# Install ArgoCD
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Apply ArgoCD application
kubectl apply -f k8s/argocd/application.yaml
```

### 2. Setup Tekton Pipeline
```bash
# Install Tekton Pipelines
kubectl apply -f https://storage.googleapis.com/tekton-releases/pipeline/latest/release.yaml

# Install Tekton Dashboard
kubectl apply -f https://github.com/tektoncd/dashboard/releases/latest/download/tekton-dashboard-release.yaml

# Apply pipeline resources
kubectl apply -f tekton/
```

### 3. Deploy Application
```bash
# Create namespace
kubectl create namespace ruby-app

# Apply Kubernetes manifests
kubectl apply -k k8s/overlays/production/
```

## 🔧 Configuration

### Database Configuration
```yaml
# k8s/base/statefulset.yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: postgresql
spec:
  serviceName: postgresql
  replicas: 1
  selector:
    matchLabels:
      app: postgresql
  template:
    spec:
      containers:
      - name: postgresql
        image: postgres:14
        env:
        - name: POSTGRES_DB
          value: ruby_app_production
        - name: POSTGRES_USER
          valueFrom:
            secretKeyRef:
              name: postgres-secret
              key: username
        - name: POSTGRES_PASSWORD
          valueFrom:
            secretKeyRef:
              name: postgres-secret
              key: password
        volumeMounts:
        - name: postgres-storage
          mountPath: /var/lib/postgresql/data
  volumeClaimTemplates:
  - metadata:
      name: postgres-storage
    spec:
      accessModes: ["ReadWriteOnce"]
      storageClassName: "fast-ssd"
      resources:
        requests:
          storage: 20Gi
```

### Application Deployment
```yaml
# k8s/base/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ruby-app
spec:
  replicas: 3
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 1
      maxSurge: 1
  selector:
    matchLabels:
      app: ruby-app
  template:
    spec:
      containers:
      - name: ruby-app
        image: ruby-app:latest
        ports:
        - containerPort: 3000
        env:
        - name: RAILS_ENV
          value: production
        - name: DATABASE_URL
          valueFrom:
            secretKeyRef:
              name: database-secret
              key: url
        livenessProbe:
          httpGet:
            path: /health
            port: 3000
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /ready
            port: 3000
          initialDelaySeconds: 5
          periodSeconds: 5
```

## 🔄 CI/CD Pipeline

### Tekton Pipeline Stages
1. **Source Checkout**: Clone repository
2. **Dependency Installation**: Bundle install
3. **Unit Tests**: RSpec test suite
4. **Security Scan**: Brakeman, bundle-audit
5. **Code Quality**: RuboCop linting
6. **Container Build**: Docker image build
7. **Container Scan**: Trivy security scan
8. **Push Image**: Push to container registry
9. **Deploy**: Update GitOps repository
10. **Integration Tests**: Post-deployment testing

### Pipeline Configuration
```yaml
# tekton/pipelines/ruby-pipeline.yaml
apiVersion: tekton.dev/v1beta1
kind: Pipeline
metadata:
  name: ruby-build-deploy
spec:
  params:
  - name: git-url
    type: string
  - name: git-revision
    type: string
    default: main
  - name: image-name
    type: string
  - name: image-tag
    type: string
  
  workspaces:
  - name: source
  - name: dockerconfig
  
  tasks:
  - name: fetch-source
    taskRef:
      name: git-clone
    workspaces:
    - name: output
      workspace: source
    params:
    - name: url
      value: $(params.git-url)
    - name: revision
      value: $(params.git-revision)
  
  - name: run-tests
    taskRef:
      name: ruby-test
    runAfter:
    - fetch-source
    workspaces:
    - name: source
      workspace: source
  
  - name: security-scan
    taskRef:
      name: ruby-security-scan
    runAfter:
    - fetch-source
    workspaces:
    - name: source
      workspace: source
  
  - name: build-image
    taskRef:
      name: buildah
    runAfter:
    - run-tests
    - security-scan
    workspaces:
    - name: source
      workspace: source
    - name: dockerconfig
      workspace: dockerconfig
    params:
    - name: IMAGE
      value: $(params.image-name):$(params.image-tag)
  
  - name: deploy-to-staging
    taskRef:
      name: argocd-sync
    runAfter:
    - build-image
    params:
    - name: application-name
      value: ruby-app-staging
    - name: image-tag
      value: $(params.image-tag)
```

## 📊 Monitoring Setup

### Prometheus Configuration
```yaml
# monitoring/prometheus/servicemonitor.yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: ruby-app-metrics
spec:
  selector:
    matchLabels:
      app: ruby-app
  endpoints:
  - port: metrics
    path: /metrics
    interval: 30s
```

### Grafana Dashboard
```json
{
  "dashboard": {
    "title": "Ruby Application Metrics",
    "panels": [
      {
        "title": "Request Rate",
        "type": "graph",
        "targets": [
          {
            "expr": "rate(http_requests_total[5m])",
            "legendFormat": "{{method}} {{status}}"
          }
        ]
      },
      {
        "title": "Response Time",
        "type": "graph",
        "targets": [
          {
            "expr": "histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))",
            "legendFormat": "95th percentile"
          }
        ]
      },
      {
        "title": "Database Connections",
        "type": "stat",
        "targets": [
          {
            "expr": "pg_stat_database_numbackends",
            "legendFormat": "Active Connections"
          }
        ]
      }
    ]
  }
}
```

## 🔐 Security Features

### Network Policies
```yaml
# k8s/base/network-policy.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: ruby-app-netpol
spec:
  podSelector:
    matchLabels:
      app: ruby-app
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: nginx-ingress
    ports:
    - protocol: TCP
      port: 3000
  egress:
  - to:
    - podSelector:
        matchLabels:
          app: postgresql
    ports:
    - protocol: TCP
      port: 5432
  - to: []
    ports:
    - protocol: TCP
      port: 53
    - protocol: UDP
      port: 53
```

### RBAC Configuration
```yaml
# k8s/base/rbac.yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: ruby-app-sa
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: ruby-app-role
rules:
- apiGroups: [""]
  resources: ["configmaps", "secrets"]
  verbs: ["get", "list"]
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: ruby-app-rolebinding
subjects:
- kind: ServiceAccount
  name: ruby-app-sa
roleRef:
  kind: Role
  name: ruby-app-role
  apiGroup: rbac.authorization.k8s.io
```

## 💾 Backup & Recovery

### Automated Database Backup
```bash
#!/bin/bash
# scripts/backup.sh

NAMESPACE="ruby-app"
POSTGRES_POD=$(kubectl get pods -n $NAMESPACE -l app=postgresql -o jsonpath='{.items[0].metadata.name}')
BACKUP_NAME="postgres-backup-$(date +%Y%m%d-%H%M%S)"
S3_BUCKET="ruby-app-backups"

echo "Creating database backup: $BACKUP_NAME"

kubectl exec -n $NAMESPACE $POSTGRES_POD -- pg_dump -U postgres ruby_app_production | \
  gzip > "/tmp/$BACKUP_NAME.sql.gz"

aws s3 cp "/tmp/$BACKUP_NAME.sql.gz" "s3://$S3_BUCKET/$BACKUP_NAME.sql.gz"

echo "Backup completed: s3://$S3_BUCKET/$BACKUP_NAME.sql.gz"

# Clean up local file
rm "/tmp/$BACKUP_NAME.sql.gz"

# Keep only last 30 backups
aws s3 ls "s3://$S3_BUCKET/" | sort | head -n -30 | awk '{print $4}' | \
  xargs -I {} aws s3 rm "s3://$S3_BUCKET/{}"
```

### Database Migration
```bash
#!/bin/bash
# scripts/migrate.sh

NAMESPACE="ruby-app"
APP_POD=$(kubectl get pods -n $NAMESPACE -l app=ruby-app -o jsonpath='{.items[0].metadata.name}')

echo "Running database migrations..."

kubectl exec -n $NAMESPACE $APP_POD -- bundle exec rails db:migrate

echo "Migration completed successfully"
```

## 🌐 Live Demo

🔗 **Live Application**: [https://ruby-app.buildwithsushant.com](https://ruby-app.buildwithsushant.com)

### Demo Features
- GitOps deployment workflow
- Rolling updates demonstration
- Database persistence testing
- Monitoring dashboards

## 📚 Documentation

- [Installation Guide](docs/installation.md)
- [Pipeline Configuration](docs/pipeline-setup.md)
- [Database Management](docs/database-ops.md)
- [Monitoring Setup](docs/monitoring.md)
- [Troubleshooting](docs/troubleshooting.md)

## 🧪 Testing

### Unit Tests
```bash
cd app
bundle exec rspec
```

### Integration Tests
```bash
kubectl apply -f tests/integration/
```

### Load Testing
```bash
kubectl apply -f tests/load/
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📞 Support

For questions or issues:
- 📧 Email: [buildwithsushant@gmail.com](mailto:buildwithsushant@gmail.com)
- 🐛 Issues: [GitHub Issues](https://github.com/buildwithsushant/ruby-gitops-pipeline/issues)

---

**Built with ❤️ by Sushant Kumar**
