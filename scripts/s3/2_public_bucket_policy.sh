#!/bin/bash
set -e

# ---------------- 61 — PUBLIC YOUR BUCKET / POLICY GENERATOR ----------------
# Every bucket is PRIVATE by default. Making it public takes TWO steps,
# and forgetting step 1 is the classic "Access Denied even though my
# policy is right" mistake.

# STEP 1: turn off Block Public Access (BPA).
# BPA is a safety switch that sits ABOVE policies — while it's on, any
# public policy is rejected/ignored no matter what it says. 4 settings:
#   BlockPublicAcls / IgnorePublicAcls        -> the old ACL way of going public
#   BlockPublicPolicy / RestrictPublicBuckets -> the bucket policy way
# REAL AWS: all 4 are ON by default for new buckets, and there is ALSO an
# account-level BPA that overrides the bucket-level one.
awslocal s3api put-public-access-block \
  --bucket my-local-bucket \
  --public-access-block-configuration \
  "BlockPublicAcls=false,IgnorePublicAcls=false,BlockPublicPolicy=false,RestrictPublicBuckets=false"

# STEP 2: attach a bucket policy.
# This JSON is exactly what the AWS Policy Generator
# (awspolicygen.s3.amazonaws.com/policygen.html) spits out — it's only a
# form that fills in these fields for you:
#   Effect    -> Allow or Deny
#   Principal -> WHO. "*" = anyone on the internet, no login needed.
#   Action    -> WHAT. s3:GetObject = download/read an object. We do NOT
#                give s3:PutObject or s3:ListBucket — public can read a
#                file if they know its name, not upload or browse.
#   Resource  -> WHICH objects, as an ARN. The "/*" at the end matters:
#                  arn:aws:s3:::my-local-bucket     = the bucket itself
#                  arn:aws:s3:::my-local-bucket/*   = every object in it
#                GetObject is an OBJECT action so it needs the /* form.
#
# This is a RESOURCE-based policy (attached to the bucket, has a
# Principal) as opposed to the IDENTITY-based IAM policies from the IAM
# lesson (attached to a user/role, no Principal).
cat > /tmp/s3-demo/public-policy.json <<'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "PublicReadGetObject",
      "Effect": "Allow",
      "Principal": "*",
      "Action": "s3:GetObject",
      "Resource": "arn:aws:s3:::my-local-bucket/*"
    }
  ]
}
EOF

# file:// tells the CLI to read the argument's value from a local file.
awslocal s3api put-bucket-policy \
  --bucket my-local-bucket \
  --policy file:///tmp/s3-demo/public-policy.json

awslocal s3api get-bucket-policy --bucket my-local-bucket --query Policy --output text

# Plain curl = anonymous request, no credentials, no signature.
# REAL AWS: the URL would be
#   https://my-local-bucket.s3.ap-south-1.amazonaws.com/hello.txt
# and this would return 403 AccessDenied before the two steps above.
# LocalStack (community) does not enforce IAM/bucket policies, so here
# the curl works even without the policy — the commands are still the
# real ones.
curl http://localhost:4566/my-local-bucket/hello.txt
