terraform {
  backend "gcs" {
    bucket  = "klemen-lokar-bucket-tfstate"
    prefix = "terraform/state"
  }
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "4.39.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "4.55.0"
    }
    alicloud = {
      source = "aliyun/alicloud"
    }
    random = {
      source  = "hashicorp/random"
      version = "3.4.3"
    }
  }
}

locals {
  project_id    = "gcp-competence-group"
  provider_location = "europe-west1"
  service_account = "gh-actions-klemen@gcp-competence-group.iam.gserviceaccount.com"
  repository = "gcp-cg-example"
}

provider "google" {
  project = local.project_id
  region  = local.provider_location
}

resource "random_id" "provider_id" {
  byte_length = 4
}

resource "google_iam_workload_identity_pool" "github_pool" {
  project                   = local.project_id
  workload_identity_pool_id = "github-pool"
  display_name              = "Github Provider Pool"
  description               = "Identity pool for Github pipelines"
  disabled                  = false
}

resource "google_iam_workload_identity_pool_provider" "github_provider" {
  project                            = local.project_id
  workload_identity_pool_id          = google_iam_workload_identity_pool.github_pool.workload_identity_pool_id
  workload_identity_pool_provider_id = "github-provider"
  display_name                       = "Github Actions provider"
  description                        = "OIDC identity pool provider for automated pipeline"
  disabled                           = false
  attribute_mapping = {
    "google.subject"       = "assertion.sub"
    "attribute.actor"      = "assertion.actor"
    "attribute.repository" = "assertion.repository"
  }
  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}

resource "google_service_account_iam_binding" "service-account-wif-binding" {

  service_account_id = "projects/${local.project_id}/serviceAccounts/${local.service_account}"
  role               = "roles/iam.workloadIdentityUser"
  members            = tolist(["principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github_pool.name}/attribute.repository/klokar/${local.repository}"])
}
