-- ============================================================
-- 公交安全管理系统数据库设计
-- 数据库: bus_safety_system
-- 作者: AI Assistant
-- 创建日期: 2025-11-30
-- ============================================================

-- 创建数据库
DROP DATABASE IF EXISTS bus_safety_system;
CREATE DATABASE bus_safety_system 
    DEFAULT CHARACTER SET utf8mb4 
    COLLATE utf8mb4_unicode_ci;

USE bus_safety_system;

-- ============================================================
-- 第一部分：基础表结构设计（符合3NF规范化要求）
-- ============================================================

-- ------------------------------------------------------------
-- 1. 员工表（存储所有员工基础信息，包括队长和司机）
-- 设计说明：将员工基础信息独立存储，避免数据冗余
-- ------------------------------------------------------------
CREATE TABLE employee (
    employee_id INT PRIMARY KEY AUTO_INCREMENT COMMENT '员工ID',
    emp_code VARCHAR(20) NOT NULL UNIQUE COMMENT '员工工号',
    name VARCHAR(50) NOT NULL COMMENT '姓名',
    gender ENUM('男', '女') NOT NULL COMMENT '性别',
    id_card VARCHAR(18) NOT NULL UNIQUE COMMENT '身份证号',
    phone VARCHAR(11) COMMENT '联系电话',
    address VARCHAR(200) COMMENT '家庭住址',
    hire_date DATE NOT NULL COMMENT '入职日期',
    status ENUM('在职', '离职', '休假') NOT NULL DEFAULT '在职' COMMENT '员工状态',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    
    -- 用户自定义完整性约束
    CONSTRAINT chk_id_card CHECK (LENGTH(id_card) = 18),
    CONSTRAINT chk_phone CHECK (phone IS NULL OR LENGTH(phone) = 11)
) ENGINE=InnoDB COMMENT='员工基础信息表';

-- ------------------------------------------------------------
-- 2. 车队表
-- 设计说明：车队是公交公司的组织单位
-- ------------------------------------------------------------
CREATE TABLE fleet (
    fleet_id INT PRIMARY KEY AUTO_INCREMENT COMMENT '车队ID',
    fleet_code VARCHAR(20) NOT NULL UNIQUE COMMENT '车队编号',
    fleet_name VARCHAR(100) NOT NULL COMMENT '车队名称',
    captain_id INT COMMENT '队长ID（员工ID）',
    description VARCHAR(500) COMMENT '车队描述',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间'
) ENGINE=InnoDB COMMENT='车队信息表';

-- ------------------------------------------------------------
-- 3. 线路表
-- 设计说明：每条线路属于一个车队
-- ------------------------------------------------------------
CREATE TABLE route (
    route_id INT PRIMARY KEY AUTO_INCREMENT COMMENT '线路ID',
    route_code VARCHAR(20) NOT NULL UNIQUE COMMENT '线路编号（如：101路）',
    route_name VARCHAR(100) NOT NULL COMMENT '线路名称',
    fleet_id INT NOT NULL COMMENT '所属车队ID',
    start_station VARCHAR(100) COMMENT '起点站',
    end_station VARCHAR(100) COMMENT '终点站',
    total_distance DECIMAL(10,2) COMMENT '总里程（公里）',
    ticket_price DECIMAL(5,2) COMMENT '票价（元）',
    status ENUM('运营中', '停运', '调整中') NOT NULL DEFAULT '运营中' COMMENT '线路状态',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间'
) ENGINE=InnoDB COMMENT='公交线路表';

-- ------------------------------------------------------------
-- 4. 司机表（员工的扩展，仅存储司机特有信息）
-- 设计说明：继承员工表，避免重复存储基础信息，符合3NF
-- ------------------------------------------------------------
CREATE TABLE driver (
    driver_id INT PRIMARY KEY COMMENT '司机ID（与员工ID相同）',
    license_no VARCHAR(20) NOT NULL UNIQUE COMMENT '驾驶证号',
    license_type ENUM('A1', 'A3', 'B1') NOT NULL DEFAULT 'A3' COMMENT '驾照类型',
    license_expire_date DATE NOT NULL COMMENT '驾照有效期',
    route_id INT COMMENT '所属线路ID',
    is_route_captain TINYINT(1) NOT NULL DEFAULT 0 COMMENT '是否为路队长（0:否 1:是）',
    driving_years INT COMMENT '驾龄（年）',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    
    -- 用户自定义完整性约束
    CONSTRAINT chk_driving_years CHECK (driving_years IS NULL OR driving_years >= 0)
) ENGINE=InnoDB COMMENT='司机信息表（员工扩展）';

-- ------------------------------------------------------------
-- 5. 车辆表
-- 设计说明：每辆车属于一条线路
-- ------------------------------------------------------------
CREATE TABLE bus (
    bus_id INT PRIMARY KEY AUTO_INCREMENT COMMENT '车辆ID',
    plate_number VARCHAR(10) NOT NULL UNIQUE COMMENT '车牌号',
    bus_code VARCHAR(20) NOT NULL UNIQUE COMMENT '车辆编号',
    model VARCHAR(50) COMMENT '车型',
    brand VARCHAR(50) COMMENT '品牌',
    seats INT COMMENT '座位数',
    purchase_date DATE COMMENT '购置日期',
    route_id INT COMMENT '所属线路ID',
    status ENUM('运营中', '维修中', '报废', '备用') NOT NULL DEFAULT '运营中' COMMENT '车辆状态',
    last_maintenance_date DATE COMMENT '上次保养日期',
    next_maintenance_date DATE COMMENT '下次保养日期',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    
    -- 用户自定义完整性约束
    CONSTRAINT chk_seats CHECK (seats IS NULL OR seats > 0)
) ENGINE=InnoDB COMMENT='公交车辆表';

-- ------------------------------------------------------------
-- 6. 站点表
-- 设计说明：独立的站点信息，可被多条线路共用
-- ------------------------------------------------------------
CREATE TABLE station (
    station_id INT PRIMARY KEY AUTO_INCREMENT COMMENT '站点ID',
    station_code VARCHAR(20) NOT NULL UNIQUE COMMENT '站点编号',
    station_name VARCHAR(100) NOT NULL COMMENT '站点名称',
    address VARCHAR(200) COMMENT '详细地址',
    longitude DECIMAL(10,7) COMMENT '经度',
    latitude DECIMAL(10,7) COMMENT '纬度',
    has_shelter TINYINT(1) DEFAULT 1 COMMENT '是否有候车亭',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间'
) ENGINE=InnoDB COMMENT='公交站点表';

