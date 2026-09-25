output "folders" {
  description = "Folder resource names by key."
  value       = { for k, f in google_folder.top : k => f.name }
}

output "tag_values" {
  description = "Tag value IDs (tagValues/...) by key/value, for bindings in later stages."
  value       = { for k, v in google_tags_tag_value.this : k => v.id }
}

output "tag_keys" {
  value = { for k, v in google_tags_tag_key.this : k => v.id }
}
