variable "eks_cluster_role_name" {
  description = "The name of the EKS cluster role"
  type        = string
}

variable "cluster_name" {
  description = "The name of the EKS cluster"
  type        = string
}

variable "subnet_ids" {
  description = "The subnet IDs to use for the EKS cluster"
  type        = list(string)
}

variable "endpoint_public_access" {
  description = "Whether or not the Amazon EKS public API server endpoint is enabled"
  type        = bool
  default     = true
}

variable "endpoint_private_access" {
  description = "Whether or not the Amazon EKS private API server endpoint is enabled"
  type        = bool
  default     = true
}

variable "vpc_id" {
  description = "The VPC ID"
  type        = string
}

variable "eks_cluster_security_group_name" {
  description = "The name of the EKS cluster security group"
  type        = string
}

variable "eks_node_group_name" {
  description = "The name of the EKS node group"
  type        = string
}

variable "eks_node_group_key" {
  description = "The ssh key of the EKS cluster node group"
  type        = string
}

variable "eks_node_group_instance_types" {
  description = "The instance type to use for the EKS node group"
  type        = list(string)
}

variable "eks_node_group_launch_template_name" {
  description = "The name of the EKS node group launch template"
  type        = string
}

variable "eks_node_group_launch_template_volume_size" {
  description = "The size of the EKS node group launch template volume"
  type        = number
}

variable "eks_node_group_launch_template_volume_type" {
  type        = string
  description = "value for the EKS node group launch template volume type"
}

variable "ami_type" {
  type        = string
  description = "value for the EKS node group launch template AMI type"
  default     = "CUSTOM"
}

variable "eks_node_group_instance_name" {
  type        = string
  description = "value for the EKS node group instance name"
}

variable "eks_node_group_role_name" {
  description = "The name of the EKS node group role"
  type        = string
}

variable "eks_node_group_desired_size" {
  description = "The desired size of the EKS node group"
  type        = number
}

variable "eks_node_group_min_size" {
  description = "The minimum size of the EKS node group"
  type        = number
}

variable "eks_node_group_max_size" {
  description = "The maximum size of the EKS node group"
  type        = number
}

variable "aws_auth_map_users" {
  description = "A list of maps of AWS IAM users and their Kubernetes roles"
  type        = list(map(string))
  default     = []
}

#TODO: Add boolean variable to decide if we want to create the EKS cluster with GPU nodes or not
