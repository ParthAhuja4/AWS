awslocal ec2 authorize-security-group-ingress \
    --group-id sg-ef7ea50c901b0c074 \ 
    --protocol tcp \
    --port 22 \
    --cidr 0.0.0.0/0

awslocal ec2 authorize-security-group-egress \
    --group-id sg-ef7ea50c901b0c074 \
    --protocol tcp \
    --port 443 \
    --cidr 0.0.0.0/0
#run this via cli or aws ui.. security group is security config applied to instances

awslocal ec2 modify-instance-attribute --instance-id i-7600548decb4382f0 --groups sg-ef7ea50c901b0c074