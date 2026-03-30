-- ============================================================
-- 用户凭证表 - 用于存储登录信息和密码
-- ============================================================

USE bus_safety_system;

-- 创建用户凭证表
CREATE TABLE IF NOT EXISTS user_credentials (
    user_id INT PRIMARY KEY AUTO_INCREMENT COMMENT '用户ID',
    employee_id INT NOT NULL UNIQUE COMMENT '员工ID（关联employee表）',
    username VARCHAR(50) UNIQUE NOT NULL COMMENT '登录用户名',
    password_hash VARCHAR(255) NOT NULL COMMENT '密码哈希',
    salt VARCHAR(64) NOT NULL COMMENT '密码盐值',
    role ENUM('admin', 'captain', 'driver', 'employee') DEFAULT 'employee' COMMENT '用户角色',
    avatar VARCHAR(255) DEFAULT NULL COMMENT '头像文件名',
    is_active TINYINT(1) DEFAULT 1 COMMENT '账号是否激活',
    last_login DATETIME COMMENT '最后登录时间',
    login_attempts INT DEFAULT 0 COMMENT '登录失败次数',
    locked_until DATETIME COMMENT '账号锁定截止时间',
    password_reset_token VARCHAR(64) COMMENT '密码重置令牌',
    token_expires_at DATETIME COMMENT '令牌过期时间',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    
    FOREIGN KEY (employee_id) REFERENCES employee(employee_id) ON DELETE CASCADE,
    INDEX idx_username (username),
    INDEX idx_employee_id (employee_id),
    INDEX idx_reset_token (password_reset_token)
) ENGINE=InnoDB COMMENT='用户登录凭证表';

-- 创建密码历史表（可选，用于防止重复使用旧密码）
CREATE TABLE IF NOT EXISTS password_history (
    history_id INT PRIMARY KEY AUTO_INCREMENT,
    user_id INT NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    FOREIGN KEY (user_id) REFERENCES user_credentials(user_id) ON DELETE CASCADE,
    INDEX idx_user_id (user_id)
) ENGINE=InnoDB COMMENT='密码历史记录表';

-- 插入默认管理员账号（密码：admin123）
-- 注意：使用SHA-256加密，与Flask应用一致
INSERT INTO user_credentials (employee_id, username, password_hash, salt, role, is_active)
SELECT 1, 'admin', 
       '70632ff10a681b1233a51c015d4f7b5f8ccd399d8926b51717792cead231637e',  -- SHA256('admin123' + 'default_salt')
       'default_salt', 
       'admin', 
       1
WHERE NOT EXISTS (SELECT 1 FROM user_credentials WHERE username = 'admin');

-- 为现有员工创建默认账号（密码：123456）
-- 注意：使用SHA256加密，与Flask应用一致
INSERT INTO user_credentials (employee_id, username, password_hash, salt, role, is_active)
SELECT 
    e.employee_id,
    e.emp_code,
    SHA2(CONCAT('123456', CONCAT('salt_', e.employee_id)), 256),  -- SHA256加密
    CONCAT('salt_', e.employee_id),
    'employee',
    1
FROM employee e
WHERE NOT EXISTS (
    SELECT 1 FROM user_credentials uc WHERE uc.employee_id = e.employee_id
)
AND e.status = '在职';

-- 创建视图：用户信息视图（用于管理界面）
CREATE OR REPLACE VIEW v_user_info AS
SELECT 
    uc.user_id,
    uc.employee_id,
    uc.username,
    e.emp_code,
    e.name,
    e.gender,
    e.phone,
    e.hire_date,
    e.status AS employee_status,
    uc.role,
    uc.avatar,
    uc.is_active,
    uc.last_login,
    uc.login_attempts,
    uc.locked_until,
    uc.created_at,
    uc.updated_at
FROM user_credentials uc
INNER JOIN employee e ON uc.employee_id = e.employee_id;

-- 查询所有用户信息
SELECT * FROM v_user_info ORDER BY created_at DESC;

SELECT '✓ 用户凭证表创建完成！' AS status;
