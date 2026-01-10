#!/bin/bash
set -e

if [ ! -d "rke2-homelab-ansible/roles/test-apps" ]; then
    echo "ERROR: rke2-homelab-ansible/roles/test-apps directory not found!"
    echo "Please run the main setup script first."
    exit 1
fi

cd rke2-homelab-ansible/roles/test-apps

echo "Creating Test Apps role files..."

# defaults/main.yml
cat > defaults/main.yml << 'EOF'
---
# Test applications defaults

test_apps_namespace: test-apps

# Test app 1 - Simple nginx
nginx_simple_name: nginx-test
nginx_simple_host: "nginx.{{ ingress_domain }}"

# Test app 2 - Nginx with PVC
nginx_pvc_name: nginx-pvc-test
nginx_pvc_host: "nginx-pvc.{{ ingress_domain }}"
nginx_pvc_storage_size: 1Gi
EOF

# tasks/main.yml
cat > tasks/main.yml << 'EOF'
---
- name: Create test apps namespace
  kubernetes.core.k8s:
    name: "{{ test_apps_namespace }}"
    api_version: v1
    kind: Namespace
    state: present
  environment:
    KUBECONFIG: "{{ kubeconfig_path }}"

- name: Deploy simple nginx test app
  kubernetes.core.k8s:
    state: present
    definition: "{{ lookup('template', 'nginx-simple.yaml.j2') | from_yaml_all }}"
  environment:
    KUBECONFIG: "{{ kubeconfig_path }}"

- name: Deploy nginx with PVC test app
  kubernetes.core.k8s:
    state: present
    definition: "{{ lookup('template', 'nginx-pvc.yaml.j2') | from_yaml_all }}"
  environment:
    KUBECONFIG: "{{ kubeconfig_path }}"

- name: Wait for test apps to be ready
  ansible.builtin.command: >
    kubectl wait --for=condition=ready pod
    -l app={{ item }}
    -n {{ test_apps_namespace }}
    --timeout=300s
  loop:
    - "{{ nginx_simple_name }}"
    - "{{ nginx_pvc_name }}"
  environment:
    KUBECONFIG: "{{ kubeconfig_path }}"
  changed_when: false

- name: Get test app pods
  ansible.builtin.command: kubectl get pods -n {{ test_apps_namespace }}
  environment:
    KUBECONFIG: "{{ kubeconfig_path }}"
  register: test_pods
  changed_when: false

- name: Display test app status
  ansible.builtin.debug:
    msg: "{{ test_pods.stdout_lines }}"

- name: Get test app ingresses
  ansible.builtin.command: kubectl get ingress -n {{ test_apps_namespace }}
  environment:
    KUBECONFIG: "{{ kubeconfig_path }}"
  register: test_ingresses
  changed_when: false

- name: Display test app ingresses
  ansible.builtin.debug:
    msg: "{{ test_ingresses.stdout_lines }}"
EOF

# templates/nginx-simple.yaml.j2
cat > templates/nginx-simple.yaml.j2 << 'EOF'
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ nginx_simple_name }}
  namespace: {{ test_apps_namespace }}
  labels:
    app: {{ nginx_simple_name }}
spec:
  replicas: 2
  selector:
    matchLabels:
      app: {{ nginx_simple_name }}
  template:
    metadata:
      labels:
        app: {{ nginx_simple_name }}
    spec:
      containers:
        - name: nginx
          image: nginx:alpine
          ports:
            - containerPort: 80
          resources:
            requests:
              memory: "64Mi"
              cpu: "50m"
            limits:
              memory: "128Mi"
              cpu: "100m"
---
apiVersion: v1
kind: Service
metadata:
  name: {{ nginx_simple_name }}
  namespace: {{ test_apps_namespace }}
spec:
  selector:
    app: {{ nginx_simple_name }}
  ports:
    - protocol: TCP
      port: 80
      targetPort: 80
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: {{ nginx_simple_name }}
  namespace: {{ test_apps_namespace }}
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
spec:
  ingressClassName: traefik
  tls:
    - hosts:
        - {{ nginx_simple_host }}
      secretName: {{ nginx_simple_name }}-tls
  rules:
    - host: {{ nginx_simple_host }}
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: {{ nginx_simple_name }}
                port:
                  number: 80
EOF

# templates/nginx-pvc.yaml.j2
cat > templates/nginx-pvc.yaml.j2 << 'EOF'
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: {{ nginx_pvc_name }}-data
  namespace: {{ test_apps_namespace }}
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: longhorn
  resources:
    requests:
      storage: {{ nginx_pvc_storage_size }}
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ nginx_pvc_name }}
  namespace: {{ test_apps_namespace }}
  labels:
    app: {{ nginx_pvc_name }}
spec:
  replicas: 1
  selector:
    matchLabels:
      app: {{ nginx_pvc_name }}
  template:
    metadata:
      labels:
        app: {{ nginx_pvc_name }}
    spec:
      containers:
        - name: nginx
          image: nginx:alpine
          ports:
            - containerPort: 80
          volumeMounts:
            - name: data
              mountPath: /usr/share/nginx/html
          resources:
            requests:
              memory: "64Mi"
              cpu: "50m"
            limits:
              memory: "128Mi"
              cpu: "100m"
      volumes:
        - name: data
          persistentVolumeClaim:
            claimName: {{ nginx_pvc_name }}-data
      initContainers:
        - name: setup
          image: busybox
          command:
            - sh
            - -c
            - |
              echo "<html><body><h1>Nginx with Longhorn Storage</h1><p>This page is served from a Longhorn persistent volume!</p><p>Hostname: $(hostname)</p></body></html>" > /data/index.html
          volumeMounts:
            - name: data
              mountPath: /data
---
apiVersion: v1
kind: Service
metadata:
  name: {{ nginx_pvc_name }}
  namespace: {{ test_apps_namespace }}
spec:
  selector:
    app: {{ nginx_pvc_name }}
  ports:
    - protocol: TCP
      port: 80
      targetPort: 80
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: {{ nginx_pvc_name }}
  namespace: {{ test_apps_namespace }}
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
spec:
  ingressClassName: traefik
  tls:
    - hosts:
        - {{ nginx_pvc_host }}
      secretName: {{ nginx_pvc_name }}-tls
  rules:
    - host: {{ nginx_pvc_host }}
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: {{ nginx_pvc_name }}
                port:
                  number: 80
EOF

echo "✓ Test Apps role created successfully!"