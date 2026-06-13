# k8sec2 Master node setup 
######################################
#########################################
Final Deployment Steps
#########################
# Disable Swap (Your steps were correct here)
swapoff -a
sudo sed -i '/swap/d' /etc/stab
# Set SELinux to Permissive
sudo setenforce 0
sudo sed -i 's/^SELINUX=enforcing$/SELINUX=permissive/' /etc/selinux/config
# Load required kernel modules
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF
sudo modprobe overlay
sudo modprobe br_netfilter
# Configure sysctl parameters for networking
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF
# Apply sysctl parameters immediately without rebooting
sudo sysctl --system

# Install containerd via standard Docker repo engine packaging
yum install -y yum-utils
yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
yum install -y containerd.io
# Generate default containerd config and enforce SystemdCgroup driver usage
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml >/dev/null
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/g' /etc/etc/containerd/config.toml
# Start and enable containerd
systemctl enable --now containerd

# Add the formal repository config (Fixed syntax from your snippet).   ##Install Kubernetes Components (v1.29)
cat <<EOF | sudo tee /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://pkgs.k8s.io/core:/stable:/v1.29/rpm/
enabled=1
gpgcheck=1
gpgkey=https://pkgs.k8s.io/core:/stable:/v1.29/rpm/repodata/repomd.xml.key
EOF
# Install binaries
yum install -y kubelet kubeadm kubectl --disableexcludes=kubernetes
systemctl enable --now kubelet

# Initialize using the correct private IP advertises address and Calico default CIDR block
sudo kubeadm init \
  --apiserver-advertise-address=<YOUR_PRIVATE_IP> \
  --pod-network-cidr=192.168.0.0/16
# Configure your root shell credentials profile to map cluster access
export KUBECONFIG=/etc/kubernetes/admin.conf
echo 'export KUBECONFIG=/etc/kubernetes/admin.conf' | sudo tee -a /etc/profile

# Apply Calico manifest rules
kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.26.1/manifests/calico.yaml
# Explicitly set interface auto-detection parameters if using custom network adapters (e.g., AWS enX0)
kubectl set env daemonset/calico-node -n kube-system IP_AUTODETECTION_METHOD=interface=enX0
# Verify the master node shifts into a 'Ready' status context
kubectl get nodes

# 1. Download the verified etcd binary archive (v3.5.11 matches standard v1.29 setups)
curl -LO https://github.com/etcd-io/etcd/releases/download/v3.5.11/etcd-v3.5.11-linux-amd64.tar.gz
# 2. Extract the archive contents
tar -xvf etcd-v3.5.11-linux-amd64.tar.gz
# 3. Move only the etcdctl command line tool into your system binaries directory
sudo mv etcd-v3.5.11-linux-amd64/etcdctl /usr/local/bin/
# 4. Clean up the leftover download files
rm -rf etcd-v3.5.11-linux-amd64*
# 5. Verify it runs successfully
etcdctl version
+++++++++++++++++++++++++++++++++++++++++
Only one network config to be used
kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml 
kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml
+++++++++++++++++++
“After kubeadm reset, all control-plane configurations are removed, including admin.conf. So kubeadm init must be executed again to recreate the cluster and restore API access.”
Clean reset (if not already done)
kubeadm reset -f
rm -rf /etc/kubernetes /var/lib/etcd
systemctl restart containerd kubelet
+++++++++++++++++++++++++++++++++++++++++
cat <<'EOF' | sudo tee /etc/crictl.yaml
runtime-endpoint: unix:///run/containerd/containerd.sock
image-endpoint: unix:///run/containerd/containerd.sock
timeout: 10
debug: false
EOF
sudo crictl ps -a | egrep "kube-apiserver|kube-controller-manager|kube-scheduler|etcd|coredns|kube-proxy" || true
kubectl get pods -n kube-system

