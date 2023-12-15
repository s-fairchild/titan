ONESHELL:
SHELL = /bin/bash

upgrade-traefik:
	helm upgrade -f clusterconfig/traefik/traefik.yaml -f clusterconfig/traefik/traefik-config.yaml traefik clusterconfig/traefik/charts/traefik-21.2.1+up21.2.0.tgz -n kube-system