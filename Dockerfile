FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && \
    apt-get install -y samba-ad-dc samba smbclient krb5-user winbind \
        bind9 dnsutils chrony && \
    rm -rf /var/lib/apt/lists/*

COPY setup.sh /setup.sh
COPY config.env.example /config.env.example # Make example available for TEST_MODE run and for users to reference

RUN chmod +x /setup.sh && TEST_MODE=1 /setup.sh --provision

# IMPORTANT: This Docker image requires a custom 'config.env' to be mounted at /config.env at runtime
# for provisioning a new domain or joining an existing one.
# The setup.sh script will use this file for configuration.
# Example: docker run -v /path/to/your/custom/config.env:/config.env your_image_name
#
# The setup.sh script is run with TEST_MODE=1 during build to ensure it works,
# using /config.env.example to create a temporary /config.env.
# This does not perform a full domain provision with example values.
CMD ["/usr/sbin/samba", "-F"]
