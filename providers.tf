# Contiene il blocco di configurazione di Terraform e specifica le versioni minime del provider AWS.
terraform{

    required_providers {
        aws = {
            source  = "hashicorp/aws"
            version = "~> 6.0" # Versione minima del provider AWS richiesta. Pessimistic constraint (allow minor version modify)
        }
    }

    required_version = ">= 1.5.0" # Versione propria di Terraform richiesta.

}

# Configurazione provider AWS
provider "aws" {
    # Configurazione del provider (non necessaria se già è stato configurato il file ~/.aws/credentials)
    region = "eu-west-1"
}