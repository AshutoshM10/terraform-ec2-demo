# terraform-ec2-demo

A minimal Terraform project that launches a single Amazon EC2 instance. Use it to learn the core Terraform workflow end to end.

## Fundamentals

| Concept | What it means | Where it is here |
|---|---|---|
| **Infrastructure as Code (IaC)** | Infrastructure is described in text files, versioned in Git, and created by a tool instead of by clicking in a console. | the whole repo |
| **Provider** | A plugin that talks to one platform's API (AWS, Azure, GCP, Kubernetes...). | `provider "aws"` in `main.tf` |
| **Resource** | One piece of infrastructure Terraform creates and manages. | `aws_instance.demo` |
| **Data source** | Reads existing information without creating anything. | `aws_ssm_parameter.al2023` (latest Amazon Linux AMI) |
| **Variable** | An input you can change without editing the code. | `variables.tf` |
| **Output** | A value printed after apply, for people or other tooling. | `outputs.tf` |
| **State** | Terraform's record of what it created. It maps your code to real resources. Stored remotely in S3 so your laptop and CI see the same state; it can contain sensitive values, so it is never committed. | `backend "s3"` in `main.tf` |
| **Backend** | Where state lives and how it is locked so two runs cannot apply at once. | S3 with `use_lockfile = true` |
| **Lock file** | `.terraform.lock.hcl` pins exact provider versions so every run uses the same plugin. Commit it. | repo root |

### The workflow

```
terraform init      # download the AWS provider, set up the working directory
terraform plan      # preview: what will be created, changed, destroyed
terraform apply     # make the changes (asks for confirmation)
terraform destroy   # delete everything this project created
```

Terraform is **declarative**: you describe the end state ("one t3.micro instance tagged X") and Terraform works out the API calls needed to get there. Running `apply` twice does not create two instances.

## Prerequisites

1. **An AWS account** with permission to create EC2 instances (e.g. `AmazonEC2FullAccess` for a sandbox) and read SSM public parameters.
2. **Terraform >= 1.10** (needed for native S3 state locking): [install guide](https://developer.hashicorp.com/terraform/install). Check with `terraform version`.
3. **AWS CLI v2**: [install guide](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html). Check with `aws --version`.
4. **Configured AWS credentials**, using one of:
   - `aws configure sso` then `export AWS_PROFILE=<profile>` (recommended)
   - `aws configure` (access key; fine for a personal sandbox)

   Verify with `aws sts get-caller-identity`.
5. **A default VPC** in the target region. New AWS accounts have one. The instance launches there.

Never put access keys in `.tf` files. The provider reads credentials from your environment.

## Usage

```bash
git clone https://github.com/AshutoshM10/terraform-ec2-demo.git
cd terraform-ec2-demo

terraform init -backend-config="bucket=<your-state-bucket>" -backend-config="region=us-east-1"
terraform plan
terraform apply
```

The state bucket comes from the one-time bootstrap below.

Override defaults with `-var`:

```bash
terraform apply -var="region=ap-south-1" -var="instance_type=t3.small"
```

When finished, **destroy it** so you are not billed:

```bash
terraform destroy
```

## CI/CD with GitHub Actions

`.github/workflows/terraform.yml` runs on every change to `*.tf`, the lock file, or the workflow itself:

| Event | What runs |
|---|---|
| Pull request to `main` | `fmt -check` → `init` → `validate` → `plan` |
| Push/merge to `main` | same, then `apply` |
| Manual (`workflow_dispatch`) | same as push when run on `main` |

GitHub authenticates to AWS with **OIDC**: the job gets a short-lived token and assumes an IAM role. No AWS keys are stored in GitHub. The role trusts only this repo's `main` branch and its PRs.

### One-time setup

1. Create the state bucket and IAM role (bucket names are globally unique, so pick your own):
   ```bash
   cd bootstrap
   terraform init
   terraform apply -var="state_bucket_name=<unique-name>"
   ```
2. Give the workflow the outputs as repository variables (not secrets; none of these are sensitive):
   ```bash
   gh variable set AWS_ROLE_ARN    --body "$(terraform output -raw role_arn)"
   gh variable set TF_STATE_BUCKET --body "$(terraform output -raw state_bucket)"
   gh variable set AWS_REGION      --body "us-east-1"
   ```
3. Push a change to a `.tf` file on `main` and watch the **Actions** tab.

The bootstrap keeps its own state locally in `bootstrap/terraform.tfstate` (git-ignored). Keep that file: it is how you later destroy the bucket and role.

### Teardown

1. Destroy the instance: run `terraform destroy` locally (with the same `-backend-config`), or delete `aws_instance.demo` from `main.tf` and push.
2. Empty the state bucket (it is versioned, so remove all versions), then run `terraform destroy -var="state_bucket_name=<unique-name>"` in `bootstrap/`.

## Inputs

| Name | Default | Description |
|---|---|---|
| `region` | `us-east-1` | AWS region |
| `instance_type` | `t3.micro` | Instance size (free-tier eligible in most regions) |
| `name` | `terraform-ec2-demo` | `Name` tag |

## Outputs

| Name | Description |
|---|---|
| `instance_id` | EC2 instance ID |
| `public_ip` | Public IP (if the subnet assigns one) |

## Security defaults

- IMDSv2 is required (`http_tokens = "required"`).
- The root volume is encrypted.
- No SSH key or open security group is created. To connect, attach an IAM role with `AmazonSSMManagedInstanceCore` and use AWS Systems Manager Session Manager instead of opening port 22.

## Cost

A `t3.micro` running 24/7 costs roughly US$7–8/month outside the free tier. Run `terraform destroy` when done.
