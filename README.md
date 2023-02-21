______________________________
Full refactoring (21.02.2023)
- add send credentials in email
- delete storage sensitive data in localhost
- add storage users in db module (user/password)
- Added support OTP key (google authenticator)
- Update openvpn 2.5 (support tls-crypt-v2)
- Add send otp key in slack
- Add tls-crypt-v2 fot server/users
- Performance settings clients ovpn files
- update ciphers openvpn
- add stop current openvpn service for increase stability playbook
- disable nat and enable forwarding packet in subnet
- remove every standard default server
- Others small fix
______________________________



# ansible-openvpn-mikrotik [![Build Status](https://travis-ci.org/dteslya/ansible-ovpn-mikrotik.svg?branch=master)](https://travis-ci.org/dteslya/ansible-ovpn-mikrotik)

Ansible role and playbooks for installing openvpn and managing clients.

This is a fork of [ansible-openvpn](https://github.com/BastiPaeltz/ansible-openvpn) which in turn is a fork of [ansible-openvpn-hardened](https://github.com/bau-sec/ansible-openvpn-hardened).

Notable changes:
- Support for Mikrotik routers as clients
- Ability to define `client-config-dir` for clients in `group_vars/all.yml`
- Adding clients using a CSR functionality is stripped
- Distro repository is used to install OpenVPN package instead of official OpenVPN repository
- EasyRSA v3.0.6 is used
- Firewall rules are saved using `netfilter-persistent`

Hence Mikrotik RouterOS only supports TCP connection type I define a separate OpenVPN instance with `proto: tcp` and `port: 443`. This instance can also be used by other clients in case of restrictive firewalls on the network.

To further guarantee RouterOS support the following settings are now default:
- `comp-lzo` is disabled
- `cipher AES-128-CBC`
- `auth SHA1`

## Supported Targets

The following Linux distros are tested:

- Ubuntu 18.04
- Ubuntu 16.04

Other distros and versions may work too.

# Quick start

Copy the sample Ansible inventory and variables to edit for your setup. (I will use `my_project` as an example for the rest of this documentation)

    cp -r inventories/sample inventories/my_project

Edit the inventory hosts (`hosts.ini`) to target your desired host. You can also change the [configuration variables](#configuration-variables) in (`group_vars/all.yml`), the defaults are however sufficient for this quickstart example.
It is also possible to [target multiple hosts each using different variables](#targeting-multiple-hosts).

OpenVPN requires some firewall rules to forward packets. By default **NO** firewall rules will be written/altered.  
However you can set `load_iptables_rules` to `true` and a [generated script](./playbooks/roles/openvpn/templates/etc_iptables_rules.v4.j2), that you can find at `/etc/openvpn/openvpn_iptables_rules.sh` on the host (after installation finished) will load the minimum required rules into ip(v4)tables. If you opt to not do this you can set the firewall rules by hand. OpenVPN will need at least the `MASQUERADE` rule from that script to work.

Run the install playbook

    ansible-playbook -i inventories/my_project/hosts.ini playbooks/install.yml

The OpenVPN server is now up and running. Time to add some clients.

## Client state syncing

When you run the `sync_clients.yml` playboook it will sync the desired state (which clients are in the `valid_clients` list, by default "phone" and "laptop") with the current state (which clients are currently valid on the OpenVPN host).  
Clients that are not desired but currently valid will be revoked.  
Clients that are desired but currently not present on the OpenVPN host will be created/added.  
**NOTE**: Once you revoke a client, it is NOT possible to make it valid again, so I suggest using somewhat unique names as `valid_clients`.  

By default once you run the `sync_clients.yml` playbook it will first tell you which clients it will add and revoke before doing it, you will have to manually confirm before it proceeds. You can disable this prompt by setting `prompt_before_syncing_clients` to `false`.

    ansible-playbook playbooks/sync_clients.yml -i inventories/my_project/hosts.ini

After the playbook finished, the credentials will be in the `fetched_creds/` directory after the playbook finished succesfully.  
You'll be prompted for the private key passphrase, this is stored in a file ending in `.txt` in the client directory you just entered in the step above.  
Try connecting to the OpenVPN server:

    cd fetched_creds/[inventory_hostname]/[client name]/
    openvpn [client name]-pki-embedded.ovpn

With the `sync_clients.yml` playbook you can maintain state of your clients, even on different hosts, see [Targeting multiple hosts](#targeting-multiple-hosts) and [State Management](#How-to-manage-state).

## Adding clients manually

To add clients, you can also run the `add_clients.yml` playbook. It needs a list named `clients_to_add`, see [the file used for the tests](./test/ansible-vars/02_add_clients.yml) on how this looks like.

    ansible-playbook playbooks/add_clients.yml -i inventories/my_project/hosts.ini -e "@test/ansible-vars/02_add_clients.yml"

The credentials will be in the `fetched_creds/` directory after the playbook finished succesfully. Try connecting to the OpenVPN server:

    cd fetched_creds/[inventory_hostname]/[client name]/
    openvpn [client name]-pki-embedded.ovpn

You'll be prompted for the private key passphrase, this is stored in a file ending in `.txt` in the client directory you just entered in the step above.

### Distributing key files

Three different OpenVPN configuration files are provided because OpenVPN clients on different platforms have different requirements for how the PKI information is referenced by the .ovpn file. This is just for convenience. All the configuration information and PKI info is the same, it's just formatted differently to support different OpenVPN clients.

- **PKI embedded** - the easiest if your client supports it. Only one file required and all the PKI information is embedded.
  - `XYZ-pki-embedded.ovpn`
- **PKCS#12** - all the PKI information is stored in the PKCS#12 file and referenced by the config. This can be more secure on Android where the OS can store the information in the PKCS#12 file in hardware backed encrypted storage.
  - `XYZ-pkcs.ovpn`
  - `XYZ.p12`
- **PKI files** - if the above two fail, all clients should support this. All of the PKI information is stored in separate files and referenced by the config.
  - `XYZ-pki-files.ovpn` - OpenVPN configuration
  - `ca.pem` - CA certificate
  - `XYZ.key` - client private key
  - `XYZ.pem` - client certificate

All private keys (embedded in config, pkcs, and .key) are encrypted with a passphrase to facilitate secure distribution to client devices.

For maximum security when copying the PKI files and configs to client devices don't copy the .txt file containing the randomly generated passphrase. Enter the passphrase manually onto the device after the key has been transferred.

### Private key passphrases

Entering a pass phrase every time the client is started can be annoying. There are a few options to make this less burdensome after the keys have been securely distributed to the client devices.

1. When starting the client, use `openvpn --config [config] --askpass [pass.txt]` if you don't want to enter the password for the private key

  From the OpenVPN man page:

  > If file is specified, read the password from the first line of file. Keep in mind that storing your password in a file to a certain extent invalidates the extra security provided by using an encrypted key.

### Adding clients using a CSR

Clients can also be added using a certificate signing request, CSR. This is useful if you intend to use keys generated and stored in a TPM. Generating the CSR will depend on your hardware, OS, TPM software, etc. If you're interested in this feature, you can probably figure this out (though [`.travis.yml`](.travis.yml) has an example of generating a CSR with *openssl*). This [blog post](https://qistoph.blogspot.nl/2015/12/tpm-authentication-in-openvpn-and-putty.html) shows how to create private key stored in a TPM and generate a CSR on Windows.

The variable `csr_path` specifies the local path to the CSR. `cn` specifies the common name specified when the CSR was created.

    ansible-playbook -e "csr_path=~/test.csr cn=test@domain.com" playbooks/add_clients.yml

This will generate the client's signed certificate and put it in `fetched_creds/[server ip]/[cn]/` as well as a nearly complete `.ovpn` client configuration file. You'll need to add references to or embed your private key and signed certificate. This will vary based on how your private key is stored. If your following the guide in the blog post mentioned above you'd do this using the OpenVPN option `cryptoapicert`.

## Targeting multiple hosts
It is possible to not only target multiple hosts but also use different groups and apply certain configuration variables to that group only. An example:

Consider this `hosts.ini` inventory:
```
[production]
bastion-prod-us-east-1
bastion-prod-us-east-2

[qa]
bastion-qa

[openvpn:children]
production
qa
```

You can now create a file `production.yml` in `group_vars/`:
```
openvpn_key_country:  "US"
openvpn_key_province: "Ohio"
openvpn_key_city: "Cleveland"
openvpn_key_org: "FOOBAR CORPORATION"
openvpn_key_ou: "Operations"
openvpn_key_email: "foobar@example.com"
```

This configuration will now be applied to hosts in the `production` group only and will override variables from the `all.yml`.  
You can even do this on a per-host level, which will override group-level variables.  
E.g. create a file `host_vars/bastion-prod-us-east-1.yml`:
```
openvpn_key_ou: "Operations Unit B"
```

Further reading: [Ansible variable documentation, especially section: "Precedence"](http://docs.ansible.com/ansible/latest/user_guide/playbooks_variables.html).

This also comes in handy when managing clients with the `sync_clients.yml` playbook because you can then configure which clients are valid on a per-host or per-group basis.

## How to manage state

You can use this to manage state by committing and continously updating configuration, especially for client syncing.
There are different approaches you can take, here are two suggestions:  
- Manage all configuration files (all `inventories/` files) on a separate location, e.g. inside of [Jenkins](https://wiki.jenkins.io/display/JENKINS/Config+File+Provider+Plugin) and once these change, trigger a run of the playbook(s), especially `sync_clients.yml`. Disadvantage: You can not easily run this from anywhere else since the configuration files are missing.
- Encrypt all configuration files (e.g. using `ansible-vault`), commit them to source control and trigger a run of the playbook(s) after a new commit is pushed.

## Revoke client access manually

To revoke clients access, you can run the `revoke_clients.yml` playbook. It needs a list named `clients_to_revoke`, see [the file used for the tests](./test/ansible-vars/03_revoke_clients.yml) on how this looks like.

    ansible-playbook playbooks/revoke_clients.yml -e "@test/ansible-vars/03_revoke_clients.yml"

# Managing the OpenVPN server

## Configuration variables

There is documentation on the most important variables in [all.yml](./inventories/sample/group_vars/all.yml).

### OpenVPN server configuration
For the full server configuration, see [`etc_openvpn_server.conf.j2`](playbooks/roles/openvpn/templates/etc_openvpn_server.conf.j2)
- `tls-auth` aids in mitigating risk of denial-of-service attacks. Additionally, when combined with usage of UDP at the transport layer (the default configuration used by *ansible-openvpn-hardened*), it complicates attempts to port scan the OpenVPN server because any unsigned packets can be immediately dropped without sending anything back to the scanner.
  - From the [OpenVPN hardening guide](https://community.openvpn.net/openvpn/wiki/Hardening):

    > The tls-auth option uses a static pre-shared key (PSK) that must be generated in advance and shared among all peers. This features adds "extra protection" to the TLS channel by requiring that incoming packets have a valid signature generated using the PSK key... The primary benefit is that an unauthenticated client cannot cause the same CPU/crypto load against a server as the junk traffic can be dropped much sooner. This can aid in mitigating denial-of-service attempts.

- `push block-outside-dns` used by OpenVPN server to fix a potential dns leak on Windows 10
  - See https://community.openvpn.net/openvpn/ticket/605
- `tls-cipher` limits allowable TLS ciphers to a subset that supports [**perfect forward secrecy**](https://en.wikipedia.org/wiki/Forward_secrecy)
  - From wikipedia:

	> Forward secrecy protects past sessions against future compromises of secret keys or passwords. If forward secrecy is used, encrypted communications and sessions recorded in the past cannot be retrieved and decrypted should long-term secret keys or passwords be compromised in the future, even if the adversary actively interfered.

- `cipher` set to `AES-256-CBC` by default
- `2048` bit RSA key size by default.
  - This can be increased to `4096` by changing `openvpn_key_size` in [`defaults/main.yml`](playbooks/roles/openvpn/defaults/main.yml) if you don't mind extra processing time. Consensus seems to be that 2048 is sufficient for all but the most sensitive data.

### OpenVPN client configuration
For the full client configuration, see [`client_common.ovpn.j2`](playbooks/roles/add_clients/templates/client_common.ovpn.j2)
- `verify-x509-name` prevents MitM attacks by verifying the server name in the supplied certificate matches the clients configuration.
- `persist-tun` prevents the traffic from leaking out over the default interface during interruptions and reconnection attempts by keeping the tun device up until connectivity is restored.

### PKI
- [easy-rsa](https://github.com/OpenVPN/easy-rsa) is used to manage the public key infrastructure.
- OpenVPN is configured to read the CRL generated by *easy-rsa* so that a single client's access can be revoked without having to reissue credentials to all of the clients.
- The private keys generated for the clients and CA are all protected with a randomly generated passphrase to facilitate secure distribution to client devices.

### Firewall

OpenVPN requires some firewall rules to forward packets.  
By default **NO** firewall rules will be written/altered.  
However you can set `load_iptables_rules` to `true` and a [generated script](./playbooks/roles/openvpn/templates/etc_iptables_rules.v4.j2), that you can find at `/etc/openvpn/openvpn_iptables_rules.sh` on the host (after installation finished) will load the minimum required rules into ip(v4)tables. If you opt to not do this you can set the firewall rules by hand. OpenVPN will need at least the `MASQUERADE` rule from that script.

### Credentials (CA password)

Credentials are generated during the install process and are saved as yml formatted files in the Ansible file hierarchy so they can be used without requiring the playbook caller to take any action. The locations are below.

- CA Private key passphrase - saved in `inventories/my_project/host_vars/[inventory_hostname].yml`
