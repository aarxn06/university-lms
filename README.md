# University LMS — DevOps Lab Question 1

Responsive university learning portal with Docker, a two-replica Kubernetes Deployment, NodePort service, health checks and a Windows Jenkins Pipeline with automated rollback.

> Demo data: faculty and dates on the website are illustrative, not official university information.

## First run (Windows PowerShell)

1. Start Docker Desktop (Linux containers).
2. Open this folder in VS Code, and open Terminal > New Terminal (PowerShell).
3. Run `docker build -t university-lms:v1 .`
4. Run `docker run -d --name university-lms-local -p 8081:80 university-lms:v1`
5. Visit http://localhost:8081 and http://localhost:8081/healthz.
6. Run `docker ps` and `docker stop university-lms-local` when finished.

## Version 1 push to Docker Hub

1. Create a public repository named `university-lms` under your Docker Hub username.
2. `docker login`
3. `docker tag university-lms:v1 YOUR_DOCKERHUB_USERNAME/university-lms:v1`
4. `docker push YOUR_DOCKERHUB_USERNAME/university-lms:v1`

## Run Kubernetes manually

1. Enable Docker Desktop's Kubernetes. Ensure context: `kubectl config use-context docker-desktop`.
2. Substitute your image into the deployment without saving credentials or replacing tracked placeholders:
   `(Get-Content -Raw deployment.yaml).Replace('IMAGE_PLACEHOLDER','YOUR_DOCKERHUB_USERNAME/university-lms:v1') | kubectl apply -f -`
3. `kubectl apply -f service.yaml`
4. `kubectl rollout status deployment/university-lms --timeout=110s`
5. `kubectl get pods -l app=university-lms`
6. Visit http://localhost:30080.

## Jenkins pipeline (on Windows)

Run Jenkins as your local Windows user who can access Docker Desktop and `kubectl`; avoid blindly running it as LocalSystem, which might use a different Kubernetes configuration. Use a suitable trusted build agent; this single-machine controller is only for a lab.

1. Create Jenkins credentials named `dockerhub-creds` of type **Username with password** (username is Docker Hub user, password is a Docker Hub personal access token with write permission).
2. Create Jenkins credential named `kubeconfig` of type **Secret file**, uploading your user profile's `.kube/config`. If that kubeconfig relies on externally referenced files, package a self-contained Kubernetes config instead; avoid adding kubeconfig to Git.
3. Set `IMAGE_REPO` in Jenkinsfile to `YOUR_DOCKERHUB_USERNAME/university-lms`.
4. Create a Jenkins **Pipeline** job using **Pipeline script from SCM**, choosing Git and this GitHub repository's HTTPS clone URL, script path `Jenkinsfile`.
5. Run a build; check the stages and open http://localhost:30080.
6. Add GitHub push-trigger integration after the basic pipeline works (requires a webhook-reachable Jenkins endpoint or a GitHub-aware alternative; localhost by itself is not accessible to GitHub webhooks).

### Rollback demo

Only after one healthy release has succeeded, edit `deployment.yaml` to deliberately change `readinessProbe.httpGet.path` from `/healthz` to `/does-not-exist`. Commit/push this as a faulty release. The Docker container can pass the local smoke tests, but the Kubernetes readiness probe fails, causing `kubectl rollout status` to time out. Jenkins automatically executes `kubectl rollout undo` and confirms the previous revision becomes ready. The Jenkins build is marked failed because the attempted release failed, while the previously working site stays available.

Restore `/healthz` in Git after demonstrating the faulty release. Verify using `kubectl rollout history deployment/university-lms`, `kubectl get pods -l app=university-lms`, and http://localhost:30080.

## Screenshots to collect

- index.html in VS Code and webpage in browser
- Docker build result, `docker ps`, and http://localhost:8081
- Docker Hub image with version tag
- GitHub repository showing code and Jenkinsfile
- Kubernetes enabled in Docker Desktop
- `kubectl get deployments`, `kubectl get pods -l app=university-lms`, `kubectl get svc`
- Browser showing http://localhost:30080
- Jenkins successful stage pipeline and updated commit
- Jenkins failed rollout / automatic undo log, healthy pods, and restored site