-- ------------------------------------------------------------
-- 7. 线路站点关联表（多对多关系）
-- 设计说明：一条线路有多个站点，一个站点可属于多条线路
-- ------------------------------------------------------------
CREATE TABLE route_station (
    route_id INT NOT NULL COMMENT '线路ID',
    station_id INT NOT NULL COMMENT '站点ID',
    sequence_no INT NOT NULL COMMENT '站点顺序（从1开始）',
    direction ENUM('上行', '下行') NOT NULL DEFAULT '上行' COMMENT '方向',
    distance_from_start DECIMAL(10,2) COMMENT '距起点距离（公里）',
    
    -- 复合主键
    PRIMARY KEY (route_id, station_id, direction),
    
    -- 用户自定义完整性约束
    CONSTRAINT chk_sequence CHECK (sequence_no > 0)
) ENGINE=InnoDB COMMENT='线路站点关联表';

-- ------------------------------------------------------------
-- 8. 违章类型表
-- 设计说明：独立维护违章类型，便于扩展和修改
-- ------------------------------------------------------------
CREATE TABLE violation_type (
    type_id INT PRIMARY KEY AUTO_INCREMENT COMMENT '违章类型ID',
    type_code VARCHAR(20) NOT NULL UNIQUE COMMENT '违章代码',
    type_name VARCHAR(100) NOT NULL COMMENT '违章名称',
    description VARCHAR(500) COMMENT '违章描述',
    penalty_points INT DEFAULT 0 COMMENT '扣分',
    fine_amount DECIMAL(10,2) DEFAULT 0.00 COMMENT '罚款金额',
    severity ENUM('轻微', '一般', '严重', '特别严重') NOT NULL DEFAULT '一般' COMMENT '严重程度',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    
    -- 用户自定义完整性约束
    CONSTRAINT chk_penalty_points CHECK (penalty_points >= 0),
    CONSTRAINT chk_fine_amount CHECK (fine_amount >= 0)
) ENGINE=InnoDB COMMENT='违章类型表';

-- ------------------------------------------------------------
-- 9. 违章记录表（核心业务表）
-- 设计说明：记录司机的所有违章信息
-- ------------------------------------------------------------
CREATE TABLE violation_record (
    record_id INT PRIMARY KEY AUTO_INCREMENT COMMENT '违章记录ID',
    driver_id INT NOT NULL COMMENT '违章司机ID',
    bus_id INT NOT NULL COMMENT '违章车辆ID',
    fleet_id INT NOT NULL COMMENT '所属车队ID',
    route_id INT NOT NULL COMMENT '所属线路ID',
    station_id INT COMMENT '违章发生站点ID（可为空）',
    violation_type_id INT NOT NULL COMMENT '违章类型ID',
    violation_time DATETIME NOT NULL COMMENT '违章发生时间',
    violation_location VARCHAR(200) COMMENT '违章地点描述',
    recorded_by INT NOT NULL COMMENT '记录人ID（队长或路队长）',
    record_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '记录时间',
    evidence_url VARCHAR(500) COMMENT '证据材料URL',
    remarks VARCHAR(500) COMMENT '备注说明',
    status ENUM('待处理', '已确认', '已申诉', '已撤销') NOT NULL DEFAULT '待处理' COMMENT '处理状态',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间'
) ENGINE=InnoDB COMMENT='违章记录表';

-- ============================================================
-- 第二部分：添加外键约束（参照完整性）
-- ============================================================

-- 车队表外键：队长必须是员工
ALTER TABLE fleet
    ADD CONSTRAINT fk_fleet_captain 
    FOREIGN KEY (captain_id) REFERENCES employee(employee_id)
    ON DELETE SET NULL ON UPDATE CASCADE;

-- 线路表外键：线路属于车队
ALTER TABLE route
    ADD CONSTRAINT fk_route_fleet 
    FOREIGN KEY (fleet_id) REFERENCES fleet(fleet_id)
    ON DELETE RESTRICT ON UPDATE CASCADE;

-- 司机表外键
ALTER TABLE driver
    ADD CONSTRAINT fk_driver_employee 
    FOREIGN KEY (driver_id) REFERENCES employee(employee_id)
    ON DELETE CASCADE ON UPDATE CASCADE,
    ADD CONSTRAINT fk_driver_route 
    FOREIGN KEY (route_id) REFERENCES route(route_id)
    ON DELETE SET NULL ON UPDATE CASCADE;

-- 车辆表外键
ALTER TABLE bus
    ADD CONSTRAINT fk_bus_route 
    FOREIGN KEY (route_id) REFERENCES route(route_id)
    ON DELETE SET NULL ON UPDATE CASCADE;

-- 线路站点关联表外键
ALTER TABLE route_station
    ADD CONSTRAINT fk_rs_route 
    FOREIGN KEY (route_id) REFERENCES route(route_id)
    ON DELETE CASCADE ON UPDATE CASCADE,
    ADD CONSTRAINT fk_rs_station 
    FOREIGN KEY (station_id) REFERENCES station(station_id)
    ON DELETE CASCADE ON UPDATE CASCADE;

