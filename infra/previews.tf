module "site_previews" {
  source = "./modules/site-previews"

  bucket_name = "lj-previews"
  domain_name = "preview.${local.domain}"
}
