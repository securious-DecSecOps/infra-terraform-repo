output "ci_instance_id" {
  value = module.ec2.ci_instance_id
}

output "runtime_instance_id" {
  value = module.ec2.runtime_instance_id
}

output "ci_public_ip" {
  value = module.ec2.ci_public_ip
}

output "ci_private_ip" {
  value = module.ec2.ci_private_ip
}

output "runtime_public_ip" {
  value = module.ec2.runtime_public_ip
}

output "runtime_private_ip" {
  value = module.ec2.runtime_private_ip
}

output "jenkins_url" {
  value = "http://${module.ec2.ci_public_ip}:8083"
}

output "harbor_url" {
  value = "http://${module.ec2.ci_public_ip}:8082"
}

output "vulnbank_nodeport_url" {
  value = "http://${module.ec2.runtime_public_ip}:30080"
}

output "ssm_connect_ci" {
  value = "aws ssm start-session --target ${module.ec2.ci_instance_id}"
}

output "ssm_connect_runtime" {
  value = "aws ssm start-session --target ${module.ec2.runtime_instance_id}"
}