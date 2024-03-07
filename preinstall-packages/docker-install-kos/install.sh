#!/bin/bash
dnf config-manager --add-repo ./docker-ce.repo

yum install -y docker-ce docker-ce-cli containerd.io
