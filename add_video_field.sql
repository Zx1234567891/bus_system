-- 为违章记录表添加视频URL字段
USE bus_safety_system;

-- 添加视频URL字段
ALTER TABLE violation_record 
ADD COLUMN video_url VARCHAR(500) COMMENT '违章视频URL' AFTER evidence_url;

-- 查看更新后的表结构
DESC violation_record;

SELECT '✓ 已成功添加 video_url 字段到 violation_record 表' AS '执行结果';
