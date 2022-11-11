terraform {
  required_version = ">= 1.0.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 4.0.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.0.0"
    }
  }
}

resource "aws_iam_role" "cluster" {
  name               = var.eks_cluster_role_name
  assume_role_policy = <<EOF
    {
    "Version": "2012-10-17",
    "Statement": [
        {
        "Effect": "Allow",
        "Principal": {
            "Service": "eks.amazonaws.com"
        },
        "Action": "sts:AssumeRole"
        }
    ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "cluster_AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.cluster.name
}

resource "aws_iam_openid_connect_provider" "oidc" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["9e99a48a9960b14926bb7f3b02e22da2b0ab7280"]
  url             = aws_eks_cluster.cluster.identity[0].oidc[0].issuer
}

provider "kubernetes" {
  host                   = aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(aws_eks_cluster.cluster.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.cluster.token
}
resource "aws_eks_cluster" "cluster" {
  name     = var.cluster_name
  role_arn = aws_iam_role.cluster.arn

  vpc_config {

    subnet_ids              = var.subnet_ids
    endpoint_public_access  = var.endpoint_public_access
    endpoint_private_access = var.endpoint_private_access
  }

  depends_on = [aws_iam_role_policy_attachment.cluster_AmazonEKSClusterPolicy]
}

resource "aws_iam_role" "ebs_csi_controller_role" {
  name = "ebs-csi-controller-role"

  assume_role_policy = <<EOF
  {
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "${aws_iam_openid_connect_provider.oidc.arn}"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "${aws_iam_openid_connect_provider.oidc.url}:sub": "system:serviceaccount:kube-system:ebs-csi-controller-sa"
          }
        }
      }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "ebs_csi_controller_policy" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
  role       = aws_iam_role.ebs_csi_controller_role.name
}
resource "aws_eks_addon" "ebs_csi_driver" {
  addon_name               = "aws-ebs-csi-driver"
  cluster_name             = aws_eks_cluster.cluster.name
  resolve_conflicts        = "OVERWRITE"
  service_account_role_arn = aws_iam_role.ebs_csi_controller_role.arn
  depends_on               = [aws_eks_cluster.cluster]
}


resource "aws_iam_role" "vpc_cni_role" {
  name = "vpc-cni-role"

  assume_role_policy = <<EOF
  {
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "${aws_iam_openid_connect_provider.oidc.arn}"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "${aws_iam_openid_connect_provider.oidc.url}:sub": "system:serviceaccount:kube-system:aws-node"
          }
        }
      }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "vpc_cni_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.vpc_cni_role.name
}

resource "aws_eks_addon" "vpc_cni" {
  addon_name               = "vpc-cni"
  cluster_name             = aws_eks_cluster.cluster.name
  resolve_conflicts        = "OVERWRITE"
  service_account_role_arn = aws_iam_role.vpc_cni_controller_role.arn
  depends_on               = [aws_eks_cluster.cluster]
}

#TODO: add more miscellanous addons

locals {
  cluster_security_group_rules = {
    ingress_api_server = {
      description = "Allow inbound traffic from the internet to the API server"
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
      type        = "ingress"
    }
    ingress_nodes_443 = {
      description              = "Allow nodes to communicate with each other"
      from_port                = 443
      to_port                  = 443
      protocol                 = "tcp"
      source_security_group_id = aws_eks_cluster.cluster.vpc_config[0].cluster_security_group_id
      type                     = "ingress"
    }
    egress_nodes_443 = {
      description              = "Allow nodes to communicate with each other"
      from_port                = 443
      to_port                  = 443
      protocol                 = "tcp"
      source_security_group_id = aws_eks_cluster.cluster.vpc_config[0].cluster_security_group_id
      type                     = "egress"
    }

    ingress_nodes_kubelet = {
      description              = "Allow nodes to communicate with each other"
      from_port                = 10250
      to_port                  = 10250
      protocol                 = "tcp"
      source_security_group_id = aws_eks_cluster.cluster.vpc_config[0].cluster_security_group_id
      type                     = "ingress"
    }
    egress_nodes_kubelet = {
      description              = "Allow nodes to communicate with each other"
      from_port                = 10250
      to_port                  = 10250
      protocol                 = "tcp"
      source_security_group_id = aws_eks_cluster.cluster.vpc_config[0].cluster_security_group_id
      type                     = "egress"
    }
  }
}

