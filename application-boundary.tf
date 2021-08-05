data "cloudfoundry_space" "broker_space" {
  name     = var.broker_space.space
  org_name = var.broker_space.org
}

module "broker_eks" {
  source = "./broker"

  name                  = "ssb-eks"
  path                  = "./app-eks"
  broker_space          = var.broker_space
  client_spaces         = var.client_spaces
  enable_ssh            = var.enable_ssh
  memory                = 512
  aws_access_key_id     = var.aws_access_key_id
  aws_secret_access_key = var.aws_secret_access_key
  aws_zone              = var.broker_zone
  depends_on = [
    aws_route53_zone.zone
  ]
}

module "broker_smtp" {
  source = "./broker"

  name                  = "ssb-smtp"
  path                  = "./app-smtp"
  broker_space          = var.broker_space
  client_spaces         = var.client_spaces
  enable_ssh            = var.enable_ssh
  aws_access_key_id     = var.aws_access_key_id
  aws_secret_access_key = var.aws_secret_access_key
  aws_zone              = var.broker_zone
  depends_on = [
    aws_route53_zone.zone
  ]
}

# This is the back-end k8s instance to be used by the ssb-solr app
resource "cloudfoundry_service_instance" "k8s_cluster" {
  name         = "ssb-solr-k8s"
  space        = data.cloudfoundry_space.broker_space.id
  service_plan = module.broker_eks.plans["aws-eks-service/raw"]
  tags         = ["k8s"]
  json_params  = "{ \"subdomain\": \"k8s-brokered\" }"
  timeouts {
    create = "40m"
    update = "90m" # in case of an EKS destroy/create
    delete = "30m"
  }
  depends_on = [
    module.broker_eks
  ]

}

module "broker_solr" {
  source = "./broker"

  name          = "ssb-solr"
  path          = "./app-solr"
  broker_space  = var.broker_space
  client_spaces = var.client_spaces
  enable_ssh    = var.enable_ssh
  services      = [cloudfoundry_service_instance.k8s_cluster.id]
}