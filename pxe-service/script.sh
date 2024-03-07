#!/bin/bash

echo "[include]
files = /etc/supervisord.d/*.ini" >> /etc/supervisord.conf


echo "[program:dhcpd]
;directory=/tmp
command=/usr/sbin/dhcpd -f -cf /etc/dhcp/dhcpd.conf -user dhcpd -group dhcpd --no-pid
priority=999
autostart=true
autorestart=unexpected
startsecs=1
startretries=3
user=root
redirect_stderr=true
stdout_logfile=/var/log/supervisor/%(program_name)s.log


[program:httpd]
;directory=/tmp
command=/usr/sbin/httpd -DFOREGROUND
priority=990
autostart=true
autorestart=unexpected
startsecs=1
startretries=3
user=root
redirect_stderr=true
stdout_logfile=/var/log/supervisor/%(program_name)s.log


[program:tftpd]
;directory=/tmp
command=/usr/sbin/in.tftpd -L -l -4 -a 0.0.0.0:69 -s /var/lib/tftpboot
priority=999
autostart=true
autorestart=unexpected
startsecs=1
startretries=3
user=root
redirect_stderr=true
stdout_logfile=/var/log/supervisor/%(program_name)s.log" > /etc/supervisord.d/conf.ini


echo "service tftp
{
socket_type = dgram
protocol = udp
wait = yes
user = root
server = /usr/sbin/in.tftpd
server_args = -s /var/lib/tftpboot
disable = no
per_source = 11
cps = 100 2
flags = IPv4
}" > /etc/xinetd.d/tftp


cp -r /mnt/* /var/www/html/os/
cp -r /var/www/html/os/images/pxeboot/* /var/lib/tftpboot

cp /var/www/html/os/EFI/BOOT/grub*.efi /var/lib/tftpboot

# if find /var/lib/tftpboot -name grubaa64.efi ;then
#   sed  -i  "s/grubx64.efi/grubaa64.efi/" /etc/dhcp/dhcpd.conf
# fi

chmod 777 /var/lib/tftpboot/*
chmod -R 777 /var/www/html/ks
chmod -R 777 /var/www/html/os

exec supervisord -n -c /etc/supervisord.conf
