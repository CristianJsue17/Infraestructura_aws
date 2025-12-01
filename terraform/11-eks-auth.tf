# ====================================
# EKS AWS-AUTH CONFIGMAP (CORREGIDO)
# ====================================

resource "kubernetes_config_map" "aws_auth" {
  metadata {
    name      = "aws-auth"
    namespace = "kube-system"
  }

  data = {
    mapRoles = yamlencode([
      {
        rolearn  = aws_iam_role.eks_nodes.arn
        username = "system:node:{{EC2PrivateDNSName}}"
        groups = [
          "system:bootstrappers",
          "system:nodes"
        ]
      },
      {
        rolearn  = aws_iam_role.bastion.arn
        username = "bastion-admin"
        groups = [
          "system:masters"
        ]
      }
    ])

    mapUsers = yamlencode([])
  }

  depends_on = [
    aws_eks_cluster.main,
    aws_eks_node_group.main
  ]

  lifecycle {
    ignore_changes = [
      metadata[0].labels,
      metadata[0].annotations
    ]
  }
}