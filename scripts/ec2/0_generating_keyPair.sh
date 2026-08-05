awslocal ec2 create-key-pair \
  --key-name my-local-key \
  # ^ This is just a LABEL for AWS to remember this key pair by.
  #   AWS generates a PRIVATE key + PUBLIC key pair right now.
  #   The private key is sent back to us ONE TIME ONLY in the API response.
  #   The public key is what AWS keeps stored internally, tagged with this name.
  #   REAL AWS: identical — same command, same behavior, real key pair created
  #   in your real AWS account instead of LocalStack's fake one.
  --query 'KeyMaterial' \
  # ^ The raw API response is big nested JSON with many fields.
  #   'KeyMaterial' is the ONE field that holds the actual private key text.
  #   --query uses JMESPath to pull out just that field.
  #   No [] needed here because KeyMaterial is a single string, not a list.
  --output text > my-local-key.pem
  # ^ --output text = print the raw private key text, not JSON-quoted/escaped
  #     (JSON would wrap it in quotes and break the key format)
  #   > my-local-key.pem = redirect that output into a new file instead of
  #     printing it to the screen. This file IS our private key from now on.
  #   REAL AWS: same — but on real AWS, if you lose this .pem file, it's gone
  #   forever. AWS never stores or re-shows your private key after this moment.
 
chmod 400 my-local-key.pem
# ^ Restricts the file so ONLY you (the owner) can read it, nobody can write
#   or execute it. SSH will flat-out REFUSE to use a key file if permissions
#   are too open — this is a mandatory security check, not optional.
#   REAL AWS: identical requirement — SSH enforces this the same way
#   regardless of whether the server is LocalStack or real AWS.