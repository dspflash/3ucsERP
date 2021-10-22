CREATE TABLE `iot_data` (
  `idx` BIGINT(20) NOT NULL AUTO_INCREMENT,
  `topic` VARCHAR(100) NOT NULL,
  `dt` DATE NOT NULL,
  `hr` TINYINT(4) NOT NULL,
  `prodtp` VARCHAR(50) DEFAULT NULL,
  `opcode` TINYINT(4) DEFAULT NULL,
  `opmode` VARCHAR(20) DEFAULT NULL,
  `prodname` VARCHAR(50) DEFAULT NULL,
  `modno` VARCHAR(20) DEFAULT NULL,
  `mods` INT(11) DEFAULT NULL,
  `tcycle` DOUBLE DEFAULT NULL,
  `trun` DOUBLE(18,2) DEFAULT NULL,
  `tstop` DOUBLE(18,2) DEFAULT NULL,
  PRIMARY KEY  (`idx`),
  UNIQUE KEY `topic_dt_hr` (`topic`,`dt`,`hr`)
) ENGINE=MYISAM DEFAULT CHARSET=utf8



CREATE TABLE `iot_data_latest` (
  `idx` BIGINT(20) NOT NULL AUTO_INCREMENT,
  `topic` VARCHAR(100) NOT NULL,
  `dt` DATETIME NOT NULL,
  `prodtp` VARCHAR(50) DEFAULT NULL,
  `opcode` TINYINT(4) DEFAULT NULL,
  `opmode` VARCHAR(20) DEFAULT NULL,
  `prodname` VARCHAR(50) DEFAULT NULL,
  `modno` VARCHAR(20) DEFAULT NULL,
  `modsplan` INT(11) DEFAULT '0',
  `mods` INT(11) DEFAULT '0',
  `tcycle` DOUBLE DEFAULT NULL,
  `trun` INT(11) DEFAULT NULL,
  `tstop` INT(11) DEFAULT NULL,
  PRIMARY KEY  (`idx`),
  UNIQUE KEY `topic` (`topic`),
  KEY `dt` (`dt`)
) ENGINE=MYISAM DEFAULT CHARSET=utf8

CREATE TABLE `iot_data_r` (
  `idx` BIGINT(20) NOT NULL AUTO_INCREMENT,
  `topic` VARCHAR(100) NOT NULL,
  `dt` DATE NOT NULL,
  `hr` TINYINT(4) NOT NULL,
  `mods` INT(11) DEFAULT NULL,
  PRIMARY KEY  (`idx`),
  UNIQUE KEY `topic_dt_hr` (`topic`,`dt`,`hr`)
) ENGINE=MYISAM DEFAULT CHARSET=utf8;

CREATE TABLE `iot_data_r_latest` (
  `idx` BIGINT(20) NOT NULL AUTO_INCREMENT,
  `topic` VARCHAR(100) NOT NULL,
  `dt` DATETIME NOT NULL,
  `mods` INT(11) DEFAULT NULL,
  PRIMARY KEY  (`idx`),
  UNIQUE KEY `topic` (`topic`),
  KEY `dt` (`dt`)
) ENGINE=MYISAM DEFAULT CHARSET=utf8;



DELIMITER $$

USE `xbs`$$

DROP PROCEDURE IF EXISTS `handle_iot_data_r`$$

CREATE DEFINER=`i3u`@`localhost` PROCEDURE `handle_iot_data_r`(_topic VARCHAR(50),_year VARCHAR(5),_month VARCHAR(3),_day VARCHAR(3),_hour VARCHAR(3),_minutes VARCHAR(3),_sec VARCHAR(3),_mods INT(11))
BEGIN
DECLARE vmods INT;
DECLARE breakable_cb INT;
DECLARE idx_ INT;
DECLARE dt_ DATETIME;
DECLARE dtnew DATETIME;
DECLARE mods_ INT;
SET vmods=0;
SET breakable_cb=0;
SET idx_=NULL;
SELECT CAST(CONCAT(_year,'-',_month,'-',_day,' ',_hour,':',_minutes,':',_sec) AS DATETIME) INTO dtnew;
SELECT idx,dt,mods INTO idx_,dt_,mods_ FROM xbs.iot_data_r_latest WHERE topic=_topic;
IF idx_ IS NOT NULL THEN
IF dtnew>dt_ THEN
IF _mods>=mods_ THEN
SET vmods=_mods-mods_;
ELSE
SET vmods=_mods;
END IF;
ELSE
SET breakable_cb=1;
END IF;
END IF;
IF breakable_cb=0 THEN
SELECT CAST(CONCAT(_year,'-',_month,'-',_day) AS DATE) INTO dt_;
INSERT INTO xbs.iot_data_r_latest (topic,dt,mods) 
VALUES(_topic,dtnew,_mods) ON DUPLICATE KEY UPDATE mods=_mods,dt=dtnew;
INSERT INTO xbs.iot_data_r (topic,dt,hr,mods) 
VALUES(_topic,dt_,_hour,vmods) ON DUPLICATE KEY UPDATE mods=mods+vmods;
END IF;
    END$$

