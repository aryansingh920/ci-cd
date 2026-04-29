# localhost:8080 -> Jenkins UI (Where you approve/watch builds).

# localhost:5001 -> Docker Registry (Where Jenkins pushes the image).

# localhost:8081 -> Argo CD UI (Where you watch the deployment).

# localhost:30080 -> Your Next.js App (Staging) 👈 We are going to set this up right now.

# Jenkins UI
# http://localhost:8080

# Jenkins Agent Port (JNLP)
# localhost:50000

# Local Docker Registry
# localhost:5001

# Docker Registry Browser UI
# http://localhost:5052

# Argo CD UI (HTTPS)
# http://localhost:8081
kubectl port-forward svc/argocd-server -n argocd 8081:443
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d


# Next.js Application (Staging)
# http://localhost:30080
kubectl port-forward svc/nextjs-service -n staging 30080:80

# Next.js Application (Production)
# http://localhost:30081
kubectl port-forward svc/nextjs-service -n production 30081:80

# Kiali Dashboard (Service Mesh Visualization)
# http://localhost:20001
kubectl port-forward svc/kiali -n istio-system 20001:20001

# Grafana (Metrics Dashboards)
# http://localhost:3000
kubectl port-forward svc/grafana -n istio-system 3000:3000

# Prometheus (Metrics Server)
# http://localhost:9090
kubectl port-forward svc/prometheus -n istio-system 9090:9090

# Istiod Debug/Status (Control Plane)
# http://localhost:15014
kubectl port-forward svc/istiod -n istio-system 15014:15014


# Find and kill process on port 3000 (Grafana)
sudo lsof -t -i:3000 | xargs kill -9

# Find and kill process on port 8080 (Jenkins/Registry Browser conflict)
sudo lsof -t -i:8080 | xargs kill -9

# Kill all active kubectl port-forwards
pgrep kubectl | xargs kill -9
