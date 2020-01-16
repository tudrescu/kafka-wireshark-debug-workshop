# Wireshark in Web Browser Container image

Docker image which builds [Wireshark](https://www.wireshark.org/) from source and makes it available via Web Browser using the [Xpra](https://xpra.org) project.

## Usage

Run the Wireshark container via

```bash

```

Access Wireshark via the browser (change password=wireshark if you provided a different password) using e.g.

[https://localhost:14500/?username=wireshark&password=wireshark](https://localhost:14500/?username=wireshark&password=wireshark)

Adding the parameter `--cap-add NET_ADMIN` should allow Wireshark to capture traffic.

By default, the container uses the default self-signed certificate to offer SSL. To specify a custom certificate, run container with
`--mount type=bind,source="$(pwd)"/ssl-cert.pem,target=/etc/xpra/ssl-cert.pem,readonly` (adjust paths accordingly).

By default, Wireshark can be accessed in the Browser only using a password. The default password is `wireshark`, but can be changed by setting the environment variable `XPRA_PW`.

It is useful to automatically restart the container on failures using the `--restart unless-stopped` parameter.

## Acknowledgements

This image is based on [ffeldhaus/docker-wireshark](https://github.com/ffeldhaus/docker-wireshark).
