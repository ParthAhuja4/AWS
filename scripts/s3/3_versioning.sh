#!/bin/bash
set -e

# ---------------- 63 — S3 VERSIONING ----------------
# Without versioning, uploading to an existing key OVERWRITES it and
# deleting it is permanent. With versioning, S3 keeps every version of
# every object, each with its own VersionId.
#
# A bucket is in one of 3 states:
#   Unversioned (default) -> Enabled -> Suspended
# Once enabled it can NEVER go back to unversioned, only Suspended
# (stops creating new versions, keeps the old ones).
# REAL AWS: identical. Remember every version is billed as a full
# object — pair versioning with a lifecycle rule (see 6_lifecycle.sh).
awslocal s3api put-bucket-versioning \
  --bucket my-local-bucket \
  --versioning-configuration Status=Enabled

awslocal s3api get-bucket-versioning --bucket my-local-bucket

# Upload the same key twice with different content -> 2 versions.
echo "version 1" > /tmp/s3-demo/doc.txt
awslocal s3 cp /tmp/s3-demo/doc.txt s3://my-local-bucket/doc.txt
echo "version 2" > /tmp/s3-demo/doc.txt
awslocal s3 cp /tmp/s3-demo/doc.txt s3://my-local-bucket/doc.txt

# A normal GET always returns the LATEST version.
awslocal s3 cp s3://my-local-bucket/doc.txt -

# list-object-versions shows the history. IsLatest marks the current one.
# Objects uploaded BEFORE versioning was enabled show VersionId "null".
awslocal s3api list-object-versions \
  --bucket my-local-bucket \
  --prefix doc.txt \
  --query 'Versions[].{Key:Key,VersionId:VersionId,Latest:IsLatest}' \
  --output table

# Grab the OLDEST version's id ([-1] = last item, list is newest-first)
# and read that specific version.
OLD_VERSION=$(awslocal s3api list-object-versions \
  --bucket my-local-bucket \
  --prefix doc.txt \
  --query 'Versions[-1].VersionId' \
  --output text)

awslocal s3api get-object \
  --bucket my-local-bucket \
  --key doc.txt \
  --version-id "$OLD_VERSION" \
  /tmp/s3-demo/doc-old.txt
cat /tmp/s3-demo/doc-old.txt

# DELETE on a versioned bucket does NOT delete anything. It adds a
# DELETE MARKER — a zero-byte placeholder that becomes the "latest
# version", so a normal GET now returns 404. All the real versions are
# still underneath.
awslocal s3 rm s3://my-local-bucket/doc.txt

awslocal s3api list-object-versions \
  --bucket my-local-bucket \
  --prefix doc.txt \
  --query '{Versions:Versions[].VersionId,DeleteMarkers:DeleteMarkers[].VersionId}'

# UNDELETE = delete the delete marker. Deleting WITH a --version-id is a
# real, permanent delete of that one version (here: the marker).
MARKER=$(awslocal s3api list-object-versions \
  --bucket my-local-bucket \
  --prefix doc.txt \
  --query 'DeleteMarkers[0].VersionId' \
  --output text)

awslocal s3api delete-object \
  --bucket my-local-bucket \
  --key doc.txt \
  --version-id "$MARKER"

# Back from the dead — prints "version 2".
awslocal s3 cp s3://my-local-bucket/doc.txt -

# REAL AWS extra: MFA Delete can be turned on so permanently deleting a
# version needs an MFA code. Only the root user can enable it.
