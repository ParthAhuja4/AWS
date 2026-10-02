#!/bin/bash
set -e

# ---------------- 60 — CREATE BUCKET ----------------

# mb = "make bucket". s3:// is just the CLI's way of saying "this path is
# in S3, not on my local disk".
# Naming rules: 3-63 chars, lowercase letters / numbers / hyphens only,
# no underscores, no uppercase, must start with a letter or number.
# REAL AWS: "my-local-bucket" would almost certainly be TAKEN already by
# someone else — names are global. People usually suffix the account id
# or a random string. On LocalStack any name works.
#
# The low-level equivalent is:
#   awslocal s3api create-bucket --bucket my-local-bucket \
#     --create-bucket-configuration LocationConstraint=ap-south-1
# LocationConstraint is REQUIRED for every region except us-east-1 (and
# must be OMITTED for us-east-1 — a historical quirk). `s3 mb` hides
# that for you.
awslocal s3 mb s3://my-local-bucket

# Make a small file to upload.
mkdir -p /tmp/s3-demo
echo "hello from s3" > /tmp/s3-demo/hello.txt

# cp works like normal cp, one side is local and the other is s3://
# The part after the bucket name is the KEY. "notes/hello.txt" does not
# create a folder called notes — the key is literally the whole string.
# REAL AWS: identical. Files over 8MB are automatically split into a
# multipart upload by the CLI.
awslocal s3 cp /tmp/s3-demo/hello.txt s3://my-local-bucket/hello.txt
awslocal s3 cp /tmp/s3-demo/hello.txt s3://my-local-bucket/notes/hello.txt

# --recursive walks every prefix, otherwise `ls` only shows one "level"
# and prints prefixes as PRE notes/
awslocal s3 ls s3://my-local-bucket --recursive

# Download it back. "-" as the destination means print to stdout.
awslocal s3 cp s3://my-local-bucket/notes/hello.txt -

# Other everyday commands:
#   awslocal s3 sync ./folder s3://my-local-bucket/folder   # only uploads changed files
#   awslocal s3 mv   s3://my-local-bucket/a.txt s3://my-local-bucket/b.txt
#   awslocal s3 rm   s3://my-local-bucket/hello.txt
#   awslocal s3 rb   s3://my-local-bucket --force           # remove bucket; --force empties it first
# A bucket must be EMPTY before it can be deleted.
