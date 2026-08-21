# Tutorial: provision a person for passwordless cluster access

By the end of this tutorial, one person has an individual cluster-tenant
identity, can log in using an SSH key, and has no password-based SSH login
path.

**You will need**

- An approved request identifying the person, their owner/manager, intended
  cluster role, and end date if access is temporary.
- The person's SSH **public** key and a way to verify its fingerprint with
  them. Never request or copy a private key.
- Root access on the BCM host that provides `/home/nvis/utils/add_user.sh`.
  The repository copy is
  [`scripts/aic_bcm_headnode_add_user.sh`](../../scripts/aic_bcm_headnode_add_user.sh).
- An existing administrator session kept open while testing.

## 1. Establish the identity record

Choose the person's site-approved account name and record the request details:

- account name and full name;
- business owner and approval;
- one approved primary group: `cmods`, `nvis-eth`, or `nvis-ib`;
- public-key fingerprint; and
- review or expiry date.

Do not reuse `cmods` or another shared service identity for a person.
Individual accounts make access reviews and activity attribution possible.

## 2. Run the provisioning script

Run the script as root on its BCM host:

```console
sudo /home/nvis/utils/add_user.sh
```

Choose the approved primary group, enter the lowercase Linux username, then
paste one complete OpenSSH **public** key line. The script displays the
username, primary group and GID, BCM profile (`breakfix`), expected home path,
and SHA-256 key fingerprint. Check these details before entering `yes`.

The script creates the BCM user with password-based SSH disabled, waits for NSS
to return the account, creates `/home/<username>` when necessary, and installs
the key in `/home/<username>/.ssh/authorized_keys`. It refuses an existing
user, a malformed/private key, unsafe home or SSH paths, and BCM/NSS GID
mismatches.

It creates only an ordinary user: any required scheduler/project entitlement is
a separate step.

## 3. Confirm the installed key

Confirm the displayed SHA-256 fingerprint with the person who supplied the
public key. The script verifies that the exact key line appears once and that
`.ssh` and `authorized_keys` have safe ownership and modes. Do not provide or
store a private key.

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

This connection must be rejected or fail because BCM disables password-based
SSH; it must not grant a shell. Keep the administrator session open until both
tests are complete.

## 5. Hand off and review

Tell the person their login host, account name, permitted use, and support
path. Do not send secrets—the person already holds their private key.

Update the access record with the successful test, approver, BCM change, and
next review date. Remove the BCM account or its access groups when the approved
end date or role change occurs, then verify the key no longer permits login.

## What you built

The person has a distinct BCM-managed identity with the selected primary group
and authenticates with their own SSH key. Human activity remains attributable
to that account; service work continues under `cmods`.
