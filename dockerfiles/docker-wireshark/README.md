# Wireshark in Web Browser Container image

Docker image which builds [Wireshark](https://www.wireshark.org/) from source and makes it available via Web the browser using the [Xpra](https://xpra.org) project.

## Usage

Run the wireshark container via

```bash
docker run \
    -p 14500:14500 \
    --restart unless-stopped  \
    --name wireshark \
    --cap-add NET_ADMIN \
    -d \
    docker-wireshark:latest
```

Access Wireshark via the browser using the IP/Hostname of your docker host and providing username and password (change password=wireshark if you provided a different password) using e.g.

[https://localhost:14500/?username=wireshark&password=wireshark](https://localhost:14500/?username=wireshark&password=wireshark)

Adding the parameter `--cap-add NET_ADMIN` should allow Wireshark to capture traffic.

By default, the container uses the default self-signed certificate to offer SSL. To specify a custom certificate, run container with
`--mount type=bind,source="$(pwd)"/ssl-cert.pem,target=/etc/xpra/ssl-cert.pem,readonly` (ajdust paths accordingly).

By default, Wireshark can be accessed in the Browser only using a password. The default password is `wireshark`, but can be changed by setting the environment variable `XPRA_PW`.

It is useful to automatically restart the container on failures using the `--restart unless-stopped` parameter.

## Acknowledgements

This image is based on [ffeldhaus/docker-wireshark](https://github.com/ffeldhaus/docker-wireshark).
