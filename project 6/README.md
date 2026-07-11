# Jenkins Multibranch Declarative CI/CD Pipeline

This repository implements a **Containerized Multibranch CI/CD Pipeline** using Jenkins, Docker, and Python. It automates testing, packaging, and delivery processes, showcasing modern container-native automation best practices.

---

## 🏗️ Architecture Workflow

Every push to your Git repository triggers a dynamic Jenkins pipeline.

```
[ Git Commit/Push ] ➔ [ Jenkins Agent ] ➔ [ Build Test Container ] ➔ [ Run Unit Tests ] ➔ [ Build Production Image ] ➔ [ Push to Docker Hub (main branch only) ]
```

---

## 🌟 Key DevOps Highlights

*   **Multibranch Pipeline Automation:** Jenkins automatically scans your repository, detects new branches (e.g. `feature/login`), and builds them using the branch-specific code and `Jenkinsfile`.
*   **Docker-in-Docker Socket Sharing:** By mounting the host's `/var/run/docker.sock` inside the Jenkins container, Jenkins can control your host's Docker engine to run container actions, avoiding the overhead of nesting VM virtualizations.
*   **Container-Native Testing:** Jenkins builds a temporary container and runs unit tests inside it. This **keeps your Jenkins controller clean** (no need to install Python, Flask, or libraries on the build server itself).
*   **Conditional Registry Pushing:** Implements strict release governance: tests are run on all branch pushes, but the final Docker image is built, tagged with the short Git commit hash, and pushed to Docker Hub **only when code is merged to the `main` branch**.
*   **Decoupled Secret Management:** Leverages Jenkins credentials store (`withCredentials`) to inject Docker Hub credentials at runtime, ensuring keys are never exposed in the source code or build logs.

---

## 🚀 How to Run and Test Locally

### 1. Spin up Jenkins Server
Start the containerized Jenkins controller using Docker Compose:
```bash
docker compose up -d
```
Verify the container is running:
```bash
docker ps
```
*Note: Jenkins will store its configurations inside a local folder named `./jenkins_home` so your work is saved between restarts.*

### 2. Retrieve Initial Admin Password
Open your browser and navigate to `http://localhost:8080`. To unlock Jenkins, retrieve the admin password by running:
```bash
docker exec jenkins-ci-server cat /var/jenkins_home/secrets/initialAdminPassword
```
Copy the 32-character key, paste it into the Jenkins setup screen, and install the **Suggested Plugins**.

### 3. Add Docker Hub Credentials
1.  Navigate to **Manage Jenkins** -> **Credentials** -> **System** -> **Global credentials (unrestricted)**.
2.  Click **Add Credentials**.
3.  Set the following:
    *   **Kind:** Username with password
    *   **Scope:** Global
    *   **Username:** *Your Docker Hub username*
    *   **Password:** *Your Docker Hub password or Personal Access Token*
    *   **ID:** `docker-hub-credentials` *(Must match the ID in the Jenkinsfile)*
4.  Click **Create**.

### 4. Create the Multibranch Pipeline
1.  On the Jenkins dashboard, click **New Item**.
2.  Enter name: `flask-app-pipeline` and select **Multibranch Pipeline**. Click **OK**.
3.  Under **Branch Sources**, click **Add source** -> **Git**.
4.  Set **Project Repository** to your GitHub repository URL:
    `https://github.com/rj1825/DEVops-Practice-2.git`
5.  Click **Save**.

Jenkins will immediately scan your repository, discover all branches containing a `Jenkinsfile`, and automatically trigger a build for each branch!

---

## 🧹 Teardown
To stop the Jenkins server:
```bash
docker compose down
```
To delete all stored Jenkins data (warning: resets configurations):
```bash
docker compose down -v
rm -rf ./jenkins_home
```
