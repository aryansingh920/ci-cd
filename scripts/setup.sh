

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
