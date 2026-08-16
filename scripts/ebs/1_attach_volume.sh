awslocal ec2 attach-volume \
  --volume-id vol-9c3f2eed0f1527438 \
  --instance-id i-7600548decb4382f0 \
  --device /dev/sdf

  # # The --device flag specifies where the volume should appear inside the instance's operating system — essentially, what device
  # name the OS should use to reference that attached volume.

awslocal ec2 describe-volumes --volume-ids vol-9c3f2eed0f1527438

# snapshots can and should be also made peroidically of the ebs so that the data is not lost