# Terraform Expressions & Conditional Logic

> Ternary operator, conditionals, and other HCL expression patterns that come up a lot once you're past basic resource blocks.

## 1. Ternary operator · Beginner

```text
condition ? true_val : false_val
```

```hcl
# Basic
variable "environment" {
  type = string
}

locals {
  instance_type = var.environment == "prod" ? "t3.large" : "t3.micro"
}

# Using a bool variable directly (no need for `== true`)
variable "enable_monitoring" {
  type    = bool
  default = false
}

resource "aws_instance" "this" {
  monitoring = var.enable_monitoring ? true : false # redundant, just: var.enable_monitoring
}

# Nested ternary (readable up to ~2 levels, refactor beyond that)
locals {
  size = var.environment == "prod" ? "large" : var.environment == "staging" ? "medium" : "small"
}
```

## 2. Conditional resource creation · Beginner

```hcl
# count: 1 or 0 to create/skip a resource
resource "aws_instance" "bastion" {
  count = var.create_bastion ? 1 : 0

  ami           = var.ami_id
  instance_type = "t3.micro"
}

# reference a conditionally-created resource
output "bastion_ip" {
  value = var.create_bastion ? aws_instance.bastion[0].public_ip : null
}

# for_each: create N resources from a map, or none
resource "aws_iam_user" "this" {
  for_each = var.create_users ? var.users : {}

  name = each.key
}
```

`count` on a resource makes it a list (`resource.name[0]`). `for_each` makes it a map (`resource.name["key"]`). Prefer `for_each` when items have stable identities — switching a `count` index around when the list order changes will destroy/recreate resources.

## 3. `coalesce` — first non-null/non-empty value · Intermediate

```hcl
locals {
  # first non-empty string wins
  name = coalesce(var.custom_name, "${var.project}-${var.environment}")
}

# coalesce fails on null args mixed with empty string checks differently than you'd expect —
# use coalescelist for lists
locals {
  subnets = coalescelist(var.custom_subnet_ids, data.aws_subnets.default.ids)
}
```

## 4. `try` and `can` — safe fallbacks · Intermediate

```hcl
# try: return the first expression that doesn't error
locals {
  # falls back to "us-east-1" if var.region_override is unset/null and errors out
  region = try(var.region_override.name, "us-east-1")

  # useful for optional nested object attributes
  bucket_versioning = try(var.bucket_config.versioning_enabled, false)
}

# can: returns true/false instead of erroring — good inside validation blocks
variable "cidr_block" {
  type = string

  validation {
    condition     = can(cidrhost(var.cidr_block, 0))
    error_message = "cidr_block must be a valid CIDR."
  }
}
```

## 5. `lookup` — map access with a default · Beginner

```hcl
variable "instance_sizes" {
  type = map(string)
  default = {
    dev  = "t3.micro"
    prod = "t3.large"
  }
}

locals {
  # lookup(map, key, default) — avoids "key not found" errors
  instance_type = lookup(var.instance_sizes, var.environment, "t3.small")
}
```

## 6. Conditional `dynamic` blocks · Intermediate

```hcl
resource "aws_security_group" "this" {
  name = "app-sg"

  # only add the ingress block if enabled
  dynamic "ingress" {
    for_each = var.enable_ssh_ingress ? [1] : []

    content {
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = var.allowed_ssh_cidrs
    }
  }

  dynamic "ingress" {
    for_each = var.additional_ports
    content {
      from_port   = ingress.value
      to_port     = ingress.value
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }
}
```

`for_each = condition ? [1] : []` is the standard trick for "include this block only if X" — `dynamic` needs something iterable, not a bool.

## 7. `for` expressions (loops that return a value) · Intermediate

```hcl
# list -> list, with a filter
locals {
  prod_subnet_ids = [for s in var.subnets : s.id if s.environment == "prod"]
}

# list -> map
locals {
  subnet_by_name = { for s in var.subnets : s.name => s.id }
}

# transform + conditional value per item
locals {
  tagged_names = [for name in var.names : var.environment == "prod" ? upper(name) : name]
}
```

