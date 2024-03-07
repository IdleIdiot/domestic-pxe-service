#!/bin/bash

CUR_DIR=$(cd "$(dirname "$0")" && pwd -P)

shutdown_firewall() {
	iptables -F || echo "iptables delete all rules failed!"

	systemctl stop firewalld || echo "Stop firewalld seem has some problem!"
	systemctl disable firewalld || echo "Disable firewalld seem has some problem!"
	systemctl status firewalld | grep -q running && echo "firewalld is still running!"

	sed -i 's/RefuseManualStop=yes/#RefuseManualStop=yes/' /usr/lib/systemd/system/auditd.service
	systemctl daemon-reload
	systemctl stop auditd || echo "Stop auditd failed"
	systemctl disable auditd || echo "Disable auditd failed!"
	sed -i 's/#RefuseManualStop=yes/RefuseManualStop=yes/' /usr/lib/systemd/system/auditd.service
	systemctl daemon-reload
	systemctl status auditd | grep -q running && echo "auditd is still running"

	case "$(getenforce)" in
	"Enforcing")
		sed -i 's/SELINUX=enforcing/SELINUX=disabled/' /etc/selinux/config
		echo "Changing selinux from enforcing to disabled."
		setenforce 0
		;;
	"Permissive")
		sed -i 's/SELINUX=permissive/SELINUX=disabled/' /etc/selinux/config
		echo "Changing selinux from permissive to disabled."
		setenforce 0
		;;
	"Disabled")
		# do nothing
		;;
	esac

	echo -e "Shut down firewall:\t[\033[32;1m OK \033[0m]"
}

check_docker(){
  if docker -v > /dev/null; then
    systemctl enable docker
  else
    if systemctl restart docker; then
      systemctl enable docker
    else
      echo "Please install docker by yourself. And rerun this shell."
      echo "Look docker & docker-compose install document: https://docs.docker.com/engine/install/"
      exit 1
    fi
  fi
  echo "ok"
}

clean_docker_data(){
  local image
  local images
  local container
  local containers

  read -r -p "Check whether to delete pxe-server images left over from the past(y/N): " is_clean

  if [ "${is_clean}" == "N" ];then
    return 0

  elif [ "${is_clean}" == "y" ];then
    echo "Clean all docker images and containers data..."
    containers="$(docker ps -a | grep 'cobbler-dev\|jenkins-dev' | awk '{print $1}')"
    for container in ${containers};
    do
      docker stop "${container}"
      docker rm "${container}"
    done

    images=$(docker images | grep 'cobbler-dev\|jenkins-dev' | awk '{print $3}')
    for image in ${images};
    do
      docker rmi "${image}"
    done

#    echo ""
#    echo "Keep docker cache, please choose option [N]!"
#    docker system prune

  else
    clean_docker_data
  fi
  echo "ok"
}

change_docker_source() {
  echo "Docker download source modify..."
  [ ! -d /data/docker.lib ] && mkdir -p /data/docker.lib
  cat > /etc/docker/daemon.json <<-EOF
  {
    "registry-mirrors": ["http://hub-mirror.c.163.com"],
    "data-root": "/data/docker.lib"
  }
EOF
  systemctl daemon-reload
  systemctl restart docker
  echo "ok"
}

install_compose() {
  echo "Install docker compose..."
  echo "Check cpu arch..."
  server_arch=$(arch)

  if [ "${server_arch}" == "x86_64" ]; then
    echo "x86_64"
    cp "${CUR_DIR}"/preinstall-packages/x86/docker-compose/docker-compose-linux-x86_64 /usr/bin/docker-compose

  elif [ "${server_arch}" == "aarch64" ]; then
    echo "aarch64"
    cp "${CUR_DIR}"/preinstall-packages/arm/docker-compose/docker-compose-linux-aarch64 /usr/bin/docker-compose

  else
    echo "Not support!"
    exit 1
  fi

  chmod +x /usr/bin/docker-compose
  echo "ok"
}



enable_ipv4_forward(){
  echo "Enable ipv4 forward ..."
  if grep net.ipv4.ip_forward /etc/sysctl.conf ;then
    sed -i 's/net.ipv4.ip_forward.*/net.ipv4.ip_forward=1/g' /etc/sysctl.conf
    sed -i 's/#*net.ipv4.ip_forward.*/net.ipv4.ip_forward=1/g' /etc/sysctl.conf
  else
    echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
  fi
  sysctl -p
  echo "ok"
}

env_config() {
  shutdown_firewall

  install_compose

  check_docker

  # clean_docker_data

  change_docker_source

  enable_ipv4_forward

}



mount_os() {
  local iso_path
  iso_path=$1
  # read -r -p "Please input your os path(ex: /opt/diag-test/ISSEOS.iso) : " iso_path
  echo ${iso_path}
  umount ${CUR_DIR}/mnt
  if mount ${iso_path} ${CUR_DIR}/mnt;then
    echo "mount os success"
  else
    echo "mount failed"
    exit 1
  fi
}


config_dhcp_nic(){

  read -r -p "Please input your nic(ex: enp13s0) to bind dhcp service: " nic
  if ip a add 192.168.233.2/24 dev ${nic};then
    echo "dhcp nic config success"
  elif [[ $? == 2 ]];then
    echo "dhcp nic already set success"
  else 
    echo "config dhcp nic failed"
    exit 1
  fi
  
}

run() {
  echo "Warning: If script failed from here, pls clean your env manual!"
  config_dhcp_nic

  # docker load -i ${CUR_DIR}/pxe-service/pxe-service.tar

  mount_os $1
  rm -f ${CUR_DIR}/pxe-service/config/dhcpd.conf
  cp ${CUR_DIR}/pxe-service/config/dhcpd.conf.template ${CUR_DIR}/pxe-service/config/dhcpd.conf
  if find ${CUR_DIR}/mnt -name grubaa64.efi ;then
    echo "aarch os"
    sed -i "s/grubx64.efi/grubaa64.efi/" ${CUR_DIR}/pxe-service/config/dhcpd.conf
  fi
  docker pull centos
  docker-compose up -d 
}

env_config
run $1
