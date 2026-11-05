# ATS Cloud Platform - Serverless AI-Driven Recruitment System

Una piattaforma **Serverless Event-Driven** per l'ingestione, il parsing e il ranking automatizzato di Curriculum Vitae basata sulle infrastrutture **AWS** e modelli linguistici avanzati **Google Gemini**.

---

## Architettura di Sistema

L'infrastruttura è completamente gestita come codice tramite **Terraform** e si compone dei seguenti livelli:

1. **API & Interface Layer:** Amazon API Gateway (HTTP API) gestito da una funzione AWS Lambda proxy (`lambda_api`) per l'interazione RESTful (upload CV in Base64, pubblicazione annunci e generazione di URL pre-firmati per la visualizzazione sicura dei file).
2. **Ingestion & Buffering Layer:** Amazon S3 (`cv-incoming-bucket`) per lo staging temporaneo dei documenti e Amazon SQS (`cv-processing-queue`) per il disaccoppiamento asincrono dell'elaborazione, affiancata da una Dead Letter Queue (`cv-dlq`).
3. **Compute & AI Layer:** AWS Lambda (`lambda_parser`) per l'estrazione del testo (via `pypdf`) e la classificazione/scoring del profilo tramite le API di Google Gemini.
4. **Persistence & Archive Layer:** Amazon DynamoDB (`jobs_table` e `candidates_table` con GSI `JobIdScoreIndex`) per la persistenza NoSQL e Amazon S3 (`cv-archive-bucket`) per la conservazione sicura a lungo termine dei CV validi.

---

## Struttura del Progetto

```text
Progetto_dir/
├── src/
│   ├── lambda_api/
│   │   └── main.py              # Backend REST API (Jobs, Candidates, Base64 Upload)
│   ├── lambda_parser/
│   │   └── main.py              # Parser asincrono SQS + Invocazione Google Gemini API
│   └── layers/
│       ├── python/              # Directory di build per le dipendenze Python (Git-Ignored)
│       └── dependencies.zip     # Layer impacchettato per l'ambiente Linux Lambda
│
├── test_cv/                     # Set di dati per collaudo e test (Job Descriptions e PDF)
├── venv/                        
│
├── .gitignore                   
├── .terraform.lock.hcl          # Lock file dei provider Terraform(Git-Ignored)
├── app.html                     # Interfaccia grafica Frontend (Single-Page Application)
├── dynamodb.tf                  # Definizione tabelle e indici GSI DynamoDB
├── gateway.tf                   # Definizione endpoint ed integrazioni API Gateway
├── iam.tf                       # Ruoli e policy di sicurezza IAM (Minimo Privilegio)
├── lambda.tf                    # Deployment funzioni Lambda e Event Source Mapping
├── main.tf                      # Configurazione provider AWS e backend Terraform
├── outputs.tf                   # Output dell'infrastruttura (API URL, Bucket Names)
├── readMe.md                    # Documentazione di progetto
├── requirements.txt             # Dipendenze Python del progetto
├── s3.tf                        # Configurazione dei bucket S3 (Incoming e Archive)
├── sqs.tf                       # Configurazione coda SQS, DLQ e Visibility Timeout
├── terraform.tfvars             # API Key(Git-Ignored)
├── config.js                    # API Url(Git-Ignored)
└── variables.tf                 # Dichiarazione delle variabili Terraform
```

> **Nota sugli Artifact di Build:** I file compresso `.zip` (`lambda_api.zip`, `lambda_parser.zip`, `dependencies.zip`) sono esclusi dal tracciamento Git (`.gitignore`). Devono essere generati localmente prima dell'esecuzione di Terraform come descritto nella guida sottostante.

---

## Requisiti Preliminari

Assicurati di avere installato e configurato i seguenti strumenti nel tuo ambiente locale:

