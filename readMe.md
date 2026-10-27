L'obiettivo è scomporre il problema globale in sottoproblemi isolati, verificando ogni singolo blocco di codice tramite il ciclo di feedback fornito dall'infrastruttura come codice (IaC).

---

## 1. Organizzazione Modulare del Progetto

Invece di concentrare l'intera architettura all'interno di un unico file `main.tf`, suddividerai la logica in file tematici per mantenere la separazione delle responsabilità e facilitare la manutenzione.

Crea la seguente struttura all'interno della cartella di progetto:

* `providers.tf`: Contiene il blocco di configurazione di Terraform e specifica le versioni minime del provider AWS.
* `variables.tf`: Dichiarazione di tutte le variabili di input (es. regione AWS, prefisso del progetto, soglie di rete).
* `s3.tf`: Dichiarazione dei bucket di ingestion (`cv-incoming-bucket`) e di archiviazione (`cv-archive-bucket`).


* `sqs.tf`: Definizione della coda di buffering (`cv-processing-queue`) e della Dead Letter Queue (`cv-dlq`).


* `dynamodb.tf`: Configurazione della tabella NoSQL (`CandidatesTable`).


* `iam.tf`: Ruoli e policy di sicurezza per concedere alla Lambda i permessi strettamente necessari.
* `lambda.tf`: Definizione del codice elaborativo (`cv-llm-parser`), delle variabili d'ambiente e delle integrazioni a eventi.


* `outputs.tf`: Esportazione dei valori chiave (es. ARN delle risorse o URL dei bucket) per verificare il completamento del deployment.

---

## 2. Metodologia di Consultazione Ufficiale

Per non copiare codice alla cieca, dovrai imparare a ricavare i blocchi HCL (HashiCorp Configuration Language) partendo dalle specifiche delle risorse. Per ciascun servizio, consulta la documentazione ufficiale del **Terraform Registry (AWS Provider)** applicando questi tre passaggi:

1. **Identificazione della Risorsa:** Cerca il nome del tipo di risorsa sul registry (ad esempio, `aws_sqs_queue`).
2. **Distinzione tra Argomenti Obbligatori e Opzionali:** Identifica i parametri indispensabili per l'istanziamento (es. `name` per SQS) e aggiungi gradualmente quelli avanzati.
3. **Mappatura dei Riferimenti Incrociati:** Individua gli attributi esportati da ciascuna risorsa (es. `.arn` o `.id`) per collegare una risorsa all'altra.

---

## 3. Guida Passo-Passo allo Sviluppo Incrementale

Segui questa sequenza ordinata. Non passare alla fase successiva senza aver eseguito e validato la fase corrente tramite i comandi `terraform validate`, `terraform plan` e `terraform apply`.

### Passo A: Definizione dei Provider e dello Storage (S3)

* **Azione:** Apri `providers.tf` e specifica il provider `aws` impostando la regione desiderata. In `s3.tf`, dichiara le risorse `aws_s3_bucket` per la ricezione iniziale del CV e per l'archiviazione post-elaborazione.


* **Concetto di Apprendimento:** Comprendere l'univocità globale del naming S3 e l'uso delle variabili in `variables.tf` per parametrizzare i nomi.

### Passo B: Messaging e Resilienza (SQS e DLQ)

* **Azione:** In `sqs.tf`, definisci prima la coda DLQ (`cv-dlq`). Successivamente, dichiara la coda principale (`cv-processing-queue`). All'interno di quest'ultima, aggiungi il parametro `redrive_policy` codificando la regola tramite la funzione `jsonencode()`.


* **Concetto di Apprendimento:** La dipendenza implicita. Inserendo l'ARN della DLQ all'interno del parametro della coda principale, Terraform comprenderà autonomamente di dover creare la DLQ per prima.

### Passo C: Data Layer (DynamoDB)

* **Azione:** In `dynamodb.tf`, configura una risorsa `aws_dynamodb_table`. Definisci il parametro `billing_mode = "PAY_PER_REQUEST"` e specifica l'attributo `candidate_id` come chiave di partizione (`hash_key`) con tipo stringa (`S`).


* **Concetto di Apprendimento:** Schemi NoSQL On-Demand su AWS e astrazione della gestione delle chiavi primarie.

### Passo D: Security e Principi di Minimo Privilegio (IAM)

* **Azione:** In `iam.tf`, crea un ruolo IAM (`aws_iam_role`) associandogli una *Trust Policy* che permetta al servizio `lambda.amazonaws.com` di assumere il ruolo. Dichiara una policy personalizzata (`aws_iam_policy`) contenente le sole azioni necessarie (`s3:GetObject`, `s3:DeleteObject`, `s3:PutObject`, `sqs:ReceiveMessage`, `sqs:DeleteMessage`, `dynamodb:PutItem`) limitate agli ARN delle risorse create nei passi precedenti. Collega infine la policy al ruolo tramite `aws_iam_role_policy_attachment`.
* **Concetto di Apprendimento:** Definizione del modello di sicurezza *Least Privilege* e separazione tra Trust Policy (chi può usare il ruolo) e Access Policy (cosa il ruolo può fare).

### Passo E: Compute e Triggers Event-Driven (Lambda, S3 Notification, SQS Event Source)

* **Azione:** In `lambda.tf`, impacchetta uno script Python minimale in un archivio ZIP tramite il data source `archive_file`. Dichiara la risorsa `aws_lambda_function` collegando il ruolo IAM creato. Configura poi:
1. `aws_s3_bucket_notification`: Per collegare l'evento di upload su S3 (`s3:ObjectCreated:*`) alla coda SQS.


2. `aws_lambda_event_source_mapping`: Per impostare il polling automatico di SQS da parte di Lambda.




* **Concetto di Apprendimento:** Disaccoppiamento event-driven, dove la sorgente (S3) non invoca direttamente il compute (Lambda), ma deposita la notifica in un buffer intermedio (SQS).

---

## 4. Gestione delle Dipendenze in Terraform

Durante la scrittura autonoma del codice, occorre prestare attenzione alla differenza tra due modalità di gestione delle dipendenze:

* **Dipendenza Implicita:** Si verifica quando un blocco di codice riutilizza un valore generato da un altro blocco. Se assegni `aws_sqs_queue.dlq.arn` dentro la risorsa della coda principale, Terraform calcola un Grafo Orientato Aciclico (DAG) e sa che deve istanziare prima la risorsa referenziata.
* **Dipendenza Esplicita (`depends_on`):** Si usa quando non esiste un passaggio diretto di parametri nel codice HCL, ma una risorsa necessita comunque che un'altra sia pienamente attiva (ad esempio, le notifiche di evento S3 verso SQS richiedono che la politica di autorizzazione SQS esista già). In questo caso si dichiara esplicitamente l'attributo `depends_on = [aws_sqs_queue_policy.esempio]`.

---

## Fonti per l'Approfondimento

Per la consultazione della documentazione ufficiale e delle specifiche di riferimento:

* **HashiCorp Terraform Registry (AWS Provider):** [Terraform AWS Provider Documentation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
* **AWS Documentation - Serverless Architecture:** [AWS Serverless Multi-Tier Architectures](https://www.google.com/search?q=https://docs.aws.amazon.com/whitepapers/latest/serverless-multi-tier-architectures-resources/welcome.html)
* **AWS IAM Documentation:** [IAM Policies and Permissions in AWS](https://docs.aws.amazon.com/IAM/latest/UserGuide/access_policies.html)
* **HashiCorp Learn:** [Build Infrastructure - Terraform Getting Started](https://developer.hashicorp.com/terraform/tutorials/aws-get-started)