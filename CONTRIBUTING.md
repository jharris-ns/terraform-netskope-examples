# Contributing to Netskope Terraform Examples

Thank you for your interest in contributing! This repository welcomes contributions including bug fixes, new examples, tutorial improvements, and documentation updates.

## How to Contribute

### Reporting Issues

- Use [GitHub Issues](https://github.com/netskopeoss/terraform-netskope-examples/issues) to report bugs or suggest improvements
- Search existing issues before creating a new one
- Include relevant details: Terraform version, provider version, error messages

### Submitting Changes

1. **Fork the repository** and create a branch from `main`
2. **Make your changes** following the guidelines below
3. **Test your changes** against a Netskope tenant
4. **Submit a pull request** with a clear description of your changes

## Code Guidelines

### Terraform Formatting

All Terraform code must pass formatting checks:

```bash
terraform fmt -check -recursive code/
```

Format your code before committing:

```bash
terraform fmt -recursive code/
```

### Validation

Ensure your code is syntactically valid:

```bash
cd code/your-example
terraform init
terraform validate
```

### Naming Conventions

- **Directories**: kebab-case (`private-app-inventory/`)
- **Terraform files**: Descriptive names (`apps-web.tf`, `rules-deny.tf`)
- **Resources**: Use meaningful names with environment prefixes

### Documentation

- Every example in `code/` must have a `README.md`
- Include: what it creates, prerequisites, usage instructions, cleanup
- For complex examples, add a `terraform.tfvars.example` file

## Testing

Contributors should test their changes against a Netskope tenant before submitting:

1. Run `terraform init` and `terraform validate`
2. Run `terraform plan` to verify expected resources
3. Run `terraform apply` to confirm resources are created correctly
4. Run `terraform destroy` to verify clean removal

**Note**: Never commit real credentials or tenant-specific values.

## Adding New Examples

1. Create a directory under `code/` with a descriptive name
2. Add `README.md` with deployment instructions
3. Add `main.tf` (simple examples) or split files (complex examples)
4. Add `terraform.tfvars.example` if variables are required
5. Update `code/README.md` to include your example in the table
6. Update the root `README.md` if appropriate

## Adding New Tutorials

1. Create `tutorials/your-topic.md`
2. Create corresponding `code/your-topic/` directory
3. Link the tutorial to the code directory
4. Update the root `README.md` tutorials table

## License

By contributing, you agree that your contributions will be licensed under the [Apache 2.0 License](./LICENSE).

## Questions?

Open a [GitHub Issue](https://github.com/netskopeoss/terraform-netskope-examples/issues) for any questions about contributing.
