#!/bin/bash

echo "欢迎使用喵哥 Linux 服务器运维管理面板一键安装脚本！"

# 检查用户是否为 root 用户
if [ "$(id -u)" != "0" ]; then
  echo "请使用 root 用户运行该脚本"
  exit 1
fi

# 安装必要的依赖
apt-get update
apt-get install -y curl git unzip wget

# 安装 Docker 和 Docker Compose
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh
systemctl start docker
systemctl enable docker
rm get-docker.sh
curl -L https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m) -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# 设置防火墙
ufw allow OpenSSH
ufw allow http
ufw allow https
ufw --force enable

# 下载并启动管理面板的 Docker 容器
docker run -d -p 9000:9000 -v /var/run/docker.sock:/var/run/docker.sock portainer/portainer-ce

# 下载并启动备份和恢复的 Docker 容器
docker run -d -v /:/host -v /var/run/docker.sock:/var/run/docker.sock \
-e BACKUP_CRON="0 0 * * *" \
-e BACKUP_DEST="s3://my-bucket" \
-e AWS_ACCESS_KEY_ID="MY_ACCESS_KEY_ID" \
-e AWS_SECRET_ACCESS_KEY="MY_SECRET_ACCESS_KEY" \
blacklabelops/backup

# 下载并启动 Nginx 的 Docker 容器
docker run -d -p 80:80 -p 443:443 \
-v /etc/nginx/conf.d \
-v /etc/nginx/certs \
-v /etc/nginx/htpasswd \
-v /var/log/nginx \
-v /var/www \
-e NGINX_DOMAIN="mydomain.com" \
-e NGINX_EMAIL="myemail@example.com" \
-e NGINX_USERNAME="myusername" \
-e NGINX_PASSWORD="mypassword" \
-e LETSENCRYPT_EMAIL="myemail@example.com" \
-e LETSENCRYPT_HOST="mydomain.com" \
-e LETSENCRYPT_TEST="false" \
--restart always \
jwilder/nginx-proxy

# 下载并启动 Let's Encrypt 的 Docker 容器
docker run -d \
-v /etc/nginx/certs \
-v /var/run/docker.sock:/var/run/docker.sock \
-e EMAIL="myemail@example.com" \
-e URL="mydomain.com" \
-e PRODUCTION="true" \
-e NGINX_PROXY_CONTAINER="nginx-proxy" \
--restart always \
jrcs/letsencrypt-nginx-proxy-companion

# 下载并启动 Wordpress 的 Docker 容器
docker run -d \
-v wordpress:/var/www/html \
-e WORDPRESS_DB_HOST=db \
-e WORDPRESS_DB_USER=root \
-e WORDPRESS_DB_PASSWORD=pass \
-e WORDPRESS_DB_NAME=wordpress \
-e WORDPRESS_TABLE_PREFIX=wp_ \
-e VIRTUAL_HOST="mydomain.com" \
-e VIRTUAL_PORT=80 \
-e LETSENCRYPT_HOST="mydomain.com" \
--restart always \
wordpress

# 下载并启动 Halo 的 Docker 容器
docker run -d \
-e DB_TYPE=mysql \
-e DB_HOST=db \
-e DB_NAME=halo
-e DB_USER=root
-e DB_PASS=pass
-p 8090:8090
--restart always
halo/halo:latest

# 最后，输出一些有用的信息
echo "管理面板地址：http://your-server-ip:9000"
echo "备份和恢复：每天自动备份，存储在 S3 存储桶中"
echo "Nginx 配置：/etc/nginx/conf.d"
echo "SSL 证书：/etc/nginx/certs"
echo "网站根目录：/var/www"
echo "Wordpress 网站地址：http://你的域名"
echo "Halo 博客地址：http://your-server-ip:8090