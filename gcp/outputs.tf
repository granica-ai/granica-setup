output "ssh_command" {
  value = "gcloud compute ssh ${google_compute_instance.vm_instance.name} --zone ${google_compute_instance.vm_instance.zone} --tunnel-through-iap"
}

output "scp_command_prefix" {
  value = "gcloud compute scp --zone ${google_compute_instance.vm_instance.zone} --tunnel-through-iap"
}

output "adminsrv_instance_name" {
  value = google_compute_instance.adminsrv_instance.name
}
