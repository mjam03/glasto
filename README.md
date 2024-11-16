# Glasto

Quick description:
 - this is a terraform script to create virtual machines in a variety of regions in Microsoft Azure
 - the script runs using Terraform
 - glastonbury can detect when you create a browser using code so you need to manually start the browser instances

## Setup

Download this repo using git clone

[Terraform](https://developer.hashicorp.com/terraform/install) - install this which is what runs the script

Windows App Viewer - this is what you use to RDP into the machines and you get it from the app store

Create a `terraform.tfvars` file in the repo with:

```
my_ip = "<insert IP here>/32"
pwd = "password_here_for_remote_connections"
```

## How to

 - open a terminal in this repo and run `terraform init`
 - then run `terraform apply -auto-approve` to run the script - this should start to create the resources in azure
 - go to your azure console and check that virtual machines are being created
 - open Windows App Viewer and in the top right corner click to add a PC
 - you will see the public IP addresses of the virtual machines in the azure console and you enter one in the top
 - click to add credentials which will be:
   - azureadmin as username
   - your password from the `terraform.tfvars` file
 - click on your new connection to open it and then you should be in to your virtual machine
 - once your in then you should be able to open your browsers and connect