DELIMITER ;

ALTER TABLE `xbs`.`iot_data_latest`     ADD COLUMN `modsplan` INT 0 AFTER `modno`;
CREATE TABLE `xbs`.`iot_dev` (
  `idx` int(11) NOT NULL auto_increment,
  `dev_id` varchar(20) default NULL,
  `dev_name` varchar(50) default NULL,
  `dev_type` varchar(10) default NULL,
  `actived` tinyint(1) default '1',
  PRIMARY KEY  (`idx`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;
insert  into `xbs`.`iot_dev`(`idx`,`dev_id`,`dev_name`,`dev_type`,`actived`) values (1,'PLC01','成型机[东洋01]','devices',1);
CREATE TABLE `xbs`.`iot_dev_data` (
  `idx` int(11) NOT NULL auto_increment,
  `dev_idx` int(11) NOT NULL,
  `data_id` varchar(20) default NULL,
  `data_name` varchar(50) default NULL,
  `data_param` varchar(20) default NULL,
  `columns` varchar(255) default NULL,
  `orderidx` tinyint(4) default '0',
  `actived` tinyint(1) default '1',
  PRIMARY KEY  (`idx`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;
insert  into `xbs`.`iot_dev_data`(`idx`,`dev_idx`,`data_id`,`data_name`,`data_param`,`columns`,`orderidx`,`actived`) values (1,1,'sys','报警数据','30','data0,data1,data2,data3,data4,data5',0,1),(2,1,'sys','报警复位数据','31','data0,data1,data2,data3,data4,data5,data6,data7,data8,data9,data10',0,0),(3,1,'sys','模式数据','32','data0,data1,data2,data3,data4',0,1),(4,1,'sys','监视数据1','33','data0,data1,data2,data3,data4,data5,data6',0,1),(5,1,'sys','监视数据2','34','data0',0,1),(6,1,'formcd','成型条件','36','data0,data1,data2,data3,data4,data5,data6,data7,data8,data9,data10',0,0),(7,1,'prodmg','生产管理','38','data0,data1,data2,data3,data4,data5,data6,data7,data8,data9,data10',0,0),(8,1,'sys','通信停止','42','data0,data1,data2,data3,data4,data5,data6,data7,data8,data9,data10',0,0),(9,1,'sys','通信开始','44','data0,data1,data2,data3,data4,data5,data6,data7,data8,data9,data10',0,0),(10,1,'cpux238','成型运转状态','46','data0,data1,data2,data3,data4,data5,data6,data7,data8,data9,data10',1,1),(11,1,'prodset','生产管理设定?变更','48',NULL,0,0);

ALTER TABLE `xbs`.`iot_dev_data`     ADD COLUMN `topic` VARCHAR(50) NULL AFTER `dev_idx`;
UPDATE iot_dev d JOIN iot_dev_data dd ON d.idx=dd.dev_idx SET dd.topic=CONCAT(d.dev_type,'/',d.dev_id,'/',dd.data_id,'/',dd.data_param);
ALTER TABLE `xbs`.`iot_dev`     CHANGE `idx` `dev_idx` INT(11) NOT NULL AUTO_INCREMENT;
ALTER TABLE `xbs`.`iot_dev_data`     CHANGE `idx` `dev_data_idx` INT(11) NOT NULL AUTO_INCREMENT;
update xbs.iot_dev_data set topic='devices/PLC01/sys/30',data_id='sys',data_name='报警数据',data_param='30',columns='data0 as 日期,data1 as 时间,data2 as 代码,data3 as 数据1,data4 as 数据2,data5 as 文字',orderidx='0',actived='1',dev_idx='1' where dev_data_idx='1';
update xbs.iot_dev_data set topic='devices/PLC01/sys/32',data_id='sys',data_name='模式数据',data_param='32',columns='data0 as 日期,data1 as 时间,data2 as 模式代码,data3 as 模式文字',orderidx='0',actived='1',dev_idx='1' where dev_data_idx='3';
update xbs.iot_dev_data set topic='devices/PLC01/sys/33',data_id='sys',data_name='监视数据1',data_param='33',columns='data0 as 年,data1 as 月,data2 as 日,data3 as 时,data4 as 分,data5 as 秒,data6 as 模数',orderidx='0',actived='1',dev_idx='1' where dev_data_idx='4';
update xbs.iot_dev_data set topic='devices/PLC01/sys/34',data_id='sys',data_name='监视数据2',data_param='34',columns='dt as 时间,data0 as 机种名',orderidx='0',actived='1',dev_idx='1' where dev_data_idx='5';
update xbs.iot_dev_data set topic='devices/PLC01/cpux238/46',data_id='cpux238',data_name='成型运转状态',data_param='46',columns='data0 as 日期,data1 as 时间,data2 as 机种名,data3 as 运转模式编码,data4 as 运转模式名,data5 as 产品名,data6 as 模具No.,data7 as 模数,data8 as 循环时间,data9 as 运转时间,data10 as 停止时间',orderidx='1',actived='1',dev_idx='1' where dev_data_idx='10';

DELIMITER $$

USE `xbs`$$

DROP PROCEDURE IF EXISTS `handle_iot_data`$$

CREATE DEFINER=`i3u`@`localhost` PROCEDURE `handle_iot_data`(_topic VARCHAR(50),_dt VARCHAR(11),_tm VARCHAR(9),_prodtp VARCHAR(50),_opcode TINYINT(4),_opmode VARCHAR(20),_prodname VARCHAR(50),_modno VARCHAR(20),_mods INT(11),_tcycle DOUBLE,_trun VARCHAR(11),_tstop VARCHAR(11))
BEGIN
DECLARE vmods INT;
DECLARE breakable_cb INT;
DECLARE idx_ INT;
DECLARE dt_ DATETIME;
DECLARE dtnew DATETIME;
DECLARE mods_ INT;
DECLARE trun_ INT;
DECLARE tstop_ INT;
SET vmods=0;
SET breakable_cb=0;
SET idx_=NULL;
SELECT idx,dt,mods,trun,tstop INTO idx_,dt_,mods_,trun_,tstop_ FROM xbs.iot_data_latest WHERE topic=_topic;
IF idx_ IS NOT NULL THEN
SELECT CAST(CONCAT(_dt,' ',_tm) AS DATETIME) INTO dtnew;
IF dtnew>dt_ THEN
IF _mods>=mods_ THEN
SET vmods=_mods-mods_;
ELSE
SET vmods=_mods;
END IF;
ELSE
SET breakable_cb=1;
END IF;
END IF;
IF breakable_cb=0 THEN
SELECT SUBSTR(_trun,-7) INTO @tmrun;
SELECT SUBSTR(_tstop,-7) INTO @tmstop;
SELECT CAST(_trun AS SIGNED)*3600+MINUTE(@tmrun)*60+SECOND(@tmrun) INTO @trun;
SELECT CAST(_tstop AS SIGNED)*3600+MINUTE(@tmstop)*60+SECOND(@tmstop) INTO @tstop;
IF trun_ IS NOT NULL AND tstop_ IS NOT NULL THEN
SET @trun_=@trun-trun_;
SET @tstop_=@tstop-tstop_;
ELSE
SET @trun_=0;
SET @tstop_=0;
END IF;
INSERT INTO xbs.iot_data_latest (topic,dt,prodtp,opcode,opmode,prodname,modno,mods,tcycle,trun,tstop) 
VALUES(_topic,CONCAT(_dt,' ',_tm),_prodtp,_opcode,_opmode,_prodname,_modno,_mods,_tcycle,@trun,@tstop) ON DUPLICATE KEY UPDATE dt=CONCAT(_dt,' ',_tm),prodtp=_prodtp,opcode=_opcode,opmode=_opmode,prodname=_prodname,modno=_modno,mods=_mods,tcycle=_tcycle,trun=@trun,tstop=@tstop;
INSERT INTO xbs.iot_data (topic,dt,hr,prodtp,opcode,opmode,prodname,modno,mods,tcycle,trun,tstop) 
VALUES(_topic,DATE(_dt),HOUR(_tm),_prodtp,_opcode,_opmode,_prodname,_modno,vmods,_tcycle,@trun_,@tstop_) ON DUPLICATE KEY UPDATE mods=mods+vmods,trun=trun+@trun_,tstop=tstop+@tstop_;
END IF;
    END$$

DELIMITER ;