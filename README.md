## 注意事项
以下文档请务必仔细阅读和参照执行，否则可能会创建失败

强调几点：
* 切勿使用root账号进行如下操作，很多软件会检查当前用户名称，so请新建用户来进行操作;
* redis 启动需要加载配置
* 对startalk来说，配置中的domain 非常重要，请务必仔细配置，保持一致。
* 在开始之前请务必保证以下几个端口没有被占用：
```
openresty服务：8080
im_http_service服务：8005 8009 8081
qfproxy服务：8006 8010 8082
push_service服务：8007 8011 8083
qtalk_search服务：8888
qtalk_cowboy_server服务：10056

im服务： 5222 5201 5202 

db: 5432 

redis: 6379
```



# Startalk EJABBERD

Startalk(前身叫Qtalk，目前主体app尚未全部改名完毕。)是基于ejabberd，根据业务需要改造而来。修改和扩展了很多
ejaberd不支持的功能。



## 关键功能

-   分布式：去掉了依赖mnesia集群的代码，来支持更大的集群，以及防止由于网络分区导致的集群状态不一致。
-   消息处理：通过ejabberd和kafka相连接，实现了消息的路由和订阅发布，可以对消息添加更丰富的处理逻辑。
-   &#x2026;

## Startalk 模块

### Startalk 主要包含：

