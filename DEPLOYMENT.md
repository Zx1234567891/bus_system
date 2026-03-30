# 部署指南

## 📋 部署步骤

### 1. 导入主数据库

```bash
mysql -u root -proot < bus_safety_system.sql
```

### 2. 导入用户凭证表（重要！）

```bash
mysql -u root -proot < user_credentials.sql
```

这将创建：
- `user_credentials` 表 - 存储用户登录凭证和加密密码
- `password_history` 表 - 密码历史记录
- `v_user_info` 视图 - 用户信息视图
- 默认admin账号（用户名：admin，密码：admin123）
- 为所有现有员工创建默认账号（密码：123456）

### 3. 启动应用

**方式1：使用启动脚本**
```bash
双击 start.bat
```

**方式2：手动启动**
```bash
python app.py
```

### 4. 访问系统

- 登录页面：http://127.0.0.1:5000/login
- 主系统：http://127.0.0.1:5000/

## 🔑 默认账号

| 用户名 | 密码 | 角色 | 说明 |
|--------|------|------|------|
| admin | admin123 | 系统管理员 | 可访问用户管理功能 |
| [员工工号] | 123456 | 员工 | 所有现有员工的默认密码 |

## 🛠️ 数据库结构

### user_credentials 表

| 字段 | 类型 | 说明 |
|------|------|------|
| user_id | INT | 用户ID（主键）|
| employee_id | INT | 员工ID（外键）|
| username | VARCHAR(50) | 用户名（唯一）|
| password_hash | VARCHAR(255) | 密码哈希 |
| salt | VARCHAR(64) | 密码盐值 |
| role | ENUM | 角色（admin/captain/driver/employee）|
| is_active | TINYINT(1) | 账号是否激活 |
| last_login | DATETIME | 最后登录时间 |
| login_attempts | INT | 登录失败次数 |
| locked_until | DATETIME | 锁定截止时间 |
| password_reset_token | VARCHAR(64) | 密码重置令牌 |
| token_expires_at | DATETIME | 令牌过期时间 |

## 🔐 安全特性

### 密码加密
- 使用 SHA-256 算法
- 每个密码使用唯一的盐值
- 盐值长度：64字符（32字节十六进制）

### 登录保护
- 连续失败5次自动锁定30分钟
- 实时显示剩余尝试次数
- 管理员可手动解锁账号

### 权限控制
- 基于角色的访问控制（RBAC）
- 管理员专属功能（用户管理）
- 登录验证装饰器保护所有路由

## 👥 用户管理功能（admin专属）

### 功能列表
1. **查看用户列表**
   - 显示所有用户信息
   - 实时状态（激活/禁用/锁定）
   - 最后登录时间
   - 登录失败次数

2. **编辑用户**
   - 修改用户角色
   - 激活/禁用账号

3. **重置密码**
   - 管理员可为任何用户重置密码
   - 最少6位密码
   - 自动解锁账号

4. **解锁账号**
   - 一键解锁被锁定的账号
   - 重置登录失败次数

5. **删除用户**
   - 删除用户及凭证
   - 不能删除自己的账号
   - 级联删除（外键约束）

## 🔄 密码管理

### 用户自助修改密码
路径：个人设置 → 修改密码

API：`POST /api/change-password`
```json
{
  "old_password": "旧密码",
  "new_password": "新密码"
}
```

### 管理员重置密码
路径：用户管理 → 重置密码

API：`POST /api/users/{user_id}/reset-password`
```json
{
  "new_password": "新密码"
}
```

## 📊 API列表

### 认证相关
- `POST /api/login` - 用户登录
- `POST /api/register` - 用户注册
- `POST /api/logout` - 用户登出
- `GET /api/current-user` - 获取当前用户信息
- `POST /api/change-password` - 修改密码

### 用户管理（admin）
- `GET /api/users` - 获取所有用户
- `GET /api/users/{id}` - 获取单个用户
- `PUT /api/users/{id}` - 更新用户信息
- `DELETE /api/users/{id}` - 删除用户
- `POST /api/users/{id}/reset-password` - 重置密码
- `POST /api/users/unlock/{id}` - 解锁账号

## ⚠️ 注意事项

1. **首次部署必须按顺序导入SQL文件**
   - 先导入 `bus_safety_system.sql`
   - 再导入 `user_credentials.sql`

2. **密码安全**
   - 生产环境建议使用更强的加密算法（bcrypt/argon2）
   - 定期更新密码
   - 不要在代码中硬编码密码

3. **备份数据**
   - 定期备份 `user_credentials` 表
   - 备份时注意密码哈希的保密性

4. **会话管理**
   - 当前使用Flask内置session
   - 生产环境建议使用Redis等持久化存储
   - SECRET_KEY每次启动随机生成（建议固定）

## 🚀 生产环境建议

1. 使用环境变量管理配置
2. 启用HTTPS
3. 使用Gunicorn/uWSGI替代Flask开发服务器
4. 配置Nginx反向代理
5. 设置防火墙规则
6. 启用日志记录
7. 定期安全审计
