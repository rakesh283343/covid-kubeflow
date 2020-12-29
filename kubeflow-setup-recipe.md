

### Install `microk8s`

```bash
sudo snap install microk8s --clasic
microk8s enable gpu
export KUBEFLOW_BUNDLER=lite
export KUBEFLOW_HOSTNAME=<your-machine-lan-name-or-ip>:<some-port-like-8080>
```

See [here]() but in short you need to 

```bash
microk8s.kubectl edit configmap -n kube-system coredns
```

and replace `forward . 8.8.8.8 8.8.4.4` to say `forward . 192.168.1.1` where `192.168.1.1` is your router's IP (more specifically your LAN DNS).

Then 

```bash
microk8s enable kubeflow
microk8s.kubectl port-forward -n kubeflow service/istio-ingressgateway <port you chose on line 9 of this doc>:80 --address 0.0.0.0
microk8s juju config dex-auth static-username=something@whatever.foo # for me had to be an email address, but maybe not totally neccessary
microk8s juju config dex-auth static-password=1qaz2wsx  #whatever you want
```

