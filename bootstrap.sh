#!/bin/bash
set -euo pipefail
cd codebase
mkdir -p k8s

# ---------- Backend ----------
cat > backend/Dockerfile <<'EOF'
FROM node:20-alpine
WORKDIR /app
COPY package*.json ./
RUN npm install --omit=dev
COPY . .
EXPOSE 5000
CMD ["node", "index.js"]
EOF

printf 'node_modules\n' > backend/.dockerignore

# ---------- Frontend ----------
cat > frontend/Dockerfile <<'EOF'
FROM nginx:alpine
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY index.html index.js /usr/share/nginx/html/
EXPOSE 80
EOF

cat > frontend/nginx.conf <<'EOF'
server {
    listen 80;
    root /usr/share/nginx/html;
    index index.html;

    location / {
        try_files $uri $uri/ =404;
    }

    # Browser calls /colour on this server; nginx forwards it to the backend Service
    location /colour {
        proxy_pass http://backend:5000;
    }
}
EOF

cat > frontend/index.js <<'EOF'
'use strict'

const header = document.querySelector('h1');

fetch('/colour').then((response) => {
    response.text().then((data) => {
        header.style.color = data;
    })
})
EOF

# ---------- Kubernetes ----------
cat > k8s/backend.yaml <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend
spec:
  replicas: 2
  selector:
    matchLabels:
      app: backend
  template:
    metadata:
      labels:
        app: backend
    spec:
      containers:
        - name: backend
          image: ademoladevops/qaa-backend:IMAGE_TAG
          ports:
            - containerPort: 5000
---
apiVersion: v1
kind: Service
metadata:
  name: backend
spec:
  type: ClusterIP
  selector:
    app: backend
  ports:
    - port: 5000
      targetPort: 5000
EOF

cat > k8s/frontend.yaml <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend
spec:
  replicas: 2
  selector:
    matchLabels:
      app: frontend
  template:
    metadata:
      labels:
        app: frontend
    spec:
      containers:
        - name: frontend
          image: ademoladevops/qaa-frontend:IMAGE_TAG
          ports:
            - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: frontend
spec:
  type: LoadBalancer
  selector:
    app: frontend
  ports:
    - port: 80
      targetPort: 80
EOF

cat > k8s-deploy.sh <<'EOF'
#!/bin/bash
set -euo pipefail
TAG="${1:-latest}"
cd "$(dirname "$0")"

# Backend first: nginx resolves the "backend" Service name at startup
sed "s|IMAGE_TAG|${TAG}|g" k8s/backend.yaml | kubectl apply -f -
kubectl rollout status deployment/backend --timeout=120s

sed "s|IMAGE_TAG|${TAG}|g" k8s/frontend.yaml | kubectl apply -f -
kubectl rollout status deployment/frontend --timeout=120s

kubectl get pods,svc
EOF
chmod +x k8s-deploy.sh

# ---------- Jenkins pipeline ----------
cat > JenkinsFile <<'EOF'
pipeline {
    agent any

    environment {
        BACKEND_IMAGE  = 'ademoladevops/qaa-backend'
        FRONTEND_IMAGE = 'ademoladevops/qaa-frontend'
        TAG            = "${env.BUILD_NUMBER}"
    }

    triggers {
        githubPush()
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Build Images') {
            steps {
                dir('codebase') {
                    sh 'docker build -t $BACKEND_IMAGE:$TAG -t $BACKEND_IMAGE:latest backend'
                    sh 'docker build -t $FRONTEND_IMAGE:$TAG -t $FRONTEND_IMAGE:latest frontend'
                }
            }
        }

        stage('Push to DockerHub') {
            steps {
                withCredentials([usernamePassword(credentialsId: 'dockerhub-creds',
                                                  usernameVariable: 'DH_USER',
                                                  passwordVariable: 'DH_PASS')]) {
                    sh 'echo "$DH_PASS" | docker login -u "$DH_USER" --password-stdin'
                    sh 'docker push $BACKEND_IMAGE:$TAG'
                    sh 'docker push $BACKEND_IMAGE:latest'
                    sh 'docker push $FRONTEND_IMAGE:$TAG'
                    sh 'docker push $FRONTEND_IMAGE:latest'
                }
            }
        }

        stage('Deploy to Kubernetes') {
            steps {
                dir('codebase') {
                    sh './k8s-deploy.sh $TAG'
                }
            }
        }
    }

    post {
        always {
            sh 'docker logout || true'
        }
    }
}
EOF

echo "Done. Files created under codebase/"
