output "service_accounts" {
  value = {
    for key, sa in google_service_account.workload_gsa :
    key => {
      email = sa.email
      name  = sa.name
    }
  }
}