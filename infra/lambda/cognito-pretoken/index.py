"""Cognito pre-token-generation trigger: stamp the caller's IAM Identity Center
group memberships onto the token as `cognito:groups`.

IdC SAML assertions can't carry group *names* (only opaque GUIDs, unofficially),
so federation alone can't populate groups. Here we resolve them directly: the
federated user's email is their IdC user name, so we look the user up in the
Identity Store and read their group display names.
"""

import os

import boto3

identitystore = boto3.client("identitystore")
IDENTITY_STORE_ID = os.environ["IDENTITY_STORE_ID"]


def _group_names(email):
    user_id = identitystore.get_user_id(
        IdentityStoreId=IDENTITY_STORE_ID,
        AlternateIdentifier={
            "UniqueAttribute": {"AttributePath": "userName", "AttributeValue": email}
        },
    )["UserId"]

    names = []
    paginator = identitystore.get_paginator("list_group_memberships_for_member")
    for page in paginator.paginate(
        IdentityStoreId=IDENTITY_STORE_ID, MemberId={"UserId": user_id}
    ):
        for membership in page["GroupMemberships"]:
            group = identitystore.describe_group(
                IdentityStoreId=IDENTITY_STORE_ID, GroupId=membership["GroupId"]
            )
            names.append(group["DisplayName"])
    return names


def handler(event, context):
    email = event["request"]["userAttributes"].get("email")

    groups = []
    if email:
        try:
            groups = _group_names(email)
        except Exception:
            # Never fail the login over a group lookup — an unhandled error here
            # blocks token issuance entirely. Degrade to no groups (fewer
            # privileges downstream) and surface it in the logs.
            import traceback

            traceback.print_exc()

    event["response"] = {
        "claimsOverrideDetails": {
            "groupOverrideDetails": {"groupsToOverride": groups}
        }
    }
    return event
