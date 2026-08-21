# Tutorial: provision a person for passwordless cluster access

By the end of this tutorial, one person has an individual cluster identity,
can log in using an SSH key, and has no password-based login path.

**You will need**

- An approved request identifying the person, their owner/manager, intended
  cluster role, and end date if access is temporary.
- The person's SSH **public** key and a way to verify its fingerprint with
  them. Never request or copy a private key.
- BCM administrator access and access to an approved app-server or slogin host
  for validation.
- An existing administrator session kept open while testing.

## 1. Establish the identity record

Choose the person's site-approved account name and record the request details:

- account name and full name;
- business owner and approval;
- membership in the required `cmods` group, any additional BCM account group(s),
  and any scheduler/project membership;
- public-key fingerprint; and
- review or expiry date.

Do not reuse `cmods`, `cmods-automation`, or another shared service identity
for a person. Individual accounts make access reviews and activity attribution
possible.

## 2. Create the account in BCM

In BCM, create the user with the approved account name and add it to the
`cmods` group. Add only the additional groups required by the approved role.
Use the site's BCM user-management procedure so BCM distributes or exposes the
account consistently on every managed login target. Do not create a competing
local account on an individual managed node.

Configure the account so password authentication is disabled or no usable
password credential exists, according to site policy. BCM is responsible for
the identity; SSH is responsible for accepting the user's public key.

Record the BCM object name/ID and the change reference. If the account must
run jobs, complete the separate scheduler/project entitlement step before
claiming the account is ready.

## 3. Register the SSH public key

Register only the approved public key using the site's BCM or centrally managed
authorized-keys mechanism. Confirm the stored fingerprint exactly matches the
fingerprint supplied by the user.

Apply the BCM configuration update through the normal configuration-management
workflow and wait until the intended app-server/slogin host reports the new
identity and key material. Do not email, paste into tickets, or store private
keys in BCM, home directories, or automation configuration.

## 4. Verify passwordless login

From a workstation that holds the matching private key, open a new session:

```console
ssh -o PreferredAuthentications=publickey -o PasswordAuthentication=no \
  <person>@<slogin-or-app-server> 'id; whoami'
```

The command must succeed and report the new individual account. Then verify
that a password cannot be used:

```console
ssh -o PubkeyAuthentication=no -o PreferredAuthentications=password \
  -o PasswordAuthentication=yes <person>@<slogin-or-app-server>
```

This connection must be rejected or fail because no password is available; it
must not grant a shell. Keep the administrator session open until both tests
are complete.

## 5. Hand off and review

Tell the person their login host, account name, permitted use, and support
path. Do not send secrets—the person already holds their private key.

Update the access record with the successful test, approver, BCM change, and
next review date. Remove the BCM account or its access groups when the approved
end date or role change occurs, then verify the key no longer permits login.

## What you built

The person has a distinct BCM-managed identity and authenticates with their own
SSH key. Human activity remains attributable to that account; service work
continues under the separate `cmods` and `cmods-automation` identities.
