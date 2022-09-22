#!/bin/sh

vagrant destroy -g --parallel
vagrant up
ansible-playbook playbook.yaml