* [AWS CLI](https://aws.amazon.com/cli/) (configurato con credenziali IAM con permessi adeguati via `aws configure`).
* [Terraform](https://www.terraform.io/) (v1.0.0+).
* [Python 3.11](https://www.python.org/).
* Una **Google Gemini API Key** valida (ottenibile da [Google AI Studio](https://aistudio.google.com/)).

---

## Guida all'Installazione e Deployment

### 1. Clonare il repository
```bash
git clone <repository-url>
cd ATS_Cloud_Platform
```

### 2. Configurare le variabili d'ambiente (`terraform.tfvars`)
Crea il file `terraform.tfvars`(o modifica il file 'terraafomr.tfvars.example') nella radice del progetto e inserisci la tua API Key di Google Gemini e la regione AWS desiderata:

```hcl
aws_region     = "eu-north-1"
gemini_api_key = "AIzaSyYourActualGeminiApiKeyHere..."
```

### 3. Compilare il Lambda Layer (Cross-Compilation per Linux x86_64)
Per evitare problemi di incompatibilità binaria nella micro-VM Linux di AWS Lambda durante l'esecuzione su sistemi macOS/Windows, compila ed estrai i pacchetti binari compatibili per Linux:

```bash
# 1. Pulisci l'ambiente locale
rm -rf src/layers/python layer_mac.zip
mkdir -p src/layers/python

# 2. Scarica i binari nativi Linux manylinux2014_x86_64
pip install \
  --platform manylinux2014_x86_64 \
  --target ./src/layers/python \
  --implementation cp \
  --python-version 3.11 \
  --only-binary=:all: \
  --no-cache-dir \
  -r requirements.txt

# 3. Impacchetta il Layer mantenendo la radice python/
cd src/layers
zip -r ../../src/layers/dependencies.zip python
cd ../..
```

### 4. Inizializzare ed applicare l'infrastruttura con Terraform
```bash
# Inizializza i provider Terraform
terraform init

# Verifica il piano di esecuzione
terraform plan

# Applica e crea le risorse su AWS
terraform apply -auto-approve
```

Al termine dell'applicazione, Terraform restituirà nei comandi di output l'endpoint dell'API Gateway, ad esempio:
`api_endpoint = "https://xxxxxxxxx.execute-api.eu-north-1.amazonaws.com"`

Questo URL andrà inserito in un file `config.js`(o modifica il file 'config.js.example') nella radice del progetto.

---

## Esecuzione del Test Applicativo

La cartella `test_cv/` contiene il materiale necessario per effettuare i collaudi funzionali dell'intero sistema.

### Step 1: Configurare il Frontend Web (`app.html`)
1. Apri il file `app.html` con un editor di testo.
2. Individua la costante `API_BASE_URL` nel file 'config.js' aggiornala con l'URL generato da Terraform:
   ```javascript
   const API_BASE_URL = "https://xxxxxxxxx.execute-api.eu-north-1.amazonaws.com";
   ```
3. Apri il file `app.html` all'interno di un qualsiasi browser web.

### Step 2: Pubblicare una Posizione Lavorativa (Area Recruiter)
1. Nella sezione **Area Recruiter**, inserisci un titolo (es. `Senior Cloud Engineer`).
2. Apri il file di testo con il testo della Job Description presente in `test_cv/` (oppure incolla i requisiti descrittivi della posizione).
3. Clicca su **Pubblica Job Description**. Verrà generato un `job_id` univoco memorizzato su DynamoDB.

### Step 3: Inviare i Curriculum (Area Candidato)
1. Nella sezione **Area Candidato**, seleziona dal menu a tendina la posizione creata.
2. Carica uno dei PDF presenti nella cartella `test_cv/`:
   * **Test CV Affine:** Seleziona un PDF contenente un CV attinente alla Job Description.
   * **Test Documento Non-CV:** Carica un file non pertinente (es. una fattura, un modulo o testo casuale).
3. Clicca su **Invia Candidatura**.

### Step 4: Verificare il Parsing e il Ranking automatizzato
1. Ritorna nell'area Recruiter e clicca sul pulsante **Candidati** accanto alla posizione creata.
2. **Esito CV Valido:** Il sistema mostrerà la graduatoria con il punteggio (Score su 100), le skill individuate, le carenze e il pulsante **Apri PDF** che genera una Presigned URL per la consultazione sicura del documento presente nel bucket d'archivio.
3. **Esito Documento Non-CV:** Il documento scartato dall'LLM viene rimosso automaticamente dal bucket d'ingresso `cv-incoming-bucket` senza essere scritto nella graduatoria o archiviato su S3.

---

## Dismissione dell'Infrastruttura (Teardown)

Per rimuovere completamente tutte le risorse create su AWS ed evitare addebiti indesiderati:

```bash
terraform destroy -auto-approve
```