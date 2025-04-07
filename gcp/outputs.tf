output "ssh_command" {
  value = "gcloud compute ssh granica-admin-server-${var.server_name} --project=${var.project_id} --zone ${google_compute_instance.vm_instance.zone} --tunnel-through-iap"
}

output "scp_command_prefix" {
  value = "gcloud compute scp granica-admin-server-${var.server_name} --project=${var.project_id} --zone ${google_compute_instance.vm_instance.zone} --tunnel-through-iap"
}

output "adminsrv_instance_name" {
  value = google_compute_instance.vm_instance.name
}
