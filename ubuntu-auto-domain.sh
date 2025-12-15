#!/bin/bash
# ==========================================
# Ubuntu 自动绑定域名脚本
# 功能: 自动配置域名 + SSL证书 + Nginx反向代理
# 适用于: Ubuntu 18.04/20.04/22.04/24.04
# 作者: maow318
# 仓库: https://github.com/maow318/ubuntu-auto-domain
# ==========================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_success() { echo -e "${GREEN}✓ $1${NC}"; }
print_error() { echo -e "${RED}✗ $1${NC}"; }
print_info() { echo -e "${BLUE}➜ $1${NC}"; }

# 检查 root 权限
if [ "$EUID" -ne 0 ]; then 
    print_error "请使用 root 权限运行"
    echo "运行: sudo $0"
    exit 1
fi

# 检查是否为 Ubuntu
if [ ! -f /etc/lsb-release ]; then
    print_error "此脚本仅支持 Ubuntu 系统"
    exit 1
fi

clear
echo -e "${GREEN}╔════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║     Ubuntu 自动绑定域名工具          ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════╝${NC}"
echo ""

# ==========================================
# 收集配置信息
# ==========================================
echo -e "${BLUE}请输入配置信息:${NC}"
echo ""

# ==========================================
# 收集配置信息
# ==========================================
echo -e "${BLUE}请输入配置信息:${NC}"
echo ""

# 读取域名
while [ -z "$DOMAIN" ]; do
    read -p "域名: " DOMAIN </dev/tty
    if [ -z "$DOMAIN" ]; then
        print_error "域名不能为空，请重新输入"
    elif [[ ! "$DOMAIN" =~ \. ]]; then
        print_error "域名格式错误，请输入完整域名（如: example.com）"
        DOMAIN=""
    fi
done

# 读取端口
while [ -z "$APP_PORT" ]; do
    read -p "应用端口: " APP_PORT </dev/tty
    if [ -z "$APP_PORT" ]; then
        print_error "端口不能为空，请重新输入"
    elif ! [[ "$APP_PORT" =~ ^[0-9]+$ ]] || [ "$APP_PORT" -lt 1 ] || [ "$APP_PORT" -gt 65535 ]; then
        print_error "端口必须在 1-65535 之间，请重新输入"
        APP_PORT=""
    fi
done

# 读取邮箱
while [ -z "$EMAIL" ]; do
    read -p "邮箱: " EMAIL </dev/tty
    if [ -z "$EMAIL" ]; then
        print_error "邮箱不能为空，请重新输入"
    fi
done

# 读取上传限制
read -p "文件上传大小限制 (如: 100M, 500M, 1G，默认 100M): " UPLOAD_SIZE </dev/tty
UPLOAD_SIZE=${UPLOAD_SIZE:-100M}

# 确认配置
echo ""
echo -e "${YELLOW}╔════════════════════════════════════════╗${NC}"
echo -e "${YELLOW}║           配置确认                    ║${NC}"
echo -e "${YELLOW}╠════════════════════════════════════════╣${NC}"
echo -e "  域名: ${GREEN}$DOMAIN${NC}"
echo -e "  端口: ${GREEN}$APP_PORT${NC}"
echo -e "  邮箱: ${GREEN}$EMAIL${NC}"
echo -e "  上传限制: ${GREEN}$UPLOAD_SIZE${NC}"
echo -e "${YELLOW}╚════════════════════════════════════════╝${NC}"
echo ""
echo -e "${RED}⚠️  重要: 确保应用监听在 127.0.0.1:$APP_PORT${NC}"
echo ""
read -p "确认无误按 Enter 继续..." </dev/tty

# ==========================================
# 1. 处理系统自动更新
# ==========================================
echo ""
print_info "[1/7] 处理系统自动更新..."

# 停止自动更新
systemctl stop unattended-upgrades 2>/dev/null || true
systemctl disable unattended-upgrades 2>/dev/null || true

# 等待并清理 apt 锁
for i in {1..30}; do
    if ! fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1; then
        break
    fi
    if [ $i -eq 1 ]; then
        echo "等待系统自动更新完成..."
    fi
    sleep 2
done

# 强制清理锁文件
killall apt apt-get 2>/dev/null || true
sleep 2
rm -f /var/lib/dpkg/lock-frontend
rm -f /var/lib/dpkg/lock
rm -f /var/cache/apt/archives/lock
dpkg --configure -a

print_success "自动更新已处理"

# ==========================================
# 2. 更新系统并安装依赖
# ==========================================
echo ""
print_info "[2/7] 更新系统..."

export DEBIAN_FRONTEND=noninteractive
apt-get update -y

print_info "安装依赖包..."
apt-get install -y nginx curl socat

print_success "依赖包安装完成"

# ==========================================
# 3. 检查域名解析
# ==========================================
echo ""
print_info "[3/7] 检查域名解析..."

if command -v dig >/dev/null 2>&1; then
    RESOLVED_IP=$(dig +short $DOMAIN @8.8.8.8 | tail -n1)
    if [ -n "$RESOLVED_IP" ]; then
        print_success "域名解析到: $RESOLVED_IP"
    else
        print_error "域名未解析，请先配置 DNS"
        exit 1
    fi
else
    print_info "跳过域名检查 (dig 未安装)"
fi

