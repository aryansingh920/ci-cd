

# kind is the tool that will spin up your local Kubernetes cluster inside Docker Desktop.
brew install kind


# Jenkins will need a place to push the Docker image, 
# and Kubernetes will need a place to pull it from. 
# We will create a local registry (localhost:5001) 
# and a cluster named local-cicd that knows how to talk to it.


# 1. Create a local docker registry container
docker run -d --restart=always -p "5001:5000" --name "kind-registry" registry:2

# 2. Create a Kind cluster with the registry enabled

kind delete cluster --name local-cicd

docker rm -f $(docker ps -aq --filter "name=local-cicd") 2>/dev/null || true

# B. Create the cluster using the file you just made
kind create cluster --name local-cicd --config kind-config.yaml

# C. Connect the registry to the cluster network
docker network connect "kind" "kind-registry"


kubectl get nodes


# run app-source
git add Dockerfile .dockerignore
git commit -m "chore: add Dockerfile for CI/CD"



# Build the custom Jenkins image
docker build -t local-jenkins -f jenkins.Dockerfile .

# Create a volume for Jenkins data
docker volume create jenkins-data


# Run Jenkins
docker run -d --name jenkins --restart=on-failure \
  --network kind \
  -p 8080:8080 -p 50000:50000 \
  -v jenkins-data:/var/jenkins_home \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v $(pwd)/jenkins-builds:/var/jenkins_home/workspace \
  local-jenkins


# Jenkins server
# http://localhost:8080

docker exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword


# Clear all build cache
docker builder prune -a -f

# Clear unused, dangling images
docker image prune -f


# Create the "Staging" Environment in Kubernetes
kubectl create namespace staging


# 1. Create a namespace for Argo CD
kubectl create namespace argocd

# 2. Apply the official Argo CD installation manifests
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

kubectl replace --force -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

kubectl apply --server-side -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml


kubectl get pods -n argocd
kubectl get pods -n staging


# Log into Argo CD
kubectl port-forward svc/argocd-server -n argocd 8081:443

# get the password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d


kubectl rollout restart deployment my-next-app -n staging

kubectl port-forward svc/nextjs-service -n staging 30080:80




docker stop registry-ui && docker rm registry-ui



# 1. Stop and remove the current registry
docker stop kind-registry && docker rm kind-registry



# 3. Reconnect it to the kind network
docker network connect kind kind-registry



docker stop registry-browser && docker rm registry-browser



# Wait 5 seconds, then check if it's actually running
docker logs registry-browser


docker run -d \
  --name registry-browser \
  --network kind \
  -p 5052:8080 \
  -e DOCKER_REGISTRY_URL=http://kind-registry:5000 \
  -e SECRET_KEY_BASE=$(openssl rand -hex 64) \
  klausmeyer/docker-registry-browser:latest


kubectl create namespace production


# Step 1 — Delete your current cluster
kind delete cluster --name local-cicd   # replace local-cicd with your cluster name

# Step 2 — Start a registry container on the kind network
docker run -d --restart=always \
  -p 5001:5000 \
  --name kind-registry \
  registry:2


# Step 4 — Connect registry to kind network (if not already)
docker network connect kind kind-registry

# Step 5 — Recreate namespaces
kubectl create namespace staging
kubectl create namespace production


kubectl describe pod -l app=nextjs -n staging


kind load docker-image localhost:5001/my-next-app:build-10 --name local-cicd


kubectl port-forward svc/nextjs-service -n production 30081:80 




kubectl create namespace istio-system

kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.20/samples/addons/extras/prometheus-operator.yaml
# (Or more simply, the minimal Istio manifests)
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.20/manifests/charts/base/crds/crd-all.gen.yaml


kubectl rollout restart deployment my-next-app -n staging


kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.20/samples/addons/prometheus.yaml
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.20/samples/addons/kiali.yaml


kubectl port-forward svc/kiali 20001:20001 -n istio-system


kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.20/samples/addons/grafana.yaml


while true; do curl -s http://localhost:30080 > /dev/null; echo "Sent request to Staging..."; sleep 0.5; done

kubectl port-forward svc/grafana 3000:3000 -n istio-system

kubectl patch svc istiod -n istio-system -p '{"spec":{"ports":[{"name":"http-monitoring","port":8080,"targetPort":8080}]}}'

# Find the process ID (PID) using port 3000 and kill it
lsof -i tcp:3000 | awk 'NR!=1 {print $2}' | xargs kill -9

