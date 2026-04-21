

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


# run local registry 
docker run -d \
  --name registry-browser \
  --network kind \
  -p 5052:8080 \
  -e DOCKER_REGISTRY_URL=http://kind-registry:5000 \
  klausmeyer/docker-registry-browser:latest

docker stop registry-ui && docker rm registry-ui



# 1. Stop and remove the current registry
docker stop kind-registry && docker rm kind-registry

# 2. Start it again with CORS headers enabled
docker run -d \
  -p 5001:5000 \
  --restart=always \
  --name kind-registry \
  -e "REGISTRY_HTTP_HEADERS_ACCESS-CONTROL-ALLOW-ORIGIN=['http://localhost:5052']" \
  -e "REGISTRY_HTTP_HEADERS_ACCESS-CONTROL-ALLOW-METHODS=['HEAD', 'GET', 'OPTIONS', 'DELETE']" \
  -e "REGISTRY_HTTP_HEADERS_ACCESS-CONTROL-ALLOW-HEADERS=['Authorization', 'Accept', 'Cache-Control', 'Raw-Control-Info', 'Content-Type']" \
  -e "REGISTRY_HTTP_HEADERS_ACCESS-CONTROL-EXPOSE-HEADERS=['Docker-Content-Digest']" \
  registry:2

# 3. Reconnect it to the kind network
docker network connect kind kind-registry



docker stop registry-browser && docker rm registry-browser

docker run -d \
  --name registry-browser \
  --network kind \
  -p 5052:8080 \
  -e DOCKER_REGISTRY_URL=http://kind-registry:5000 \
  klausmeyer/docker-registry-browser:latest

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
