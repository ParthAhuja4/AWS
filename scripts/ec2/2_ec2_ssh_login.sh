ssh -i my-local-key.pem root@172.17.0.3
# ^ -i my-local-key.pem = "here's my private key, use it to prove who I am"
#   root@172.17.0.3      = username @ server address to log into
#
#   NO NAMES are checked here at all — "my-local-key" as a label is
#   completely irrelevant at this point. SSH purely checks: does the
#   private key I'm offering mathematically match one of the public keys
#   sitting in this server's ~/.ssh/authorized_keys file? If yes -> login
#   succeeds. If no -> rejected. That's it.
#
#   REAL AWS DIFFERENCES:
#   - IP: real AWS gives you a real public IP (or private VPC IP), not an
#     internal Docker bridge IP like 172.17.0.3
#   - Username: depends on the AMI's OS — commonly ec2-user (Amazon Linux),
#     ubuntu (Ubuntu AMIs), admin (Debian) — NOT always "root"
#   - Security Groups are actually enforced on real AWS — port 22 must be
#     explicitly opened in the security group or SSH can't even reach the
#     instance, regardless of whether your key is correct
#   - Reachability: real AWS instances are reachable over the internet (if
#     configured to allow it); LocalStack containers are only reachable
#     from your own machine
 