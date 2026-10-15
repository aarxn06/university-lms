// Windows PowerShell pipeline. Run Jenkins under the Windows account that
// can execute `docker` and `kubectl` against Docker Desktop.
pipeline {
    agent any
    options {
        timestamps()
        disableConcurrentBuilds()
    }
    environment {
    IMAGE_REPO = 'aarxn06/university-lms'
    DEPLOYMENT_NAME = 'university-lms'
    K8S_NAMESPACE = 'default'
    PATH = "C:\\Users\\Aaron Patric Johnson\\AppData\\Local\\Programs\\DockerDesktop\\resources\\bin;${env.PATH}"
}
    stages {
        stage('Clone Code') {
            steps { checkout scm }
        }
        stage('Validate Application') {
            steps {
                powershell '''
                  $ErrorActionPreference = 'Stop'
                  $content = Get-Content -Raw index.html
                  foreach ($word in @('Courses','Faculty','Resources','Assignments','Examination')) {
                    if (-not $content.Contains($word)) { throw "Missing required content: $word" }
                  }
                  if (-not (Test-Path healthz)) { throw 'Missing healthz file' }
                '''
            }
        }
        stage('Build Docker Image') {
            steps {
                powershell '''
                  $image = '{0}:{1}' -f $env:IMAGE_REPO, $env:BUILD_NUMBER
                  docker build -t $image .
                  if ($LASTEXITCODE -ne 0) { throw 'docker build failed' }
                '''
            }
        }
        stage('Smoke Test Image') {
            steps {
                powershell '''
                  $ErrorActionPreference = 'Stop'
                  $image = '{0}:{1}' -f $env:IMAGE_REPO, $env:BUILD_NUMBER
                  $container = 'university-lms-ci-' + $env:BUILD_NUMBER
                  docker run -d --name $container -p 127.0.0.1:18080:80 $image
                  if ($LASTEXITCODE -ne 0) { throw 'docker run failed' }
                  try {
                    $healthy = $false
                    for ($i=0; $i -lt 12; $i++) {
                      try {
                        $page = Invoke-WebRequest -Uri 'http://127.0.0.1:18080/' -UseBasicParsing -TimeoutSec 3
                        $health = Invoke-WebRequest -Uri 'http://127.0.0.1:18080/healthz' -UseBasicParsing -TimeoutSec 3
                        if ($page.StatusCode -eq 200 -and $page.Content.Contains('CampusLearn') -and $health.StatusCode -eq 200) {
                          $healthy = $true
                          break
                        }
                      } catch { Start-Sleep -Seconds 1 }
                    }
                    if (-not $healthy) { throw 'Container smoke test failed' }
                  } finally {
                    docker rm -f $container | Out-Null
                  }
                '''
            }
        }
        stage('Push Image to Docker Hub') {
            steps {
                withCredentials([usernamePassword(credentialsId: 'dockerhub-lms-q1', usernameVariable: 'DH_USER', passwordVariable: 'DH_TOKEN')]) {
                    powershell '''
                      if ($env:DH_USER -ne 'aarxn06') { throw 'Jenkins Docker Hub username is incorrect; edit credential dockerhub-lms-q1' }
                      $token = $env:DH_TOKEN.Trim()
                      if ([string]::IsNullOrWhiteSpace($token)) { throw 'Jenkins credential token is empty' }
                      Write-Host ('Jenkins supplied Docker Hub token with ' + $token.Length + ' characters (token not displayed)')
                      $psi = New-Object System.Diagnostics.ProcessStartInfo
                      $psi.FileName = (Get-Command docker.exe).Source
                      $psi.Arguments = 'login --username aarxn06 --password-stdin'
                      $psi.UseShellExecute = $false
                      $psi.RedirectStandardInput = $true
                      $psi.RedirectStandardOutput = $true
                      $psi.RedirectStandardError = $true
                      $proc = [System.Diagnostics.Process]::Start($psi)
                      $proc.StandardInput.WriteLine($token)
                      $proc.StandardInput.Close()
                      $stdout = $proc.StandardOutput.ReadToEnd()
                      $stderr = $proc.StandardError.ReadToEnd()
                      $proc.WaitForExit()
                      if ($stdout) { Write-Host $stdout }
                      if ($proc.ExitCode -ne 0) { throw ('Docker Hub login failed: ' + $stderr) }
                      $image = '{0}:{1}' -f $env:IMAGE_REPO, $env:BUILD_NUMBER
                      docker push $image
                      if ($LASTEXITCODE -ne 0) { throw 'Docker Hub push failed' }
                    '''
                }
            }
        }
        stage('Deploy & Health Check') {
            steps {
                withCredentials([file(credentialsId: 'kubeconfig-lms-q1', variable: 'KUBECONFIG')]) {
                    powershell '''
                      $ErrorActionPreference = 'Stop'
                      $image = '{0}:{1}' -f $env:IMAGE_REPO, $env:BUILD_NUMBER
                      kubectl --context docker-desktop --namespace $env:K8S_NAMESPACE get nodes
                      if ($LASTEXITCODE -ne 0) { throw 'Kubernetes access failed' }
                      $manifest = (Get-Content -Raw deployment.yaml).Replace('IMAGE_PLACEHOLDER', $image)
                      $manifest | kubectl --context docker-desktop --namespace $env:K8S_NAMESPACE apply -f -
                      if ($LASTEXITCODE -ne 0) { throw 'Deployment apply failed' }
                      kubectl --context docker-desktop --namespace $env:K8S_NAMESPACE apply -f service.yaml
                      if ($LASTEXITCODE -ne 0) { throw 'Service apply failed' }
                      kubectl --context docker-desktop --namespace $env:K8S_NAMESPACE rollout status deployment/$env:DEPLOYMENT_NAME --timeout=110s
                      if ($LASTEXITCODE -ne 0) {
                        Write-Host 'Unhealthy rollout detected. Rolling back to previous Kubernetes revision...'
                        kubectl --context docker-desktop --namespace $env:K8S_NAMESPACE rollout undo deployment/$env:DEPLOYMENT_NAME
                        if ($LASTEXITCODE -ne 0) { throw 'Failed to start rollback' }
                        kubectl --context docker-desktop --namespace $env:K8S_NAMESPACE rollout status deployment/$env:DEPLOYMENT_NAME --timeout=110s
                        if ($LASTEXITCODE -ne 0) { throw 'Rollback did not become healthy' }
                        throw 'New release failed. Previous stable version restored successfully.'
                      }
                      kubectl --context docker-desktop --namespace $env:K8S_NAMESPACE get pods -l app=university-lms
                    '''
                }
            }
        }
    }
}

