-- 插入测试数据脚本
USE bus_safety_system;

-- 插入测试违章记录（近30天）
INSERT INTO violation (driver_id, bus_plate, type_id, violation_date, location, points_deducted, fine_amount, status, description) VALUES
(1, '川A12345', 1, DATE_SUB(CURDATE(), INTERVAL 1 DAY), '成都市一环路', 3, 200, '已处理', '超速行驶'),
(2, '川A23456', 2, DATE_SUB(CURDATE(), INTERVAL 2 DAY), '成都市二环路', 6, 500, '已处理', '闯红灯'),
(3, '川A34567', 3, DATE_SUB(CURDATE(), INTERVAL 3 DAY), '成都市三环路', 2, 100, '待处理', '违规变道'),
(1, '川A12345', 4, DATE_SUB(CURDATE(), INTERVAL 5 DAY), '成都市四环路', 3, 150, '已处理', '不按规定车道行驶'),
(4, '川A45678', 1, DATE_SUB(CURDATE(), INTERVAL 7 DAY), '成都市天府大道', 3, 200, '已处理', '超速行驶'),
(5, '川A56789', 5, DATE_SUB(CURDATE(), INTERVAL 8 DAY), '成都市人民南路', 2, 100, '待处理', '违规停车'),
(2, '川A23456', 6, DATE_SUB(CURDATE(), INTERVAL 10 DAY), '成都市武侯大道', 3, 300, '已处理', '未系安全带'),
(6, '川A67890', 1, DATE_SUB(CURDATE(), INTERVAL 12 DAY), '成都市锦江大道', 3, 200, '已处理', '超速行驶'),
(3, '川A34567', 2, DATE_SUB(CURDATE(), INTERVAL 14 DAY), '成都市青羊大道', 6, 500, '已处理', '闯红灯'),
(7, '川A78901', 7, DATE_SUB(CURDATE(), INTERVAL 15 DAY), '成都市金牛大道', 12, 2000, '待处理', '酒后驾驶'),
(1, '川A12345', 3, DATE_SUB(CURDATE(), INTERVAL 18 DAY), '成都市成华大道', 2, 100, '已处理', '违规变道'),
(8, '川A89012', 1, DATE_SUB(CURDATE(), INTERVAL 20 DAY), '成都市高新大道', 3, 200, '已处理', '超速行驶'),
(4, '川A45678', 8, DATE_SUB(CURDATE(), INTERVAL 22 DAY), '成都市天府二街', 3, 200, '已处理', '遮挡号牌'),
(2, '川A23456', 1, DATE_SUB(CURDATE(), INTERVAL 25 DAY), '成都市剑南大道', 3, 200, '待处理', '超速行驶'),
(9, '川A90123', 2, DATE_SUB(CURDATE(), INTERVAL 28 DAY), '成都市世纪城', 6, 500, '已处理', '闯红灯');

-- 更新违章类型表，确保有严重程度
UPDATE violation_type SET severity = '轻微' WHERE type_id IN (3, 5, 6);
UPDATE violation_type SET severity = '一般' WHERE type_id IN (1, 4, 8);
UPDATE violation_type SET severity = '严重' WHERE type_id = 2;
UPDATE violation_type SET severity = '特别严重' WHERE type_id = 7;

SELECT '测试数据插入完成！' as message;
SELECT COUNT(*) as total_violations FROM violation;
