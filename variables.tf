variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "region" {
  description = "The GCP region for deployments"
  type        = string
  default     = "us-central1"
}

variable "reasoning_engine_service_name" {
  description = "The name of the Reasoning Engine Cloud Run service"
  type        = string
  default     = "reasoning-engine"
}

variable "extraction_agents_service_name" {
  description = "The name of the Extraction Agents Cloud Run service"
  type        = string
  default     = "extraction-agents"
}

variable "reasoning_engine_image" {
  description = "Container image for Reasoning Engine"
  type        = string
  default     = "us-docker.pkg.dev/cloudrun/container/hello"
}

variable "extraction_agents_image" {
  description = "Container image for Extraction Agents"
  type        = string
  default     = "us-docker.pkg.dev/cloudrun/container/hello"
}

variable "bq_dataset_name" {
  description = "The name of the primary BigQuery dataset"
  type        = string
  default     = "kg_production"
}

variable "dataform_repo_name" {
  description = "The name of the Dataform repository"
  type        = string
  default     = "knowledge-graph-dataform"
}
