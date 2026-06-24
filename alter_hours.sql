-- 飞行时长/管制时长改为支持小数
ALTER TABLE useraccount MODIFY flight_hours DECIMAL(10,1) NOT NULL DEFAULT 0.0;
ALTER TABLE useraccount MODIFY control_hours DECIMAL(10,1) NOT NULL DEFAULT 0.0;
