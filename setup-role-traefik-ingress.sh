#!/bin/bash
set -e

if [ ! -d "rke2-homelab-ansible/roles/traefik-ingress" ]; then
    echo "ERROR: rke2-homelab-ansible/roles/traefik-ingress directory not found!"
    echo "Please run the main setup script first."
    exit 1
fi

cd rke2-homelab-ansible/roles/traefik-ingress

echo "Creating Traefik Ingress role files..."

# defaults/main.yml
cat > defaults/main.yml << 'EOF'
---
# Traefik Ingress Controller defaults

traefik_version: "26.1.0"
traefik_namespace: traefik

# Service configuration
traefik_service_type: NodePort

# DNS-01 challenge configuration
traefik_dns_provider: cloudflare
traefik_cloudflare_dns_api_token: "{{ cloudflare_api_token }}"

# Let's Encrypt
traefik_acme_email: "{{ acme_email }}"
traefik_acme_server: "{{ acme_server }}"
EOF

# tasks/main.yml
cat > tasks/main.yml << 'EOF'
---
- name: Create Traefik namespace
  kubernetes.core.k8s:
    name: "{{ traefik_namespace }}"
    api_version: v1
    kind: Namespace
    state: present
  environment:
    KUBECONFIG: "{{ kubeconfig_path }}"

- name: Install cert-manager CRDs
  ansible.builtin.command: >
    kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.14.2/cert-manager.crds.yaml
  environment:
    KUBECONFIG: "{{ kubeconfig_path }}"
  changed_when: false

- name: Add cert-manager Helm repository
  kubernetes.core.helm_repository:
    name: jetstack
    repo_url: https://charts.jetstack.io
  environment:
    KUBECONFIG: "{{ kubeconfig_path }}"

- name: Deploy cert-manager
  kubernetes.core.helm:
    name: cert-manager
    chart_ref: jetstack/cert-manager
    chart_version: "v1.14.2"
    release_namespace: cert-manager
    create_namespace: true
  environment:
    KUBECONFIG: "{{ kubeconfig_path }}"

- name: Wait for cert-manager to be ready
  ansible.builtin.command: >
    kubectl wait --for=condition=ready pod
    -l app=cert-manager
    -n cert-manager
    --timeout=300s
  environment:
    KUBECONFIG: "{{ kubeconfig_path }}"
  changed_when: false

- name: Create Cloudflare API token secret
  kubernetes.core.k8s:
    state: present
    definition:
      apiVersion: v1
      kind: Secret
      metadata:
        name: cloudflare-api-token
        namespace: "{{ traefik_namespace }}"
      type: Opaque
      stringData:
        dns-token: "{{ traefik_cloudflare_dns_api_token }}"
  environment:
    KUBECONFIG: "{{ kubeconfig_path }}"

- name: Add Traefik Helm repository
  kubernetes.core.helm_repository:
    name: traefik
    repo_url: https://traefik.github.io/charts
  environment:
    KUBECONFIG: "{{ kubeconfig_path }}"

- name: Deploy Traefik ingress controller
  kubernetes.core.helm:
    name: traefik
    chart_ref: traefik/traefik
    chart_version: "{{ traefik_version }}"
    release_namespace: "{{ traefik_namespace }}"
    create_namespace: false
    values:
      service:
        type: "{{ traefik_service_type }}"
        nodePorts:
          http: "{{ ingress_http_nodeport }}"
          https: "{{ ingress_https_nodeport }}"
      ports:
        web:
          port: 8000
          expose: true
          exposedPort: 80
          nodePort: "{{ ingress_http_nodeport }}"
        websecure:
          port: 8443
          expose: true
          exposedPort: 443
          nodePort: "{{ ingress_https_nodeport }}"
          tls:
            enabled: true
      ingressClass:
        enabled: true
        isDefaultClass: true
      providers:
        kubernetesCRD:
          enabled: true
          allowCrossNamespace: true
        kubernetesIngress:
          enabled: true
          publishedService:
            enabled: true
      additionalArguments:
        - "--certificatesresolvers.letsencrypt.acme.dnschallenge=true"
        - "--certificatesresolvers.letsencrypt.acme.dnschallenge.provider={{ traefik_dns_provider }}"
        - "--certificatesresolvers.letsencrypt.acme.email={{ traefik_acme_email }}"
        - "--certificatesresolvers.letsencrypt.acme.storage=/data/acme.json"
        - "--certificatesresolvers.letsencrypt.acme.caserver={{ traefik_acme_server }}"
      env:
        - name: CF_DNS_API_TOKEN
          valueFrom:
            secretKeyRef:
              name: cloudflare-api-token
              key: dns-token
      persistence:
        enabled: true
        size: 1Gi
  environment:
    KUBECONFIG: "{{ kubeconfig_path }}"

- name: Wait for Traefik to be ready
  ansible.builtin.command: >
    kubectl wait --for=condition=ready pod
    -l app.kubernetes.io/name=traefik
    -n {{ traefik_namespace }}
    --timeout=300s
  environment:
    KUBECONFIG: "{{ kubeconfig_path }}"
  changed_when: false

- name: Deploy cert-manager ClusterIssuer
  kubernetes.core.k8s:
    state: present
    definition: "{{ lookup('template', 'cluster-issuer.yaml.j2') | from_yaml }}"
  environment:
    KUBECONFIG: "{{ kubeconfig_path }}"

- name: Get Traefik service details
  ansible.builtin.command: kubectl get svc -n {{ traefik_namespace }} traefik
  environment:
    KUBECONFIG: "{{ kubeconfig_path }}"
  register: traefik_svc
  changed_when: false

- name: Display Traefik service
  ansible.builtin.debug:
    msg: "{{ traefik_svc.stdout_lines }}"
EOF

# templates/cluster-issuer.yaml.j2
cat > templates/cluster-issuer.yaml.j2 << 'EOF'
apiVersion: v1
kind: Secret
metadata:
  name: cloudflare-api-token-secret
  namespace: {{ traefik_namespace }}
type: Opaque
stringData:
  api-token: {{ traefik_cloudflare_dns_api_token }}
---
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: {{ traefik_acme_server }}
    email: {{ traefik_acme_email }}
    privateKeySecretRef:
      name: letsencrypt-prod-account-key
    solvers:
      - dns01:
          cloudflare:
            apiTokenSecretRef:
              name: cloudflare-api-token-secret
              key: api-token
EOF

echo "✓ Traefik Ingress role created successfully!"