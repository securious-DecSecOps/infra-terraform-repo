output "ci_instance_id" {
  value = aws_instance.ci.id
}

output "runtime_instance_id" {
  value = aws_instance.runtime.id
}

output "ci_public_ip" {
  value = aws_instance.ci.public_ip
}

output "ci_private_ip" {
  value = aws_instance.ci.private_ip
}

output "runtime_public_ip" {
  value = aws_instance.runtime.public_ip
}

output "runtime_private_ip" {
  value = aws_instance.runtime.private_ip
}