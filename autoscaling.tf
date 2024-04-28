provider "aws" {
  region = "us-east-2"
}

# user data to install web server
locals {
  user_data = <<-EOF
                #!/bin/bash
                yum update -y
                yum install -y httpd
                systemctl start httpd
                systemctl enable httpd
                echo "Hello from Instance" > /var/www/html/index.html
              EOF

  user_data_base64 = base64encode(local.user_data)
}



# Create a launch template with user data and security group
resource "aws_launch_template" "web" {
  name_prefix       = "web-template-"
  image_id          = "ami-09b90e09742640522"
  instance_type     = "t2.micro"
  user_data         = local.user_data_base64
  vpc_security_group_ids = [aws_security_group.instance.id]
}

# Create an auto-scaling group with the launch template
resource "aws_autoscaling_group" "web" {
  name                     = "web-asg"
  launch_template {
    id                      = aws_launch_template.web.id
    version                 = "$Latest"
  }
  min_size                 = 2
  max_size                 = 5
  desired_capacity         = 3
  vpc_zone_identifier      = ["subnet-03545f9888da1022f"]  
}



# Create load balancer
resource "aws_lb" "web" {
  name               = "web-lb"
  internal           = false
  load_balancer_type = "application"
  subnets            = ["subnet-03545f9888da1022f", "subnet-00ffd331df33a6489"]  
}

# Create target group
resource "aws_lb_target_group" "web" {
  name     = "web-target-group"
  port     = 80
  protocol = "HTTP"
  vpc_id   = "vpc-0057a7320247e4289" 
}

# Create listener
resource "aws_lb_listener" "web" {
  load_balancer_arn = aws_lb.web.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web.arn
  }
}

# Attach target group to autoscaling group
resource "aws_autoscaling_policy" "web_scale_in_policy" {
  name                   = "web-scale-in-policy"
  scaling_adjustment     = -1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.web.name
}

resource "aws_autoscaling_policy" "web_scale_out_policy" {
  name                   = "web-scale-out-policy"
  scaling_adjustment     = 1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.web.name
}

# Output the DNS name of the load balancer
output "lb_dns_name" {
  value = aws_lb.web.dns_name
}