resource "aws_security_group" "ng" {
  name        = var.eks_cluster_security_group_name
  description = "Security group for EKS cluster"
  vpc_id      = var.vpc_id
  tags = {
    Name = var.eks_cluster_security_group_name
  }
}

resource "aws_security_group_rule" "ng" {
  for_each = local.cluster_security_group_rules

  security_group_id = aws_security_group.ng.id
  protocol          = each.value.protocol
  from_port         = each.value.from_port
  to_port           = each.value.to_port
  type              = each.value.type

  description              = each.value.description
  cidr_blocks              = try(each.value.cidr_blocks, null)
  source_security_group_id = try(each.value.source_security_group_id, null)
}

locals {
  aws_auth_configmap_data = {
    mapRoles = yamlencode([
      {
        rolearn  = aws_iam_role.ng.arn
        username = "system:node:{{EC2PrivateDNSName}}"
        groups   = ["system:bootstrappers", "system:nodes"]
      }
    ])
    # mapUsers for each user variable
    mapUsers = yamlencode([
      for user in var.aws_auth_map_users : {
        userarn  = user.userarn
        username = user.username
        groups   = ["system:masters"]
      }
    ])
  }
}

resource "kubernetes_config_map" "aws_auth" {
  metadata {
    name      = "aws-auth"
    namespace = "kube-system"
  }
  data = local.aws_auth_configmap_data
  lifecycle {
    ignore_changes = [
      data
    ]
  }
}

resource "kubernetes_config_map_v1_data" "aws_auth" {

  force = true
  metadata {
    name      = "aws-auth"
    namespace = "kube-system"
  }
  data = local.aws_auth_configmap_data
  depends_on = [
    kubernetes_config_map.aws_auth
  ]
}

#TODO: Fix ami version
data "aws_ami" "eks_worker" {
  most_recent = true
  owners      = ["602401143452"] # Amazon
  filter {
    name   = "name"
    values = ["amazon-eks-node-*"]
  }
}

resource "aws_iam_role" "ng" {
  name               = var.eks_node_group_role_name
  assume_role_policy = <<EOF
    {
    "Version": "2012-10-17",
    "Statement": [
        {
        "Effect": "Allow",
        "Principal": {
            "Service": "ec2.amazonaws.com"
        },
        "Action": "sts:AssumeRole"
        }
    ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "ng_AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.ng.name
}

resource "aws_iam_role_policy_attachment" "ng_AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.ng.name
}

resource "aws_iam_role_policy_attachment" "ng_AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.ng.name
}

resource "aws_iam_role_policy_attachment" "ng_AmazonSSMManagedInstanceCore" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.ng.name
}


resource "aws_iam_instance_profile" "ng" {
  name = var.eks_node_group_role_name
  role = aws_iam_role.ng.name
}

locals {
  eks_tag = merge(
    {
      "Name" = var.eks_node_group_instance_name
    },
    {
      "kubernetes.io/cluster/${var.cluster_name}" = "owned"
    },
    {
      "eks:cluster-name" = var.cluster_name
    },
  )
}

data "template_file" "user_data" {
  template = file("${path.module}/templates/userdata.tpl")
  vars = {
    cluster_name     = aws_eks_cluster.cluster.name
    cluster_endpoint = aws_eks_cluster.cluster.endpoint
    cluster_ca       = aws_eks_cluster.cluster.certificate_authority[0].data
  }
}

