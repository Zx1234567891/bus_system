-- 修复重复数据的SQL脚本
-- 使用前请先备份数据库！

USE bus_safety_system;

-- 1. 查看重复的身份证号
SELECT id_card, COUNT(*) as count 
FROM employee 
GROUP BY id_card 
HAVING count > 1;

-- 2. 查看重复的工号
SELECT emp_code, COUNT(*) as count 
FROM employee 
GROUP BY emp_code 
HAVING count > 1;

-- 3. 删除重复的测试数据（保留最新的一条）
-- 注意：这会删除旧的重复记录！
-- DELETE e FROM employee e
-- INNER JOIN (
--     SELECT id_card, MAX(employee_id) as max_id
--     FROM employee
--     GROUP BY id_card
--     HAVING COUNT(*) > 1
-- ) dup ON e.id_card = dup.id_card AND e.employee_id < dup.max_id;

-- 4. 如果要删除所有测试数据，使用以下语句：
-- DELETE FROM employee WHERE name LIKE '%测试%' OR emp_code LIKE 'TEST%';

-- 5. 检查数据完整性
SELECT COUNT(*) as total_employees FROM employee;
SELECT COUNT(*) as total_drivers FROM driver;
SELECT COUNT(DISTINCT id_card) as unique_id_cards FROM employee;
