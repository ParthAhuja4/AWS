awslocal ec2 authorize-security-group-ingress \
    --group-id sg-dbb5bb89bff554870 \ 
    --protocol tcp \
    --port 22 \
    --cidr 0.0.0.0/0

awslocal ec2 authorize-security-group-egress \
    --group-id sg-dbb5bb89bff554870 \
    --protocol tcp \
    --port 443 \
    --cidr 0.0.0.0/0
#run this via cli or aws ui.. security group is security config applied to instances

awslocal ec2 modify-instance-attribute --instance-id i-20fac50da5366fd31 --groups sg-dbb5bb89bff554870