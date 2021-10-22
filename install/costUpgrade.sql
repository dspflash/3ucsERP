CREATE TABLE IF NOT EXISTS `xbs`.`xbs_log` (
  `xbs_log_id` BIGINT(20) NOT NULL AUTO_INCREMENT,
  `log_level` ENUM('error','warning','debug','info') DEFAULT NULL,
  `task` VARCHAR(20) DEFAULT NULL,
  `program` VARCHAR(50) DEFAULT NULL,
  `msg` TEXT,
  `user_id` INT(11) DEFAULT NULL,
  `org_id` INT(11) DEFAULT NULL,
  `dt` DATETIME DEFAULT NULL,
  PRIMARY KEY  (`xbs_log_id`),
  KEY `task` (`task`),
  KEY `user_id` (`user_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

DELIMITER $$

USE `xbs`$$

DROP PROCEDURE IF EXISTS `_cost_rollup_4_material`$$

CREATE DEFINER=`i3u`@`localhost` PROCEDURE `_cost_rollup_4_material`(itemIdM BIGINT,costType INT,userid INT,orgId INT,dt DATETIME,autoCost BOOLEAN)
BEGIN
SET @ich=NULL;
SET @ludt=NULL;
SET @cst_base_rollup=1;
SELECT cst_item_cost_header_id,last_update_date,based_on_rollup_cb INTO @ich,@ludt,@cst_base_rollup FROM cst_item_cost_header WHERE (item_id_m,bom_cost_type,org_id)=(itemIdM, costType, orgId);
IF @ich IS NULL AND autoCost THEN
INSERT INTO cst_item_cost_header (item_id_m,bom_cost_type,based_on_rollup_cb,purchase_price,sales_price,include_in_rollup_cb,created_by,creation_date,last_update_by,last_update_date,org_id) 
VALUES(itemIdM,costType,1,0,0,1,userid,dt,userid,dt,orgId);
SELECT LAST_INSERT_ID() INTO @ich;
ELSE
UPDATE cst_item_cost_header SET last_update_by=userid,last_update_date=dt,org_id=orgId WHERE cst_item_cost_header_id=@ich;
END IF;
IF @ich IS NOT NULL AND (@ludt IS NULL OR @ludt!=dt) AND @cst_base_rollup=1 THEN
UPDATE cst_item_cost_line SET amount=0 WHERE cst_item_cost_header_id=@ich;
SET @base_price=NULL;
SELECT unit_price INTO @base_price FROM po_line pl JOIN po_header ph ON pl.po_header_id=ph.po_header_id WHERE (item_id_m,receving_org_id)=(itemIdM,orgId) AND po_status IN (323,326) ORDER BY po_line_id DESC LIMIT 0,1;
SELECT unit_price/IF(pl.uom_id=i.uom_id,1,IFNULL(GetUomRelation(pl.uom_id,i.uom_id),1)) INTO @base_price#,@uom_conv 
FROM po_line pl JOIN po_header ph ON pl.po_header_id=ph.po_header_id JOIN item i ON i.item_id_m=pl.item_id_m AND i.org_id=pl.receving_org_id
WHERE pl.item_id_m=itemIdM AND po_status IN (323,326) ORDER BY po_line_id DESC LIMIT 0,1;
IF @base_price IS NULL THEN
SELECT list_price INTO @base_price FROM item WHERE (item_id_m,org_id)=(itemIdM,orgId);
END IF;
IF @base_price IS NOT NULL THEN
#INSERT INTO xbs.xbs_log (log_level,task,program,msg,user_id,org_id,dt)VALUES('info','costRollup','4Material548',itemIdM,userid,orgId,now());
#INSERT INTO cst_item_cost_line (cst_item_cost_header_id,cost_element_type,cost_element_id,amount,cost_basis,this_level_cb,created_by,creation_date,last_update_by,last_update_date) select @ich,548,bom_material_element_id,@base_price,default_basis,1,userid,dt,userid,dt from bom_material_element where (org_id,status)=(orgId,1) ON DUPLICATE KEY UPDATE amount=@base_price,last_update_by=userid,last_update_date=dt;
SET @ciclid=NULL;
SELECT cst_item_cost_line_id INTO @ciclid FROM cst_item_cost_line cisl JOIN bom_material_element bme ON cisl.cost_element_id=bme.bom_material_element_id WHERE (cst_item_cost_header_id,cost_element_type,this_level_cb)=(@ich,548,1);
IF @ciclid IS NULL THEN
INSERT INTO cst_item_cost_line (cst_item_cost_header_id,cost_element_type,cost_element_id,amount,cost_basis,this_level_cb,created_by,creation_date,last_update_by,last_update_date) SELECT @ich,548,bom_material_element_id,@base_price,default_basis,1,userid,dt,userid,dt FROM bom_material_element WHERE (org_id,STATUS)=(orgId,1);
ELSE 
UPDATE cst_item_cost_line SET amount=@base_price,last_update_by=userid,last_update_date=dt WHERE cst_item_cost_line_id=@ciclid;
END IF;
#INSERT INTO xbs.xbs_log (log_level,task,program,msg,user_id,org_id,dt)VALUES('info','costRollup','4Material549',itemIdM,userid,orgId,NOW());
#INSERT INTO cst_item_cost_line (cst_item_cost_header_id,cost_element_type,cost_element_id,amount,cost_basis,this_level_cb,created_by,creation_date,last_update_by,last_update_date) select @ich,549,bom_overhead_id,rate,default_basis,1,userid,dt,userid,dt from bom_overhead_v where (overhead_type,rate_bom_cost_type,org_id,status)=(356,costType,orgId,1) ON DUPLICATE KEY UPDATE amount=rate,last_update_by=userid,last_update_date=dt;
SET @ciclid=NULL;
SELECT cst_item_cost_line_id INTO @ciclid FROM cst_item_cost_line cisl JOIN bom_overhead_v boh ON cisl.cost_element_id=boh.bom_overhead_id WHERE (cst_item_cost_header_id,cost_element_type,this_level_cb)=(@ich,549,1);
IF @ciclid IS NULL THEN
INSERT INTO cst_item_cost_line (cst_item_cost_header_id,cost_element_type,cost_element_id,amount,cost_basis,this_level_cb,created_by,creation_date,last_update_by,last_update_date) SELECT @ich,549,bom_overhead_id,rate,default_basis,1,userid,dt,userid,dt FROM bom_overhead_v WHERE (overhead_type,rate_bom_cost_type,org_id,STATUS)=(356,costType,orgId,1);
ELSE
UPDATE cst_item_cost_line SET amount=rate,last_update_by=userid,last_update_date=dt WHERE cst_item_cost_line_id=@ciclid;
END IF;
#update to standard cost
#IF updateStandard THEN
#call _cost_update_standard(itemIdM, costType,userid, orgId);
#END IF;
END IF;
DELETE FROM cst_item_cost_line WHERE amount=0 AND cst_item_cost_header_id=@ich;
END IF;
    END$$

DELIMITER ;

DELIMITER $$

USE `xbs`$$

DROP PROCEDURE IF EXISTS `_cost_rollup_cost_lines`$$

CREATE DEFINER=`i3u`@`localhost` PROCEDURE `_cost_rollup_cost_lines`(ich INT,itemIdM BIGINT, costType INT,userid INT, orgId INT, dt DATETIME, autoCost BOOLEAN)
BEGIN
DECLARE cpitem BIGINT;
DECLARE makebuy VARCHAR(5);
DECLARE cpusage INT;
DECLARE cpqty DECIMAL(15,5);
DECLARE done INT;
DECLARE cstbl CURSOR FOR SELECT component_item_id_m,usage_basis,usage_quantity,make_buy FROM item_component_v WHERE item_id_m=itemIdM AND org_id=orgId;
DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = 1;
SET @@max_sp_recursion_depth = 100;
#INSERT INTO xbs.xbs_log (log_level,task,program,msg,user_id,org_id,dt)VALUES('info','costRollup','4Lines',itemIdM,userid,orgId,NOW());
    OPEN cstbl;
    BEGIN_cstbl: LOOP
        FETCH cstbl INTO cpitem,cpusage,cpqty,makebuy;
        IF done THEN
            LEAVE BEGIN_cstbl;
        END IF;
        IF makebuy='make' THEN
	CALL _cost_rollup_forItem(cpitem, costType,userid, orgId, dt, autoCost);
INSERT INTO tmp_cst_item_cost_line (cst_item_cost_header_id,cost_element_type,cost_element_id,amount,cost_basis,this_level_cb) SELECT ich,cost_element_type,cost_element_id,l.amount*cpqty,cost_basis,0 FROM cst_item_cost_line l JOIN cst_item_cost_header h ON l.cst_item_cost_header_id=h.cst_item_cost_header_id WHERE (item_id_m,bom_cost_type,include_in_rollup_cb,org_id)=(cpitem,costType,1,orgId) ON DUPLICATE KEY UPDATE tmp_cst_item_cost_line.amount=tmp_cst_item_cost_line.amount+l.amount*cpqty;
	ELSE
	CALL _cost_rollup_4_material(cpitem, costType,userid, orgId, dt, autoCost);
INSERT INTO tmp_cst_item_cost_line (cst_item_cost_header_id,cost_element_type,cost_element_id,amount,cost_basis,this_level_cb) SELECT ich,cost_element_type,cost_element_id,l.amount*cpqty,cost_basis,
1#IF(cost_element_type=548,1,0) 
FROM cst_item_cost_line l JOIN cst_item_cost_header h ON l.cst_item_cost_header_id=h.cst_item_cost_header_id WHERE (item_id_m,bom_cost_type,include_in_rollup_cb,org_id)=(cpitem,costType,1,orgId) ON DUPLICATE KEY UPDATE tmp_cst_item_cost_line.amount=tmp_cst_item_cost_line.amount+l.amount*cpqty;
	END IF;
#insert into tmp_cst_item_cost_line (cst_item_cost_header_id,cost_element_type,cost_element_id,amount,cost_basis) select ich,cost_element_type,cost_element_id,l.amount,cost_basis FROM cst_item_cost_line l JOIN cst_item_cost_header h ON l.cst_item_cost_header_id=h.cst_item_cost_header_id WHERE (item_id_m,bom_cost_type,org_id,h.last_update_date)=(itemIdM, costType, orgId,dt) on DUPLICATE key update tmp_cst_item_cost_line.amount=tmp_cst_item_cost_line.amount+l.amount;
    END LOOP BEGIN_cstbl;
    CLOSE cstbl;
#INSERT INTO xbs.xbs_log (log_level,task,program,msg,user_id,org_id,dt)VALUES('info','costRollup','4LinesEnd',itemIdM,userid,orgId,NOW());
    END$$

DELIMITER ;

DELIMITER $$

USE `xbs`$$

DROP PROCEDURE IF EXISTS `_cost_rollup_forItem`$$

CREATE DEFINER=`i3u`@`localhost` PROCEDURE `_cost_rollup_forItem`(itemIdM BIGINT,costType INT,userid INT,orgId INT,dt DATETIME,autoCost BOOLEAN)
BEGIN
SET @ich=NULL;
SET @ludt=NULL;
SET @cst_base_rollup=1;
SELECT cst_item_cost_header_id,last_update_date,based_on_rollup_cb INTO @ich,@ludt,@cst_base_rollup FROM cst_item_cost_header WHERE (item_id_m,bom_cost_type,org_id)=(itemIdM, costType, orgId);
IF @ich IS NULL AND autoCost THEN
INSERT INTO cst_item_cost_header (item_id_m,bom_cost_type,based_on_rollup_cb,purchase_price,sales_price,include_in_rollup_cb,created_by,creation_date,last_update_by,last_update_date,org_id) 
VALUES(itemIdM,costType,1,0,0,1,userid,dt,userid,dt,orgId);
SELECT LAST_INSERT_ID() INTO @ich;
ELSE
UPDATE cst_item_cost_header SET last_update_by=userid,last_update_date=dt,org_id=orgId WHERE cst_item_cost_header_id=@ich;
END IF;
IF @ich IS NOT NULL AND (@ludt IS NULL OR @ludt!=dt) AND @cst_base_rollup=1 THEN
INSERT INTO xbs.xbs_log (log_level,task,program,msg,user_id,org_id,dt)VALUES('info','costRollup','4Item',itemIdM,userid,orgId,NOW());
UPDATE cst_item_cost_line SET amount=0 WHERE cst_item_cost_header_id=@ich;
CALL _cost_rollup_cost_lines(@ich,itemIdM,costType,userid, orgId, dt,autoCost);
SELECT cst_item_cost_header_id INTO @ich FROM cst_item_cost_header WHERE (item_id_m,bom_cost_type,org_id)=(itemIdM, costType, orgId);
INSERT INTO tmp_cst_item_cost_line (cst_item_cost_header_id,cost_element_type,cost_element_id,amount,cost_basis,this_level_cb) SELECT @ich,IF(osp_cb,551,547),resource_id,resource_rate*resource_usage,charge_basis,1 FROM bom_routing_detail brd JOIN bom_routing_header brh ON brd.bom_routing_header_id=brh.bom_routing_header_id JOIN bom_resource res ON res.bom_resource_id=brd.resource_id LEFT JOIN bom_resource_cost brc ON brc.bom_resource_id=brd.resource_id WHERE (brh.item_id_m,bom_cost_type,brh.org_id)=(itemIdM,costType,orgId) ON DUPLICATE KEY UPDATE amount=amount+resource_rate*resource_usage;
INSERT INTO tmp_cst_item_cost_line (cst_item_cost_header_id,cost_element_type,cost_element_id,amount,cost_basis,this_level_cb) SELECT @ich,550,bom_overhead_id,rate*resource_usage,default_basis,1 FROM bom_routing_detail brd JOIN bom_routing_header brh ON brd.bom_routing_header_id=brh.bom_routing_header_id JOIN bom_overhead_v boh ON (boh.resource_id=brd.resource_id AND rate_bom_cost_type=resource_bom_cost_type)WHERE (item_id_m,rate_bom_cost_type,brh.org_id,boh.status)=(itemIdM,costType,orgId,1) ON DUPLICATE KEY UPDATE amount=amount+rate*resource_usage;
#INSERT INTO xbs.xbs_log (log_level,task,program,msg,user_id,org_id,dt)VALUES('info','costRollup','4ItemIU',itemIdM,userid,orgId,NOW());
#insert into cst_item_cost_line (cost_element_type,cost_element_id,cost_basis,amount,this_level_cb,cst_item_cost_header_id,created_by,creation_date,last_update_by,last_update_date) select cost_element_type,cost_element_id,cost_basis,amount,this_level_cb,@ich,userid,dt,userid,dt FROM tmp_cst_item_cost_line where cst_item_cost_header_id=@ich ON DUPLICATE KEY UPDATE cst_item_cost_line.amount=tmp_cst_item_cost_line.amount,last_update_by=userid,last_update_date=dt;
SET @tclid=NULL;
SET @clid=NULL;
SET @idx=0;
WHILE @idx=0 OR @tclid IS NOT NULL DO
SET @tclid=NULL;
SET @ddl=CONCAT('SELECT  tcicl.cst_item_cost_line_id,cicl.cst_item_cost_line_id,tcicl.amount into @tclid,@clid,@tamount FROM tmp_cst_item_cost_line tcicl LEFT JOIN cst_item_cost_line cicl 
ON tcicl.cost_element_type=cicl.cost_element_type AND tcicl.cost_element_id=cicl.cost_element_id AND tcicl.this_level_cb=cicl.this_level_cb AND tcicl.cst_item_cost_header_id=cicl.cst_item_cost_header_id WHERE tcicl.cst_item_cost_header_id=',@ich,' limit ',@idx,',1');
SET @idx=@idx+1;
PREPARE stmt FROM @ddl;
EXECUTE stmt;
#INSERT INTO xbs.xbs_log (log_level,task,program,msg,user_id,org_id,dt)VALUES('info','costRollup','4ItemX',concat(itemIdM,@idx,ifnull(@tclid,''),ifnull(@clid,'')),userid,orgId,NOW());
IF @tclid IS NOT NULL THEN
IF @clid IS NULL THEN
INSERT INTO cst_item_cost_line (cost_element_type,cost_element_id,cost_basis,amount,this_level_cb,cst_item_cost_header_id,created_by,creation_date,last_update_by,last_update_date) SELECT cost_element_type,cost_element_id,cost_basis,amount,this_level_cb,@ich,userid,dt,userid,dt FROM tmp_cst_item_cost_line WHERE cst_item_cost_line_id=@tclid;
ELSE
UPDATE cst_item_cost_line SET amount=@tamount,last_update_by=userid,last_update_date=dt WHERE cst_item_cost_line_id=@clid;
END IF;
END IF;
END WHILE;
INSERT INTO xbs.xbs_log (log_level,task,program,msg,user_id,org_id,dt)VALUES('info','costRollup','4ItemEND',itemIdM,userid,orgId,NOW());
#update to standard cost
#IF updateStandard THEN
#CALL _cost_update_standard(itemIdM, costType,userid, orgId);
#end if;
DELETE FROM cst_item_cost_line WHERE amount=0 AND cst_item_cost_header_id=@ich;
END IF;
    END$$

DELIMITER ;

DELIMITER $$

USE `xbs`$$

DROP PROCEDURE IF EXISTS `cost_rollup_forItems`$$

CREATE DEFINER=`i3u`@`localhost` PROCEDURE `cost_rollup_forItems`(itemIdM BIGINT, itemIdM2 BIGINT, costType INT,userid INT, orgId INT, autoCost BOOLEAN)
BEGIN
DECLARE xItemIdM BIGINT;
DECLARE makebuy VARCHAR(5);
DECLARE costing BOOLEAN;
DECLARE done INT;
DECLARE cstitems CURSOR FOR SELECT item_id_m,make_buy,costing_enabled_cb FROM item WHERE IF(itemIdM2=0,IF(itemIdM=0,item_id_m IS NOT NULL,item_id_m=itemIdM),item_id_m BETWEEN itemIdM AND itemIdM2) AND org_id=orgId AND item_status!=278;
#DECLARE CONTINUE HANDLER FOR SQLEXCEPTION INSERT INTO xbs.xbs_log (log_level,task,program,msg,user_id,org_id,dt)VALUES('Error','costRollup','4Items','Rollup Failed',userid,orgId,NOW());
DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = 1;
IF costType!=1 THEN	#1 for frozen(standard and should update from others)
CREATE TEMPORARY TABLE IF NOT EXISTS `tmp_cst_item_cost_line` (
  `cst_item_cost_line_id` INT(12) NOT NULL AUTO_INCREMENT,
  `cst_item_cost_header_id` INT(12) NOT NULL,
  `cost_element_type` SMALLINT(6) NOT NULL,
  `cost_element_id` INT(12) DEFAULT NULL,
  `amount` DECIMAL(20,5) NOT NULL,
  `cost_basis` INT(11) DEFAULT NULL,
  `this_level_cb` TINYINT(1) DEFAULT '0',
  PRIMARY KEY  (`cst_item_cost_line_id`),
  UNIQUE KEY `cst_item_cost_header_id_2` (`cst_item_cost_header_id`,`cost_element_type`,`cost_element_id`,`this_level_cb`)
) ENGINE=INNODB AUTO_INCREMENT=5 DEFAULT CHARSET=utf8;
TRUNCATE TABLE tmp_cst_item_cost_line;
DELETE FROM xbs_log WHERE task='costRollup' AND user_id=userid;
SET @currollupdt=NOW();
    OPEN cstitems;
    BEGIN_cstitems: LOOP
        FETCH cstitems INTO xItemIdM,makebuy,costing;
        IF done THEN
            LEAVE BEGIN_cstitems;
        END IF;
        #IF costing THEN
        IF makebuy='make' THEN
	CALL _cost_rollup_forItem(xItemIdM, costType,userid, orgId, @currollupdt, autoCost);
	ELSE#elseif itemIdM!=0 then#just for one item cost rollup
	CALL _cost_rollup_4_material(xItemIdM, costType,userid, orgId, @currollupdt, autoCost);
	END IF;
	#END IF;
    END LOOP BEGIN_cstitems;
    CLOSE cstitems;
END IF;
    END$$

DELIMITER ;

DELIMITER $$

USE `xbs`$$

DROP PROCEDURE IF EXISTS `_cost_update_standard`$$

CREATE DEFINER=`i3u`@`localhost` PROCEDURE `_cost_update_standard`(itemIdM BIGINT,standCostType INT,costType INT,dt DATETIME,userid INT,orgId INT)
BEGIN
INSERT INTO cst_item_cost_header (item_id_m,bom_cost_type,based_on_rollup_cb,include_in_rollup_cb,created_by,creation_date,last_update_by,last_update_date,org_id) VALUES(itemIdM,'1','1','1',userid,dt,userid,dt,orgId) ON DUPLICATE KEY UPDATE last_update_by=userid,last_update_date=dt;
SET @fcih=NULL;
SET @ccih=NULL;
SELECT cst_item_cost_header_id INTO @fcih FROM cst_item_cost_header WHERE (bom_cost_type,item_id_m,org_id)=(standCostType,itemIdM,orgId);
SELECT cst_item_cost_header_id INTO @ccih FROM cst_item_cost_header WHERE (bom_cost_type,item_id_m,org_id)=(costType,itemIdM,orgId);
IF @fcih IS NOT NULL AND @fcih!=0 THEN
INSERT INTO tmp_cst_item_cost_line_variance (cost_element_type,cost_element_id,cost_basis,amount,cst_item_cost_header_id,this_level_cb) SELECT cost_element_type,cost_element_id,cost_basis,-amount,@fcih,this_level_cb FROM cst_item_cost_line srcl WHERE srcl.cst_item_cost_header_id=@fcih;
INSERT INTO tmp_cst_item_cost_line_variance (cost_element_type,cost_element_id,cost_basis,amount,cst_item_cost_header_id,this_level_cb) SELECT cost_element_type,cost_element_id,cost_basis,amount,@fcih,this_level_cb FROM cst_item_cost_line srcl WHERE srcl.cst_item_cost_header_id=@ccih ON DUPLICATE KEY UPDATE tmp_cst_item_cost_line_variance.amount=tmp_cst_item_cost_line_variance.amount+srcl.amount;
UPDATE cst_item_cost_line SET amount=0 WHERE cst_item_cost_header_id=@fcih;
#INSERT INTO cst_item_cost_line (cost_element_type,cost_element_id,cost_basis,amount,cst_item_cost_header_id,this_level_cb,created_by,creation_date,last_update_by,last_update_date) SELECT cost_element_type,cost_element_id,cost_basis,amount,@fcih,this_level_cb,userid,dt,userid,dt FROM cst_item_cost_line srcl WHERE srcl.cst_item_cost_header_id=@ccih ON DUPLICATE KEY UPDATE cst_item_cost_line.amount=srcl.amount,last_update_by=userid,last_update_date=dt;
SET @fclid=NULL;
SET @cclid=NULL;
SET @idx=0;
WHILE @idx=0 OR @cclid IS NOT NULL DO
SET @cclid=NULL;
SET @fclid=NULL;
SET @ddl=CONCAT('SELECT  fcicl.cst_item_cost_line_id,ccicl.cst_item_cost_line_id,ccicl.amount into @fclid,@cclid,@camount 
FROM (cst_item_cost_line ccicl JOIN cst_item_cost_header ccich ON ccicl.cst_item_cost_header_id=ccich.cst_item_cost_header_id AND ccich.bom_cost_type=',costType,') 
LEFT JOIN  (cst_item_cost_line fcicl JOIN cst_item_cost_header fcich ON fcicl.cst_item_cost_header_id=fcich.cst_item_cost_header_id AND fcich.bom_cost_type=',standCostType,') 
 ON (fcicl.cost_element_type=ccicl.cost_element_type AND fcicl.cost_element_id=ccicl.cost_element_id AND fcicl.this_level_cb=ccicl.this_level_cb 
 AND fcich.item_id_m=ccich.item_id_m AND fcich.org_id=ccich.org_id) where ccich.cst_item_cost_header_id=',@ccih,' limit ',@idx,',1');
SET @idx=@idx+1;
PREPARE stmt FROM @ddl;
EXECUTE stmt;
IF @cclid IS NOT NULL THEN
IF @fclid IS NULL THEN
INSERT INTO cst_item_cost_line (cost_element_type,cost_element_id,cost_basis,amount,this_level_cb,cst_item_cost_header_id,created_by,creation_date,last_update_by,last_update_date) SELECT cost_element_type,cost_element_id,cost_basis,amount,this_level_cb,@fcih,userid,dt,userid,dt FROM cst_item_cost_line WHERE cst_item_cost_line_id=@cclid;
ELSE
UPDATE cst_item_cost_line SET amount=@camount,last_update_by=userid,last_update_date=dt WHERE cst_item_cost_line_id=@fclid;
END IF;
END IF;
END WHILE;
DELETE FROM cst_item_cost_line WHERE amount=0 AND cst_item_cost_header_id=@fcih;
END IF;
    END$$

DELIMITER ;