## 8. Combining `for_each` + ternary for environment-based config · Expert

```hcl
locals {
  env_config = {
    dev = {
      instance_count = 1
      instance_type  = "t3.micro"
    }
    prod = {
      instance_count = 3
      instance_type  = "t3.large"
    }
  }

  config = local.env_config[var.environment]
}

resource "aws_instance" "app" {
  count = local.config.instance_count

  ami           = var.ami_id
  instance_type = local.config.instance_type
}
```

Prefer this map-lookup pattern over chained ternaries once you have more than 2-3 environments — it's easier to extend and diff in review.

## 9. Null checks · Beginner

```hcl
locals {
  # `!= null` guard before using an optional value
  has_custom_domain = var.custom_domain != null

  domain_name = var.custom_domain != null ? var.custom_domain : "${var.project}.example.com"
  # same thing, shorter:
  domain_name_alt = coalesce(var.custom_domain, "${var.project}.example.com")
}
```

## 10. Expert patterns & gotchas · Expert

### count/for_each on values only known after apply

```hcl
# BROKEN: instance.id doesn't exist until after apply, so Terraform can't
# figure out how many `aws_eip` resources to plan for
resource "aws_instance" "app" {
  count = 3
  ami           = var.ami_id
  instance_type = "t3.micro"
}

resource "aws_eip" "app" {
  count = length([for i in aws_instance.app : i.id if i.public_ip == ""]) # fails to plan
  instance = aws_instance.app[count.index].id
}

# FIX: don't derive the count from a computed attribute of a resource in the
# same config — derive it from something known at plan time (a variable,
# a data source that already exists, or a fixed count that matches app's)
resource "aws_eip" "app" {
  count    = 3
  instance = aws_instance.app[count.index].id
}
```

This is the "count/for_each depends on a value that cannot be determined until apply" error. It bites people who reach for `count`/`for_each` as a general-purpose loop instead of realizing Terraform needs to know **how many** resources to create during `plan`, before anything is created.

### `merge()` + `flatten()` for nested config

```hcl
# merge: combine multiple conditional maps into one, later args win on key conflicts
locals {
  default_tags = { Project = var.project }
  env_tags     = var.environment == "prod" ? { Backup = "daily" } : {}
  tags         = merge(local.default_tags, local.env_tags, var.extra_tags)
}

# flatten: collapse a list-of-lists (e.g. one list of subnet objects per VPC)
locals {
  subnets_per_vpc = [for vpc in var.vpcs : [for cidr in vpc.subnet_cidrs : { vpc = vpc.name, cidr = cidr }]]
  all_subnets     = flatten(local.subnets_per_vpc)
}
```

`merge()` is the standard way to layer conditional tag/config maps without a chain of ternaries. `flatten()` is what you reach for once a `for` expression starts nesting — a `for` inside a `for` produces a list of lists, and most resource arguments want a flat list.

### `optional()` in variable type constraints (Terraform 1.3+)

```hcl
variable "bucket_config" {
  type = object({
    name               = string
    versioning_enabled = optional(bool, false)
    lifecycle_days     = optional(number, 30)
  })
}

# no more: try(var.bucket_config.versioning_enabled, false) scattered through locals —
# the default lives in the type constraint itself
resource "aws_s3_bucket_versioning" "this" {
  bucket = var.bucket_config.name
  versioning_configuration {
    status = var.bucket_config.versioning_enabled ? "Enabled" : "Disabled"
  }
}
```

Once you're writing modules with several optional nested settings, `optional(type, default)` in the `object()` type constraint replaces most of the `try()`/`coalesce()` calls from sections 3-4 — the default is declared once, at the boundary, instead of at every use site.

### Multi-level `dynamic` blocks

```hcl
resource "aws_security_group" "this" {
  name = "app-sg"

  dynamic "ingress" {
    for_each = var.ingress_rules
    content {
      from_port = ingress.value.from_port
      to_port   = ingress.value.to_port
      protocol  = ingress.value.protocol

      # a dynamic block nested inside a dynamic block — valid, but readability drops fast
      cidr_blocks = ingress.value.cidr_blocks
    }
  }
}
```

