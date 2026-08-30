resource "aws_iam_role" "demo-node" {
  name = "wezvatech-eks-demo-node"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "demo-node-AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.demo-node.name
}

resource "aws_iam_role_policy_attachment" "demo-node-AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.demo-node.name
}

resource "aws_iam_role_policy_attachment" "demo-node-AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.demo-node.name
}

# --------------------------------------------------
# SYSTEM APPS NODE GROUPS
# --------------------------------------------------
resource "aws_eks_node_group" "system_apps_blue" {
  # Keep defined while 'blue' is active or being drained
  count           = var.node_color == "blue" || var.node_color == "both" ? 1 : 0
  cluster_name    = aws_eks_cluster.demo.name
  node_group_name = "system-apps-pool-blue"
  node_role_arn   = aws_iam_role.demo-node.arn
  subnet_ids      = data.aws_subnets.default.ids

  instance_types = ["t3.medium"]

  scaling_config {
    desired_size = 1
    max_size     = 3
    min_size     = 1
  }

  depends_on = [
    aws_iam_role_policy_attachment.demo-node-AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.demo-node-AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.demo-node-AmazonEC2ContainerRegistryReadOnly,
  ]
}

resource "aws_eks_node_group" "system_apps_green" {
  count           = var.node_color == "green" || var.node_color == "both" ? 1 : 0
  cluster_name    = aws_eks_cluster.demo.name
  node_group_name = "system-apps-pool-green"
  node_role_arn   = aws_iam_role.demo-node.arn
  subnet_ids      = data.aws_subnets.default.ids

  instance_types = ["t3.medium"]

  scaling_config {
    desired_size = 1
    max_size     = 3
    min_size     = 1
  }

  depends_on = [
    aws_iam_role_policy_attachment.demo-node-AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.demo-node-AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.demo-node-AmazonEC2ContainerRegistryReadOnly,
  ]
}

# --------------------------------------------------
# ML GPU NODE GROUPS
# --------------------------------------------------
resource "aws_eks_node_group" "ml_gpu_blue" {
  count           = var.node_color == "blue" || var.node_color == "both" ? 1 : 0
  cluster_name    = aws_eks_cluster.demo.name
  node_group_name = "ml-gpu-pool-blue"
  node_role_arn   = aws_iam_role.demo-node.arn
  subnet_ids      = data.aws_subnets.default.ids

  instance_types = ["t2.medium"]

  scaling_config {
    desired_size = 1
    max_size     = 2
    min_size     = 0
  }

  taint {
    key    = "dedicated"
    value  = "ml-inference"
    effect = "NO_SCHEDULE"
  }

  depends_on = [
    aws_iam_role_policy_attachment.demo-node-AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.demo-node-AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.demo-node-AmazonEC2ContainerRegistryReadOnly,
  ]
}

resource "aws_eks_node_group" "ml_gpu_green" {
  count           = var.node_color == "green" || var.node_color == "both" ? 1 : 0
  cluster_name    = aws_eks_cluster.demo.name
  node_group_name = "ml-gpu-pool-green"
  node_role_arn   = aws_iam_role.demo-node.arn
  subnet_ids      = data.aws_subnets.default.ids

  instance_types = ["t3.medium"] # Can upgrade instance types/AMI here if needed

  scaling_config {
    desired_size = 1
    max_size     = 2
    min_size     = 0
  }

  taint {
    key    = "dedicated"
    value  = "ml-inference"
    effect = "NO_SCHEDULE"
  }

  depends_on = [
    aws_iam_role_policy_attachment.demo-node-AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.demo-node-AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.demo-node-AmazonEC2ContainerRegistryReadOnly,
  ]
}

resource "null_resource" "update_kubeconfig" {
  depends_on = [
    aws_eks_cluster.demo
  ]

  provisioner "local-exec" {
    command = "aws eks update-kubeconfig --name ${var.cluster_name} --region ${var.aws_region}"
  }
}
