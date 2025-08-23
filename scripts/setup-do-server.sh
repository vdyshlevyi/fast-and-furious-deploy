#!/bin/sh

echo "-> Add linux user: devuser"
adduser devuser
echo "-> Add user to sudo group"
usermod -aG sudo devuser

echo "-> Add user to k8s group(to access kubectl as devuser)"
groupadd k8s
usermod -aG k8s devuser

echo "-> Login as devuser"
su - devuser


echo "-> Install kubernetes(k3s)"
sudo curl -sfL https://get.k3s.io | sh -
mkdir -p ~/.kube
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sudo chown $(id -u):$(id -g) ~/.kube/config
echo "-> Add KUBECONFIG to .bashrc"
echo 'export KUBECONFIG=$HOME/.kube/config' >> ~/.bashrc
echo "-> Apply new .bashrc"
source ~/.bashrc

echo "-> kubectl works with direct config"
kubectl get nodes --kubeconfig ~/.kube/config
echo "-> kubectl works with KUBECONFIG"
kubectl get nodes

echo "-> Use nano as default editor"
echo 'export KUBE_EDITOR="nano"' >> ~/.bashrc
source ~/.bashrc

echo "-> Install Helm"
sudo curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
echo "-> Check Helm version"
helm version

echo "-> Add namespace for ArgoCD"
kubectl create namespace argocd

echo "-> Add Helm repo"
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update

echo "-> Install ArgoCD via Helm"
helm install argocd argo/argo-cd -n argocd

echo "-> Create Ingress for ArgoCD"
cat <<EOF > argocd-server-ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: argocd-server-ingress
  namespace: argocd
spec:
  ingressClassName: traefik
  rules:
  - host: "argocd.165.232.94.220.nip.io"   # use your droplet IP + nip.io
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: argocd-server
            port:
              number: 80  # use http with --insecure arg or 443 port instead

EOF
kubectl apply -f argocd-server-ingress.yaml

# After that edit argocd-server deployment and add --insecure flag
kubectl edit deployment argocd-server -n argocd
# It should look like this
#containers:
#  - args:
#    - /usr/local/bin/argocd-server
#    - --port=8080
#    - --metrics-port=8083
#    - --insecure

# After that open http://argocd.165.232.94.220.nip.io - you should see the ArgoCD UI login page

# To get the initial admin password
kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath="{.data.password}" | base64 -d; echo


# how to get access

# Loki, Grafana, Promtail