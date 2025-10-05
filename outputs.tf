#output "instance_ami" {
#  value = aws_instance.web.ami
#}

#output "instance_arn" {
#  value = aws_instance.web.arn
#}

#output "blog_target_group_arns" {
#  value = try([module.blog_alb.target_groups.blog.arn], [])
#}
