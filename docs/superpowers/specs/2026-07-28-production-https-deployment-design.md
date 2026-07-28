# 线上 API HTTPS 部署设计

## 目标

为 `api.homecrm.store` 的现有 Docker Nginx 接入已签发的 TLS 证书，
使 `https://api.homecrm.store/api` 可访问，同时暂时保留现有 HTTP 服务。

## 当前结构

- 生产 Compose：`/etc/homecrm/docker-compose.prod.yml`
- 代码目录：`/www/home_crm`
- Nginx 容器：`homecrm-nginx-1`，镜像 `nginx:1.27-alpine`
- 当前端口：宿主机 `80` 映射到容器 `80`
- 当前 Nginx 配置挂载自代码仓库
  `/www/home_crm/server/docker/nginx/default.conf`
- 生产代码仓库当前无未提交改动

## 方案

生产 TLS 配置与代码仓库分离：

- 证书文件存放于 `/etc/homecrm/ssl`。
- 生产 Nginx 配置存放于 `/etc/homecrm/nginx/default.conf`。
- Compose 将证书目录和生产 Nginx 配置只读挂载到容器。
- Compose 新增宿主机 `443` 到容器 `443` 的端口映射。
- 同一 Nginx server 同时监听 80 和 443，不在本次部署中强制 HTTP 跳转。
- 只启用 TLS 1.2 和 TLS 1.3。

证书私钥权限设为 `600`，证书目录权限设为 `700`；证书和私钥不进入
Git 仓库。

## 部署与回滚

变更前备份现有 Compose 和 Nginx 配置。部署时先验证：

1. 证书域名、有效期以及证书与私钥匹配。
2. `docker compose config` 能正确解析。
3. 新 Nginx 配置通过 `nginx -t`。

仅在验证通过后重建 Nginx 容器，不重启 API 容器。若验证或外部访问失败，
恢复备份的 Compose 和 Nginx 配置并重建 Nginx。

## 验收

- 宿主机监听 443。
- Nginx 容器健康运行，配置检查通过。
- TLS 握手返回 `api.homecrm.store` 的有效证书链。
- `https://api.homecrm.store/api` 返回 HTTP 200 和 API 健康信息。
- `http://api.homecrm.store/api` 保持现有行为。
