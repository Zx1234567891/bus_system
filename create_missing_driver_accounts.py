#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""为现有的没有用户账号的司机自动创建账号"""

import pymysql
import hashlib
import secrets

def hash_password(password, salt=None):
    """密码哈希函数"""
    if salt is None:
        salt = secrets.token_hex(32)
    password_hash = hashlib.sha256((password + salt).encode()).hexdigest()
    return password_hash, salt

# 连接数据库
conn = pymysql.connect(
    host='localhost',
    port=3306,
    user='root',
    password='root',
    database='bus_safety_system',
    charset='utf8mb4'
)

try:
    with conn.cursor(pymysql.cursors.DictCursor) as cursor:
        print("正在查找没有用户账号的司机...")
        
        # 查找所有没有用户账号的司机
        cursor.execute("""
            SELECT e.employee_id, e.emp_code, e.name
            FROM employee e
            INNER JOIN driver d ON e.employee_id = d.driver_id
            LEFT JOIN user_credentials uc ON e.employee_id = uc.employee_id
            WHERE uc.user_id IS NULL
        """)
        
        drivers_without_account = cursor.fetchall()
        
        if not drivers_without_account:
            print("✓ 所有司机都已有用户账号！")
        else:
            print(f"发现 {len(drivers_without_account)} 个司机没有用户账号")
            print()
            
            # 为每个司机创建账号
            default_password = '123456'
            created_count = 0
            
            for driver in drivers_without_account:
                password_hash, salt = hash_password(default_password)
                
                try:
                    cursor.execute("""
                        INSERT INTO user_credentials (employee_id, username, password_hash, salt, role, is_active)
                        VALUES (%s, %s, %s, %s, 'driver', 1)
                    """, (driver['employee_id'], driver['emp_code'], password_hash, salt))
                    
                    print(f"✓ 已为司机 {driver['emp_code']} ({driver['name']}) 创建账号")
                    created_count += 1
                except Exception as e:
                    print(f"× 为司机 {driver['emp_code']} ({driver['name']}) 创建账号失败: {e}")
            
            conn.commit()
            print()
            print(f"======================================")
            print(f"✓ 成功为 {created_count} 个司机创建用户账号")
            print(f"  默认密码: {default_password}")
            print(f"  用户名: 员工工号")
            print(f"  角色: 司机 (driver)")
            print(f"======================================")
            
except Exception as e:
    print(f"× 错误: {e}")
    conn.rollback()
finally:
    conn.close()

print()
print("完成！现在新添加的司机可以在用户管理中看到了。")
