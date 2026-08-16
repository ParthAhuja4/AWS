awslocal ec2 create-volume \
  --availability-zone ap-south-1 \
  --size 10 \
  --volume-type gp2

#--size 10 means 10GB

# returns:
# {
#     "VolumeType": "gp2",
#     "VolumeId": "vol-e82e121c6c8e82689",
#     "Size": 10,
#     "SnapshotId": "",
#     "State": "creating",
#     "CreateTime": "2026-08-16T14:18:54+00:00",
#     "Encrypted": false
# }