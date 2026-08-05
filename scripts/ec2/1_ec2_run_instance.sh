awslocal ec2 run-instances \
  --image-id ami-df5de72bdb3b \
  # ^ Which OS image to boot from (this one = Ubuntu 22.04 in LocalStack)
  #   REAL AWS: you'd use a real AWS AMI ID (different ID, same idea)
  --count 1 \
  --instance-type t2.micro \
  # ^ Hardware size. On LocalStack this is mostly cosmetic (just a Docker
  #   container underneath). REAL AWS: this determines actual CPU/RAM
  #   allocated AND determines your hourly billing rate.
  --key-name my-local-key
  # ^ THIS IS THE ANSWER TO "how does the name link to the .pem file":
  #   It does NOT inject your .pem file anywhere. Instead, AWS looks up the
  #   PUBLIC key it stored under this name (back in Step 1) and hands it to
  #   the instance during boot. The instance's own startup process then
  #   writes that public key into ~/.ssh/authorized_keys on itself.
  #   The "name" only matters at THIS lookup moment — it has zero role
  #   later on when you actually SSH in.
  #   REAL AWS: identical mechanism, done via cloud-init at boot time.
 
awslocal ec2 describe-instances \
  --query 'Reservations[].Instances[].{ID:InstanceId,IP:PublicIpAddress,KeyName:KeyName,State:State.Name}' \
  # ^ QUERY FLAG EXPLAINED:
  #   Raw response shape is nested: Reservations (a list) -> each contains
  #   Instances (another list) -> each Instance is an object with 40+ fields.
  #
  #   Reservations[]   -> [] means "this is a list, iterate through every
  #                        item in it" (square brackets = array in JMESPath)
  #   .Instances[]     -> same idea, one level deeper: iterate every
  #                        instance inside each reservation
  #   .{ID:InstanceId, IP:PublicIpAddress, KeyName:KeyName, State:State.Name}
  #                    -> {} means "build a NEW smaller object with just
  #                        these fields, renamed for readability"
  #                        State.Name works because State is itself a
  #                        nested object ({"Name": "running"}), so we dot
  #                        into it to grab just the Name value
  #   REAL AWS: identical query syntax works the same way — JMESPath
  #   filtering is a feature of the AWS CLI itself, not LocalStack.
  --output table
  # ^ Renders the filtered JSON as a readable ASCII table instead of raw JSON