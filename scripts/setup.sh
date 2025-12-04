#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== Infrastructure Setup Script ===${NC}"

# Check requirements
check_requirements() {
    echo -e "${YELLOW}Checking requirements...${NC}"

    local missing=()

    command -v terraform >/dev/null 2>&1 || missing+=("terraform")
    command -v ansible >/dev/null 2>&1 || missing+=("ansible")
    command -v kubectl >/dev/null 2>&1 || missing+=("kubectl")
    command -v oci >/dev/null 2>&1 || missing+=("oci-cli")

    if [ ${#missing[@]} -ne 0 ]; then
        echo -e "${RED}Missing required tools: ${missing[*]}${NC}"
        exit 1
    fi

    echo -e "${GREEN}All requirements satisfied!${NC}"
}

# Initialize Terraform
init_terraform() {
    echo -e "${YELLOW}Initializing Terraform...${NC}"
    cd terraform
    terraform init
    cd ..
    echo -e "${GREEN}Terraform initialized!${NC}"
}

# Check Ansible inventory
check_ansible() {
    echo -e "${YELLOW}Checking Ansible configuration...${NC}"
    cd ansible
    ansible-inventory --list > /dev/null 2>&1
    cd ..
    echo -e "${GREEN}Ansible configuration valid!${NC}"
}

# Main
main() {
    check_requirements
    init_terraform
    check_ansible

    echo -e "${GREEN}"
    echo "==================================="
    echo "Setup complete!"
    echo ""
    echo "Next steps:"
    echo "1. Configure terraform/terraform.tfvars"
    echo "2. Update ansible/inventory.yml with server IPs"
    echo "3. Run: cd terraform && terraform plan"
    echo "==================================="
    echo -e "${NC}"
}

main "$@"
