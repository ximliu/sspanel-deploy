#!/usr/bin/env bash

#
# System Required:  CentOS 6,7, Debian, Ubuntu
# Description: One click Shadowsocks Server
#
# Author: QuNiu
#

# PATH
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH
clear

# libsodium
libsodium_file="libsodium-1.0.16"
libsodium_url="https://github.com/jedisct1/libsodium/releases/download/1.0.16/libsodium-1.0.16.tar.gz"

# shadowsocks
shadowsocks_dir="shadowsocks"
shadowsocks_name="shadowsocks"
shadowsocks_file="shadowsocks-manyuser"
shadowsocks_url="https://github.com/quniu/sspanel-deploy/releases/download/v1.0.0/shadowsocks-manyuser.tar.gz"
shadowsocks_service_yum="https://raw.githubusercontent.com/quniu/sspanel-deploy/master/service/${shadowsocks_name}"
shadowsocks_service_apt="https://raw.githubusercontent.com/quniu/sspanel-deploy/master/service/${shadowsocks_name}-debian"

# Current folder
cur_dir=`pwd`

# Stream Ciphers
ciphers=(
none
aes-128-cfb
aes-192-cfb
aes-256-cfb
aes-128-ctr
aes-192-ctr
aes-256-ctr
aes-128-gcm
aes-192-gcm
aes-256-gcm
camellia-128-cfb
camellia-192-cfb
camellia-256-cfb
rc4-md5
bf-cfb
salsa20
chacha20
chacha20-ietf
chacha20-poly1305
chacha20-ietf-poly1305
xchacha-ietf-poly1305
sodium-aes-256-gcm
)
# Reference URL:

# Protocol
protocols=(
origin
auth_chain_a
auth_chain_b
auth_sha1_v4
auth_sha1_v4_compatible
auth_aes128_md5
auth_aes128_sha1
verify_deflate
)

# obfs
obfs=(
plain
tls1.2_ticket_auth
tls1.2_ticket_auth_compatible
tls1.2_ticket_fastauth
tls1.2_ticket_fastauth_compatible
http_simple
http_simple_compatible
http_post
http_post_compatible
)

# interfaces
interfaces=(
glzjinmod
modwebapi
)

# Color
red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

# Make sure only root can run our script
[[ $EUID -ne 0 ]] && echo -e "[${red}Error${plain}] This script must be run as root!" && exit 1

# Disable selinux
disable_selinux(){
    if [ -s /etc/selinux/config ] && grep 'SELINUX=enforcing' /etc/selinux/config; then
        sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
        setenforce 0
    fi
}

# Check system
check_sys(){
    local checkType=$1
    local value=$2

    local release=''
    local systemPackage=''

    if [[ -f /etc/redhat-release ]]; then
        release="centos"
        systemPackage="yum"
    elif cat /etc/issue | grep -Eqi "debian"; then
        release="debian"
        systemPackage="apt"
    elif cat /etc/issue | grep -Eqi "ubuntu"; then
        release="ubuntu"
        systemPackage="apt"
    elif cat /etc/issue | grep -Eqi "centos|red hat|redhat"; then
        release="centos"
        systemPackage="yum"
    elif cat /proc/version | grep -Eqi "debian"; then
        release="debian"
        systemPackage="apt"
    elif cat /proc/version | grep -Eqi "ubuntu"; then
        release="ubuntu"
        systemPackage="apt"
    elif cat /proc/version | grep -Eqi "centos|red hat|redhat"; then
        release="centos"
        systemPackage="yum"
    fi

    if [[ ${checkType} == "sysRelease" ]]; then
        if [ "$value" == "$release" ]; then
            return 0
        else
            return 1
        fi
    elif [[ ${checkType} == "packageManager" ]]; then
        if [ "$value" == "$systemPackage" ]; then
            return 0
        else
            return 1
        fi
    fi
}

# Get version
getversion(){
    if [[ -s /etc/redhat-release ]]; then
        grep -oE  "[0-9.]+" /etc/redhat-release
    else
        grep -oE  "[0-9.]+" /etc/issue
    fi
}

# CentOS version
centosversion(){
    if check_sys sysRelease centos; then
        local code=$1
        local version="$(getversion)"
        local main_ver=${version%%.*}
        if [ "$main_ver" == "$code" ]; then
            return 0
        else
            return 1
        fi
    else
        return 1
    fi
}

