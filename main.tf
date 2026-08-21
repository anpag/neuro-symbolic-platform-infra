terraform {
  required_version = ">= 1.5.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.0.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

data "google_project" "project" {
  project_id = var.project_id
}

# ==============================================================================
# 1. IAM Service Accounts (Least-Privilege Dedicated SAs)
# ==============================================================================

resource "google_service_account" "extraction_agents_sa" {
  account_id   = "extraction-agents-sa"
  display_name = "Extraction Agents Service Account"
  description  = "Dedicated least-privilege SA for LangGraph and Vertex AI extraction agents"
}

resource "google_service_account" "reasoning_engine_sa" {
  account_id   = "reasoning-engine-sa"
  display_name = "Reasoning Engine Service Account"
  description  = "Dedicated least-privilege SA for Native Rust GEB Reasoning Engine"
}

resource "google_service_account" "eventarc_sa" {
  account_id   = "eventarc-trigger-sa"
  display_name = "Eventarc Trigger Service Account"
  description  = "Dedicated SA for Eventarc storage triggers to Cloud Run"
}

# --- Extraction Agents SA IAM Bindings ---
resource "google_project_iam_member" "extraction_vertex_user" {
  project = var.project_id
  role    = "roles/aiplatform.user"
  member  = "serviceAccount:${google_service_account.extraction_agents_sa.email}"
}

resource "google_project_iam_member" "extraction_storage_viewer" {
  project = var.project_id
  role    = "roles/storage.objectViewer"
  member  = "serviceAccount:${google_service_account.extraction_agents_sa.email}"
}

resource "google_project_iam_member" "extraction_pubsub_publisher" {
  project = var.project_id
  role    = "roles/pubsub.publisher"
  member  = "serviceAccount:${google_service_account.extraction_agents_sa.email}"
}

resource "google_project_iam_member" "extraction_bq_viewer" {
  project = var.project_id
  role    = "roles/bigquery.dataViewer"
  member  = "serviceAccount:${google_service_account.extraction_agents_sa.email}"
}

resource "google_project_iam_member" "extraction_secret_accessor" {
  project = var.project_id
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${google_service_account.extraction_agents_sa.email}"
}

# --- Reasoning Engine SA IAM Bindings ---
resource "google_project_iam_member" "reasoning_vertex_user" {
  project = var.project_id
  role    = "roles/aiplatform.user"
  member  = "serviceAccount:${google_service_account.reasoning_engine_sa.email}"
}

resource "google_project_iam_member" "reasoning_storage_viewer" {
  project = var.project_id
  role    = "roles/storage.objectViewer"
  member  = "serviceAccount:${google_service_account.reasoning_engine_sa.email}"
}

resource "google_project_iam_member" "reasoning_bq_editor" {
  project = var.project_id
  role    = "roles/bigquery.dataEditor"
  member  = "serviceAccount:${google_service_account.reasoning_engine_sa.email}"
}

resource "google_project_iam_member" "reasoning_bq_job_user" {
  project = var.project_id
  role    = "roles/bigquery.jobUser"
  member  = "serviceAccount:${google_service_account.reasoning_engine_sa.email}"
}

resource "google_project_iam_member" "reasoning_secret_accessor" {
  project = var.project_id
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${google_service_account.reasoning_engine_sa.email}"
}

# --- Eventarc SA IAM Bindings ---
resource "google_project_iam_member" "eventarc_event_receiver" {
  project = var.project_id
  role    = "roles/eventarc.eventReceiver"
  member  = "serviceAccount:${google_service_account.eventarc_sa.email}"
}

# ==============================================================================
# 2. Pub/Sub Topics & Storage
# ==============================================================================

resource "google_pubsub_topic" "raw_graph_events" {
  name = "raw-graph-events"
}

resource "google_pubsub_topic" "inferred_graph_events" {
  name = "inferred-graph-events"
}

resource "google_storage_bucket" "unstructured_docs" {
  name                        = "${var.project_id}-unstructured-docs"
  location                    = "US"
  uniform_bucket_level_access = true
  force_destroy               = false
}

resource "google_bigquery_dataset" "knowledge_graph" {
  dataset_id                 = var.bq_dataset_name
  friendly_name              = "Enterprise Knowledge Graph Production"
  description                = "Production dataset for enterprise knowledge graph nodes, edges, and SHACL validation"
  location                   = "US"
  delete_contents_on_destroy = false
}

# ==============================================================================
# 3. Dataform Integration & Permissions
# ==============================================================================

resource "google_dataform_repository" "knowledge_graph_dataform" {
  provider = google
  name     = var.dataform_repo_name
  region   = var.region
}

# Dataform default P4SA (service-PROJECT_NUMBER@gcp-sa-dataform.iam.gserviceaccount.com)
resource "google_project_iam_member" "dataform_bigquery_data_editor" {
  project = var.project_id
  role    = "roles/bigquery.dataEditor"
  member  = "serviceAccount:service-${data.google_project.project.number}@gcp-sa-dataform.iam.gserviceaccount.com"
}

resource "google_project_iam_member" "dataform_bigquery_job_user" {
  project = var.project_id
  role    = "roles/bigquery.jobUser"
  member  = "serviceAccount:service-${data.google_project.project.number}@gcp-sa-dataform.iam.gserviceaccount.com"
}

resource "google_project_iam_member" "dataform_secret_accessor" {
  project = var.project_id
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:service-${data.google_project.project.number}@gcp-sa-dataform.iam.gserviceaccount.com"
}

# ==============================================================================
# 4. Cloud Run Deployments (Reasoning Engine: 8GB RAM / 4 CPUs, Extraction Agents)
# ==============================================================================

# Native Rust GEB Reasoning Engine (8GB RAM / 4 CPUs)
resource "google_cloud_run_v2_service" "reasoning_engine" {
  name     = var.reasoning_engine_service_name
  location = var.region

  template {
    service_account = google_service_account.reasoning_engine_sa.email

    scaling {
      min_instance_count = 0
      max_instance_count = 10
    }

    containers {
      image = var.reasoning_engine_image

      resources {
        limits = {
          memory = "8Gi"
          cpu    = "4"
        }
      }

      env {
        name  = "PROJECT_ID"
        value = var.project_id
      }
      env {
        name  = "LOCATION"
        value = var.region
      }
      env {
        name  = "BQ_DATASET"
        value = google_bigquery_dataset.knowledge_graph.dataset_id
      }
      env {
        name  = "MODEL_NAME"
        value = "gemini-1.5-flash"
      }
    }
  }
}

# LangGraph + Vertex AI Extraction Agents
resource "google_cloud_run_v2_service" "extraction_agents" {
  name     = var.extraction_agents_service_name
  location = var.region

  template {
    service_account = google_service_account.extraction_agents_sa.email

    scaling {
      min_instance_count = 0
      max_instance_count = 20
    }

    containers {
      image = var.extraction_agents_image

      resources {
        limits = {
          memory = "2Gi"
          cpu    = "2"
        }
      }

      env {
        name  = "PROJECT_ID"
        value = var.project_id
      }
      env {
        name  = "LOCATION"
        value = var.region
      }
      env {
        name  = "MODEL_NAME"
        value = "gemini-1.5-flash"
      }
      env {
        name  = "OUTPUT_TOPIC"
        value = google_pubsub_topic.raw_graph_events.name
      }
      env {
        name  = "REASONING_ENGINE_URL"
        value = google_cloud_run_v2_service.reasoning_engine.uri
      }
      env {
        name  = "BQ_DATASET"
        value = google_bigquery_dataset.knowledge_graph.dataset_id
      }
    }
  }
}

# Grant Eventarc Invoker permission to invoke Extraction Agents
resource "google_cloud_run_v2_service_iam_member" "eventarc_invoker_extraction" {
  location = google_cloud_run_v2_service.extraction_agents.location
  project  = var.project_id
  name     = google_cloud_run_v2_service.extraction_agents.name
  role     = "roles/run.invoker"
  member   = "serviceAccount:${google_service_account.eventarc_sa.email}"
}

# Eventarc GCS Upload Trigger -> Extraction Agents
resource "google_eventarc_trigger" "gcs_to_extraction_agents" {
  name            = "gcs-upload-to-extraction-agents"
  location        = var.region
  service_account = google_service_account.eventarc_sa.email

  matching_criteria {
    attribute = "type"
    value     = "google.cloud.storage.object.v1.finalized"
  }

  matching_criteria {
    attribute = "bucket"
    value     = google_storage_bucket.unstructured_docs.name
  }

  destination {
    cloud_run_service {
      service = google_cloud_run_v2_service.extraction_agents.name
      region  = var.region
    }
  }

  depends_on = [
    google_project_iam_member.eventarc_event_receiver,
    google_cloud_run_v2_service_iam_member.eventarc_invoker_extraction
  ]
}
