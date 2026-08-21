# Neuro-Symbolic Platform Infrastructure

Production Terraform infrastructure configurations for the Neuro-Symbolic Knowledge Platform on Google Cloud Platform.

## Architecture Overview

1. **Reasoning Engine (Cloud Run v2)**:
   - High-performance container running native Rust GEB engine and FastAPI orchestration.
   - Resource limits: **8GB RAM / 4 CPUs**.
   - Dedicated least-privilege service account (`reasoning-engine-sa`) with BigQuery and Secret Manager access.

2. **Extraction Agents (Cloud Run v2)**:
   - LangGraph + Vertex AI Gemini multimodal document processing microservice.
   - Resource limits: **2GB RAM / 2 CPUs**.
   - Dedicated service account (`extraction-agents-sa`) with `roles/aiplatform.user`, `roles/pubsub.publisher`, and `roles/storage.objectViewer`.

3. **Dataform Integration**:
   - `google_dataform_repository` managing Relational SHACL data quality and property graph transformations in BigQuery.
   - IAM permissions granted to Dataform service account (`roles/bigquery.dataEditor`, `roles/bigquery.jobUser`, `roles/secretmanager.secretAccessor`).

4. **Event-Driven Ingestion**:
   - GCS bucket for document ingestion (`${project_id}-unstructured-docs`).
   - Eventarc trigger invoking Extraction Agents upon `google.cloud.storage.object.v1.finalized`.
   - Pub/Sub topics: `raw-graph-events`, `inferred-graph-events`.

## Validation & Deployment

```bash
terraform init -backend=false
terraform validate
terraform plan -var="project_id=YOUR_PROJECT_ID"
terraform apply -var="project_id=YOUR_PROJECT_ID"
```

