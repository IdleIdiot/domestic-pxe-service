# FROM pxe-service:0.2 
FROM centos:latest
 
MAINTAINER wanghui01@thtfpc.com

RUN rm -f /etc/yum.repos.d/* &&curl https://mirrors.aliyun.com/repo/Centos-8.repo > /etc/yum.repos.d/CentOS-Base.repo && \
    sed -i -e '/mirrors.cloud.aliyuncs.com/d' -e '/mirrors.aliyuncs.com/d' /etc/yum.repos.d/CentOS-Base.repo && \
    dnf makecache && dnf install python3 httpd tftp-server dhcp-server tftp-server xinetd -y && \
    curl  https://bootstrap.pypa.io/pip/3.6/get-pip.py -o /root/get-pip.py && python3 /root/get-pip.py && \
    pip install supervisor && mkdir /etc/supervisor && \
    echo_supervisord_conf > /etc/supervisord.conf && mkdir /etc/supervisord.d && mkdir /var/log/supervisor && \
    mkdir /var/www/html/os/ && mkdir /var/www/html/ks
 

ADD script.sh /script.sh

RUN chmod +x /script.sh 

CMD ["/script.sh"]

