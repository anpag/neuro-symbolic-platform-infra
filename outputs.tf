output "reasoning_engine_url" {
  description = "The URL of the Reasoning Engine Cloud Run service"
  value       = google_cloud_run_v2_service.reasoning_engine.uri
}

output "extraction_agents_url" {
  description = "The URL of the Extraction Agents Cloud Run service"
  value       = google_cloud_run_v2_service.extraction_agents.uri
}

output "dataform_repository_name" {
  description = "The name of the Dataform repository"
  value       = google_dataform_repository.knowledge_graph_dataform.name
}

output "raw_graph_events_topic" {
  description = "The Pub/Sub topic for raw graph events"
  value       = google_pubsub_topic.raw_graph_events.id
}

output "inferred_graph_events_topic" {
  description = "The Pub/Sub topic for inferred graph events"
  value       = google_pubsub_topic.inferred_graph_events.id
}

output "bigquery_dataset_id" {
  description = "The BigQuery dataset ID"
  value       = google_bigquery_dataset.knowledge_graph.id
}

output "unstructured_docs_bucket" {
  description = "GCS bucket for ingesting unstructured documents and PDFs"
  value       = google_storage_bucket.unstructured_docs.name
}
