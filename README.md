
### 执行脚本
```
yum -y install wget
rm -rf ./deploy.sh ./shadowsocks.log
wget -N --no-check-certificate https://raw.githubusercontent.com/quniu/sspanel-deploy/master/deploy.sh
chmod +x deploy.sh
./deploy.sh 2>&1 | tee shadowsocks.log
```

### 说明
日志在`/root/`下面

脚本在`/root/`下面

安装路径在`/usr/local/shadowsocks`下面

### 查看shadowsocks服务

默认安装成功之后会自动启动服务

其他服务命令
```
service shadowsocks status
service shadowsocks stop
service shadowsocks start
```

### 注意
安装过程会要求填写或者确认某些数据，请认真看清楚！！！！！

一下是数据库默认信息

数据库ip，默认`127.0.0.1`

数据库端口，默认`3306`

数据库名，默认`sspanel`

数据库用户名，默认`sspanel`

数据库密码，默认`password`

### 建议

先创建节点获取到ID再去部署shadowsocks服务，因为配置需要填的node ID，这个node ID是在后台节点列表里ID选项对应的ID值


仅供个人参考学习，请勿用于商业活动
