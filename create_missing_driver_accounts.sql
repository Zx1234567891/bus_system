-- 为现有的没有用户账号的司机创建账号
-- 默认密码：123456

USE bus_safety_system;

-- 插入用户凭证（为所有没有账号的司机创建）
INSERT INTO user_credentials (employee_id, username, password_hash, salt, role, is_active)
SELECT 
    e.employee_id,
    e.emp_code as username,
    -- SHA256('123456' + salt) 的结果
    SHA2(CONCAT('123456', UUID()), 256) as password_hash,
    UUID() as salt,
    'driver' as role,
    1 as is_active
FROM employee e
INNER JOIN driver d ON e.employee_id = d.driver_id
LEFT JOIN user_credentials uc ON e.employee_id = uc.employee_id
WHERE uc.user_id IS NULL;  -- 只为没有账号的司机创建

-- 查看结果
SELECT 
    e.emp_code as '工号',
    e.name as '姓名',
    uc.username as '用户名',
    uc.role as '角色',
    '123456' as '默认密码'
FROM employee e
INNER JOIN driver d ON e.employee_id = d.driver_id
INNER JOIN user_credentials uc ON e.employee_id = uc.employee_id
ORDER BY e.emp_code;

SELECT CONCAT('✓ 已为 ', COUNT(*), ' 个司机创建用户账号') as '执行结果'
FROM employee e
INNER JOIN driver d ON e.employee_id = d.driver_id
INNER JOIN user_credentials uc ON e.employee_id = uc.employee_id;