# ==========================================
# 4. 安装 acme.sh
# ==========================================
echo ""
print_info "[4/7] 安装 acme.sh..."

export HOME=/root

if [ -f /root/.acme.sh/acme.sh ]; then
    print_info "acme.sh 已存在，跳过安装"
else
    curl -s https://get.acme.sh | sh -s email=$EMAIL
    sleep 2
fi

# 加载环境
source /root/.bashrc 2>/dev/null || true

# 设置默认 CA
/root/.acme.sh/acme.sh --set-default-ca --server letsencrypt

print_success "acme.sh 已准备就绪"

# ==========================================
# 5. 申请 SSL 证书
# ==========================================
echo ""
print_info "[5/7] 申请 SSL 证书..."

# 停止 nginx
systemctl stop nginx 2>/dev/null || true

# 申请证书
if /root/.acme.sh/acme.sh --issue --standalone -d $DOMAIN --listen-v4 --force; then
    print_success "证书申请成功"
else
    print_error "证书申请失败"
    echo ""
    echo "可能原因:"
    echo "  1. 域名未正确解析到本服务器"
    echo "  2. 80 端口被占用"
    echo "  3. 防火墙阻止访问"
    exit 1
fi

# ==========================================
# 6. 配置 Nginx
# ==========================================
echo ""
print_info "[6/7] 配置 Nginx..."

# 创建证书目录
CERT_DIR="/etc/ssl/${DOMAIN}"
mkdir -p $CERT_DIR

cat > /etc/nginx/sites-available/${DOMAIN} <<EOF
# HTTP -> HTTPS 重定向
server {
    listen 80;
    listen [::]:80;
    server_name ${DOMAIN};
    
    location /.well-known/acme-challenge/ {
        root /var/www/html;
    }
    
    location / {
        return 301 https://\$host\$request_uri;
    }
}

# HTTPS 反向代理
server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name ${DOMAIN};

    # SSL 证书
    ssl_certificate ${CERT_DIR}/fullchain.pem;
    ssl_certificate_key ${CERT_DIR}/privkey.pem;
    
    # SSL 配置
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers off;
    ssl_session_cache shared:SSL:10m;
    
    # 安全头
    add_header Strict-Transport-Security "max-age=31536000" always;
    
    # 文件上传大小限制
    client_max_body_size ${UPLOAD_SIZE};
    
    # 反向代理配置
    location / {
        proxy_pass http://127.0.0.1:${APP_PORT};
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        
        # WebSocket 支持
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        
        # 超时设置
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
}
EOF

# 启用站点
ln -sf /etc/nginx/sites-available/${DOMAIN} /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

print_success "Nginx 配置已创建"

# ==========================================
# 7. 安装证书并启动 Nginx
# ==========================================
echo ""
print_info "[7/7] 安装证书..."

# 安装证书（不使用 reload 命令）
/root/.acme.sh/acme.sh \
    --install-cert -d $DOMAIN \
    --key-file ${CERT_DIR}/privkey.pem \
    --fullchain-file ${CERT_DIR}/fullchain.pem

print_success "证书已安装"

# 测试 Nginx 配置
print_info "测试 Nginx 配置..."
if nginx -t; then
    print_success "Nginx 配置验证通过"
else
    print_error "Nginx 配置有误"
    nginx -t
    exit 1
fi

# 启动 Nginx
print_info "启动 Nginx..."
systemctl start nginx
systemctl enable nginx

# 等待 Nginx 启动
sleep 2

# 更新 acme.sh 的 reload 命令
/root/.acme.sh/acme.sh \
    --install-cert -d $DOMAIN \
    --key-file ${CERT_DIR}/privkey.pem \
    --fullchain-file ${CERT_DIR}/fullchain.pem \
    --reloadcmd "systemctl reload nginx"

print_success "Nginx 已启动"

# 自动续期
/root/.acme.sh/acme.sh --upgrade --auto-upgrade

# ==========================================
# 完成
# ==========================================
echo ""
echo -e "${GREEN}╔════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║          🎉 配置完成！               ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════╝${NC}"
echo ""
echo -e "🌐 访问地址: ${GREEN}https://${DOMAIN}${NC}"
echo -e "📧 邮箱: $EMAIL"
echo -e "🔐 证书: $CERT_DIR"
echo -e "🔒 端口: 127.0.0.1:$APP_PORT"
echo ""
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}测试命令:${NC}"
echo ""
echo -e "  curl -I https://${DOMAIN}"
echo -e "  systemctl status nginx"
echo -e "  ss -tlnp | grep ${APP_PORT}"
echo ""
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${RED}⚠️  防火墙配置提醒:${NC}"
echo ""
echo "  请自行配置防火墙，开放以下端口:"
echo -e "  ${GREEN}✓${NC} 22/tcp  - SSH"
echo -e "  ${GREEN}✓${NC} 80/tcp  - HTTP"
echo -e "  ${GREEN}✓${NC} 443/tcp - HTTPS"
echo -e "  ${RED}✗${NC} ${APP_PORT}/tcp - 拒绝外部访问"
echo ""
echo "  UFW 示例命令:"
echo "    ufw allow 22/tcp"
echo "    ufw allow 80/tcp"
echo "    ufw allow 443/tcp"
echo "    ufw deny ${APP_PORT}/tcp"
echo "    ufw enable"
echo ""
