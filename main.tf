data "aws_ami" "app_ami" {
  most_recent = true

  filter {
    name   = "name"
    values = ["bitnami-tomcat-*-x86_64-hvm-ebs-nami"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["979382823631"] # Bitnami
}

#resource "aws_instance" "blog" {
#  ami           = data.aws_ami.app_ami.id
#  instance_type = var.instance_type

#  tags = {
#    Name = "HelloWorld"
# }
#}

module "blog_vpc" {
  source = "terraform-aws-modules/vpc/aws"
  version = "~> 6.0"

  name = "dev"
  cidr = "10.0.0.0/16"

  azs            = ["us-west-2a", "us-west-2b", "us-west-2c"]
  public_subnets = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

  tags = {
    Terraform   = "true"
    Environment = "dev"
  }
}

resource "aws_launch_template" "blog" {
  name_prefix   = "blog-"
  image_id      = data.aws_ami.app_ami.id
  instance_type = var.instance_type

  network_interfaces {
    security_groups = [module.blog_sg.security_group_id]
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "blog-instance"
    }
  }

}


#module "blog_autoscaling" {
#  source  = "terraform-aws-modules/autoscaling/aws"
#  version = "~> 9.0"

#  name = "blog"

#  min_size            = 1
#  max_size            = 2
#  vpc_zone_identifier = module.blog_vpc.public_subnets
  # REMOVE: security_groups = [module.blog_sg.security_group_id]
  # REMOVE: instance_type = var.instance_type
  # REMOVE: image_id = data.aws_ami.app_ami.id

  # ADD: Tell the ASG module to use your external Launch Template
  #launch_template {
  #  id      = aws_launch_template.blog.id
  #  version = "$Latest" # Le indicamos que siempre use la última versión de tu plantilla
  #}

#  launch_template_id = aws_launch_template.blog.id
#  launch_template_version = "$Latest"

  
#}

resource "aws_autoscaling_group" "blog" {
  name                  = "blog"
  min_size              = 1
  max_size              = 2
  vpc_zone_identifier   = module.blog_vpc.public_subnets

  # Esta sintaxis es la estándar de Terraform, ¡siempre funciona!
  target_group_arns     = [module.blog_alb.target_group_arns[0]] 

  launch_template {
    id      = aws_launch_template.blog.id
    version = "$Latest"
  }
}

module "blog_alb" {
  source  = "terraform-aws-modules/alb/aws"
  version = "~> 7.0"

  name               = "blog-alb"
  load_balancer_type = "application"

  vpc_id          = module.blog_vpc.vpc_id
  subnets         = module.blog_vpc.public_subnets
  security_groups = [module.blog_sg.security_group_id]

  http_tcp_listeners = [
    {
      port               = 80
      protocol           = "HTTP"
      target_group_index = 0
    }
  ]

  target_groups = [
    {
      name_prefix      = "blog-"
      backend_protocol = "HTTP"
      backend_port     = 80
      target_type      = "instance"
    }
  ]

  tags = {
    Environment = "dev"
  }
}


module "blog_sg" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 5.0"

  vpc_id              = module.blog_vpc.vpc_id
  name                = "blog"
  ingress_rules       = ["https-443-tcp", "http-80-tcp"]
  ingress_cidr_blocks = ["0.0.0.0/0"]
  egress_rules        = ["all-all"]
  egress_cidr_blocks  = ["0.0.0.0/0"]
}
