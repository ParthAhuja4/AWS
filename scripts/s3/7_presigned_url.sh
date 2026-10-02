#!/bin/bash
set -e

# ---------------- 75 — PRESIGNED URL ----------------
# Problem: the bucket is PRIVATE and should stay private, but one person
# with no AWS account needs one file (an invoice, a paid download).
# Making the bucket public (2_public_bucket_policy.sh) is far too much.
#
# A presigned URL = a normal object URL + a SIGNATURE in the query
# string, made with MY credentials. Whoever holds the URL acts as me,
# for that ONE object, for that ONE action, until it expires.

# A separate bucket that was never made public.
awslocal s3 mb s3://my-private-bucket
echo "secret invoice" > /tmp/s3-demo/invoice.txt
awslocal s3 cp /tmp/s3-demo/invoice.txt s3://my-private-bucket/invoice.txt

# --expires-in is in SECONDS. Default 3600 (1 hour), max 604800 (7 days).
# Nothing is sent to AWS here — the CLI computes the signature locally
# from the secret key, so it will happily sign a URL for an object that
# doesn't even exist.
URL=$(awslocal s3 presign s3://my-private-bucket/invoice.txt --expires-in 300)
echo "$URL"

# What the query string contains:
#   X-Amz-Algorithm      AWS4-HMAC-SHA256 (Signature Version 4)
#   X-Amz-Credential     access key id + date/region/service scope
#                        (the access key ID is visible, the SECRET is not)
#   X-Amz-Date           when it was signed
#   X-Amz-Expires        lifetime in seconds
#   X-Amz-SignedHeaders  which headers are covered by the signature
#   X-Amz-Signature      the proof. Change any character of the URL and
#                        it no longer matches -> 403.

# Anyone can now fetch it with no credentials at all.
curl "$URL"

# REAL AWS:
#   - after 300s the same URL returns 403 "Request has expired"
#   - the URL only has the permissions of whoever signed it. If that
#     user loses s3:GetObject, every URL they signed dies instantly.
#   - signed with temporary credentials (an IAM role)? The URL dies when
#     those credentials expire, even if --expires-in was longer.
#   - there is no "revoke" button for a single URL — keep expiry short.
#   - `s3 presign` only makes GET (download) URLs. Presigned PUT URLs,
#     which let a browser upload straight to S3 without passing through
#     your server, are made from an SDK, e.g. boto3:
#       s3.generate_presigned_url("put_object",
#           Params={"Bucket": "my-private-bucket", "Key": "upload.txt"},
#           ExpiresIn=300)
