FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && \
    apt-get install -y samba-ad-dc samba smbclient krb5-user winbind \
        bind9 dnsutils chrony && \
    rm -rf /var/lib/apt/lists/*

COPY setup.sh /setup.sh
COPY config.env.example /config.env

RUN chmod +x /setup.sh && TEST_MODE=1 /setup.sh --provision

CMD ["/usr/sbin/samba", "-F"]
