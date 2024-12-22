#!/bin/bash

./uninstall_kube.sh "beelink"
./uninstall_kube.sh "zima"

./install_kube.sh "zima"
./install_kube.sh "beelink"

# Setup the cluster
./install_metallb.sh
./install_cert_manager.sh
./install_grafana.sh
./install_nginx_ingress.sh
./install_harbor.sh

# install_dnsmasq.sh
# install_grafana.sh
# install_harbor.sh
