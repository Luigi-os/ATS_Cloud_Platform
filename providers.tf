# This file contains the configuration for the Terraform providers and backend.

terraform{
    # Configurazione del backend S3 per lo stato remoto di Terraform. (Sicuro)
    backend "s3" {
        bucket = "gg-cv-test-bucket-state-00000" # Identificativo univoco del bucket S3.
        key    = "dev/terraform.tfstate" # Percorso del file di stato all'interno del bucket S3.
        region = "eu-north-1" # Hardcoded perchè la risorsa S3 è già stata creata in precedenza.
        encrypt = true # Abilita la crittografia del file di stato.
        use_lockfile = true # Abilita il locking del file di stato.
    }
    # Configurazione dei provider richiesti da Terraform.
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
    region = var.region # Regione AWS in cui creare le risorse.
    # Configurazione del provider (non necessaria se già è stato configurato il file ~/.aws/credentials)
}

