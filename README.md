# Ubuntu 自动绑定域名

🚀 一键为你的 Ubuntu 服务器绑定域名，自动配置 SSL 证书和 Nginx 反向代理

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Ubuntu](https://img.shields.io/badge/Ubuntu-18.04%20%7C%2020.04%20%7C%2022.04%20%7C%2024.04-orange)](https://ubuntu.com/)

## ✨ 功能特性

- ✅ 自动绑定域名到你的应用
- ✅ 自动申请免费 SSL 证书（Let's Encrypt）
- ✅ 自动配置 Nginx 反向代理
- ✅ 自动 HTTPS 加密访问
- ✅ 支持 WebSocket
- ✅ 证书自动续期，永久有效
- ✅ 可自定义文件上传大小

## 📋 使用前准备

1. **一台 Ubuntu 服务器** (18.04/20.04/22.04/24.04)
2. **一个域名** (已经解析到服务器 IP)
3. **Root 权限**

## 🚀 快速开始

### 方法 1: 下载脚本运行

```bash
wget https://raw.githubusercontent.com/maow318/ubuntu-auto-domain/main/ubuntu-auto-domain.sh
chmod +x ubuntu-auto-domain.sh
sudo ./ubuntu-auto-domain.sh
```

### 方法 2: 一键运行（推荐）

```bash
curl -fsSL https://raw.githubusercontent.com/maow318/ubuntu-auto-domain/main/ubuntu-auto-domain.sh | sudo bash
```

### 输入配置信息

脚本会提示你输入：

| 项目 | 说明 | 示例 |
|------|------|------|
| 域名 | 你的域名 | `example.com` |
| 应用端口 | 你的应用监听的本地端口 | `3000` |
| 邮箱 | 接收证书通知 | `admin@example.com` |
| 上传限制 | 最大文件上传大小 | `100M` / `500M` / `1G` |

### 完成！

访问 `https://你的域名` 就能看到你的应用了！

## 📖 使用示例

```bash
╔════════════════════════════════════════╗
║     Ubuntu 自动绑定域名工具          ║
╚════════════════════════════════════════╝

请输入配置信息:

域名: myapp.com
应用端口: 3000
邮箱: admin@myapp.com
文件上传大小限制 (如: 100M, 500M, 1G，默认 100M): 500M

╔════════════════════════════════════════╗
║           配置确认                    ║
╠════════════════════════════════════════╣
  域名: myapp.com
  端口: 3000
  邮箱: admin@myapp.com
  上传限制: 500M
╚════════════════════════════════════════╝

⚠️  重要: 确保应用监听在 127.0.0.1:3000

[1/7] 处理系统自动更新...
✓ 自动更新已处理

[2/7] 更新系统...
✓ 依赖包安装完成

[3/7] 检查域名解析...
✓ 域名解析到: 1.2.3.4

[4/7] 安装 acme.sh...
✓ acme.sh 已准备就绪

[5/7] 申请 SSL 证书...
✓ 证书申请成功

[6/7] 配置 Nginx...
✓ Nginx 配置已创建

[7/7] 安装证书...
✓ 证书已安装
✓ Nginx 配置验证通过
✓ Nginx 已启动

╔════════════════════════════════════════╗
║          🎉 配置完成！               ║
╚════════════════════════════════════════╝

🌐 访问地址: https://myapp.com
```

## ⚙️ 工作原理

```
互联网
  ↓
域名 (example.com:443)
  ↓
Nginx (SSL 加密)
  ↓
本地应用 (127.0.0.1:3000)
```

1. **用户访问** `https://example.com`
2. **Nginx 接收请求** 并验证 SSL 证书
3. **转发到本地应用** `127.0.0.1:3000`
4. **返回响应** 给用户

## 🔒 安全说明

- ✅ 应用端口不会暴露到公网
- ✅ 只能通过 HTTPS(443) 访问
- ✅ 自动强制 HTTP 跳转到 HTTPS
- ✅ 证书自动续期，无需手动操作

## ⚠️ 重要提示

### 1. 应用必须监听 127.0.0.1

**正确示例：**

```javascript
// Node.js / Express
app.listen(3000, '127.0.0.1', () => {
  console.log('Server running on 127.0.0.1:3000');
});

// Python / Flask
if __name__ == '__main__':
    app.run(host='127.0.0.1', port=3000)

// Go
http.ListenAndServe("127.0.0.1:3000", nil)
```

**错误示例：**

```javascript
// ❌ 错误：这会暴露到公网
app.listen(3000, '0.0.0.0')
```

### 2. 域名必须先解析

运行脚本前，确保域名已解析：

```bash
# 检查域名解析
dig +short example.com
# 或
nslookup example.com
```

### 3. 防火墙配置

脚本不会自动配置防火墙，完成后需要手动配置：

```bash
sudo ufw allow 22/tcp   # SSH
sudo ufw allow 80/tcp   # HTTP
sudo ufw allow 443/tcp  # HTTPS
sudo ufw deny 3000/tcp  # 拒绝直接访问应用端口
sudo ufw enable
```

## 📂 生成的文件

| 文件 | 路径 |
|------|------|
| Nginx 配置 | `/etc/nginx/sites-available/你的域名` |
| SSL 证书 | `/etc/ssl/你的域名/fullchain.pem` |
| SSL 私钥 | `/etc/ssl/你的域名/privkey.pem` |

## 🔄 证书管理

### 查看证书信息

```bash
/root/.acme.sh/acme.sh --info -d example.com
```

### 手动续期

```bash
/root/.acme.sh/acme.sh --renew -d example.com --force
```

### 查看自动续期任务

```bash
crontab -l | grep acme
```

## 🧪 测试

### 测试 HTTPS 访问

```bash
curl -I https://example.com
```

### 检查 Nginx 状态

```bash
systemctl status nginx
```

### 检查证书有效期

```bash
echo | openssl s_client -servername example.com -connect example.com:443 2>/dev/null | openssl x509 -noout -dates
```

## 🐛 常见问题

### Q: 证书申请失败？

**A:** 检查：
1. 域名解析：`dig +short example.com`
2. 80 端口：`netstat -tlnp | grep :80`
3. 防火墙：`sudo ufw status`

### Q: 502 Bad Gateway？

**A:** 检查：
1. 应用是否运行：`ps aux | grep 你的应用`
2. 端口是否正确：`ss -tlnp | grep 3000`
3. 是否监听 127.0.0.1

### Q: 如何修改上传大小？

**A:** 编辑 Nginx 配置：

```bash
sudo nano /etc/nginx/sites-available/example.com
# 修改 client_max_body_size 行
sudo systemctl reload nginx
```

### Q: 如何绑定多个域名？

**A:** 再次运行脚本，输入新域名

### Q: 如何卸载？

**A:** 删除配置文件：

```bash
sudo systemctl stop nginx
sudo rm /etc/nginx/sites-enabled/example.com
sudo rm /etc/nginx/sites-available/example.com
sudo rm -rf /etc/ssl/example.com
sudo systemctl start nginx
```

## 🎨 支持的应用

- ✅ Node.js (Express, Koa, Next.js)
- ✅ Python (Flask, Django, FastAPI)
- ✅ Go (Gin, Echo, Fiber)
- ✅ Java (Spring Boot)
- ✅ PHP (Laravel, Symfony)
- ✅ Ruby (Rails)
- ✅ 静态网站 (HTML/CSS/JS)
- ✅ WebSocket 应用

## 📊 系统要求

- **系统**: Ubuntu 18.04+
- **内存**: ≥ 512MB
- **磁盘**: ≥ 1GB
- **网络**: 公网访问

## 📜 开源协议

MIT License - 免费使用，随意修改

## 🤝 贡献

欢迎提交 Issue 和 Pull Request！

如果这个脚本帮到了你，请给个 ⭐ Star！

## 📮 反馈

遇到问题？[提交 Issue](https://github.com/maow318/ubuntu-auto-domain/issues)

---

**Made with ❤️ by [maow318](https://github.com/maow318)**