-- 违章记录表外键
ALTER TABLE violation_record
    ADD CONSTRAINT fk_vr_driver 
    FOREIGN KEY (driver_id) REFERENCES driver(driver_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,
    ADD CONSTRAINT fk_vr_bus 
    FOREIGN KEY (bus_id) REFERENCES bus(bus_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,
    ADD CONSTRAINT fk_vr_fleet 
    FOREIGN KEY (fleet_id) REFERENCES fleet(fleet_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,
    ADD CONSTRAINT fk_vr_route 
    FOREIGN KEY (route_id) REFERENCES route(route_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,
    ADD CONSTRAINT fk_vr_station 
    FOREIGN KEY (station_id) REFERENCES station(station_id)
    ON DELETE SET NULL ON UPDATE CASCADE,
    ADD CONSTRAINT fk_vr_type 
    FOREIGN KEY (violation_type_id) REFERENCES violation_type(type_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,
    ADD CONSTRAINT fk_vr_recorder 
    FOREIGN KEY (recorded_by) REFERENCES employee(employee_id)
    ON DELETE RESTRICT ON UPDATE CASCADE;

-- ============================================================
-- 第三部分：创建索引（加速查询）
-- ============================================================

-- 员工表索引
CREATE INDEX idx_employee_name ON employee(name);
CREATE INDEX idx_employee_status ON employee(status);
CREATE INDEX idx_employee_hire_date ON employee(hire_date);

-- 车队表索引
CREATE INDEX idx_fleet_name ON fleet(fleet_name);

-- 线路表索引
CREATE INDEX idx_route_fleet ON route(fleet_id);
CREATE INDEX idx_route_status ON route(status);

-- 司机表索引
CREATE INDEX idx_driver_route ON driver(route_id);
CREATE INDEX idx_driver_route_captain ON driver(is_route_captain);

-- 车辆表索引
CREATE INDEX idx_bus_route ON bus(route_id);
CREATE INDEX idx_bus_status ON bus(status);

-- 站点表索引
CREATE INDEX idx_station_name ON station(station_name);

-- 线路站点关联表索引
CREATE INDEX idx_rs_station ON route_station(station_id);

-- 违章记录表索引（核心查询优化）
CREATE INDEX idx_vr_driver ON violation_record(driver_id);
CREATE INDEX idx_vr_bus ON violation_record(bus_id);
CREATE INDEX idx_vr_fleet ON violation_record(fleet_id);
CREATE INDEX idx_vr_route ON violation_record(route_id);
CREATE INDEX idx_vr_type ON violation_record(violation_type_id);
CREATE INDEX idx_vr_violation_time ON violation_record(violation_time);
CREATE INDEX idx_vr_status ON violation_record(status);
CREATE INDEX idx_vr_recorder ON violation_record(recorded_by);

-- 复合索引（常用查询组合）
CREATE INDEX idx_vr_fleet_time ON violation_record(fleet_id, violation_time);
CREATE INDEX idx_vr_driver_time ON violation_record(driver_id, violation_time);
CREATE INDEX idx_vr_route_time ON violation_record(route_id, violation_time);

-- ============================================================
-- 第四部分：创建视图（简化查询）
-- ============================================================

-- ------------------------------------------------------------
-- 视图1：司机完整信息视图（关联员工基础信息）
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW v_driver_info AS
SELECT 
    d.driver_id,
    e.emp_code,
    e.name AS driver_name,
    e.gender,
    e.id_card,
    e.phone,
    e.hire_date,
    e.status AS emp_status,
    d.license_no,
    d.license_type,
    d.license_expire_date,
    d.driving_years,
    d.is_route_captain,
    d.route_id,
    r.route_code,
    r.route_name,
    f.fleet_id,
    f.fleet_code,
    f.fleet_name
FROM driver d
INNER JOIN employee e ON d.driver_id = e.employee_id
LEFT JOIN route r ON d.route_id = r.route_id
LEFT JOIN fleet f ON r.fleet_id = f.fleet_id;

-- ------------------------------------------------------------
-- 视图2：车队完整信息视图（包含队长信息）
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW v_fleet_info AS
SELECT 
    f.fleet_id,
    f.fleet_code,
    f.fleet_name,
    f.captain_id,
    e.emp_code AS captain_emp_code,
    e.name AS captain_name,
    e.phone AS captain_phone,
    f.description,
    (SELECT COUNT(*) FROM route r WHERE r.fleet_id = f.fleet_id) AS route_count,
    (SELECT COUNT(*) FROM bus b 
     INNER JOIN route r ON b.route_id = r.route_id 
     WHERE r.fleet_id = f.fleet_id) AS bus_count
FROM fleet f
LEFT JOIN employee e ON f.captain_id = e.employee_id;

-- ------------------------------------------------------------
-- 视图3：线路完整信息视图
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW v_route_info AS
SELECT 
    r.route_id,
    r.route_code,
    r.route_name,
    r.start_station,
    r.end_station,
    r.total_distance,
    r.ticket_price,
    r.status,
    f.fleet_id,
    f.fleet_code,
    f.fleet_name,
    (SELECT COUNT(*) FROM driver d WHERE d.route_id = r.route_id) AS driver_count,
    (SELECT COUNT(*) FROM bus b WHERE b.route_id = r.route_id) AS bus_count,
    (SELECT e.name FROM driver d 
     INNER JOIN employee e ON d.driver_id = e.employee_id 
     WHERE d.route_id = r.route_id AND d.is_route_captain = 1 LIMIT 1) AS route_captain_name
FROM route r
INNER JOIN fleet f ON r.fleet_id = f.fleet_id;

-- ------------------------------------------------------------
-- 视图4：违章记录详细视图
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW v_violation_detail AS
SELECT 
    vr.record_id,
    vr.violation_time,
    vr.violation_location,
    vr.record_time,
    vr.status AS record_status,
    vr.remarks,
    -- 司机信息
    vr.driver_id,
    e_driver.emp_code AS driver_emp_code,
    e_driver.name AS driver_name,
    -- 车辆信息
    vr.bus_id,
    b.plate_number,
    b.bus_code,
    -- 车队信息
    vr.fleet_id,
    f.fleet_code,
    f.fleet_name,
    -- 线路信息
    vr.route_id,
    r.route_code,
    r.route_name,
    -- 站点信息
    vr.station_id,
    s.station_name,
    -- 违章类型
    vr.violation_type_id,
    vt.type_code AS violation_code,
    vt.type_name AS violation_name,
    vt.penalty_points,
    vt.fine_amount,
    vt.severity,
    -- 记录人信息
    vr.recorded_by,
    e_recorder.emp_code AS recorder_emp_code,
    e_recorder.name AS recorder_name
FROM violation_record vr
INNER JOIN driver d ON vr.driver_id = d.driver_id
INNER JOIN employee e_driver ON d.driver_id = e_driver.employee_id
INNER JOIN bus b ON vr.bus_id = b.bus_id
INNER JOIN fleet f ON vr.fleet_id = f.fleet_id
INNER JOIN route r ON vr.route_id = r.route_id
LEFT JOIN station s ON vr.station_id = s.station_id
INNER JOIN violation_type vt ON vr.violation_type_id = vt.type_id
INNER JOIN employee e_recorder ON vr.recorded_by = e_recorder.employee_id;

-- ------------------------------------------------------------
-- 视图5：司机违章统计视图
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW v_driver_violation_stats AS
SELECT 
    d.driver_id,
    e.emp_code,
    e.name AS driver_name,
    r.route_code,
    r.route_name,
    f.fleet_name,
    COUNT(vr.record_id) AS total_violations,
    SUM(vt.penalty_points) AS total_penalty_points,
    SUM(vt.fine_amount) AS total_fine_amount,
    SUM(CASE WHEN vt.severity = '严重' OR vt.severity = '特别严重' THEN 1 ELSE 0 END) AS serious_violations
FROM driver d
INNER JOIN employee e ON d.driver_id = e.employee_id
LEFT JOIN route r ON d.route_id = r.route_id
LEFT JOIN fleet f ON r.fleet_id = f.fleet_id
LEFT JOIN violation_record vr ON d.driver_id = vr.driver_id AND vr.status != '已撤销'
LEFT JOIN violation_type vt ON vr.violation_type_id = vt.type_id
GROUP BY d.driver_id, e.emp_code, e.name, r.route_code, r.route_name, f.fleet_name;

-- ------------------------------------------------------------
-- 视图6：车队违章统计视图
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW v_fleet_violation_stats AS
SELECT 
    f.fleet_id,
    f.fleet_code,
    f.fleet_name,
    COUNT(vr.record_id) AS total_violations,
    SUM(vt.penalty_points) AS total_penalty_points,
    SUM(vt.fine_amount) AS total_fine_amount,
    COUNT(DISTINCT vr.driver_id) AS violated_driver_count
FROM fleet f
LEFT JOIN violation_record vr ON f.fleet_id = vr.fleet_id AND vr.status != '已撤销'
LEFT JOIN violation_type vt ON vr.violation_type_id = vt.type_id
GROUP BY f.fleet_id, f.fleet_code, f.fleet_name;

-- ============================================================
-- 第五部分：创建存储过程
-- ============================================================

DELIMITER //

-- ------------------------------------------------------------
-- 存储过程1：添加违章记录
-- 参数说明：队长或路队长录入司机违章信息
-- ------------------------------------------------------------
CREATE PROCEDURE sp_add_violation_record(
    IN p_driver_id INT,
    IN p_bus_id INT,
    IN p_station_id INT,
    IN p_violation_type_id INT,
    IN p_violation_time DATETIME,
    IN p_violation_location VARCHAR(200),
    IN p_recorded_by INT,
    IN p_remarks VARCHAR(500),
    OUT p_result INT,
    OUT p_message VARCHAR(200)
)
BEGIN
    DECLARE v_fleet_id INT;
    DECLARE v_route_id INT;
    DECLARE v_is_authorized INT DEFAULT 0;
    
    -- 错误处理
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SET p_result = -1;
        SET p_message = '系统错误，请联系管理员';
        ROLLBACK;
    END;
    
    START TRANSACTION;
    
    -- 获取司机所属的线路和车队
    SELECT r.fleet_id, d.route_id INTO v_fleet_id, v_route_id
    FROM driver d
    INNER JOIN route r ON d.route_id = r.route_id
    WHERE d.driver_id = p_driver_id;
    
    -- 检查司机是否存在
    IF v_route_id IS NULL THEN
        SET p_result = -2;
        SET p_message = '司机不存在或未分配线路';
        ROLLBACK;
    ELSE
        -- 验证记录人权限（必须是该车队的队长或该线路的路队长）
        SELECT COUNT(*) INTO v_is_authorized
        FROM (
            -- 检查是否为车队队长
            SELECT captain_id AS auth_id FROM fleet WHERE fleet_id = v_fleet_id AND captain_id = p_recorded_by
            UNION
            -- 检查是否为路队长
            SELECT driver_id AS auth_id FROM driver WHERE route_id = v_route_id AND is_route_captain = 1 AND driver_id = p_recorded_by
        ) auth_check;
        
        IF v_is_authorized = 0 THEN
            SET p_result = -3;
            SET p_message = '无权限录入违章记录，仅队长或路队长可操作';
            ROLLBACK;
        ELSE
            -- 插入违章记录
            INSERT INTO violation_record (
                driver_id, bus_id, fleet_id, route_id, station_id,
                violation_type_id, violation_time, violation_location,
                recorded_by, remarks
            ) VALUES (
                p_driver_id, p_bus_id, v_fleet_id, v_route_id, p_station_id,
                p_violation_type_id, p_violation_time, p_violation_location,
                p_recorded_by, p_remarks
            );
            
            SET p_result = LAST_INSERT_ID();
            SET p_message = '违章记录添加成功';
            COMMIT;
        END IF;
    END IF;
END //

-- ------------------------------------------------------------
-- 存储过程2：查询司机违章历史
-- ------------------------------------------------------------
CREATE PROCEDURE sp_get_driver_violations(
    IN p_driver_id INT,
    IN p_start_date DATE,
    IN p_end_date DATE
)
BEGIN
    SELECT 
        vr.record_id,
        vr.violation_time,
        vt.type_name AS violation_type,
        vt.severity,
        vt.penalty_points,
        vt.fine_amount,
        b.plate_number,
        r.route_code,
        s.station_name,
        vr.violation_location,
        vr.status,
        e.name AS recorder_name,
        vr.remarks
    FROM violation_record vr
    INNER JOIN violation_type vt ON vr.violation_type_id = vt.type_id
    INNER JOIN bus b ON vr.bus_id = b.bus_id
    INNER JOIN route r ON vr.route_id = r.route_id
    LEFT JOIN station s ON vr.station_id = s.station_id
    INNER JOIN employee e ON vr.recorded_by = e.employee_id
    WHERE vr.driver_id = p_driver_id
      AND (p_start_date IS NULL OR DATE(vr.violation_time) >= p_start_date)
      AND (p_end_date IS NULL OR DATE(vr.violation_time) <= p_end_date)
    ORDER BY vr.violation_time DESC;
END //

-- ------------------------------------------------------------
-- 存储过程3：统计指定时间段内各车队违章情况
-- ------------------------------------------------------------
CREATE PROCEDURE sp_fleet_violation_report(
    IN p_start_date DATE,
    IN p_end_date DATE
)
BEGIN
    SELECT 
        f.fleet_code,
        f.fleet_name,
        COUNT(vr.record_id) AS violation_count,
        SUM(CASE WHEN vt.severity = '轻微' THEN 1 ELSE 0 END) AS minor_count,
        SUM(CASE WHEN vt.severity = '一般' THEN 1 ELSE 0 END) AS normal_count,
        SUM(CASE WHEN vt.severity = '严重' THEN 1 ELSE 0 END) AS serious_count,
        SUM(CASE WHEN vt.severity = '特别严重' THEN 1 ELSE 0 END) AS critical_count,
        SUM(vt.penalty_points) AS total_points,
        SUM(vt.fine_amount) AS total_fine,
        COUNT(DISTINCT vr.driver_id) AS involved_drivers
    FROM fleet f
    LEFT JOIN violation_record vr ON f.fleet_id = vr.fleet_id 
        AND vr.status != '已撤销'
        AND (p_start_date IS NULL OR DATE(vr.violation_time) >= p_start_date)
        AND (p_end_date IS NULL OR DATE(vr.violation_time) <= p_end_date)
    LEFT JOIN violation_type vt ON vr.violation_type_id = vt.type_id
    GROUP BY f.fleet_id, f.fleet_code, f.fleet_name
    ORDER BY violation_count DESC;
END //

-- ------------------------------------------------------------
-- 存储过程4：添加新司机（同时创建员工和司机记录）
-- ------------------------------------------------------------
CREATE PROCEDURE sp_add_driver(
    IN p_emp_code VARCHAR(20),
    IN p_name VARCHAR(50),
    IN p_gender ENUM('男', '女'),
    IN p_id_card VARCHAR(18),
    IN p_phone VARCHAR(11),
    IN p_address VARCHAR(200),
    IN p_hire_date DATE,
    IN p_license_no VARCHAR(20),
    IN p_license_type ENUM('A1', 'A3', 'B1'),
    IN p_license_expire_date DATE,
    IN p_driving_years INT,
    IN p_route_id INT,
    OUT p_driver_id INT,
    OUT p_message VARCHAR(200)
)
BEGIN
    DECLARE v_employee_id INT;
    
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SET p_driver_id = -1;
        SET p_message = '添加失败，请检查数据是否重复';
        ROLLBACK;
    END;
    
    START TRANSACTION;
    
    -- 先创建员工记录
    INSERT INTO employee (emp_code, name, gender, id_card, phone, address, hire_date)
    VALUES (p_emp_code, p_name, p_gender, p_id_card, p_phone, p_address, p_hire_date);
    
    SET v_employee_id = LAST_INSERT_ID();
    
    -- 创建司机记录
    INSERT INTO driver (driver_id, license_no, license_type, license_expire_date, driving_years, route_id)
    VALUES (v_employee_id, p_license_no, p_license_type, p_license_expire_date, p_driving_years, p_route_id);
    
    SET p_driver_id = v_employee_id;
    SET p_message = '司机添加成功';
    
    COMMIT;
END //

-- ------------------------------------------------------------
-- 存储过程5：设置路队长
-- ------------------------------------------------------------
CREATE PROCEDURE sp_set_route_captain(
    IN p_route_id INT,
    IN p_driver_id INT,
    OUT p_result INT,
    OUT p_message VARCHAR(200)
)
BEGIN
    DECLARE v_current_route INT;
    
    -- 检查司机是否属于该线路
    SELECT route_id INTO v_current_route FROM driver WHERE driver_id = p_driver_id;
    
    IF v_current_route IS NULL THEN
        SET p_result = -1;
        SET p_message = '司机不存在';
    ELSEIF v_current_route != p_route_id THEN
        SET p_result = -2;
        SET p_message = '该司机不属于此线路';
    ELSE
        -- 先取消该线路原有路队长
        UPDATE driver SET is_route_captain = 0 WHERE route_id = p_route_id;
        
        -- 设置新路队长
        UPDATE driver SET is_route_captain = 1 WHERE driver_id = p_driver_id;
        
        SET p_result = 1;
        SET p_message = '路队长设置成功';
    END IF;
END //

-- ------------------------------------------------------------
-- 存储过程6：更新违章记录状态
-- ------------------------------------------------------------
CREATE PROCEDURE sp_update_violation_status(
    IN p_record_id INT,
    IN p_new_status ENUM('待处理', '已确认', '已申诉', '已撤销'),
    IN p_operator_id INT,
    OUT p_result INT,
    OUT p_message VARCHAR(200)
)
BEGIN
    DECLARE v_fleet_id INT;
    DECLARE v_route_id INT;
    DECLARE v_is_authorized INT DEFAULT 0;
    
    -- 获取违章记录所属车队和线路
    SELECT fleet_id, route_id INTO v_fleet_id, v_route_id
    FROM violation_record WHERE record_id = p_record_id;
    
    IF v_fleet_id IS NULL THEN
        SET p_result = -1;
        SET p_message = '违章记录不存在';
    ELSE
        -- 验证操作权限
        SELECT COUNT(*) INTO v_is_authorized
        FROM (
            SELECT captain_id AS auth_id FROM fleet WHERE fleet_id = v_fleet_id AND captain_id = p_operator_id
            UNION
            SELECT driver_id AS auth_id FROM driver WHERE route_id = v_route_id AND is_route_captain = 1 AND driver_id = p_operator_id
        ) auth_check;
        
        IF v_is_authorized = 0 THEN
            SET p_result = -2;
            SET p_message = '无权限操作此记录';
        ELSE
            UPDATE violation_record SET status = p_new_status WHERE record_id = p_record_id;
            SET p_result = 1;
            SET p_message = '状态更新成功';
        END IF;
    END IF;
END //

DELIMITER ;

-- ============================================================
-- 第六部分：创建函数
-- ============================================================

DELIMITER //

-- ------------------------------------------------------------
-- 函数1：获取司机总违章次数
-- ------------------------------------------------------------
CREATE FUNCTION fn_get_driver_violation_count(p_driver_id INT)
RETURNS INT
DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE v_count INT;
    SELECT COUNT(*) INTO v_count 
    FROM violation_record 
    WHERE driver_id = p_driver_id AND status != '已撤销';
    RETURN IFNULL(v_count, 0);
END //

-- ------------------------------------------------------------
-- 函数2：获取司机总扣分
-- ------------------------------------------------------------
CREATE FUNCTION fn_get_driver_penalty_points(p_driver_id INT)
RETURNS INT
DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE v_points INT;
    SELECT SUM(vt.penalty_points) INTO v_points
    FROM violation_record vr
    INNER JOIN violation_type vt ON vr.violation_type_id = vt.type_id
    WHERE vr.driver_id = p_driver_id AND vr.status != '已撤销';
    RETURN IFNULL(v_points, 0);
END //

-- ------------------------------------------------------------
-- 函数3：获取车队当月违章次数
-- ------------------------------------------------------------
CREATE FUNCTION fn_get_fleet_monthly_violations(p_fleet_id INT)
RETURNS INT
DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE v_count INT;
    SELECT COUNT(*) INTO v_count
    FROM violation_record
    WHERE fleet_id = p_fleet_id 
      AND status != '已撤销'
      AND YEAR(violation_time) = YEAR(CURRENT_DATE)
      AND MONTH(violation_time) = MONTH(CURRENT_DATE);
    RETURN IFNULL(v_count, 0);
END //

-- ------------------------------------------------------------
-- 函数4：检查员工是否有管理权限（队长或路队长）
-- ------------------------------------------------------------
CREATE FUNCTION fn_has_management_authority(p_employee_id INT)
RETURNS TINYINT(1)
DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE v_is_captain INT DEFAULT 0;
    DECLARE v_is_route_captain INT DEFAULT 0;
    
    -- 检查是否为车队队长
    SELECT COUNT(*) INTO v_is_captain FROM fleet WHERE captain_id = p_employee_id;
    
    -- 检查是否为路队长
    SELECT COUNT(*) INTO v_is_route_captain FROM driver WHERE driver_id = p_employee_id AND is_route_captain = 1;
    
    RETURN (v_is_captain > 0 OR v_is_route_captain > 0);
END //

-- ------------------------------------------------------------
-- 函数5：获取线路名称
-- ------------------------------------------------------------
CREATE FUNCTION fn_get_route_name(p_route_id INT)
RETURNS VARCHAR(100)
DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE v_name VARCHAR(100);
    SELECT route_name INTO v_name FROM route WHERE route_id = p_route_id;
    RETURN v_name;
END //

DELIMITER ;

-- ============================================================
-- 第七部分：创建触发器
-- ============================================================

DELIMITER //

-- ------------------------------------------------------------
-- 触发器1：确保每条线路只有一个路队长
-- ------------------------------------------------------------
CREATE TRIGGER trg_before_driver_update
BEFORE UPDATE ON driver
FOR EACH ROW
BEGIN
    DECLARE v_existing_captain INT;
    
    IF NEW.is_route_captain = 1 AND OLD.is_route_captain = 0 THEN
        -- 检查该线路是否已有路队长
        SELECT driver_id INTO v_existing_captain
        FROM driver 
        WHERE route_id = NEW.route_id AND is_route_captain = 1 AND driver_id != NEW.driver_id
        LIMIT 1;
        
        IF v_existing_captain IS NOT NULL THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = '该线路已有路队长，请先取消原路队长资格';
        END IF;
    END IF;
END //

-- ------------------------------------------------------------
-- 触发器2：违章记录插入时自动填充车队ID（如果未提供）
-- ------------------------------------------------------------
CREATE TRIGGER trg_before_violation_insert
BEFORE INSERT ON violation_record
FOR EACH ROW
BEGIN
    DECLARE v_fleet_id INT;
    DECLARE v_route_id INT;
    
    -- 如果未提供车队ID，根据司机所属线路自动填充
    IF NEW.fleet_id IS NULL OR NEW.route_id IS NULL THEN
        SELECT r.fleet_id, d.route_id INTO v_fleet_id, v_route_id
        FROM driver d
        INNER JOIN route r ON d.route_id = r.route_id
        WHERE d.driver_id = NEW.driver_id;
        
        IF NEW.fleet_id IS NULL THEN
            SET NEW.fleet_id = v_fleet_id;
        END IF;
        
        IF NEW.route_id IS NULL THEN
            SET NEW.route_id = v_route_id;
        END IF;
    END IF;
END //

DELIMITER ;

-- ============================================================
-- 第八部分：插入测试数据
-- ============================================================

-- 插入违章类型基础数据
INSERT INTO violation_type (type_code, type_name, description, penalty_points, fine_amount, severity) VALUES
('VT001', '闯红灯', '驾驶机动车违反交通信号灯通行', 6, 200.00, '严重'),
('VT002', '未礼让斑马线', '机动车行经人行横道时，应当减速行驶；遇行人正在通过人行横道，应当停车让行', 3, 100.00, '一般'),
('VT003', '压线', '机动车违反禁止标线指示', 3, 100.00, '一般'),
('VT004', '违章停车', '机动车违反规定停放、临时停车', 0, 200.00, '轻微'),
('VT005', '超速行驶', '驾驶机动车超过规定时速', 6, 200.00, '严重'),
('VT006', '疲劳驾驶', '连续驾驶机动车超过4小时未停车休息', 6, 200.00, '严重'),
('VT007', '接打电话', '驾驶机动车时拨打接听手持电话', 2, 50.00, '轻微'),
('VT008', '未系安全带', '驾驶人未按规定使用安全带', 0, 50.00, '轻微'),
('VT009', '变道不打灯', '变更车道时不按规定使用灯光', 1, 50.00, '轻微'),
('VT010', '逆向行驶', '机动车逆向行驶', 12, 200.00, '特别严重');

-- 插入员工数据（先插入队长）
INSERT INTO employee (emp_code, name, gender, id_card, phone, address, hire_date, status) VALUES
('EMP001', '郑旭', '男', '510101198001011234', '13800000001', '成都市武侯区人民南路100号', '2010-03-15', '在职'),
('EMP002', '李建国', '男', '510102198205152345', '13800000002', '成都市青羊区蜀都大道200号', '2012-06-20', '在职'),
('EMP003', '王志强', '男', '510103197808083456', '13800000003', '成都市金牛区一环路北300号', '2008-09-10', '在职');

-- 插入车队数据
INSERT INTO fleet (fleet_code, fleet_name, captain_id, description) VALUES
('FLT001', '第一车队', 1, '负责城北片区公交运营'),
('FLT002', '第二车队', 2, '负责城南片区公交运营'),
('FLT003', '第三车队', 3, '负责城东片区公交运营');

-- 插入线路数据
INSERT INTO route (route_code, route_name, fleet_id, start_station, end_station, total_distance, ticket_price, status) VALUES
('101', '101路公交', 1, '火车北站', '天府广场', 12.5, 2.00, '运营中'),
('102', '102路公交', 1, '九里堤', '春熙路', 15.8, 2.00, '运营中'),
('201', '201路公交', 2, '火车南站', '天府软件园', 8.3, 2.00, '运营中'),
('202', '202路公交', 2, '华阳客运站', '世纪城', 10.2, 2.00, '运营中'),
('301', '301路公交', 3, '十里店', '成都东站', 6.5, 2.00, '运营中'),
('302', '302路公交', 3, '龙泉驿', '万年场', 18.6, 2.00, '运营中');

-- 插入更多员工数据（司机）
INSERT INTO employee (emp_code, name, gender, id_card, phone, address, hire_date, status) VALUES
-- 101路司机
('DRV001', '赵大勇', '男', '510104199001011001', '13900000001', '成都市成华区建设路1号', '2015-03-01', '在职'),
('DRV002', '钱小明', '男', '510105199102022002', '13900000002', '成都市锦江区东大街2号', '2016-05-15', '在职'),
('DRV003', '孙丽华', '女', '510106198803033003', '13900000003', '成都市武侯区科华北路3号', '2014-08-20', '在职'),
-- 102路司机
('DRV004', '李强', '男', '510107199204044004', '13900000004', '成都市青羊区金沙路4号', '2017-01-10', '在职'),
('DRV005', '周伟', '男', '510108198505055005', '13900000005', '成都市金牛区营门口5号', '2013-11-25', '在职'),
('DRV006', '吴芳', '女', '510109199306066006', '13900000006', '成都市高新区天府大道6号', '2018-04-08', '在职'),
-- 201路司机
('DRV007', '郑刚', '男', '510110198707077007', '13900000007', '成都市双流区广都路7号', '2015-07-12', '在职'),
('DRV008', '王磊', '男', '510111199408088008', '13900000008', '成都市天府新区华阳街8号', '2019-02-28', '在职'),
('DRV009', '冯静', '女', '510112198909099009', '13900000009', '成都市龙泉驿区龙泉街9号', '2016-10-05', '在职'),
-- 202路司机
('DRV010', '陈波', '男', '510113199010100010', '13900000010', '成都市新都区新都大道10号', '2017-06-18', '在职'),
('DRV011', '杨帆', '男', '510114198611110011', '13900000011', '成都市郫都区郫筒街11号', '2014-03-22', '在职'),
-- 301路司机
('DRV012', '黄涛', '男', '510115199212120012', '13900000012', '成都市青白江区凤凰大道12号', '2018-09-30', '在职'),
('DRV013', '许敏', '女', '510116198413130013', '13900000013', '成都市温江区柳城大道13号', '2012-12-12', '在职'),
-- 302路司机
('DRV014', '朱杰', '男', '510117199114140014', '13900000014', '成都市都江堰市都江堰大道14号', '2016-08-08', '在职'),
('DRV015', '林海', '男', '510118198815150015', '13900000015', '成都市彭州市天彭大道15号', '2015-05-05', '在职');

-- 插入司机数据
INSERT INTO driver (driver_id, license_no, license_type, license_expire_date, route_id, is_route_captain, driving_years) VALUES
-- 101路司机（赵大勇为路队长）
(4, 'A3202015001', 'A3', '2027-03-01', 1, 1, 9),
(5, 'A3202016002', 'A3', '2028-05-15', 1, 0, 8),
(6, 'A3202014003', 'A3', '2026-08-20', 1, 0, 10),
-- 102路司机（李强为路队长）
(7, 'A3202017004', 'A3', '2029-01-10', 2, 1, 7),
(8, 'A3202013005', 'A3', '2025-11-25', 2, 0, 11),
(9, 'A3202018006', 'A3', '2030-04-08', 2, 0, 6),
-- 201路司机（郑刚为路队长）
(10, 'A3202015007', 'A3', '2027-07-12', 3, 1, 9),
(11, 'A3202019008', 'A3', '2031-02-28', 3, 0, 5),
(12, 'A3202016009', 'A3', '2028-10-05', 3, 0, 8),
-- 202路司机（陈波为路队长）
(13, 'A3202017010', 'A3', '2029-06-18', 4, 1, 7),
(14, 'A3202014011', 'A3', '2026-03-22', 4, 0, 10),
-- 301路司机（黄涛为路队长）
(15, 'A3202018012', 'A3', '2030-09-30', 5, 1, 6),
(16, 'A3202012013', 'A3', '2024-12-12', 5, 0, 12),
-- 302路司机（朱杰为路队长）
(17, 'A3202016014', 'A3', '2028-08-08', 6, 1, 8),
(18, 'A3202015015', 'A3', '2027-05-05', 6, 0, 9);

-- 插入站点数据
INSERT INTO station (station_code, station_name, address, longitude, latitude, has_shelter) VALUES
('ST001', '火车北站', '成都市金牛区火车北站', 104.0718, 30.7032, 1),
('ST002', '人民北路', '成都市金牛区人民北路', 104.0665, 30.6895, 1),
('ST003', '文殊院', '成都市青羊区文殊院街', 104.0612, 30.6758, 1),
('ST004', '骡马市', '成都市青羊区骡马市街', 104.0560, 30.6621, 1),
('ST005', '天府广场', '成都市青羊区天府广场', 104.0657, 30.6575, 1),
('ST006', '九里堤', '成都市金牛区九里堤', 104.0320, 30.7125, 1),
('ST007', '营门口', '成都市金牛区营门口', 104.0285, 30.6890, 1),
('ST008', '抚琴', '成都市金牛区抚琴街', 104.0380, 30.6720, 1),
('ST009', '宽窄巷子', '成都市青羊区宽窄巷子', 104.0485, 30.6680, 1),
('ST010', '春熙路', '成都市锦江区春熙路', 104.0815, 30.6575, 1),
('ST011', '火车南站', '成都市武侯区火车南站', 104.0615, 30.6058, 1),
('ST012', '桐梓林', '成都市武侯区桐梓林', 104.0580, 30.6185, 1),
('ST013', '倪家桥', '成都市武侯区倪家桥', 104.0625, 30.6312, 1),
('ST014', '天府软件园', '成都市高新区天府软件园', 104.0685, 30.5450, 1),
('ST015', '华阳客运站', '成都市天府新区华阳', 104.0520, 30.5125, 1),
('ST016', '世纪城', '成都市高新区世纪城', 104.0685, 30.5680, 1),
('ST017', '十里店', '成都市成华区十里店', 104.1285, 30.6580, 1),
('ST018', '成都东站', '成都市成华区成都东站', 104.1385, 30.6285, 1),
('ST019', '龙泉驿', '成都市龙泉驿区', 104.2520, 30.5580, 1),
('ST020', '万年场', '成都市成华区万年场', 104.1125, 30.6480, 1);

-- 插入线路站点关联数据（示例：101路）
INSERT INTO route_station (route_id, station_id, sequence_no, direction, distance_from_start) VALUES
-- 101路上行
(1, 1, 1, '上行', 0.00),
(1, 2, 2, '上行', 2.50),
(1, 3, 3, '上行', 5.20),
(1, 4, 4, '上行', 8.30),
(1, 5, 5, '上行', 12.50),
-- 101路下行
(1, 5, 1, '下行', 0.00),
(1, 4, 2, '下行', 4.20),
(1, 3, 3, '下行', 7.30),
(1, 2, 4, '下行', 10.00),
(1, 1, 5, '下行', 12.50);

-- 插入车辆数据
INSERT INTO bus (plate_number, bus_code, model, brand, seats, purchase_date, route_id, status) VALUES
-- 101路车辆
('川A10101', 'BUS101001', '纯电动公交车', '宇通', 35, '2020-01-15', 1, '运营中'),
('川A10102', 'BUS101002', '纯电动公交车', '宇通', 35, '2020-01-15', 1, '运营中'),
('川A10103', 'BUS101003', '纯电动公交车', '比亚迪', 38, '2021-06-20', 1, '运营中'),
-- 102路车辆
('川A10201', 'BUS102001', '纯电动公交车', '宇通', 35, '2019-08-10', 2, '运营中'),
('川A10202', 'BUS102002', '纯电动公交车', '比亚迪', 38, '2021-03-25', 2, '运营中'),
('川A10203', 'BUS102003', '混合动力公交车', '金龙', 40, '2018-11-05', 2, '维修中'),
-- 201路车辆
('川A20101', 'BUS201001', '纯电动公交车', '宇通', 35, '2020-05-18', 3, '运营中'),
('川A20102', 'BUS201002', '纯电动公交车', '比亚迪', 38, '2022-01-10', 3, '运营中'),
-- 202路车辆
('川A20201', 'BUS202001', '纯电动公交车', '宇通', 35, '2019-12-20', 4, '运营中'),
('川A20202', 'BUS202002', '纯电动公交车', '比亚迪', 38, '2021-07-08', 4, '运营中'),
-- 301路车辆
('川A30101', 'BUS301001', '纯电动公交车', '宇通', 35, '2020-09-12', 5, '运营中'),
('川A30102', 'BUS301002', '纯电动公交车', '金龙', 40, '2022-04-22', 5, '运营中'),
-- 302路车辆
('川A30201', 'BUS302001', '混合动力公交车', '金龙', 40, '2018-06-15', 6, '运营中'),
('川A30202', 'BUS302002', '纯电动公交车', '比亚迪', 38, '2021-11-30', 6, '运营中');

-- 插入违章记录测试数据
INSERT INTO violation_record (driver_id, bus_id, fleet_id, route_id, station_id, violation_type_id, violation_time, violation_location, recorded_by, remarks, status) VALUES
-- 第一车队违章记录
(5, 1, 1, 1, 3, 1, '2025-11-15 08:30:00', '文殊院路口', 4, '早高峰闯红灯', '已确认'),
(5, 2, 1, 1, 4, 2, '2025-11-18 17:45:00', '骡马市斑马线', 1, '未礼让行人', '待处理'),
(6, 3, 1, 1, 2, 3, '2025-11-20 09:15:00', '人民北路', 4, '实线变道', '已确认'),
(8, 4, 1, 2, 7, 4, '2025-11-22 14:20:00', '营门口公交站', 7, '超时停车', '待处理'),
(9, 5, 1, 2, 9, 7, '2025-11-25 11:00:00', '宽窄巷子附近', 1, '行车中接打电话', '已确认'),
-- 第二车队违章记录
(11, 7, 2, 3, 12, 1, '2025-11-16 07:50:00', '桐梓林路口', 10, '闯红灯', '已确认'),
(12, 8, 2, 3, 13, 5, '2025-11-19 16:30:00', '倪家桥路段', 2, '超速20%', '待处理'),
(13, 9, 2, 4, 15, 2, '2025-11-21 08:45:00', '华阳客运站', 13, '未礼让斑马线', '已确认'),
-- 第三车队违章记录
(15, 11, 3, 5, 17, 3, '2025-11-17 10:30:00', '十里店路段', 15, '压双黄线', '已确认'),
(16, 12, 3, 5, 18, 8, '2025-11-23 15:00:00', '成都东站', 3, '未系安全带', '待处理'),
(17, 13, 3, 6, 19, 4, '2025-11-24 12:15:00', '龙泉驿站点', 17, '违规停车上下客', '已确认'),
(18, 14, 3, 6, 20, 9, '2025-11-26 09:30:00', '万年场路口', 3, '变道未打转向灯', '待处理');

-- ============================================================
-- 完成提示
-- ============================================================
SELECT '公交安全管理系统数据库创建完成！' AS message;
SELECT CONCAT('数据库包含 ', 
    (SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'bus_safety_system'), 
    ' 个表，',
    (SELECT COUNT(*) FROM information_schema.views WHERE table_schema = 'bus_safety_system'),
    ' 个视图') AS summary;

