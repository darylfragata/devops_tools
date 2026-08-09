# Terraform Commands

## 1. Setup & Initialization

```bash
terraform init
terraform init -upgrade
terraform init -reconfigure
terraform init -backend-config=<file>
terraform init -migrate-state
```

## 2. Formatting & Validation

```bash
terraform fmt
terraform fmt -recursive
terraform validate
```

## 3. Planning

```bash
terraform plan
terraform plan -out=tfplan
terraform plan -var-file=<file>
terraform plan -var="key=value"
terraform plan -target=<resource>
terraform plan -refresh-only
terraform show tfplan
```

## 4. Apply & Destroy

```bash
terraform apply
terraform apply tfplan
terraform apply -var-file=<file>
terraform apply -target=<resource>
terraform apply -refresh-only
terraform destroy
terraform destroy -var-file=<file>
```

## 5. State Management

```bash
terraform state list
terraform state show <resource>
terraform state mv <source> <destination>
terraform state rm <resource>
terraform state pull
terraform state push <file>
```

## 6. Import

```bash
terraform import <address> <id>
```

## 7. Output & Variables

```bash
terraform output
terraform output -json
terraform console
```

## 8. Providers & Dependencies

```bash
terraform providers
terraform version
terraform get
```

## 9. Workspace

```bash
terraform workspace list
terraform workspace show
terraform workspace new <name>
terraform workspace select <name>
terraform workspace delete <name>
```

## 10. Debugging

```bash
terraform show
terraform graph
terraform providers
```

# Common Workflow

```bash
terraform fmt -recursive
terraform init
terraform validate
terraform plan
terraform apply
```