resource "aws_launch_template" "lt" {
  name          = var.eks_node_group_launch_template_name
  ebs_optimized = true
  key_name      = var.eks_node_group_key
  image_id      = data.aws_ami.eks_worker.id
  vpc_security_group_ids = [
    aws_security_group.ng.id,
    aws_eks_cluster.cluster.vpc_config[0].cluster_security_group_id,
  ]
  user_data = base64encode(
    data.template_file.user_data.rendered
  )

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size           = var.eks_node_group_launch_template_volume_size
      volume_type           = "gp3"
      delete_on_termination = true
    }
  }
  tag_specifications {
    resource_type = "instance"
    tags          = local.eks_tag
  }

  lifecycle {
    create_before_destroy = true
    ignore_changes = [
      tag_specifications,
      name,
      image_id
    ]
  }
}

# locals {
#   ami_type = var.eks_node_group_launch_template_ami_type == "AL2_x86_64" ? "AL2_x86_64" : "AL2_x86_64_GPU"
# }

#TODO: Add loop for multiple node groups - GPU equipped and non GPU equipped
resource "aws_eks_node_group" "ng" {
  cluster_name    = aws_eks_cluster.cluster.name
  node_group_name = var.eks_node_group_name
  node_role_arn   = aws_iam_role.ng.arn
  subnet_ids      = var.subnet_ids
  instance_types  = var.eks_node_group_instance_types
  ami_type        = var.ami_type
  scaling_config {
    desired_size = var.eks_node_group_desired_size
    max_size     = var.eks_node_group_max_size
    min_size     = var.eks_node_group_min_size
  }

  launch_template {
    id      = aws_launch_template.lt.id
    version = aws_launch_template.lt.latest_version
  }
  lifecycle {
    create_before_destroy = true
    ignore_changes = [
      #scaling_config[0].desired_size
    ]
  }

  depends_on = [
    aws_iam_instance_profile.ng,
    aws_iam_role.ng,
    aws_launch_template.lt,
  ]
}

#TODO: Add GPU node group

# data "aws_ami" "eks_worker_gpu" {
#   most_recent = true
#   owners      = ["602401143452"] # Amazon
#   filter {
#     name   = "name"
#     values = ["amazon-eks-gpu-node-*"]
#   }
# }

# resource "aws_launch_template" "lt_gpu" {
#   name          = var.eks_node_group_launch_template_name_gpu
#   ebs_optimized = true
#   key_name      = var.eks_node_group_key
#   image_id      = data.aws_ami.eks_worker.id
#   vpc_security_group_ids = [
#     aws_security_group.ng.id,
#     aws_eks_cluster.cluster.vpc_config[0].cluster_security_group_id,
#   ]
#   user_data = base64encode(
#     data.template_file.user_data.rendered
#   )
#
#   block_device_mappings {
#     device_name = "/dev/xvda"
#     ebs {
#       volume_size           = var.eks_node_group_launch_template_volume_size
#       volume_type           = "gp3"
#       delete_on_termination = true
#     }
#   }
#   tag_specifications {
#     resource_type = "instance"
#     tags          = local.eks_tag
#   }
#
#   lifecycle {
#     create_before_destroy = true
#     ignore_changes = [
#       tag_specifications,
#       name,
#       image_id
#     ]
#   }
# }

# resource "aws_eks_node_group" "ng_gpu" {
#   cluster_name    = aws_eks_cluster.cluster.name
#   node_group_name = var.eks_node_group_name_gpu
#   node_role_arn   = aws_iam_role.ng.arn
#   subnet_ids      = var.subnet_ids
#   instance_types  = var.eks_node_group_instance_types_gpu
#   ami_type        = var.ami_type_gpu
#   scaling_config {
#     desired_size = var.eks_node_group_desired_size_gpu
#     max_size     = var.eks_node_group_max_size_gpu
#     min_size     = var.eks_node_group_min_size_gpu
#   }
#
#   launch_template {
#     id      = aws_launch_template.lt.id
#     version = aws_launch_template.lt.latest_version
#   }
#   lifecycle {
#     create_before_destroy = true
#     ignore_changes = [
#       #scaling_config[0].desired_size
#     ]
#   }
#
#   depends_on = [
#     aws_iam_instance_profile.ng,
#     aws_iam_role.ng,
#     aws_launch_template.lt,
#   ]
# }

