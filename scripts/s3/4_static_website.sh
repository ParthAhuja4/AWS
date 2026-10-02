#!/bin/bash
set -e

# ---------------- 64 — HOST STATIC WEBSITE IN S3 ----------------
# S3 can serve a bucket as a website — no EC2, no nginx (compare with
# ec2/3_nginx_install.sh). STATIC only: html/css/js/images. Nothing runs
# on the server, so no PHP/Node/Python backends.
#
# Needs 3 things:
#   1. the files uploaded
#   2. website hosting turned on (index + error document)
#   3. the bucket publicly readable (done in 2_public_bucket_policy.sh)

mkdir -p /tmp/s3-demo/site
echo "<h1>Hello from my S3 website</h1>" > /tmp/s3-demo/site/index.html
echo "<h1>404 - nothing here</h1>" > /tmp/s3-demo/site/error.html

# sync = upload only what's new/changed. Re-run it after editing the
# site and only the edited files go up.
# The CLI guesses Content-Type from the file extension (.html ->
# text/html). If that header is wrong the browser DOWNLOADS the file
# instead of rendering it.
awslocal s3 sync /tmp/s3-demo/site s3://my-local-bucket

# --index-document = file served for "/" (and for any "folder/" path)
# --error-document = file served on a 4xx, e.g. a key that doesn't exist
awslocal s3 website s3://my-local-bucket \
  --index-document index.html \
  --error-document error.html

awslocal s3api get-bucket-website --bucket my-local-bucket

# The WEBSITE endpoint is a different URL from the normal REST endpoint.
# Only the website endpoint understands index/error documents.
# REAL AWS: http://my-local-bucket.s3-website.ap-south-1.amazonaws.com
#   - website endpoints are HTTP only. For HTTPS + a custom domain you
#     put CloudFront in front of the bucket.
#   - to use your own domain directly with Route 53, the bucket name
#     must exactly equal the domain (bucket "www.example.com").
curl http://my-local-bucket.s3-website.localhost.localstack.cloud:4566/
curl http://my-local-bucket.s3-website.localhost.localstack.cloud:4566/does-not-exist
