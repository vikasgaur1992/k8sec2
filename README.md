# k8sec2 Master node setup 
######################################
free -m
swapoff -a
cat /etc/fstab 
sudo sed -i '/swap/d' /etc/fstab
yum install docker -y
systemctl enable docker
systemctl start docker
rpm --import https://pkgs.k8s.io/core:/stable:/v1.29/rpm/repodata/repomd.xml.key

cat <<EOF | sudo tee /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://pkgs.k8s.io/core:/stable:/v1.29/rpm/
enabled=1
gpgcheck=1
gpgkey=https://pkgs.k8s.io/core:/stable:/v1.29/rpm/repodata/repomd.xml.key
EOF
# Install
yum install -y kubelet kubeadm kubectl
systemctl enable --now kubelet
++++++++++++++++++
Initialize cluster
sudo kubeadm init --pod-network-cidr=10.244.0.0/1  - test
After kubeadm init --apiserver-advertise-address=(private_ip) --pod-network-cidr=192.168.0.0/16
export KUBECONFIG=/etc/kubernetes/admin.conf
echo 'export KUBECONFIG=/etc/kubernetes/admin.conf' | sudo tee -a /etc/profile
Run - kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml
kubectset env daemonset/calico-node -n kube-system IP_AUTODETECTION_METHOD=interface=enX0
kubectl get nodes
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
swapoff -a
sed -i '/swap/d' /etc/fstab
modprobe overlay
modprobe br_netfilter
cat <<EOF | tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF
sysctl --system
yum install -y containerd
mkdir -p /etc/containerd
containerd config default | tee /etc/containerd/config.toml
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
systemctl enable --now containerd
+++++++++++++++++++++++++++++++++++++
cat <<EOF | tee /etc/crictl.yaml
runtime-endpoint: unix:///run/containerd/containerd.sock
image-endpoint: unix:///run/containerd/containerd.sock
timeout: 10
debug: false
EOF
+++++++++++++++++++++++++++++
cat <<EOF | tee /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://pkgs.k8s.io/core:/stable:/v1.29/rpm/
enabled=1
gpgcheck=1
gpgkey=https://pkgs.k8s.io/core:/stable:/v1.29/rpm/repodata/repomd.xml.key
EOF
++++++++++++++++++++++++++++
yum install -y kubelet kubeadm kubectl
systemctl enable --now kubelet
+++++++++++++++++++
Master Node - token valid for 24 hours only
kubeadm token create --print-join-command
kubeadm join 172.31.34.81:6443 --token 4nqtes.okcey4rlzpnjixd5 --discovery-token-ca-cert-hash sha256:c5923ebed4b51492bc6b9131b8c6167e45ed591dd48b3fb934462539248715d1
++++++++++++++++++++++++
On Worker node, output of above command
kubeadm join 172.31.44.157:6443 --token 4nqtes.okcey4rlzpnjixd5 --discovery-token-ca-cert-hash sha256:c5923ebed4b51492bc6b9131b8c6167e45ed591dd48b3fb934462539248715d1
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
