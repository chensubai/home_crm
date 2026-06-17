# Docker 运行说明

服务：

- `nginx`：对外暴露 `8080`。
- `api`：PHP-FPM + Laravel。
- `mysql`：MySQL 8.4，数据卷 `mysql-data`。

首次启动：

```bash
cp server/.env.example server/.env
docker compose up --build
docker compose exec api php artisan migrate
```

API 容器启动时会检查 `server/vendor/autoload.php`，不存在就自动运行 `composer install`。这样 Laravel 依赖会落在宿主机的 `server/vendor` 目录，方便 IDE 索引。

测试：

```bash
docker compose run --rm --no-deps api ./vendor/bin/phpunit
```

如果依赖未安装或镜像未拉取，重新执行：

```bash
docker compose build --no-cache api
```