+ [ejabberd](https://github.com/qunarcorp/ejabberd-open)

IM核心组件，负责维持与客户端的长连接和消息路由

+ [or](https://github.com/qunarcorp/or_open)

IM负载均衡组件，负责验证客户端身份，以及转发http请求到对应的后台服务
+ [im_http_service](https://github.com/qunarcorp/im_http_service_open)

IM HTTP接口服务，负责IM相关数据的查询、设置以及历史消息同步

+ [qtalk_cowboy](https://github.com/qunarcorp/qtalk_cowboy_open)(后面所有的接口都会迁移到im_http_service，这个服务会废弃)

IM HTTP接口服务，负责IM相关数据的查询、设置以及历史消息同步，后面会全部迁移到im_http_service上

+ [qfproxy](https://github.com/qunarcorp/qfproxy_open)

IM文件服务，负责文件的上传和下载

+ [qtalk_serach](https://github.com/qunarcorp/qtalk_search)

提供远程搜索人员和群的服务

+ redis

IM缓存服务

+ postgresql

IM数据库服务

### Startalk 各个模块之间的关系

![architecture](image/arch.png)

## 安装

前提条件：

+ 服务器要求：centos7
+ hosts添加： 127.0.0.1 startalk.com
+ 主机名是：startalk.com
+ 所有项目都安装到/startalk下面
+ 安装用户和用户组是：startalk:startalk，要保证startalk用户有sudo权限
+ 家目录下有download文件夹，所有文件会下载到该文件夹下
+ 数据库用户名密码是ejabberd:123456，服务地址是：127.0.0.1
+ redis密码是：123456，服务地址是：127.0.0.1
+ 数据库初始化sql在doc目录下
+ 保证可访问主机的：5222、5202、8080端口（关掉防火墙：sudo systemctl stop firewalld.service）
+ IM服务的域名是:qtalk.test.org
+ tls证书：默认安装用的是一个测试证书，线上使用，请更换/startalk/ejabberd/etc/ejabberd/server.pem文件，生成方法见[securing-ejabberd-with-tls-encryption](https://blog.process-one.net/securing-ejabberd-with-tls-encryption/)

```
依赖包
# sudo yum install epel-release
# sudo yum -y update
# sudo yum -y groupinstall Base "Development Tools" "Perl Support"
# sudo yum -y install openssl openssl-devel unixODBC unixODBC-devel pkgconfig libSM libSM-devel libxslt ncurses-devel libyaml libyaml-devel expat expat-devel libxml2-devel libxml2 java-1.8.0-openjdk  java-1.8.0-openjdk-devel  pam-devel pcre-devel gd-devel bzip2-devel zlib-devel libicu-devel libwebp-devel gmp-devel curl-devel postgresql-devel libtidy libtidy-devel recode aspell libmcrypt  libmemcached gd

redis安装
sudo yum install -y redis
sudo vim /etc/redis.conf
 
daemonize yes
requirepass 123456
maxmemory 134217728   ##128Mbytes
 
启动redis
sudo redis-server /etc/redis.conf
 
数据库安装
１ 下载源代码
wget https://ftp.postgresql.org/pub/source/v11.1/postgresql-11.1.tar.gz
 
2 编译安装
#解压
tar -zxvf postgresql-11.1.tar.gz
cd postgresql-11.1/
sudo ./configure --prefix=/opt/pg11 --with-perl --with-libxml --with-libxslt
 
sudo make world
#编译的结果最后必须如下，否则需要检查哪里有error
#All of PostgreSQL successfully made. Ready to install.
 
sudo make install-world
#安装的结果做后必须如下，否则没有安装成功
#PostgreSQL installation complete.
 
3. 添加postgres OS用户
sudo groupadd postgres
  
sudo useradd -g postgres postgres
  
sudo mkdir -p /export/pg110_data
  
sudo chown postgres:postgres /export/pg110_data
 
4. 创建数据库实例
su - postgres
 
/opt/pg11/bin/initdb -D /export/pg110_data
 
5. 启动DB实例
 
/opt/pg11/bin/pg_ctl -D /export/pg110_data start
 
6. 初始化DB结构
 
/opt/pg11/bin/psql -U postgres -d postgres -f qtalk.sql
 
7. 初始化DB user: ejabberd的密码
 
/opt/pg11/bin/psql -U postgres -d postgres -c "ALTER USER ejabberd WITH PASSWORD '123456';"
 
8. 初始化测试数据
 
/opt/pg11/bin/psql -U postgres -d ejabberd -c "
insert into host_info (host, description, host_admin) values ('qtalk.test.org', 'qtalk.test.org', 'test');
insert into host_users (host_id, user_id, user_name, department, dep1, pinyin, frozen_flag, version, user_type, hire_flag, gender, password, initialpwd, ps_deptid) values ('1', 'test', '测试账号', '/机器人', '机器人', 'test', '0', '1', 'U', '1', '1', '1234567890', '1', 'qtalk');
insert into vcard_version (username, version, profile_version, gender, host, url) values ('test', '1', '1', '1', 'qtalk.test.org', 'https://qt.qunar.com/file/v2/download/avatar/1af5bc967f8535a4af19eca10dc95cf1.png');
insert into host_users (host_id, user_id, user_name, department, dep1, pinyin, frozen_flag, version, user_type, hire_flag, gender, password, initialpwd, ps_deptid) values ('1', 'file-transfer', '文件传输助手', '/智能服务助手', '智能服务助手', 'file-transfer', '1', '1', 'U', '1', '1', '15f15057f5be45c6bb6522d08078e0d4', '1', 'qtalk');
insert into vcard_version (username, version, profile_version, gender, host, url) values ('file-transfer', '1', '1', '1', 'qtalk.test.org', 'https://qt.qunar.com/file/v2/download/avatar/new/daa8a007ae74eb307856a175a392b5e1.png?name=daa8a007ae74eb307856a175a392b5e1.png&file=file/daa8a007ae74eb307856a175a392b5e1.png&fileName=file/daa8a007ae74eb307856a175a392b5e1.png');
"

新建安装目录
$ sudo mkdir /startalk
$ sudo chown startalk:startalk /startalk

下载源码
$ cd /home/startalk/download
$ git clone https://github.com/qunarcorp/ejabberd-open.git
$ git clone https://github.com/qunarcorp/or_open.git
$ git clone https://github.com/qunarcorp/qtalk_cowboy_open.git


openresty安装
$ cd /home/startalk/download
$ wget https://openresty.org/download/openresty-1.13.6.2.tar.gz
$ tar -zxvf openresty-1.13.6.2.tar.gz
$ cd openresty-1.13.6.2
$ ./configure --prefix=/startalk/openresty --with-http_auth_request_module
$ make
$ make install

or安装
$ cd /home/startalk/download
$ cd or_open
$ cp -rf conf /startalk/openresty/nginx
$ cp -rf lua_app /startalk/openresty/nginx

or配置修改

location的配置
/startalk/openresty/nginx/conf/conf.d/subconf/or.server.location.package.qtapi.conf

upstream的配置
/startalk/openresty/nginx/conf/conf.d/upstreams/qt.qunar.com.upstream.conf

redis连接地址配置
/startalk/openresty/nginx/lua_app/checks/qim/qtalkredis.lua

or操作
启动：/startalk/openresty/nginx/sbin/nginx
停止：/startalk/openresty/nginx/sbin/nginx -s stop


安装erlang
$ cd /home/startalk/download
$ wget http://erlang.org/download/otp_src_19.3.tar.gz
$ tar -zxvf otp_src_19.3.tar.gz
$ cd otp_src_19.3
$ ./configure --prefix=/startalk/erlang1903
$ make
$ make install

添加PATH
$ vim ~/.bash_profile
 
----------------------------------
$ User specific environment and startup programs
ERLANGPATH=/startalk/erlang1903
PATH=$PATH:$HOME/bin:$ERLANGPATH/bin
----------------------------------
 
$ . ~/.bash_profile

安装ejabberd
$ cd /home/startalk/download
$ cd ejabberd-open/
$ ./configure --prefix=/startalk/ejabberd --with-erlang=/startalk/erlang1903 --enable-pgsql --enable-full-xml
$ make
$ make install
$ cp ejabberd.yml.qunar /startalk/ejabberd/etc/ejabberd/ejabberd.yml
$ cp ejabberdctl.cfg.qunar /startalk/ejabberd/etc/ejabberd/ejabberdctl.cfg
$ vim /startalk/ejabberd/etc/ejabberd/ejabberd.yml
$ vim /startalk/ejabberd/etc/ejabberd/ejabberdctl.cfg

ejabberd配置
参考 https://github.com/qunarcorp/ejabberd-open/blob/master/doc/setting.md

启动ejabberd

$ cd /startalk/ejabberd
启动
$ ./sbin/ejabberdctl start
停止
$ ./sbin/ejabberdctl stop

安装qtalk_cowboy
$ cd /home/startalk/download
$ cp -rf qtalk_cowboy_open /startalk/qtalk_cowboy
$ cd /startalk/qtalk_cowboy/
$ ./rebar compile

启动qtalk_cowboy
$ ./bin/ejb_http_server start
停止qtalk_cowboy
$ ./bin/ejb_http_server stop


安装java服务
$ cd /home/startalk/download/
$ cp -rf or_open/deps/tomcat /startalk/
$ cd /startalk/tomcat

修改导航地址：
$  vim /startalk/tomcat/im_http_service/webapps/im_http_service/WEB-INF/classes/nav.json

-
{
  "Login": {
    "loginType": "password"
  },
  "baseaddess": {
    "simpleapiurl": "http://ip:8080",
    "fileurl": "http://ip:8080",
    "domain": "qtalk.test.org",
    "javaurl": "http://ip:8080/package",
    "protobufPcPort": 5202,
    "xmpp": "ip",
    "xmppport": 5222,
    "protobufPort": 5202,
    "pubkey": "rsa_public_key",
    "xmppmport": 5222,
    "httpurl": "http://ip:8080/newapi",
    "apiurl": "http://ip:8080/api"
  },
  "imConfig": {
    "RsaEncodeType": 1,
    "showOrganizational": true
  },
  "version": 10005
}
-
将ip替换成对应机器的ip地址


修改文件服务器配置

$ vim /startalk/tomcat/qfproxy/webapps/qfproxy/WEB-INF/classes/qfproxy.properties

project.host.and.port=http://ip:8080

将ip替换成对应机器的ip地址

修改推送服务的地址

$ vim /startalk/tomcat/push_service/webapps/push_service/WEB-INF/classes/app.properties
#使用星语push url
qtalk_push_url=http://ip:8091/qtapi/token/sendPush.qunar
#使用星语push key
qtalk_push_key=12342a14-e6c0-463f-90a0-92b8faec4063

启动java服务
$ cd /startalk/tomcat/im_http_service
$ ./bin/startup.sh


$ cd /startalk/tomcat/qfproxy
$ ./bin/startup.sh

$ cd /startalk/tomcat/push_service
$ ./bin/startup.sh

客户端配置导航地址：http://ip:8080/newapi/nck/qtalk_nav.qunar，使用账号：test，密码：1234567890登陆
```

## 配置文件修改

参考文档[setting.md](doc/setting.md)

## 接口文档

参考文档[interface.md](doc/interface.md)

## 开发指南

- [developer guide](https://docs.ejabberd.im/developer/guide/)

## 问题反馈

- qchat@qunar.com（邮件）
- qq群(852987381)