yum install -y containerd
mkdir -p /etc/containerd
containerd config default | tee /etc/containerd/config.toml
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
systemctl enable containerd
systemctl restart containerd
###############################################
Workernode setup
# Disable Swap
swapoff -a
sudo sed -i '/swap/d' /etc/fstab
# Set SELinux to Permissive
sudo setenforce 0
sudo sed -i 's/^SELINUX=enforcing$/SELINUX=permissive/' /etc/selinux/config

# Load required kernel modules
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF
sudo modprobe overlay
sudo modprobe br_netfilter
# Configure sysctl parameters for networking
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF
# Apply sysctl parameters immediately
sudo sysctl --system

# Install containerd via standard Docker repo engine packaging
yum install -y yum-utils
yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
yum install -y containerd
# Generate default containerd config and enforce SystemdCgroup driver usage
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml >/dev/null
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/g' /etc/containerd/config.toml
# Start and enable containerd
systemctl enable --now containerd

# Add the repository config
cat <<EOF | sudo tee /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://pkgs.k8s.io/core:/stable:/v1.29/rpm/
enabled=1
gpgcheck=1
gpgkey=https://pkgs.k8s.io/core:/stable:/v1.29/rpm/repodata/repomd.xml.key
EOF

# Install binaries
yum install -y kubelet kubeadm kubectl --disableexcludes=kubernetes
systemctl enable --now kubelet

kubeadm join 172.31.34.126:6443 --token <token> --discovery-token-ca-cert-hash sha256:
kubectl get nodes
+++++++++++++++++++
Master Node - token valid for 24 hours only
kubeadm token create --print-join-command
kubeadm join 172.31.34.81:6443 --token 4nqtes.okcey4rlzpnjixd5 --discovery-token-ca-cert-hash sha256:c5923ebed4b51492bc6b9131b8c6167e45ed591dd48b3fb934462539248715d1
+++++++++++++++++++++++++++
Test workload
kubectl create deployment nginx --image=nginx
deployment.apps/nginx created
kubectl expose deployment nginx --type=NodePort --port=80
service/nginx exposed
kubectl get svc nginx-service
kubectl get pods -o wide
NAME                     READY   STATUS    RESTARTS   AGE   IP               NODE                          NOMINATED NODE   READINESS GATES
nginx-7854ff8877-5zlxm   1/1     Running   0          45s   192.168.108.65   ip-172-31-35-6.ec2.internal   <none>           <none>
kubectl get svc
NAME         TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)        AGE
kubernetes   ClusterIP   10.96.0.1       <none>        443/TCP        56m
nginx        NodePort    10.104.46.225   <none>        80:30280/TCP   45s
#####################################
LOGS CHECK
##################
kubectl logs -n kube-system <calico-node-pod-name>
kubectl delete pod -n kube-system <calico-node-pod-name>
kubectl get pods -n kube-system
kubectl describe pod -n kube-system <calico-node-pod-name>
kubectl get pods -n kube-system -l k8s-app=calico-node -w
kubectlogs -n kube-system calico-node-pod-name --all-containers
kubectdescribe pod -n kube-system calico-node-dt67v | grep BGP
++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++



DOCKER IMAGE
cat Dockerfile 
FROM nginx:latest
COPY app/index.html /usr/share/nginx/html/index.html
docker build -t your-dockerhub-username/my-app:latest .
docker images                                               /*check created image
docker run -d -p 8080:80 vikasgaur/my-app:latest        /*test
docker login
docker push vikasgaur/my-app:latest                         /*push image
After updating deployment.yaml
kubectl apply -f k83/deployment.yaml
kubectl logs -l app=my-app
dnf install iptables-services -y
systemctl enable iptables
sudo systemctl start iptables
iptables -L -n
kubectl delete pod -n kube-system -l k8s-app=kube-proxy
iptables -t nat -L -n | grep 30280
kubectl get pods -o wide                                /*workerip
curl http://workerip:30280
