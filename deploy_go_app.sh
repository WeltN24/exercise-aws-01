#! /bin/sh

# Due to basic requirements for building this environment we are choosing the AWS Elastic Beanstalk service
# (and deploying it via AWS EB CLI):
# - Go application - nginx based reverse proxy maps the application to the load balancer
# - highly available - will deploy AWS Elasti Load Balancer and EC2 instances in Auto Scaling Group
# - log aggregation - AWS CloudWatch Logs

# Create the application home directory

mkdir welt24go
cd welt24go

# Initialize the git repository

sudo git init

# Fetch from remote repository and integrate local

sudo git pull https://github.com/cristidas/exercise-aws-01.git

# Commit changes to the local repository

sudo git commit "Initial commit"

# Configure the AWS EB CLI and the project

eb init -p "Go 1.6" -r us-west-2 w24new

# Create the AWS Elastic Beanstalk environment

eb create w24newenv -d --elb-type classic

# Enable AWS CloudWatch logs

eb logs -cw