sudo lsof -t -i:3000 | xargs kill -9

kubectl patch configmap kiali -n istio-system --type merge -p '{"data":{"kiali.yaml":"external_services:\n  istio:\n    istio_sidecar_injector_config_map: istio-sidecar-injector\n    istiod_deployment_name: istiod\n    url_service_version: http://istiod.istio-system.svc:15014/version\n"}}'

kubectl label pod -l istio=pilot -n istio-system app=istiod

kubectl get svc -n istio-system

kubectl patch svc istiod -n istio-system --type=json -p='[{"op": "add", "path": "/spec/ports/-", "value": {"name": "status-port", "port": 15014, "targetPort": 15014}}]'

kubectl rollout restart deployment kiali -n istio-system

kubectl label deployment istiod -n istio-system app=istiod istio=pilot --overwrite

kubectl patch configmap kiali -n istio-system --type merge -p '{"data":{"kiali.yaml":"external_services:\n  istio:\n    istiod_deployment_name: istiod\n    url_service_version: http://istiod.istio-system.svc:15014/version\n    discovery_interface: \"kubernetes\"\n"}}'


kubectl patch deployment istiod -n istio-system --type='json' -p='[{"op": "add", "path": "/spec/template/spec/containers/0/ports/-", "value": {"containerPort": 15014, "protocol": "TCP"}}]'

kubectl logs -l istio=pilot -n istio-system --tail=20

kubectl port-forward svc/kiali 20001:20001 -n istio-system

kubectl port-forward svc/istiod 15014:15014 -n istio-system

kubectl port-forward svc/prometheus 9090:9090 -n istio-system


kubectl patch configmap kiali -n istio-system --type merge -p '{"data":{"kiali.yaml":"external_services:\n  prometheus:\n    url: http://prometheus.istio-system.svc:9090\n"}}'
kubectl rollout restart deployment kiali -n istio-system



kubectl apply -f istio.yaml

# Force Istiod to restart with the new RBAC + ConfigMap
kubectl rollout restart deployment/istiod -n istio-system
kubectl rollout status deployment/istiod -n istio-system

# Watch logs — should no longer show "forbidden" or "waiting for sync"
kubectl logs -n istio-system deploy/istiod -f | grep -E "ready|forbidden|error|warn|serving"




kubectl apply -f - <<'EOF'
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: istiod-clusterrole
rules:
- apiGroups: [""]
  resources: ["configmaps", "endpoints", "secrets", "services", "serviceaccounts", "namespaces", "pods", "nodes", "persistentvolumeclaims"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
- apiGroups: ["apps"]
  resources: ["deployments", "replicasets", "statefulsets", "daemonsets"]
  verbs: ["get", "list", "watch"]
- apiGroups: ["admissionregistration.k8s.io"]
  resources: ["mutatingwebhookconfigurations", "validatingwebhookconfigurations"]
  verbs: ["get", "list", "watch", "update", "patch"]
- apiGroups: ["apiextensions.k8s.io"]
  resources: ["customresourcedefinitions"]
  verbs: ["get", "list", "watch"]
- apiGroups: ["networking.k8s.io"]
  resources: ["ingresses", "ingressclasses"]
  verbs: ["get", "list", "watch"]
- apiGroups: ["coordination.k8s.io"]
  resources: ["leases"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
- apiGroups: ["networking.istio.io", "security.istio.io", "extensions.istio.io", "telemetry.istio.io"]
  resources: ["*"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
- apiGroups: ["certificates.k8s.io"]
  resources: ["certificatesigningrequests", "certificatesigningrequests/approval", "certificatesigningrequests/status"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
- apiGroups: ["discovery.k8s.io"]
  resources: ["endpointslices"]
  verbs: ["get", "list", "watch"]
- apiGroups: ["gateway.networking.k8s.io"]
  resources: ["*"]
  verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: istiod-clusterrolebinding
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: istiod-clusterrole
subjects:
- kind: ServiceAccount
  name: istiod
  namespace: istio-system
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: istio
  namespace: istio-system
data:
  mesh: |
    defaultConfig:
      discoveryAddress: istiod.istio-system.svc:15012
    enablePrometheusMerge: true
  meshNetworks: 'networks: {}'
EOF



kubectl rollout restart deployment/istiod -n istio-system
kubectl rollout status deployment/istiod -n istio-system
