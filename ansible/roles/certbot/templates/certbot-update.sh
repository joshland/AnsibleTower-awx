#!/bin/bash

## Managed by Ansible

#/usr/local/certbot/bin/certbot --dns-route53 --dns-route53-propagation-seconds 30 --post-hook "/usr/local/certbot/unifi_ssl_import.sh" renew
{{ venvpath }}/bin/certbot --dns-route53 --dns-route53-propagation-seconds 30 --post-hook "{{ venvpath }}/nginx_restart.sh" renew
