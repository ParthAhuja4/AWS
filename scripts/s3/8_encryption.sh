#!/bin/bash
set -e

# ---------------- 76 — ENCRYPTION: AT REST, SERVER-SIDE, CLIENT-SIDE ----------------
# Two moments data needs protecting:
#   IN TRANSIT -> while travelling to/from S3. Solved by HTTPS (TLS).
#   AT REST    -> while sitting on S3's disks. Solved by the options
#                 below. They differ in ONE thing: who holds the key and
#                 who does the encrypting.
#
#   SERVER-SIDE (SSE): you send plain data over HTTPS, S3 encrypts it
#   before writing to disk and decrypts it when you read it back.
#     SSE-S3   key owned + managed by S3. AES-256. Zero effort, free.
#              THE DEFAULT for every new object since Jan 2023.
#     SSE-KMS  key lives in KMS. You control who may use the key, can
#              rotate/disable it, and every use is logged in CloudTrail.
#              Reader needs s3:GetObject AND kms:Decrypt.
#     SSE-C    YOU supply the key on every request. S3 uses it, then
#              forgets it. Lose the key = lose the data.
#
#   CLIENT-SIDE: you encrypt BEFORE uploading. S3 only ever sees
#   gibberish and never has the key.

echo "confidential" > /tmp/s3-demo/secret.txt

# ---- SSE-S3 ----
# --sse AES256 = "S3, encrypt this with your own managed key".
awslocal s3 cp /tmp/s3-demo/secret.txt s3://my-private-bucket/sse-s3.txt --sse AES256

# head-object = fetch only the metadata. ServerSideEncryption says which
# kind was used.
awslocal s3api head-object \
  --bucket my-private-bucket \
  --key sse-s3.txt \
  --query ServerSideEncryption

# ---- SSE-KMS ----
# Create a customer-managed KMS key and keep its id.
# REAL AWS: a customer-managed key costs ~$1/month plus per-request
# fees. Skipping --sse-kms-key-id uses the free AWS-managed key
# "aws/s3" instead.
KEY_ID=$(awslocal kms create-key \
  --description "s3 demo key" \
  --query KeyMetadata.KeyId \
  --output text)

awslocal s3 cp /tmp/s3-demo/secret.txt s3://my-private-bucket/sse-kms.txt \
  --sse aws:kms \
  --sse-kms-key-id "$KEY_ID"

awslocal s3api head-object \
  --bucket my-private-bucket \
  --key sse-kms.txt \
  --query '{Encryption:ServerSideEncryption,KmsKey:SSEKMSKeyId}'

# ---- SSE-C ----
# A random 32-byte (256-bit) key that only we have.
# fileb:// = read the file as raw BINARY (file:// would treat it as text).
# REAL AWS: SSE-C requests are rejected over plain HTTP — HTTPS is
# mandatory because the key itself travels in the request headers.
openssl rand -out /tmp/s3-demo/sse-c.key 32

awslocal s3 cp /tmp/s3-demo/secret.txt s3://my-private-bucket/sse-c.txt \
  --sse-c AES256 \
  --sse-c-key fileb:///tmp/s3-demo/sse-c.key

# The SAME key must be sent again to read it. Without the two --sse-c
# flags this download fails with 400 Bad Request.
awslocal s3 cp s3://my-private-bucket/sse-c.txt - \
  --sse-c AES256 \
  --sse-c-key fileb:///tmp/s3-demo/sse-c.key

# ---- DEFAULT BUCKET ENCRYPTION ----
# Instead of remembering --sse on every upload, set the bucket default.
# BucketKeyEnabled = S3 caches a short-lived bucket-level key so it
# doesn't call KMS for every single object (big cut in KMS cost).
awslocal s3api put-bucket-encryption \
  --bucket my-private-bucket \
  --server-side-encryption-configuration "{
    \"Rules\": [{
      \"ApplyServerSideEncryptionByDefault\": {
        \"SSEAlgorithm\": \"aws:kms\",
        \"KMSMasterKeyID\": \"$KEY_ID\"
      },
      \"BucketKeyEnabled\": true
    }]
  }"

awslocal s3api get-bucket-encryption --bucket my-private-bucket

# ---- CLIENT-SIDE ----
# Encrypt locally with openssl, upload the encrypted file. To S3 this is
# just an ordinary object full of random-looking bytes.
#   -pbkdf2 = derive the real key from the password properly
#   -pass   = the password (hardcoded here ONLY because it's a demo)
openssl enc -aes-256-cbc -pbkdf2 \
  -in /tmp/s3-demo/secret.txt \
  -out /tmp/s3-demo/secret.txt.enc \
  -pass pass:my-demo-password

awslocal s3 cp /tmp/s3-demo/secret.txt.enc s3://my-private-bucket/client-side.txt.enc

# Download and decrypt (-d) with the same password.
awslocal s3 cp s3://my-private-bucket/client-side.txt.enc /tmp/s3-demo/downloaded.enc
openssl enc -d -aes-256-cbc -pbkdf2 \
  -in /tmp/s3-demo/downloaded.enc \
  -pass pass:my-demo-password

# REAL AWS: client-side is normally done with the S3 Encryption Client
# in an SDK (it can keep the key in KMS) rather than raw openssl.
#
# To FORCE encryption in transit, add a bucket policy statement that
# Denies everything when the request is not HTTPS:
#   "Effect": "Deny", "Principal": "*", "Action": "s3:*",
#   "Resource": ["arn:aws:s3:::my-private-bucket", "arn:aws:s3:::my-private-bucket/*"],
#   "Condition": { "Bool": { "aws:SecureTransport": "false" } }
