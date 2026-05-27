output "ci_security_group_id" {
  value = aws_security_group.ci.id
}

output "runtime_security_group_id" {
  value = aws_security_group.runtime.id
}

output "defectdojo_security_group_id" {
  value = aws_security_group.defectdojo.id
}