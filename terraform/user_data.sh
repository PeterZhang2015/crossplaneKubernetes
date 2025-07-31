#!/bin/bash

# User data script for EKS node group security hardening
set -o xtrace

# Update system packages
yum update -y

# Configure EKS bootstrap
/etc/eks/bootstrap.sh ${cluster_name} --region ${region}

# Security hardening
# Disable unused services
systemctl disable postfix
systemctl stop postfix

# Configure log rotation
cat > /etc/logrotate.d/kubernetes <<EOF
/var/log/pods/*/*.log {
    daily
    missingok
    rotate 7
    compress
    notifempty
    create 0644 root root
}
EOF

# Set up CloudWatch agent for additional monitoring
yum install -y amazon-cloudwatch-agent

# Configure sysctl for security
cat >> /etc/sysctl.conf <<EOF
# Network security
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv4.conf.all.log_martians = 1
net.ipv4.conf.default.log_martians = 1
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.icmp_ignore_bogus_error_responses = 1
net.ipv4.tcp_syncookies = 1
EOF

sysctl -p

# Install additional security tools
yum install -y aide
aide --init
mv /var/lib/aide/aide.db.new.gz /var/lib/aide/aide.db.gz

echo "Node initialization completed successfully"