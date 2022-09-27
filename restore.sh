#!/bin/bash

ansible-playbook --tags reset playbook.yaml
ansible-playbook --tags gen playbook.yaml
