# Setup guide

This guide takes you from nothing to a running platform. It takes about two hours, most of it
waiting while the servers install their software. The commands use Windows PowerShell.

Nothing in this project is open to the internet. You reach Jenkins, Grafana, Prometheus and the
website through AWS Systems Manager (Session Manager) tunnels, so your IP address does not matter
and no SSH key is stored on your laptop.

## 0. Before you start

1. **AWS account.** Turn on MFA for the root user. In IAM create a user `terraform-admin`
   with the `AdministratorAccess` policy (and no permissions boundary), then create an access
   key for the command line. Keep the keys private.
2. **Budget alert.** Billing and Cost Management, Budgets, create a monthly cost budget of a few
   dollars with an email alert.
3. **Tools:**
   ```powershell
   winget install Hashicorp.Terraform
   winget install Amazon.AWSCLI
   winget install Git.Git
   winget install Amazon.SessionManagerPlugin
   ```
   Open a new PowerShell window and check that `terraform -version`, `aws --version`,
   `git --version` and `session-manager-plugin` all work.
4. **Connect the AWS CLI:**
   ```powershell
   aws configure
   aws sts get-caller-identity
   ```
   Use region `ap-south-1` and output format `json`. The second command should print your account.

## 1. Put the project on GitHub

The CI server clones the repository on first boot, so it must be **public** and pushed before
you run Terraform.

```powershell
cd shipyard
git init
git add .
git status
git commit -m "Initial commit"
git branch -M main
git remote add origin https://github.com/<your-username>/shipyard.git
git push -u origin main
```

Check `git status` first: no `.tfstate` or `terraform.tfvars` file should be listed.

## 2. Configure Terraform

```powershell
cd terraform
copy terraform.tfvars.example terraform.tfvars
notepad terraform.tfvars
```

Set `repo_url` to your repository URL and save. Edit the file in Notepad, not with commands.

The defaults are `t3.small` (CI server) and `c7i-flex.large` (Kubernetes node). If your account
does not offer one of them, set another type in the same file. The Kubernetes node needs at
least 4 GB of RAM, and `m7i-flex.large` (8 GB) works.

## 3. Create the platform

```powershell
terraform init
terraform plan
```

The plan ends with `Plan: 22 to add, 0 to change, 0 to destroy.` Then:

```powershell
terraform apply
```

Type `yes`. **Charges start here.** Terraform prints ready-made commands for the shells and
tunnels used below.

## 4. Wait for the automatic setup (about 15 minutes)

The CI server installs Jenkins, then runs Ansible, which installs Kubernetes, Prometheus and
Grafana on the other server. Open a shell on the CI server:

```powershell
terraform output -raw shell_ci_server
```

Copy the printed command and run it. If it says `TargetNotConnected`, the server is still booting,
so wait three minutes and try again. In the shell, run these one at a time:

```bash
tail -n 3 /var/log/user-data.log           # ends with "First boot finished"
tail -f /var/log/ansible-bootstrap.log     # ends with "Ansible finished"
```

Press `Ctrl + C` to stop following the second log. If Ansible failed, fix the cause and run
`bash /opt/platform/scripts/run-ansible.sh` again. It is safe to repeat.

## 5. Unlock Jenkins

In the CI server shell:

```bash
sudo cat /var/lib/jenkins/secrets/initialAdminPassword
```

Then, in a **new** PowerShell window in the `terraform` folder, start the Jenkins tunnel and leave
it running:

```powershell
terraform output -raw open_jenkins
```

Run the printed command, open http://localhost:8080, paste the password, choose **Install
suggested plugins** and create your admin user.

## 6. Create the pipeline job

1. **New Item**, name `shipyard`, type **Pipeline**
2. In the Pipeline section choose **Pipeline script from SCM**, SCM **Git**
3. Repository URL: your GitHub repository, Branch Specifier `*/main`, Script Path `Jenkinsfile`
4. **Save**, then **Build Now**

The first build takes longer because Trivy downloads its vulnerability database. When all stages
are green, later pushes start builds by themselves (Jenkins polls GitHub about every two minutes).

## 7. Open the website, Grafana and Prometheus

Each one needs its own PowerShell window in the `terraform` folder. Run the printed command and
leave it open while you use the page.

| Command | Then open |
|---|---|
| `terraform output -raw open_website` | http://localhost:8081 |
| `terraform output -raw open_grafana` | http://localhost:3000 |
| `terraform output -raw open_prometheus` | http://localhost:9090 |

Grafana: user `admin`, password from `terraform output -raw grafana_admin_password`. The
dashboard is **Shipyard overview** in the Shipyard folder. In Prometheus check **Status, Targets**
(everything `UP`) and **Alerts**.

## 8. Try the demos

The Kubernetes commands run in a shell on the node:

```powershell
terraform output -raw shell_k8s_node
```

**Ship a change.** Edit the headline in `public/index.html`, commit and push. A build starts within
about two minutes. Refresh the website to see the new headline and build number.

**Autoscaling.** Click **Start load** on the website, then in the node shell run:

```bash
sudo k3s kubectl -n shipyard get hpa -w
sudo k3s kubectl -n shipyard get pods
```

Watch the replicas grow from 2 towards 5 here, on the website and in Grafana.

**Rollback.** Add `process.exit(1);` as the first line of `src/server.js`, commit and push. The
build passes lint, tests and the scan, but the new pods crash. Jenkins rolls back and the site
stays up. Remove the line and push again.

**Alert.** In the node shell:

```bash
sudo k3s kubectl -n shipyard delete hpa shipyard
sudo k3s kubectl -n shipyard scale deployment shipyard --replicas=0
```

After about a minute the `ShipyardDown` alert fires in Prometheus. Run the pipeline again to
restore the app and the autoscaler.

Other useful commands:

```bash
sudo k3s kubectl -n shipyard rollout history deployment/shipyard
sudo k3s kubectl -n shipyard logs deployment/shipyard
sudo k3s kubectl -n monitoring get pods
```

## 9. Screenshots

Save these in `docs/screenshots/` with exactly these names. The README shows them.

| File name | What to capture |
|---|---|
| `01-jenkins-pipeline.png` | Jenkins stage view of a green build with every stage passed |
| `02-jenkins-rollback.png` | Jenkins stage view of the failed build after the rollback demo |
| `03-website-scaling.png` | The website during load, with several pods in the grid |
| `04-grafana-dashboard.png` | The Shipyard overview dashboard while pods scale |
| `05-hpa-scaling.png` | Terminal showing `get hpa -w` and `get pods` with replicas growing |
| `06-prometheus-alert.png` | Prometheus Alerts page with `ShipyardDown` firing |

Hide account IDs and passwords before you commit the images.

## 10. Clean up

Close the tunnel windows, then:

```powershell
terraform destroy
```

Type `yes`. This deletes both servers, their disks, the registry, roles and security groups.
Check the EC2 and ECR consoles for leftovers and look at the Billing page the next day.

## Common problems

| Problem | Fix |
|---|---|
| `AccessDenied` from Terraform | The IAM user needs the `AdministratorAccess` policy and no permissions boundary |
| `SessionManagerPlugin is not found` | Install it (step 0) and open a new PowerShell window |
| `TargetNotConnected` | The server is still booting. Wait three minutes |
| Tunnel starts but the page does not open | Check that the tunnel window is still open and the server finished its setup (step 4) |
| Pipeline fails at "Prepare" with "Cannot reach the cluster" | Ansible is not finished. Wait for it, then **Build Now** |
| Repository is private | The CI server cannot clone it. Make it public |
| Platform left running after the demo | Run `terraform destroy` |