`dynamic` blocks can nest, but two levels deep is usually the point to stop and ask whether this belongs in a child module instead — nested `dynamic` + `for_each` + ternary is hard to review and easy to get wrong in a way `terraform plan` won't catch.

### Conditional logic at the module boundary

```hcl
# you CAN skip creating a whole module call:
module "bastion" {
  count  = var.create_bastion ? 1 : 0
  source = "./modules/bastion"
}

# you CANNOT conditionally omit a single argument passed into a module —
# pass null and let the module's own default/try() handle it
module "app" {
  source          = "./modules/app"
  instance_type   = var.environment == "prod" ? "t3.large" : null # module defines a default for null
}
```

`count`/`for_each` work on the `module` block itself (skip/repeat the whole module), but there's no equivalent for a single input — the module has to be written to treat `null` as "use my default" (typically via `optional()` in its variable type or a `coalesce()` inside).

### Conditionals and `lifecycle { ignore_changes }`

```hcl
# ignore_changes itself can't be conditional — this is invalid:
# ignore_changes = var.freeze_tags ? [tags] : []

# workaround: split into two resource blocks gated by count, one with the
# lifecycle block and one without
resource "aws_instance" "app_frozen" {
  count = var.freeze_tags ? 1 : 0
  # ...
  lifecycle {
    ignore_changes = [tags]
  }
}

resource "aws_instance" "app" {
  count = var.freeze_tags ? 0 : 1
  # ...
}
```

`lifecycle` arguments are evaluated statically and can't reference variables conditionally. The split-resource workaround above is the common escape hatch — but it doubles the resource block and everything that references it needs its own ternary/coalesce to pick whichever one actually exists, so only reach for this when the alternative (manually reconciling drift) is worse.

## Quick reference

| Need | Use |
| --- | --- |
| Pick between two values | `condition ? a : b` |
| Create a resource or not | `count = condition ? 1 : 0` |
| First non-null/non-empty value | `coalesce(a, b, c)` |
| Safe optional nested attribute | `try(expr, default)` |
| Validate without erroring | `can(expr)` |
| Map lookup with default | `lookup(map, key, default)` |
| Optional block inside a resource | `dynamic` + `for_each = cond ? [1] : []` |
| Filter/transform a list or map | `for` expression |
| Layer conditional maps together | `merge(a, b, c)` |
| Collapse a list of lists | `flatten(list)` |
| Default for an optional object field | `optional(type, default)` in the type constraint |

## Try it in `terraform console`

`terraform console` needs to run inside a directory with at least one `.tf` file (an empty one is fine) — it loads that config's providers/state, then gives you a REPL. These are self-contained (literal values, no `var.*`) so you can paste them straight in without setting anything up:

```bash
terraform console
```

```text
# ternary
> true ? "yes" : "no"
"yes"

> 5 > 3 ? "bigger" : "smaller"
"bigger"

# coalesce - first non-null/non-empty
> coalesce(null, "", "fallback")
"fallback"

# try - fallback when the expression errors
> try(nonexistent_var, "default")
"default"

# can - true/false instead of an error
> can(cidrhost("10.0.0.0/24", 5))
true

> can(cidrhost("not-a-cidr", 5))
false

# lookup with a default
> lookup({ dev = "t3.micro", prod = "t3.large" }, "staging", "t3.small")
"t3.small"

# for expression - filter + transform
> [for n in [1, 2, 3, 4, 5] : n * 2 if n % 2 == 0]
[
  4,
  8,
]

# for expression - list to map
> { for n in ["a", "b", "c"] : n => upper(n) }
{
  "a" = "A"
  "b" = "B"
  "c" = "C"
}

# null checks
> null != null
false

> coalesce(null, "example.com")
"example.com"

# string interpolation + ternary together
> "env-${true ? "prod" : "dev"}"
"env-prod"
```

To try expressions against your *actual* variables (`var.environment`, etc.), run `terraform console` from inside the module directory — it reads `terraform.tfvars` / `*.auto.tfvars` automatically, same as `plan`/`apply`. Exit with `exit` or Ctrl+D.