# Get public IP address
get_ip(){
    local IP=$( ip addr | egrep -o '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | egrep -v "^192\.168|^172\.1[6-9]\.|^172\.2[0-9]\.|^172\.3[0-2]\.|^10\.|^127\.|^255\.|^0\." | head -n 1 )
    [ -z ${IP} ] && IP=$( wget -qO- -t1 -T2 ipv4.icanhazip.com )
    [ -z ${IP} ] && IP=$( wget -qO- -t1 -T2 ipinfo.io/ip )
    [ ! -z ${IP} ] && echo ${IP} || echo
}

get_char(){
    SAVEDSTTY=`stty -g`
    stty -echo
    stty cbreak
    dd if=/dev/tty bs=1 count=1 2> /dev/null
    stty -raw
    stty echo
    stty $SAVEDSTTY
}

# Pre-installation settings
install_prepare(){
    if check_sys packageManager yum || check_sys packageManager apt; then
        # Not support CentOS 5
        if centosversion 5; then
            echo -e "$[{red}Error${plain}] Not supported CentOS 5, please change to CentOS 6+/Debian 7+/Ubuntu 12+ and try again!"
            exit 1
        fi
    else
        echo -e "[${red}Error${plain}] Your OS is not supported. please change OS to CentOS/Debian/Ubuntu and try again!"
        exit 1
    fi
    # Set Shadowsocks config password
    echo "Please enter password for Shadowsocks:"
    read -p "(Default password: abc123456):" shadowsockspwd
    [ -z "${shadowsockspwd}" ] && shadowsockspwd="abc123456"
    echo
    echo "---------------------------"
    echo "password = ${shadowsockspwd}"
    echo "---------------------------"
    echo
    # Set Shadowsocks config port
    while true
    do
    echo -e "Please enter a port for Shadowsocks [1-65535]:"
    read -p "(Default port: 8899):" shadowsocksport
    [ -z "${shadowsocksport}" ] && shadowsocksport="8899"
    expr ${shadowsocksport} + 1 &>/dev/null
    if [ $? -eq 0 ]; then
        if [ ${shadowsocksport} -ge 1 ] && [ ${shadowsocksport} -le 65535 ] && [ ${shadowsocksport:0:1} != 0 ]; then
            echo
            echo "---------------------------"
            echo "port = ${shadowsocksport}"
            echo "---------------------------"
            echo
            break
        fi
    fi
    echo -e "[${red}Error${plain}] Please enter a correct number [1-65535]"
    done

    # Set shadowsocks config stream ciphers
    while true
    do
    echo -e "Please select stream cipher for Shadowsocks:"
    for ((i=1;i<=${#ciphers[@]};i++ )); do
        hint="${ciphers[$i-1]}"
        echo -e "${green}${i}${plain}) ${hint}"
    done
    read -p "Which cipher you'd select(Default: ${ciphers[3]}):" pick
    [ -z "$pick" ] && pick=4
    expr ${pick} + 1 &>/dev/null
    if [ $? -ne 0 ]; then
        echo -e "[${red}Error${plain}] Please enter a number"
        continue
    fi
    if [[ "$pick" -lt 1 || "$pick" -gt ${#ciphers[@]} ]]; then
        echo -e "[${red}Error${plain}] Please enter a number between 1 and ${#ciphers[@]}"
        continue
    fi
    shadowsockscipher=${ciphers[$pick-1]}
    echo
    echo "---------------------------"
    echo "cipher = ${shadowsockscipher}"
    echo "---------------------------"
    echo
    break
    done

    # Set shadowsocks config protocol
    while true
    do
    echo -e "Please select protocol for Shadowsocks:"
    for ((i=1;i<=${#protocols[@]};i++ )); do
        hint="${protocols[$i-1]}"
        echo -e "${green}${i}${plain}) ${hint}"
    done
    read -p "Which protocol you'd select(Default: ${protocols[5]}):" protocol
    [ -z "$protocol" ] && protocol=6
    expr ${protocol} + 1 &>/dev/null
    if [ $? -ne 0 ]; then
        echo -e "[${red}Error${plain}] Input error, please input a number"
        continue
    fi
    if [[ "$protocol" -lt 1 || "$protocol" -gt ${#protocols[@]} ]]; then
        echo -e "[${red}Error${plain}] Input error, please input a number between 1 and ${#protocols[@]}"
        continue
    fi
    shadowsocksprotocol=${protocols[$protocol-1]}
    echo
    echo "---------------------------"
    echo "protocol = ${shadowsocksprotocol}"
    echo "---------------------------"
    echo
    break
    done

    # Set shadowsocks config obfs
    while true
    do
    echo -e "Please select obfs for Shadowsocks:"
    for ((i=1;i<=${#obfs[@]};i++ )); do
        hint="${obfs[$i-1]}"
        echo -e "${green}${i}${plain}) ${hint}"
    done
    read -p "Which obfs you'd select(Default: ${obfs[2]}):" r_obfs
    [ -z "$r_obfs" ] && r_obfs=3
    expr ${r_obfs} + 1 &>/dev/null
    if [ $? -ne 0 ]; then
        echo -e "[${red}Error${plain}] Input error, please input a number"
        continue
    fi
    if [[ "$r_obfs" -lt 1 || "$r_obfs" -gt ${#obfs[@]} ]]; then
        echo -e "[${red}Error${plain}] Input error, please input a number between 1 and ${#obfs[@]}"
        continue
    fi
    shadowsocksobfs=${obfs[$r_obfs-1]}
    echo
    echo "---------------------------"
    echo "obfs = ${shadowsocksobfs}"
    echo "---------------------------"
    echo
    break
    done
}

# Download files
download_files(){
    # Clean install package
    install_cleanup

    # Download libsodium
    if ! wget --no-check-certificate -O ${libsodium_file}.tar.gz ${libsodium_url}; then
        echo -e "[${red}Error${plain}] Failed to download ${libsodium_file}.tar.gz!"
        exit 1
    fi

    # Download Shadowsocks
    if ! wget --no-check-certificate -O ${shadowsocks_file}.tar.gz ${shadowsocks_url}; then
        echo -e "[${red}Error${plain}] Failed to download Shadowsocks file!"
        exit 1
    fi

    # Download Shadowsocks service script
    if check_sys packageManager yum; then
        if ! wget --no-check-certificate ${shadowsocks_service_yum} -O /etc/init.d/${shadowsocks_name}; then
            echo -e "[${red}Error${plain}] Failed to download Shadowsocks chkconfig file!"
            exit 1
        fi
    elif check_sys packageManager apt; then
        if ! wget --no-check-certificate ${shadowsocks_service_apt} -O /etc/init.d/${shadowsocks_name}; then
            echo -e "[${red}Error${plain}] Failed to download Shadowsocks chkconfig file!"
            exit 1
        fi
    fi
}

# Firewall set
firewall_set(){
    echo -e "[${green}Info${plain}] firewall set start..."
    if centosversion 6; then
        /etc/init.d/iptables status > /dev/null 2>&1
        if [ $? -eq 0 ]; then
            iptables -L -n | grep -i ${shadowsocksport} > /dev/null 2>&1
            if [ $? -ne 0 ]; then
                iptables -I INPUT -m state --state NEW -m tcp -p tcp --dport ${shadowsocksport} -j ACCEPT
                iptables -I INPUT -m state --state NEW -m udp -p udp --dport ${shadowsocksport} -j ACCEPT
                /etc/init.d/iptables save
                /etc/init.d/iptables restart
            else
                echo -e "[${green}Info${plain}] port ${shadowsocksport} has been set up!"
            fi
        else
            echo -e "[${yellow}Warning${plain}] iptables looks like shutdown or not installed, please manually set it if necessary!"
        fi
    elif centosversion 7; then
        systemctl status firewalld > /dev/null 2>&1
        if [ $? -eq 0 ]; then
            firewall-cmd --permanent --zone=public --add-port=${shadowsocksport}/tcp
            firewall-cmd --permanent --zone=public --add-port=${shadowsocksport}/udp
            firewall-cmd --reload
        else
            echo -e "[${yellow}Warning${plain}] firewalld looks like not running or not installed, please enable port ${shadowsocksport} manually if necessary!"
        fi
    fi
    echo -e "[${green}Info${plain}] firewall set completed..."
}

# Set userapiconfig.py
config_userapi(){
    cat > /usr/local/${shadowsocks_dir}/userapiconfig.py<<-EOF
# Config
NODE_ID = ${mysql_nodeid}


# hour,set 0 to disable
SPEEDTEST = 6
CLOUDSAFE = 1
ANTISSATTACK = 0
AUTOEXEC = 0

MU_SUFFIX = 'baidu.com'
MU_REGEX = '%5m%id.%suffix'

SERVER_PUB_ADDR = '127.0.0.1'  # mujson_mgr need this to generate ssr link
API_INTERFACE = '${shadowsocksinterface}'  # glzjinmod, modwebapi

WEBAPI_URL = 'https://zhaoj.in'
WEBAPI_TOKEN = 'glzjin'

# mudb
MUDB_FILE = 'mudb.json'

# Mysql
MYSQL_HOST = '${mysql_ip_address}'
MYSQL_PORT = ${mysql_ip_port}
MYSQL_USER = '${mysql_user_name}'
MYSQL_PASS = '${mysql_db_password}'
MYSQL_DB = '${mysql_db_name}'

MYSQL_SSL_ENABLE = 0
MYSQL_SSL_CA = ''
MYSQL_SSL_CERT = ''
MYSQL_SSL_KEY = ''

# API
API_HOST = '127.0.0.1'
API_PORT = 80
API_PATH = '/mu/v2/'
API_TOKEN = 'abcdef'
API_UPDATE_TIME = 60

# Manager (ignore this)
MANAGE_PASS = 'ss233333333'
# if you want manage in other server you should set this value to global ip
MANAGE_BIND_IP = '127.0.0.1'
# make sure this port is idle
MANAGE_PORT = 23333
EOF
}

# Config user-config.json
config_userjson(){
    cat > /usr/local/${shadowsocks_dir}/user-config.json<<-EOF
{
    "server": "0.0.0.0",
    "server_ipv6": "::",
    "server_port": ${shadowsocksport},
    "local_address": "127.0.0.1",
    "local_port": 1080,

    "password": "${shadowsockspwd}",
    "timeout": 120,
    "udp_timeout": 60,
    "method": "${shadowsockscipher}",
    "protocol": "${shadowsocksprotocol}",
    "protocol_param": "",
    "obfs": "${shadowsocksobfs}",
    "obfs_param": "",
    "speed_limit_per_con": 0,

    "dns_ipv6": false,
    "connect_verbose_info": 1,
    "connect_hex_data": 0,
    "redirect": "",
    "fast_open": false,
    "friendly_detect": 1
}
EOF
}

# Deploy config
deploy_config(){
    while true
    do
    # Set api_interface.py
    echo -e "Please select interface for Shadowsocks:"
    for ((i=1;i<=${#interfaces[@]};i++ )); do
        hint="${interfaces[$i-1]}"
        echo -e "${green}${i}${plain}) ${hint}"
    done
    read -p "Which interface you'd select(Default: ${interfaces[0]}):" interface
    [ -z "$interface" ] && interface=1
    expr ${interface} + 1 &>/dev/null
    if [ $? -ne 0 ]; then
        echo -e "[${red}Error${plain}] Input error, please input a number"
        continue
    fi
    if [[ "$interface" -lt 1 || "$interface" -gt ${#interfaces[@]} ]]; then
        echo -e "[${red}Error${plain}] Input error, please input a number between 1 and ${#interfaces[@]}"
        continue
    fi
    shadowsocksinterface=${interfaces[$interface-1]}
    echo
    echo "---------------------------"
    echo "api_interface = ${shadowsocksinterface}"
    echo "---------------------------"
    echo
    break
    done

    # Set MySQL
    while true
    do
    #ip
    echo -e "Please enter the mysql ip address:"
    read -p "(Default address: 127.0.0.1):" mysql_ip_address
    [ -z "${mysql_ip_address}" ] && mysql_ip_address="127.0.0.1"
    expr ${mysql_ip_address} + 1 &>/dev/null
    #port
    echo -e "Please enter the mysql port:"
    read -p "(Default port: 3306):" mysql_ip_port
    [ -z "${mysql_ip_port}" ] && mysql_ip_port="3306"
    expr ${mysql_ip_port} + 1 &>/dev/null
    #db_name
    echo -e "Please enter the mysql db_name:"
    read -p "(Default name: sspanel):" mysql_db_name
    [ -z "${mysql_db_name}" ] && mysql_db_name="sspanel"
    expr ${mysql_db_name} + 1 &>/dev/null
    #user_name
    echo -e "Please enter the mysql user_name:"
    read -p "(Default user: sspanel):" mysql_user_name
    [ -z "${mysql_user_name}" ] && mysql_user_name="sspanel"
    expr ${mysql_user_name} + 1 &>/dev/null
    #db_password
    echo -e "Please enter the mysql db_password:"
    read -p "(Default password: password):" mysql_db_password
    [ -z "${mysql_db_password}" ] && mysql_db_password="password"
    expr ${mysql_db_password} + 1 &>/dev/null
    #nodeid
    echo -e "Please enter This node ID:"
    read -p "(Default ID: 3):" mysql_nodeid
    [ -z "${mysql_nodeid}" ] && mysql_nodeid="3"
    expr ${mysql_nodeid} + 1 &>/dev/null
    echo
    echo -e "-----------------------------------------------------"
    echo -e "The MySQL Configuration has been completed! "
    echo -e "-----------------------------------------------------"
    echo -e "Your MySQL IP       : ${mysql_ip_address}            "
    echo -e "Your MySQL Port     : ${mysql_ip_port}               "
    echo -e "Your MySQL User     : ${mysql_user_name}             "
    echo -e "Your MySQL Password : ${mysql_db_password}           "
    echo -e "Your MySQL DBname   : ${mysql_db_name}               "
    echo -e "Your Node ID        : ${mysql_nodeid}                "
    echo -e "-----------------------------------------------------"
    break
    done

    echo "Press any key to start install Shadowsocks or Press Ctrl+C to cancel. Please continue!"
    char=`get_char`
    # Install necessary dependencies
    if check_sys packageManager yum; then
        yum -y install python python-devel openssl openssl-devel libffi-devel curl wget unzip gcc automake autoconf make libtool wget git
        yum -y install python-setuptools && easy_install pip
    elif check_sys packageManager apt; then
        apt-get -y update
        apt-get -y install python python-dev openssl libssl-dev libffi-dev curl wget unzip gcc automake autoconf make libtool wget git
        apt-get -y install python-setuptools && easy_install pip
    fi
    cd ${cur_dir}
}

# Deploy Shadowsocks
deploy_shadowsocks(){
    cd ${cur_dir}
    easy_install ordereddict
    pip install cython
    pip install cymysql
    tar zxf ${shadowsocks_file}.tar.gz
    mv ${shadowsocks_file} /usr/local/${shadowsocks_dir}
    cd /usr/local/${shadowsocks_dir}
    pip install -r requirements.txt
    config_userapi
    config_userjson
    cd ${cur_dir}
}

# Install libsodium
install_libsodium(){
    if [ ! -f /usr/lib/libsodium.a ]; then
        cd ${cur_dir}
        tar zxf ${libsodium_file}.tar.gz
        cd ${libsodium_file}
        ./configure --prefix=/usr && make && make install
        if [ $? -ne 0 ]; then
            echo -e "[${red}Error${plain}] libsodium install failed!"
            install_cleanup
            exit 1
        fi
    fi

    ldconfig
}

# Starts shadowsocks service
start_service(){
    if [ -f /usr/local/${shadowsocks_dir}/server.py ]; then
        if [ $? -eq 0 ]; then
            chmod +x /etc/init.d/${shadowsocks_name}
            if check_sys packageManager yum; then
                chkconfig --add ${shadowsocks_name}
                chkconfig ${shadowsocks_name} on
            elif check_sys packageManager apt; then
                update-rc.d -f ${shadowsocks_name} defaults
            fi

            /etc/init.d/${shadowsocks_name} start
            if [ $? -eq 0 ]; then
                echo -e "[${green}Info${plain}] Shadowsocks start success!"
            else
                echo -e "[${yellow}Warning${plain}] Shadowsocks start failure!"
            fi
            
            echo
            echo -e "-------------------------------------------------"
            echo -e "Congratulations, Shadowsocks deploy completed!"
            echo -e "-------------------------------------------------"        
            echo -e "               Config  Info                      "
            echo -e "Your Server IP        : $(get_ip)                "
            echo -e "Your Server Port      : ${shadowsocksport}      "
            echo -e "Your Password         : ${shadowsockspwd}       "
            echo -e "Your Encryption Method: ${shadowsockscipher}    "
            echo -e "Your Protocol         : ${shadowsocksprotocol}  "
            echo -e "Your Obfs             : ${shadowsocksobfs}      "
            echo -e "Your Connect Info     : 1                        "
            echo -e "               Deploy  Info                      "
            echo -e "Your Api Interface    : ${shadowsocksinterface} "
            echo -e "Your MySQL IP         : ${mysql_ip_address}      "
            echo -e "Your MySQL Port       : ${mysql_ip_port}         " 
            echo -e "Your MySQL User       : ${mysql_user_name}       "
            echo -e "Your MySQL Password   : ${mysql_db_password}     "
            echo -e "Your MySQL DBname     : ${mysql_db_name}         "
            echo -e "Your Node ID          : ${mysql_nodeid}          "
            echo -e "-------------------------------------------------"         
            echo -e "                Enjoy it!                        "
            echo -e "-------------------------------------------------" 
        else
            echo
            echo -e "[${red}Error${plain}] Could not find server.py file, failed to start service!"
            exit 1
        fi

    else
        echo
        echo -e "[${red}Error${plain}] Shadowsocks install failed!"
        exit 1
    fi
}

# Clean install
install_cleanup(){
    cd ${cur_dir}
    rm -rf ${libsodium_file}.tar.gz
    rm -rf ${libsodium_file}
    rm -rf ${shadowsocks_file}.tar.gz
    rm -rf ${shadowsocks_file}
}


# Install Shadowsocks
install_shadowsocks(){
    if [ -d "/usr/local/${shadowsocks_dir}" ]; then
        printf "Shadowsocks has been installed, Do you want to uninstall it? (y/n)"
        printf "\n"
        read -p "(Default: y):" install_answer
        [ -z ${install_answer} ] && install_answer="y"
        if [ "${install_answer}" == "y" ] || [ "${install_answer}" == "Y" ]; then
            uninstall
            cd ${cur_dir}
            choose_command
        else
            echo
            echo "uninstall cancelled, nothing to do..."
            echo
        fi
    else
        disable_selinux
        install_prepare
        deploy_config
        download_files
        install_libsodium
        deploy_shadowsocks
        if check_sys packageManager yum; then
            firewall_set
        fi
        start_service
        install_cleanup
        exit 0
    fi
}

# Uninstall Shadowsocks
uninstall_shadowsocks(){
    printf "Are you sure uninstall Shadowsocks? (y/n)"
    printf "\n"
    read -p "(Default: n):" answer
    [ -z ${answer} ] && answer="n"
    if [ "${answer}" == "y" ] || [ "${answer}" == "Y" ]; then
        if [ -d "/usr/local/${shadowsocks_dir}" ]; then
            /etc/init.d/${shadowsocks_name} status > /dev/null 2>&1
            if [ $? -eq 0 ]; then
                /etc/init.d/${shadowsocks_name} stop
            fi
            if check_sys packageManager yum; then
                chkconfig --del ${shadowsocks_name}
            elif check_sys packageManager apt; then
                update-rc.d -f ${shadowsocks_name} remove
            fi
            install_cleanup

            rm -f /etc/init.d/${shadowsocks_name}
            rm -f ./${shadowsocks_name}.log
            rm -rf /usr/local/${shadowsocks_dir}
            echo "Shadowsocks uninstall success!"
        else
            echo
            echo "Your Shadowsocks is not installed!"
            echo
        fi
    else
        echo
        echo "uninstall cancelled, nothing to do..."
        echo
    fi
}

# Initialization step
commands=(
Install\ Shadowsocks
Uninstall\ Shadowsocks
)


# Choose command
choose_command(){  
    while true
    do
    echo 
    echo -e "Welcome! Please select command to start:"
    echo -e "-------------------------------------------"
    for ((i=1;i<=${#commands[@]};i++ )); do
        hint="${commands[$i-1]}"
        echo -e "${green}${i}${plain}) ${hint}"
    done
    echo -e "-------------------------------------------"
    read -p "Which command you'd select(Default: ${commands[0]}):" order_num
    [ -z "$order_num" ] && order_num=1
    expr ${order_num} + 1 &>/dev/null
    if [ $? -ne 0 ]; then
        echo 
        echo -e "[${red}Error${plain}] Please enter a number"
        continue
    fi
    if [[ "$order_num" -lt 1 || "$order_num" -gt ${#commands[@]} ]]; then
        echo 
        echo -e "[${red}Error${plain}] Please enter a number between 1 and ${#commands[@]}"
        continue
    fi
    break
    done

    case $order_num in
        1)
        install_shadowsocks
        ;;
        2)
        uninstall_shadowsocks
        ;;
        *)
        exit 1
        ;;
    esac
}
# start
cd ${cur_dir}
choose_command

