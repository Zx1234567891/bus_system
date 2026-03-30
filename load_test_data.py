#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""插入测试数据脚本"""

import pymysql
from datetime import datetime, timedelta

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
    with conn.cursor() as cursor:
        print("正在插入测试违章数据...")
        
        # 插入近30天的违章记录
        # violation_record表结构: driver_id, bus_id, fleet_id, route_id, station_id, violation_type_id, violation_time, violation_location, status
        # 使用真实存在的ID (driver_id: 5,6,8,9,11,12,14,16,18,23)
        test_violations = [
            (5, 1, 1, 1, 1, 1, 1, '成都市一环路', '已确认'),
            (6, 2, 1, 2, 2, 2, 2, '成都市二环路', '已确认'),
            (8, 3, 2, 3, 3, 3, 3, '成都市三环路', '待处理'),
            (5, 1, 1, 1, 1, 4, 5, '成都市四环路', '已确认'),
            (9, 4, 2, 4, 4, 1, 7, '成都市天府大道', '已确认'),
            (11, 5, 3, 5, 5, 5, 8, '成都市人民南路', '待处理'),
            (6, 2, 1, 2, 2, 6, 10, '成都市武侯大道', '已确认'),
            (12, 6, 3, 6, 6, 1, 12, '成都市锦江大道', '已确认'),
            (8, 3, 2, 3, 3, 2, 14, '成都市青羊大道', '已确认'),
            (14, 7, 1, 7, 7, 7, 15, '成都市金牛大道', '待处理'),
            (5, 1, 1, 1, 1, 3, 18, '成都市成华大道', '已确认'),
            (16, 8, 2, 8, 8, 1, 20, '成都市高新大道', '已确认'),
            (9, 4, 2, 4, 4, 8, 22, '成都市天府二街', '已确认'),
            (6, 2, 1, 2, 2, 1, 25, '成都市剑南大道', '待处理'),
            (18, 9, 3, 9, 9, 2, 28, '成都市世纪城', '已确认'),
        ]
        
        for v in test_violations:
            driver_id, bus_id, fleet_id, route_id, station_id, type_id, days_ago, location, status = v
            violation_time = (datetime.now() - timedelta(days=days_ago)).strftime('%Y-%m-%d %H:%M:%S')
            
            cursor.execute("""
                INSERT INTO violation_record (driver_id, bus_id, fleet_id, route_id, station_id, 
                                            violation_type_id, violation_time, violation_location, 
                                            recorded_by, status)
                VALUES (%s, %s, %s, %s, %s, %s, %s, %s, 1, %s)
            """, (driver_id, bus_id, fleet_id, route_id, station_id, type_id, violation_time, location, status))
        
        print(f"✓ 已插入 {len(test_violations)} 条违章记录")
        
        # 更新违章类型的严重程度
        cursor.execute("UPDATE violation_type SET severity = '轻微' WHERE type_id IN (3, 5, 6)")
        cursor.execute("UPDATE violation_type SET severity = '一般' WHERE type_id IN (1, 4, 8)")
        cursor.execute("UPDATE violation_type SET severity = '严重' WHERE type_id = 2")
        cursor.execute("UPDATE violation_type SET severity = '特别严重' WHERE type_id = 7")
        
        print("✓ 已更新违章类型严重程度")
        
        conn.commit()
        
        # 验证数据
        cursor.execute("SELECT COUNT(*) FROM violation_record")
        count = cursor.fetchone()[0]
        print(f"\n当前违章记录总数: {count}")
        
        print("\n✓ 测试数据加载完成！")
        
except Exception as e:
    print(f"× 错误: {e}")
    conn.rollback()
finally:
    conn.close()
