DELIMITER $$

USE `xbs`$$

DROP PROCEDURE IF EXISTS `tbColumnAddChg`$$

CREATE DEFINER=`i3u`@`localhost` PROCEDURE `tbColumnAddChg`(
    IN dbName TINYTEXT,
    IN tableName TINYTEXT,
    IN fieldName TINYTEXT,
    IN fieldDef TEXT,
    IN komt TEXT,
    IN colAfter TINYTEXT)
BEGIN
    SET @ddl=CONCAT('ALTER TABLE ',dbName,'.',tableName);
    IF NOT EXISTS (SELECT * FROM information_schema.COLUMNS WHERE column_name=fieldName AND table_name=tableName AND table_schema=dbName) THEN
	SET @ddl=CONCAT(@ddl,' ADD COLUMN ');
    ELSE
        SET @ddl=CONCAT(@ddl,' change ',fieldName,' ');
    END IF;
	SET @ddl=CONCAT(@ddl,fieldName,' ',fieldDef);
        IF komt!='' THEN
        SET @ddl=CONCAT(@ddl,' COMMENT \'',komt,'\'');
        END IF;
        IF colAfter!='' THEN
        SET @ddl=CONCAT(@ddl,' AFTER ',colAfter);
        END IF;
        PREPARE stmt FROM @ddl;
        EXECUTE stmt;
END$$

DELIMITER ;

DELIMITER $$

USE `xbs`$$

DROP PROCEDURE IF EXISTS `tbColumnDropIfExists`$$

CREATE DEFINER=`i3u`@`localhost` PROCEDURE `tbColumnDropIfExists`(
    IN dbName TINYTEXT,
    IN tableName TINYTEXT,
    IN fieldName TINYTEXT)
BEGIN
    IF EXISTS (SELECT * FROM information_schema.COLUMNS WHERE column_name=fieldName AND table_name=tableName AND table_schema=dbName) THEN
        SELECT 1 INTO @n;
        SET @ddl=CONCAT('ALTER TABLE ',dbName,'.',tableName,' DROP ',fieldName);
        PREPARE stmt FROM @ddl;
        EXECUTE stmt;
    END IF;
END$$

DELIMITER ;

DELIMITER $$

USE `xbs`$$

DROP PROCEDURE IF EXISTS `tbIndexAddModify`$$

CREATE DEFINER=`i3u`@`localhost` PROCEDURE `tbIndexAddModify`(
    IN dbName TINYTEXT,
    IN tableName TINYTEXT,
    IN indexName TINYTEXT,
    IN fieldnames TEXT)
BEGIN
    SET @ddl=CONCAT('ALTER TABLE ',dbName,'.',tableName);
    SELECT COUNT(*) INTO @cnt FROM information_schema.statistics WHERE index_name=indexName AND table_name=tableName AND table_schema=dbName;
    IF @cnt>0 THEN
        SET @ddl=CONCAT(@ddl,' DROP KEY ',indexName,', ');
    END IF;
	SET @ddl=CONCAT(@ddl,' ADD INDEX ');
	SET @ddl=CONCAT(@ddl,indexName,'(',fieldnames,')');
        PREPARE stmt FROM @ddl;
        EXECUTE stmt;
END$$

DELIMITER ;

CALL tbColumnAddChg('xbs','sd_so_header','document_extn_ref','VARCHAR(50) NULL','Original document reference for the order in external system','ordered_date');
CALL tbColumnDropIfExists('xbs','po_quote_header','approval_status');
CALL tbColumnAddChg('xbs','po_quote_header','approval_status','INT(11) default 321','','quote_status');
CALL tbIndexAddModify('xbs','po_quote_header','approval_status','approval_status');
UPDATE xbs.option_line SET option_header_id='132',option_line_code='REVIEW',option_line_value='复核',description='ReView',STATUS='0',last_update_by='14',last_update_date=NOW() WHERE option_line_id='324';
UPDATE xbs.po_quote_header SET approval_status=320 WHERE quote_status=1487;
UPDATE xbs.po_quote_header SET approval_status=326 WHERE quote_status=1489;
CALL tbColumnAddChg('xbs','inv_receipt_line','reference_key_name','ENUM(\'po_line\',\'wip_wo_bom\',\'sd_so_line\',\'am_wo_bom\',\'wip_wo_header\',\'inv_receipt_line\',\'wip_move_transaction\')','','');
CALL tbColumnAddChg('xbs','sd_delivery_line','pkg_uom_id','INT(11) DEFAULT 0','','line_uom_id');
CALL tbColumnAddChg('xbs','sd_delivery_line','pkg_quantity','INT(11) DEFAULT 0','','pkg_uom_id');
CALL tbColumnAddChg('xbs','sd_delivery_line','pkg_description','VARCHAR(50) DEFAULT NULL','','pkg_quantity');

DELIMITER $$

USE `xbs`$$

DROP PROCEDURE IF EXISTS `bomimport`$$

CREATE DEFINER=`i3u`@`localhost` PROCEDURE `bomimport`(product VARCHAR(50),material VARCHAR(50),itemname VARCHAR(50),spec VARCHAR(50),m_uom VARCHAR(20),m_price DECIMAL(20,5),quantity DECIMAL(20,5),operation VARCHAR(20),dept VARCHAR(20),recvsubinv VARCHAR(25),wipsupplytp VARCHAR(20),wipsubinv VARCHAR(25), orgid INT,userid INT)
BEGIN
SET @prduom='Ea';
IF(material!='') THEN
SET @item=NULL;
SET @product=NULL;
SET @routid=NULL;
SET @routseq=NULL;
SET @routseqnum=NULL;
SET @bomid=NULL;
SET @bom_seq=NULL;
SET @uomid=NULL;
SET @recvsubinv=1;
SELECT item_id_m INTO @item FROM item WHERE item_number=material AND org_id=orgid;
SELECT uom_id INTO @uomid FROM uom WHERE uom_name=m_uom;
IF(@uomid IS NULL) THEN
INSERT INTO uom (uom_name,created_by, creation_date, last_update_by, last_update_date) VALUES(m_uom,userid,NOW(),userid,NOW());
SELECT LAST_INSERT_ID() INTO @uomid;
END IF;
SELECT subinventory_id INTO @recvsubinv FROM subinventory WHERE subinventory=recvsubinv AND org_id=orgid;
INSERT INTO item(item_number,item_name,item_specification,uom_id,list_price,item_type,make_buy,bom_enabled_cb,bom_type,org_id,receipt_sub_inventory,created_by, creation_date, last_update_by, last_update_date) VALUES(material,itemname,spec,@uomid,m_price,IF(m_price!=0,106,105),IF(m_price!=0,'buy','make'),IF(m_price!=0,0,1),IF(m_price!=0,0,1077),orgid,@recvsubinv,userid,NOW(),userid,NOW()) ON DUPLICATE KEY UPDATE item_name=itemname,item_specification=spec,uom_id=@uomid,list_price=m_price,item_type=IF(m_price!=0,106,105),make_buy=IF(m_price!=0,'buy','make'),bom_enabled_cb=IF(m_price!=0,0,1),bom_type=IF(m_price!=0,0,1077),receipt_sub_inventory=@recvsubinv,last_update_by=userid,last_update_date=NOW();
IF(@item IS NULL) THEN
SELECT LAST_INSERT_ID() INTO @item;
UPDATE item SET item_id_m=@item WHERE item_id=@item AND org_id=orgid;
END IF;
IF product!='' THEN
SELECT item_id_m INTO @product FROM item WHERE item_number=product AND org_id=orgid;
IF(@product IS NULL) THEN
SET @uomid=NULL;
SELECT uom_id INTO @uomid FROM uom WHERE uom_name=@prduom;
IF(@uomid IS NULL) THEN
INSERT INTO uom (uom_name,created_by, creation_date, last_update_by, last_update_date) VALUES(@prduom,userid,NOW(),userid,NOW());
SELECT LAST_INSERT_ID() INTO @uomid;
END IF;
INSERT INTO item(item_number,uom_id,item_type,make_buy,bom_enabled_cb,bom_type,org_id,created_by, creation_date, last_update_by, last_update_date) VALUES(product,@uomid,99,'make',1,1077,orgid,userid,NOW(),userid,NOW());
SELECT LAST_INSERT_ID() INTO @product;
UPDATE item SET item_id_m=@product WHERE item_id=@product AND org_id=orgid;
END IF;
IF(@product IS NOT NULL) THEN
SELECT bom_routing_header_id INTO @routid FROM bom_routing_header WHERE item_id_m=@product AND org_id=orgid;
IF(@routid IS NULL) THEN
INSERT INTO bom_routing_header (item_id_m,org_id,effective_date,routing_revision,completion_subinventory,created_by, creation_date, last_update_by, last_update_date) VALUES(@product,orgid,NOW(),'1.0',0,userid,NOW(),userid,NOW());
SELECT LAST_INSERT_ID() INTO @routid;
END IF;
SET @stdopid=NULL;
SET @dptid=NULL;
IF operation!='' THEN
SELECT bom_standard_operation_id,department_id INTO @stdopid,@dptid FROM bom_standard_operation WHERE (standard_operation,org_id)=(operation,orgid);
IF @stdopid IS NULL THEN
#if dept!='' then
SELECT bom_department_id INTO @dptid FROM bom_department WHERE (department,org_id)=(IF(dept='',operation,dept),orgid);
IF @dptid IS NULL THEN
INSERT INTO bom_department (department,STATUS,description,org_id,created_by,creation_date,last_update_by,last_update_date) VALUES(IF(dept='',operation,dept),'1','',orgid,userid,NOW(),userid,NOW());
SELECT LAST_INSERT_ID() INTO @dptid;
END IF;
#end if;
INSERT INTO bom_standard_operation (department_id,standard_operation,description,STATUS,created_by,creation_date,last_update_by,last_update_date,org_id) VALUES(@dptid,operation,'','1',userid,NOW(),userid,NOW(),orgid);
SELECT LAST_INSERT_ID() INTO @stdopid;
END IF;
END IF;
SET @bomrt_seq=NULL;
SELECT MAX(routing_sequence) INTO @bomrt_seq FROM bom_routing_line WHERE bom_routing_header_id=@routid;
IF(@bomrt_seq IS NULL) THEN
SET @bomrt_seq = 10;
ELSE
SET @bomrt_seq = @bomrt_seq+10;
END IF;
INSERT IGNORE INTO bom_routing_line (bom_routing_header_id,routing_sequence,routing_seq_num,standard_operation_id,department_id,created_by, creation_date, last_update_by, last_update_date) 
VALUES(@routid,@bomrt_seq,0,@stdopid,@dptid,userid,NOW(),userid,NOW());
SELECT routing_sequence,routing_seq_num INTO @routseq,@routseqnum FROM bom_routing_line_v WHERE (bom_routing_header_id,standard_operation,org_id)=(@routid,operation,orgid);
SELECT bom_header_id INTO @bomid FROM bom_header WHERE item_id_m = @product AND org_id=orgid;
IF(@bomid IS NULL) THEN
INSERT INTO bom_header (item_id_m,bom_revision,org_id,created_by, creation_date, last_update_by, last_update_date) VALUES(@product,'1.0',orgid,userid,NOW(),userid,NOW());
SELECT LAST_INSERT_ID() INTO @bomid;
END IF;
SELECT MAX(bom_sequence) INTO @bom_seq FROM bom_line WHERE bom_header_id=@bomid;
IF(@bom_seq IS NULL) THEN
SET @bom_seq = 10;
ELSE
SET @bom_seq = @bom_seq+10;
END IF;
SET @wipsupplytp=NULL;
SET @wipsubinv=NULL;
SELECT option_line_id INTO @wipsupplytp FROM option_line WHERE option_header_id=135 AND option_line_value=wipsupplytp;
SELECT subinventory_id INTO @wipsubinv FROM subinventory WHERE subinventory=wipsubinv AND org_id=orgid;
INSERT INTO bom_line(bom_header_id, bom_sequence, routing_sequence,routing_seq_num, component_item_id_m,usage_basis, usage_quantity,wip_supply_type,supply_sub_inventory,created_by, creation_date, last_update_by, last_update_date) VALUES(@bomid,@bom_seq,IFNULL(@routseq,10),IFNULL(@routseqnum,0),@item,351,quantity,@wipsupplytp,@wipsubinv,userid,NOW(),userid,NOW()) 
ON DUPLICATE KEY UPDATE usage_quantity=quantity,wip_supply_type=@wipsupplytp,supply_sub_inventory=@wipsubinv,last_update_by=userid,last_update_date=NOW();
END IF;
END IF;
END IF;
    END$$

DELIMITER ;

DELIMITER $$

USE `xbs`$$

DROP VIEW IF EXISTS `po_so_v`$$

CREATE ALGORITHM=UNDEFINED DEFINER=`i3u`@`localhost` SQL SECURITY DEFINER VIEW `po_so_v` AS (
SELECT
  `ph`.`po_number`        AS `po_number`,
  `so`.`so_number`        AS `so_number`,
  IFNULL(`ph`.`printed_date`,CAST(`pl`.`creation_date` AS DATE)) AS `printed_date`,
  `pl`.`need_by_date`     AS `need_by_date`,
  `m`.`item_number`       AS `material`,
  `pl`.`line_quantity`    AS `line_quantity`,
  `uom`.`uom_name`        AS `uom_name`,
  `pl`.`unit_price`       AS `unit_price`,
  `pl`.`line_description` AS `line_description`,
  `sp`.`supplier_name`    AS `supplier_name`,
  `pl`.`promise_date`     AS `promise_date`,
  `ph`.`po_status`        AS `po_status`,
  `pl`.`status`           AS `status`,
  `ph`.`bu_org_id`        AS `bu_org_id`,
  `ph`.`po_header_id`     AS `po_header_id`,
  `ph`.`supplier_id`      AS `supplier_id`
FROM (((((`po_line` `pl`
       LEFT JOIN `sd_so_header` `so`
         ON (((`pl`.`reference_key_name` = _utf8'sd_so_header')
              AND (`pl`.`reference_header_id` = `so`.`sd_so_header_id`))))
      JOIN `po_header` `ph`
        ON ((`ph`.`po_header_id` = `pl`.`po_header_id`)))
     JOIN `item` `m`
       ON (((`pl`.`item_id_m` = `m`.`item_id_m`)
            AND (`pl`.`receving_org_id` = `m`.`org_id`))))
    JOIN `uom`
      ON (((`uom`.`uom_id` = `pl`.`uom_id`)
           AND (`pl`.`receving_org_id` = `m`.`org_id`))))
   JOIN `supplier` `sp`
     ON ((`sp`.`supplier_id` = `ph`.`supplier_id`))))$$

DELIMITER ;

DELIMITER $$

USE `xbs`$$

DROP VIEW IF EXISTS `sd_so_header_v`$$

CREATE ALGORITHM=UNDEFINED DEFINER=`i3u`@`localhost` SQL SECURITY DEFINER VIEW `sd_so_header_v` AS (
SELECT
  CAST(`s`.`creation_date` AS DATE) AS `create_date`,
  `s`.`so_number`                AS `so_number`,
  `s`.`document_extn_ref`        AS `document_extn_ref`,
  `s`.`description`              AS `description`,
  `a`.`customer_name`            AS `ar_customer_name`,
  `a0`.`customer_site_name`      AS `customer_site_name`,
  CONCAT(`e`.`last_name`,_utf8' ',`e`.`first_name`) AS `employee`,
  `o2`.`option_line_value`       AS `approval_statusv`,
  `o3`.`option_line_value`       AS `so_statusv`,
  `a1`.`address`                 AS `ship_to_id`,
  `a2`.`address`                 AS `bill_to_id`,
  `s`.`header_amount`            AS `header_amount`,
  `s`.`pre_payment_amount`       AS `pre_payment_amount`,
  `s`.`tax_amount`               AS `tax_amount`,
  `c`.`title`                    AS `doc_currency`,
  `s`.`prepaid_status`           AS `prepaid_status`,
  `s`.`prepaid_amount`           AS `prepaid_amount`,
  `c0`.`title`                   AS `currency`,
  `x`.`username`                 AS `creator`,
  `x0`.`username`                AS `updator`,
  `p`.`payment_term`             AS `payment_term_id`,
  `s`.`payment_term_date`        AS `payment_term_date`,
  `s`.`agreement_start_date`     AS `agreement_start_date`,
  `s`.`aggrement_end_date`       AS `aggrement_end_date`,
  `g`.`currency_conversion_type` AS `exchange_rate_type`,
  `s`.`exchange_rate`            AS `exchange_rate`,
  `s`.`released_amount`          AS `released_amount`,
  `o1`.`option_line_value`       AS `order_source_type`,
  `s`.`hr_employee_id`           AS `hr_employee_id`,
  `s`.`ar_customer_id`           AS `ar_customer_id`,
  `s`.`ar_customer_site_id`      AS `ar_customer_site_id`,
  `s`.`sd_so_header_id`          AS `sd_so_header_id`,
  `s`.`approval_status`          AS `approval_status`,
  `s`.`so_status`                AS `so_status`,
  `s`.`bu_org_id`                AS `bu_org_id`,
  `s`.`created_by`               AS `created_by`,
  `s`.`creation_date`            AS `creation_date`,
  `s`.`last_update_by`           AS `last_update_by`,
  `s`.`last_update_date`         AS `last_update_date`
FROM (((((((((((((((`sd_so_header` `s`
                 LEFT JOIN `hr_employee` `e`
                   ON ((`s`.`hr_employee_id` = `e`.`hr_employee_id`)))
                LEFT JOIN `ar_customer` `a`
                  ON ((`s`.`ar_customer_id` = `a`.`ar_customer_id`)))
               LEFT JOIN `ar_customer_site` `a0`
                 ON ((`s`.`ar_customer_site_id` = `a0`.`ar_customer_site_id`)))
              LEFT JOIN `mdm_price_list_header` `m`
                ON ((`s`.`price_list_header_id` = `m`.`mdm_price_list_header_id`)))
             LEFT JOIN `address` `a1`
               ON ((`s`.`ship_to_id` = `a1`.`address_id`)))
            LEFT JOIN `address` `a2`
              ON ((`s`.`bill_to_id` = `a2`.`address_id`)))
           LEFT JOIN `currency` `c`
             ON ((`s`.`doc_currency` = `c`.`currency_id`)))
          LEFT JOIN `currency` `c0`
            ON ((`s`.`currency` = `c0`.`currency_id`)))
         LEFT JOIN `payment_term` `p`
           ON ((`s`.`payment_term_id` = `p`.`payment_term_id`)))
        LEFT JOIN `gl_currency_conversion` `g`
          ON ((`s`.`exchange_rate_type` = `g`.`gl_currency_conversion_id`)))
       LEFT JOIN `option_line` `o1`
         ON ((`s`.`order_source_type` = `o1`.`option_line_id`)))
      LEFT JOIN `option_line` `o2`
        ON ((`s`.`approval_status` = `o2`.`option_line_id`)))
     LEFT JOIN `option_line` `o3`
       ON ((`s`.`so_status` = `o3`.`option_line_id`)))
    LEFT JOIN `xerp_user` `X`
      ON ((`s`.`created_by` = `x`.`xerp_user_id`)))
   LEFT JOIN `xerp_user` `x0`
     ON ((`s`.`last_update_by` = `x0`.`xerp_user_id`)))
ORDER BY `s`.`sd_so_header_id`)$$

DELIMITER ;

DELIMITER $$

USE `xbs`$$

DROP VIEW IF EXISTS `sd_so_line_v`$$

CREATE ALGORITHM=UNDEFINED DEFINER=`i3u`@`localhost` SQL SECURITY DEFINER VIEW `sd_so_line_v` AS (
SELECT
  `sh`.`so_number`           AS `so_number`,
  `sh`.`document_extn_ref`   AS `document_extn_ref`,
  `sh`.`ar_customer_name`    AS `ar_customer_name`,
  `s0`.`item_number`         AS `item_number`,
  `s0`.`item_description`    AS `item_description`,
  `s0`.`item_name`           AS `item_name`,
  `s0`.`item_specification`  AS `item_specification`,
  `s`.`line_number`          AS `line_number`,
  `s`.`line_quantity`        AS `line_quantity`,
  `s`.`shipped_quantity`     AS `shipped_quantity`,
  (`s`.`line_quantity` - `s`.`shipped_quantity`) AS `UnShipped_quantity`,
  `u`.`uom_name`             AS `uom_name`,
  `sos`.`option_line_value`  AS `so_statusv`,
  `o2`.`option_line_value`   AS `line_statusv`,
  `s`.`actual_ship_date`     AS `actual_ship_date`,
  `o`.`option_line_value`    AS `line_type`,
  `o0`.`option_line_value`   AS `supply_source`,
  `s`.`unit_price`           AS `unit_price`,
  `s`.`line_price`           AS `line_price`,
  `s`.`price_date`           AS `price_date`,
  `s`.`gl_line_price`        AS `gl_line_price`,
  `s`.`gl_tax_amount`        AS `gl_tax_amount`,
  `m`.`tax_code`             AS `tax_code_id`,
  `s`.`tax_amount`           AS `tax_amount`,
  `s`.`requested_date`       AS `requested_date`,
  `s`.`promise_date`         AS `promise_date`,
  `s`.`schedule_ship_date`   AS `schedule_ship_date`,
  `o1`.`option_line_value`   AS `destination_type`,
  `s`.`invoiced_quantity`    AS `invoiced_quantity`,
  `s`.`picked_quantity`      AS `picked_quantity`,
  `s`.`line_description`     AS `line_description`,
  `s`.`created_by`           AS `created_by`,
  `s`.`creation_date`        AS `creation_date`,
  `s`.`last_update_by`       AS `last_update_by`,
  `s`.`last_update_date`     AS `last_update_date`,
  `s`.`shipping_org_id`      AS `shipping_org_id`,
  `s`.`sd_so_line_id`        AS `sd_so_line_id`,
  `s`.`sd_so_header_id`      AS `sd_so_header_id`,
  `sh`.`ar_customer_id`      AS `ar_customer_id`,
  `s`.`bom_config_header_id` AS `bom_config_header_id`,
  `sh`.`so_status`           AS `so_status`,
  `s`.`uom_id`               AS `uom_id`,
  `s`.`line_status`          AS `line_status`,
  `s`.`item_id_m`            AS `item_id_m`,
  `s`.`wip_wo_header_id`     AS `wip_wo_header_id`
FROM (((((((((`sd_so_line` `s`
           LEFT JOIN `uom` `u`
             ON ((`s`.`uom_id` = `u`.`uom_id`)))
          JOIN `sd_so_header_v` `sh`
            ON ((`s`.`sd_so_header_id` = `sh`.`sd_so_header_id`)))
         LEFT JOIN `option_line` `sos`
           ON ((`sh`.`so_status` = `sos`.`option_line_id`)))
        LEFT JOIN `option_line` `o`
          ON ((`s`.`line_type` = `o`.`option_line_id`)))
       LEFT JOIN `option_line` `o0`
         ON ((`s`.`supply_source` = `o0`.`option_line_id`)))
      LEFT JOIN `item` `s0`
        ON (((`s`.`item_id_m` = `s0`.`item_id_m`)
             AND (`s`.`shipping_org_id` = `s0`.`org_id`))))
     LEFT JOIN `mdm_tax_code` `m`
       ON ((`s`.`tax_code_id` = `m`.`mdm_tax_code_id`)))
    LEFT JOIN `option_line` `o1`
      ON ((`s`.`destination_type` = `o1`.`option_line_id`)))
   LEFT JOIN `option_line` `o2`
     ON ((`s`.`line_status` = `o2`.`option_line_id`))))$$

DELIMITER ;

DELIMITER $$

USE `xbs`$$

DROP VIEW IF EXISTS `sd_dlv_line_v`$$

CREATE ALGORITHM=UNDEFINED DEFINER=`i3u`@`localhost` SQL SECURITY DEFINER VIEW `sd_dlv_line_v` AS (
SELECT
  `s0`.`so_number`              AS `so_number`,
  `s0`.`document_extn_ref`      AS `document_extn_ref`,
  `ac`.`customer_name`          AS `customer_name`,
  `ds`.`option_line_value`      AS `delivery_statusv`,
  `i`.`item_number`             AS `item_number`,
  `i`.`item_name`               AS `item_name`,
  `i`.`item_specification`      AS `item_specification`,
  `i`.`item_description`        AS `item_description`,
  `u`.`uom_name`                AS `line_uom`,
  `s`.`quantity`                AS `quantity`,
  `s`.`shipped_quantity`        AS `shipped_quantity`,
  `u2`.`uom_name`               AS `pkg_uom`,
  `s`.`pkg_quantity`            AS `pkg_quantity`,
  `s`.`pkg_description`         AS `pkg_description`,
  `s1`.`unit_price`             AS `unit_price`,
  `s1`.`line_price`             AS `line_price`,
  `s`.`picking_date`            AS `picking_date`,
  `s`.`actual_ship_date`        AS `actual_ship_date`,
  `acs`.`customer_site_name`    AS `customer_site_name`,
  `da`.`address`                AS `ship_address`,
  `s2`.`subinventory`           AS `subinventory`,
  `l`.`locator`                 AS `locator`,
  `u0`.`uom_name`               AS `volume_uom`,
  `s`.`total_volume`            AS `total_volume`,
  `s1`.`line_number`            AS `line_number`,
  `u1`.`uom_name`               AS `weight_uom`,
  `s`.`total_weight`            AS `total_weight`,
  `x`.`username`                AS `creator`,
  `x0`.`username`               AS `updator`,
  `s`.`item_id_m`               AS `item_id_m`,
  `i`.`item_rev_number`         AS `item_rev_number`,
  `s0`.`ar_customer_id`         AS `ar_customer_id`,
  `s`.`sd_delivery_line_id`     AS `sd_delivery_line_id`,
  `s`.`sd_delivery_header_id`   AS `sd_delivery_header_id`,
  `s0`.`sd_so_header_id`        AS `sd_so_header_id`,
  `s`.`sd_so_line_id`           AS `sd_so_line_id`,
  `s`.`line_uom_id`             AS `line_uom_id`,
  `s`.`volume_uom_id`           AS `volume_uom_id`,
  `s`.`weight_uom_id`           AS `weight_uom_id`,
  `s`.`staging_subinventory_id` AS `staging_subinventory_id`,
  `s`.`staging_locator_id`      AS `staging_locator_id`,
  `s`.`shipping_org_id`         AS `shipping_org_id`,
  `s`.`delivery_status`         AS `delivery_status`,
  `s`.`created_by`              AS `created_by`,
  `s`.`creation_date`           AS `creation_date`,
  `s`.`last_update_by`          AS `last_update_by`,
  `s`.`last_update_date`        AS `last_update_date`
FROM (((((((((((((((`sd_delivery_line` `s`
                 LEFT JOIN `sd_so_header` `s0`
                   ON ((`s`.`sd_so_header_id` = `s0`.`sd_so_header_id`)))
                LEFT JOIN `sd_so_line` `s1`
                  ON ((`s`.`sd_so_line_id` = `s1`.`sd_so_line_id`)))
               LEFT JOIN `ar_customer` `ac`
                 ON ((`s0`.`ar_customer_id` = `ac`.`ar_customer_id`)))
              LEFT JOIN `ar_customer_site` `acs`
                ON ((`s0`.`ar_customer_site_id` = `acs`.`ar_customer_site_id`)))
             LEFT JOIN `address` `da`
               ON ((`s0`.`ship_to_id` = `da`.`address_id`)))
            LEFT JOIN `item` `i`
              ON (((`s`.`item_id_m` = `i`.`item_id_m`)
                   AND (`i`.`org_id` = `s1`.`shipping_org_id`))))
           LEFT JOIN `uom` `u`
             ON ((`s`.`line_uom_id` = `u`.`uom_id`)))
          LEFT JOIN `subinventory` `s2`
            ON ((`s`.`staging_subinventory_id` = `s2`.`subinventory_id`)))
         LEFT JOIN `locator` `l`
           ON ((`s`.`staging_locator_id` = `l`.`locator_id`)))
        LEFT JOIN `uom` `u0`
          ON ((`s`.`volume_uom_id` = `u0`.`uom_id`)))
       LEFT JOIN `option_line` `ds`
         ON ((`ds`.`option_line_id` = `s`.`delivery_status`)))
      LEFT JOIN `uom` `u1`
        ON ((`s`.`weight_uom_id` = `u1`.`uom_id`)))
     LEFT JOIN `uom` `u2`
       ON ((`s`.`pkg_uom_id` = `u2`.`uom_id`)))
    LEFT JOIN `xerp_user` `x`
      ON ((`s`.`created_by` = `x`.`xerp_user_id`)))
   LEFT JOIN `xerp_user` `x0`
     ON ((`s`.`last_update_by` = `x0`.`xerp_user_id`))))$$

DELIMITER ;

DELIMITER $$

USE `xbs`$$

DROP VIEW IF EXISTS `sd_quote_v`$$

CREATE ALGORITHM=UNDEFINED DEFINER=`i3u`@`localhost` SQL SECURITY DEFINER VIEW `sd_quote_v` AS (
SELECT
  `q`.`quote_number`         AS `quote_number`,
  `s`.`line_number`          AS `line_number`,
  `i`.`item_number`          AS `item_number`,
  `i`.`item_description`     AS `item_description`,
  `i`.`item_name`            AS `item_name`,
  `i`.`item_specification`   AS `item_specification`,
  `s`.`unit_price`           AS `unit_price`,
  `s`.`line_quantity`        AS `line_quantity`,
  `u`.`uom_name`             AS `uom_name`,
  `m`.`tax_code`             AS `tax_code`,
  `o1`.`option_line_value`   AS `statusv`,
  `q`.`approval_statusv`     AS `approval_statusv`,
  `s`.`price_date`           AS `price_date`,
  `q`.`customer_name`        AS `customer_name`,
  `q`.`customer_site_name`   AS `customer_site_name`,
  `q`.`description`          AS `description`,
  `q`.`ship_to_addr`         AS `ship_to_addr`,
  `q`.`bill_to_addr`         AS `bill_to_addr`,
  `q`.`doc_currency`         AS `doc_currency`,
  `q`.`payment_term`         AS `payment_term`,
  `q`.`payment_term_date`    AS `payment_term_date`,
  `q`.`agreement_start_date` AS `agreement_start_date`,
  `q`.`aggrement_end_date`   AS `aggrement_end_date`,
  `q`.`created_by`           AS `created_by`,
  `q`.`creation_date`        AS `creation_date`,
  `q`.`last_update_by`       AS `last_update_by`,
  `q`.`last_update_date`     AS `last_update_date`,
  `q`.`bu_org_id`            AS `bu_org_id`,
  `q`.`header_amount`        AS `header_amount`,
  `q`.`sd_quote_header_id`   AS `sd_quote_header_id`,
  `q`.`sd_lead_id`           AS `sd_lead_id`,
  `q`.`sd_opportunity_id`    AS `sd_opportunity_id`,
  `q`.`status`               AS `status`,
  `q`.`approval_status`      AS `approval_status`,
  `q`.`ar_customer_id`       AS `ar_customer_id`,
  `q`.`ar_customer_site_id`  AS `ar_customer_site_id`,
  `o`.`option_line_value`    AS `line_type`,
  `s`.`tax_amount`           AS `tax_amount`,
  `s`.`requested_date`       AS `requested_date`,
  `s`.`promise_date`         AS `promise_date`,
  `o0`.`option_line_value`   AS `destination_typev`,
  `s`.`line_description`     AS `line_description`,
  `s`.`shipping_org_id`      AS `shipping_org_id`,
  `s`.`item_id_m`            AS `item_id_m`,
  `s`.`tax_code_id`          AS `tax_code_id`,
  `s`.`uom_id`               AS `uom_id`,
  `s`.`sd_quote_line_id`     AS `sd_quote_line_id`
FROM (((((((`sd_quote_line` `s`
         LEFT JOIN `uom` `u`
           ON ((`s`.`uom_id` = `u`.`uom_id`)))
        LEFT JOIN `sd_quote_header_v` `q`
          ON ((`s`.`sd_quote_header_id` = `q`.`sd_quote_header_id`)))
       LEFT JOIN `option_line` `o`
         ON ((`s`.`line_type` = `o`.`option_line_id`)))
      LEFT JOIN `item` `i`
        ON ((`s`.`item_id_m` = `i`.`item_id_m`)))
     LEFT JOIN `mdm_tax_code` `m`
       ON ((`s`.`tax_code_id` = `m`.`mdm_tax_code_id`)))
    LEFT JOIN `option_line` `o0`
      ON ((`s`.`destination_type` = `o0`.`option_line_id`)))
   LEFT JOIN `option_line` `o1`
     ON ((`q`.`status` = `o1`.`option_line_id`)))
WHERE (`i`.`item_status` <> 278))$$

DELIMITER ;

DELIMITER $$

USE `xbs`$$

DROP VIEW IF EXISTS `po_line_v`$$

CREATE ALGORITHM=UNDEFINED DEFINER=`i3u`@`localhost` SQL SECURITY DEFINER VIEW `po_line_v` AS (
SELECT
  `po`.`po_number`          AS `po_number`,
  `pl`.`line_number`        AS `line_number`,
  `lt`.`option_line_value`  AS `line_typev`,
  `i`.`item_number`         AS `item_number`,
  `i`.`item_name`           AS `item_name`,
  `i`.`item_specification`  AS `item_specification`,
  `i`.`item_description`    AS `item_description`,
  `pl`.`need_by_date`       AS `need_by_date`,
  `pl`.`promise_date`       AS `promise_date`,
  `pl`.`unit_price`         AS `unit_price`,
  `pl`.`line_quantity`      AS `line_quantity`,
  `pl`.`accepted_quantity`  AS `accepted_quantity`,
  `u`.`uom_name`            AS `uom`,
  `pl`.`line_price`         AS `line_price`,
  `ls`.`option_line_value`  AS `lSTATUS`,
  `m`.`tax_code`            AS `tax_code`,
  `pl`.`tax_amount`         AS `tax_amount`,
  `pl`.`line_description`   AS `line_description`,
  `pl`.`quantity`           AS `quantity`,
  `a`.`address`             AS `ship_to_location_id`,
  `s`.`subinventory`        AS `subinventory_id`,
  `l`.`locator`             AS `locator_id`,
  `imt`.`option_line_value` AS `invoice_match_type`,
  `pl`.`shipment_number`    AS `shipment_number`,
  `pl`.`requestor`          AS `requestor`,
  `pl`.`price_date`         AS `price_date`,
  `pl`.`received_quantity`  AS `received_quantity`,
  `pl`.`delivered_quantity` AS `delivered_quantity`,
  `pl`.`invoiced_quantity`  AS `invoiced_quantity`,
  `pl`.`paid_quantity`      AS `paid_quantity`,
  `ds`.`option_line_value`  AS `dSTATUS`,
  `i`.`org_id`              AS `org_id`,
  `pl`.`item_id_m`          AS `item_id_m`,
  `pl`.`po_header_id`       AS `po_header_id`,
  `pl`.`po_line_id`         AS `po_line_id`,
  `po`.`supplier_id`        AS `supplier_id`,
  `pl`.`line_type`          AS `line_type`,
  `pl`.`created_by`         AS `created_by`,
  `pl`.`creation_date`      AS `creation_date`,
  `pl`.`last_update_by`     AS `last_update_by`,
  `pl`.`last_update_date`   AS `last_update_date`,
  `pl`.`status`             AS `status`
FROM (((((((((((`po_line` `pl`
             JOIN `po_header` `po`
               ON ((`pl`.`po_header_id` = `po`.`po_header_id`)))
            LEFT JOIN `option_line` `lt`
              ON ((`pl`.`line_type` = `lt`.`option_line_id`)))
           LEFT JOIN `item` `i`
             ON (((`pl`.`item_id_m` = `i`.`item_id_m`)
                  AND (`pl`.`receving_org_id` = `i`.`org_id`))))
          LEFT JOIN `mdm_tax_code` `m`
            ON ((`pl`.`tax_code_id` = `m`.`mdm_tax_code_id`)))
         LEFT JOIN `option_line` `ls`
           ON ((`pl`.`status` = `ls`.`option_line_id`)))
        LEFT JOIN `uom` `u`
          ON ((`pl`.`uom_id` = `u`.`uom_id`)))
       LEFT JOIN `address` `a`
         ON ((`pl`.`ship_to_location_id` = `a`.`address_id`)))
      LEFT JOIN `subinventory` `s`
        ON ((`pl`.`subinventory_id` = `s`.`subinventory_id`)))
     LEFT JOIN `locator` `l`
       ON ((`pl`.`locator_id` = `l`.`locator_id`)))
    LEFT JOIN `option_line` `imt`
      ON ((`pl`.`invoice_match_type` = `imt`.`option_line_id`)))
   LEFT JOIN `option_line` `ds`
     ON ((`pl`.`status` = `ds`.`option_line_id`))))$$

DELIMITER ;

DELIMITER $$

USE `xbs`$$

DROP VIEW IF EXISTS `po_requisition_line_v`$$

CREATE ALGORITHM=UNDEFINED DEFINER=`i3u`@`localhost` SQL SECURITY DEFINER VIEW `po_requisition_line_v` AS (
SELECT
  `ph`.`po_requisition_number`    AS `po_requisition_number`,
  `po`.`po_number`                AS `po_number`,
  `prs`.`option_line_value`       AS `requisition_statusv`,
  `ps`.`option_line_value`        AS `po_statusv`,
  `o`.`option_line_value`         AS `line_type`,
  `o0`.`org`                      AS `receving_org`,
  `p`.`line_number`               AS `line_number`,
  `i`.`item_number`               AS `item_number`,
  `i`.`item_name`                 AS `item_name`,
  `i`.`item_specification`        AS `item_specification`,
  `i`.`item_description`          AS `item_description`,
  `p`.`price_date`                AS `price_date`,
  `p`.`line_quantity`             AS `line_quantity`,
  `u`.`uom_name`                  AS `uom_name`,
  `p`.`line_price`                AS `line_price`,
  `p`.`line_description`          AS `line_description`,
  `o1`.`option_line_value`        AS `STATUS`,
  `p`.`need_by_date`              AS `need_by_date`,
  `p`.`item_id_m`                 AS `item_id_m`,
  `p`.`uom_id`                    AS `uom_id`,
  `p`.`receving_org_id`           AS `receving_org_id`,
  `ph`.`bu_org_id`                AS `bu_org_id`,
  `ph`.`requisition_status`       AS `requisition_status`,
  `p`.`po_requisition_line_id`    AS `po_requisition_line_id`,
  `ph`.`po_requisition_header_id` AS `po_requisition_header_id`,
  `p`.`reference_key_name`        AS `reference_key_name`,
  `p`.`reference_header_id`       AS `reference_header_id`,
  `p`.`reference_line_id`         AS `reference_line_id`,
  `p`.`created_by`                AS `created_by`,
  `p`.`creation_date`             AS `creation_date`,
  `p`.`last_update_by`            AS `last_update_by`,
  `p`.`last_update_date`          AS `last_update_date`
FROM ((((((((((`po_requisition_line` `p`
            LEFT JOIN `uom` `u`
              ON ((`p`.`uom_id` = `u`.`uom_id`)))
           JOIN `po_requisition_header` `ph`
             ON ((`p`.`po_requisition_header_id` = `ph`.`po_requisition_header_id`)))
          LEFT JOIN `option_line` `o`
            ON ((`p`.`line_type` = `o`.`option_line_id`)))
         LEFT JOIN `org` `o0`
           ON ((`p`.`receving_org_id` = `o0`.`org_id`)))
        LEFT JOIN `item` `i`
          ON (((`p`.`item_id_m` = `i`.`item_id_m`)
               AND (`p`.`receving_org_id` = `i`.`org_id`))))
       LEFT JOIN `option_line` `o1`
         ON ((`p`.`status` = `o1`.`option_line_id`)))
      LEFT JOIN `option_line` `prs`
        ON ((`ph`.`requisition_status` = `prs`.`option_line_id`)))
     LEFT JOIN `po_line` `pl`
       ON ((`p`.`po_requisition_line_id` = `pl`.`po_req_line_id`)))
    LEFT JOIN `po_header` `po`
      ON (((`pl`.`po_header_id` = `po`.`po_header_id`)
           AND (`po`.`po_status` <> 322))))
   LEFT JOIN `option_line` `ps`
     ON ((`po`.`po_status` = `ps`.`option_line_id`))))$$

DELIMITER ;

DELIMITER $$

USE `xbs`$$

DROP VIEW IF EXISTS `po_quote_supplier_v`$$

CREATE ALGORITHM=UNDEFINED DEFINER=`i3u`@`localhost` SQL SECURITY DEFINER VIEW `po_quote_supplier_v` AS (
SELECT
  `s`.`supplier_name`    AS `supplier_name`,
  `s`.`supplier_id`      AS `supplier_id`,
  `l`.`item_id_m`        AS `item_id_m`,
  `l`.`quote_unit_price` AS `quote_unit_price`,
  `q`.`bu_org_id`        AS `bu_org_id`
FROM ((`po_quote_header` `q`
    JOIN `po_quote_line` `l`
      ON ((`q`.`po_quote_header_id` = `l`.`po_quote_header_id`)))
   JOIN `supplier` `s`
     ON ((`s`.`supplier_id` = `q`.`supplier_id`)))
WHERE (`q`.`rev`
       AND (`q`.`quote_status` = 1489)))$$

DELIMITER ;

DELIMITER $$

USE `xbs`$$

DROP PROCEDURE IF EXISTS `convertPOfromPRQ`$$

CREATE DEFINER=`i3u`@`localhost` PROCEDURE `convertPOfromPRQ`(reqid BIGINT,userid BIGINT,orgid BIGINT)
BEGIN
DECLARE reqLid BIGINT;
#DECLARE reqQty DECIMAL(20,5);
DECLARE done INT;
DECLARE poreqs CURSOR FOR SELECT po_requisition_line_id FROM po_requisition_line pl JOIN po_requisition_header ph ON pl.po_requisition_header_id=ph.po_requisition_header_id WHERE pl.po_requisition_header_id=reqid AND requisition_status=326 AND bu_org_id=orgid AND line_quantity;
DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = 1;
    OPEN poreqs;
    BEGIN_reqs: LOOP
        FETCH poreqs INTO reqLid;
        IF done THEN
            LEAVE BEGIN_reqs;
        END IF;
#        IF(reqQty>0) THEN
        CALL convertPOfromPRQLine(reqid,reqLid,userid,orgid);
#        END IF;
    END LOOP BEGIN_reqs;
    CLOSE poreqs;
    END$$

DELIMITER ;

DELIMITER $$

USE `xbs`$$

DROP PROCEDURE IF EXISTS `convertPOfromPRQLine`$$

CREATE DEFINER=`i3u`@`localhost` PROCEDURE `convertPOfromPRQLine`(rqHid BIGINT,rqLid BIGINT,userid BIGINT,orgid BIGINT)
BEGIN
SET @poid=NULL;
SET @spid=NULL;
SET @sptid=NULL;
SET @itmid=NULL;
IF NOT EXISTS(SELECT po_line_id FROM po_line WHERE po_req_line_id=rqLid) THEN
SELECT item_id_m INTO @itmid FROM po_requisition_line WHERE po_requisition_line_id=rqLid;
SELECT supplier_id INTO @spid FROM xbs.po_quote_supplier_v WHERE item_id_m=@itmid AND bu_org_id=orgid ORDER BY quote_unit_price LIMIT 0,1;
IF @spid IS NOT NULL THEN
SELECT po_header_id INTO @poid FROM supplier_quote_po_v WHERE (item_id_m,supplier_id,bu_org_id,created_by)=(@itmid,@spid,orgid,userid);
IF @poid IS NULL THEN
SET @currency=NULL;
SET @payment=NULL;
SELECT currency_id,payment_term_id,supplier_site_id INTO @currency,@payment,@sptid FROM supplier_all_v WHERE supplier_id=@spid;
INSERT INTO po_header (bu_org_id, po_type,supplier_id, supplier_site_id, ship_to_id, bill_to_id, currency, payment_term_id, exchange_rate_type, exchange_rate, po_status, created_by, creation_date, last_update_by, last_update_date) SELECT bu_org_id, 319, @spid, @sptid, ship_to_id, bill_to_id, @currency,@payment, exchange_rate_type, exchange_rate, 321, userid, NOW(), userid, NOW() FROM po_requisition_header WHERE po_requisition_header_id=rqHid;
SELECT LAST_INSERT_ID() INTO @poid;
END IF;
END IF;
IF @poid IS NOT NULL THEN
SET @taxcodeid=NULL;
SET @unitprice=NULL;
SET @taxpercent=NULL;
SELECT valid_date,unit_price,tax_code_id INTO @price_date,@unitprice,@taxcodeid FROM po_quote_v WHERE (rev AND quote_status=1489) AND supplier_id=@spid AND item_id_m=@itmid;
IF @taxcodeid IS NOT NULL THEN
SELECT percentage INTO @taxpercent FROM mdm_tax_code WHERE mdm_tax_code_id=@taxcodeid;
END IF;
INSERT INTO po_line (po_header_id,po_req_line_id, line_number, receving_org_id, item_id_m, item_description, line_quantity, price_list_header_id, price_date, unit_price, line_price,tax_code_id,tax_amount, reference_doc_type, reference_doc_number, line_type, line_description, uom_id, STATUS, shipment_number, subinventory_id, locator_id, requestor, ship_to_location_id, quantity, need_by_date, promise_date, charge_ac_id, accrual_ac_id, budget_ac_id, ppv_ac_id, received_quantity, accepted_quantity, delivered_quantity, invoiced_quantity, paid_quantity, reference_key_name, reference_header_id, reference_line_id, created_by, creation_date, last_update_by, last_update_date, rev_enabled_cb, rev_number)
SELECT 	@poid,po_requisition_line_id, line_number, receving_org_id, item_id_m, item_description, line_quantity, NULL, @price_date, @unitprice, @unitprice*line_quantity,@taxcodeid,IF(@taxpercent IS NULL,0,@taxpercent*@unitprice*line_quantity/100), reference_doc_type, reference_doc_number, line_type, line_description, uom_id, 1497, shipment_number, subinventory_id, locator_id, created_by, ship_to_location_id, quantity, need_by_date, promise_date, charge_ac_id, accrual_ac_id, budget_ac_id, ppv_ac_id, received_quantity, accepted_quantity, delivered_quantity, invoiced_quantity, paid_quantity, reference_key_name, reference_header_id, reference_line_id, userid, NOW(), userid, NOW(), rev_enabled_cb, rev_number FROM po_requisition_line WHERE po_requisition_line_id=rqLid;
END IF;
END IF;
    END$$

DELIMITER ;

DELIMITER $$

USE `xbs`$$

DROP TRIGGER /*!50032 IF EXISTS */ `sys_process_flow_line_insertB`$$

CREATE
    /*!50017 DEFINER = 'i3u'@'localhost' */
    TRIGGER `sys_process_flow_line_insertB` BEFORE INSERT ON `sys_process_flow_line` 
    FOR EACH ROW BEGIN
SET @linenum=NULL;
SELECT MAX(line_number) INTO @linenum FROM sys_process_flow_line sl JOIN sys_process_flow_header sh ON sl.sys_process_flow_header_id=sh.sys_process_flow_header_id WHERE sl.sys_process_flow_header_id=NEW.sys_process_flow_header_id;
IF @linenum IS NULL THEN
SET new.line_number=1;
ELSE
SET new.line_number=@linenum+1;
END IF;
    END;
$$

DELIMITER ;

DELIMITER $$

USE `xbs`$$

DROP VIEW IF EXISTS `po_quote_header_v`$$

CREATE ALGORITHM=UNDEFINED DEFINER=`i3u`@`localhost` SQL SECURITY DEFINER VIEW `po_quote_header_v` AS (
SELECT
  `p`.`quote_number`         AS `quote_number`,
  `p0`.`rfq_name`            AS `rfq_name`,
  `s`.`supplier_name`        AS `supplier_name`,
  `s0`.`supplier_site_name`  AS `supplier_site_name`,
  `o`.`option_line_value`    AS `quote_typev`,
  `o1`.`option_line_value`   AS `quote_statusv`,
  `qas`.`option_line_value`  AS `approval_statusv`,
  `a`.`address`              AS `ship_to_addr`,
  `a0`.`address`             AS `bill_to_addr`,
  `c0`.`title`               AS `currency`,
  `p1`.`payment_term`        AS `payment_term`,
  `p`.`effective_start_date` AS `effective_start_date`,
  `p`.`effective_end_date`   AS `effective_end_date`,
  `p`.`valid_date`           AS `valid_date`,
  `p`.`rev`                  AS `rev`,
  `p`.`description`          AS `description`,
  `x`.`username`             AS `creator`,
  `x0`.`username`            AS `updator`,
  `p`.`supplier_quote`       AS `supplier_quote`,
  `p`.`created_by`           AS `created_by`,
  `p`.`creation_date`        AS `creation_date`,
  `p`.`last_update_by`       AS `last_update_by`,
  `p`.`last_update_date`     AS `last_update_date`,
  `p`.`po_quote_header_id`   AS `po_quote_header_id`,
  `p`.`bu_org_id`            AS `bu_org_id`,
  `p`.`supplier_id`          AS `supplier_id`,
  `p`.`supplier_site_id`     AS `supplier_site_id`,
  `p`.`po_rfq_header_id`     AS `po_rfq_header_id`,
  `p`.`ship_to_id`           AS `ship_to_id`,
  `p`.`bill_to_id`           AS `bill_to_id`,
  `p`.`payment_term_id`      AS `payment_term_id`,
  `p`.`currency`             AS `currency_id`,
  `p`.`quote_status`         AS `quote_status`,
  `p`.`approval_status`      AS `approval_status`
FROM ((((((((((((`po_quote_header` `p`
              LEFT JOIN `option_line` `qas`
                ON ((`p`.`approval_status` = `qas`.`option_line_id`)))
             LEFT JOIN `po_rfq_header` `p0`
               ON ((`p`.`po_rfq_header_id` = `p0`.`po_rfq_header_id`)))
            LEFT JOIN `supplier` `s`
              ON ((`p`.`supplier_id` = `s`.`supplier_id`)))
           LEFT JOIN `supplier_site` `s0`
             ON ((`p`.`supplier_site_id` = `s0`.`supplier_site_id`)))
          LEFT JOIN `option_line` `o`
            ON ((`p`.`quote_type` = `o`.`option_line_id`)))
         LEFT JOIN `address` `a`
           ON ((`p`.`ship_to_id` = `a`.`address_id`)))
        LEFT JOIN `address` `a0`
          ON ((`p`.`bill_to_id` = `a0`.`address_id`)))
       LEFT JOIN `currency` `c0`
         ON ((`p`.`currency` = `c0`.`currency_id`)))
      LEFT JOIN `payment_term` `p1`
        ON ((`p`.`payment_term_id` = `p1`.`payment_term_id`)))
     LEFT JOIN `option_line` `o1`
       ON ((`p`.`quote_status` = `o1`.`option_line_id`)))
    LEFT JOIN `xerp_user` `X`
      ON ((`p`.`created_by` = `x`.`xerp_user_id`)))
   LEFT JOIN `xerp_user` `x0`
     ON ((`p`.`last_update_by` = `x0`.`xerp_user_id`)))
ORDER BY `p`.`po_quote_header_id`)$$

DELIMITER ;

DELIMITER $$

USE `xbs`$$

DROP TRIGGER /*!50032 IF EXISTS */ `poLineUpdate`$$

CREATE
    /*!50017 DEFINER = 'i3u'@'localhost' */
    TRIGGER `poLineUpdate` BEFORE UPDATE ON `po_line` 
    FOR EACH ROW BEGIN
    IF old.po_req_line_id>0 THEN
    IF new.status!=old.status THEN
    UPDATE po_requisition_line SET STATUS=new.status WHERE po_requisition_line_id=old.po_req_line_id;
    END IF;
    IF new.promise_date!=old.promise_date THEN
    UPDATE po_requisition_line SET promise_date=new.promise_date WHERE po_requisition_line_id=old.po_req_line_id;
    END IF;
    END IF;
    IF new.accepted_quantity>=old.line_quantity THEN 
    SET new.status=1500;
    SELECT COUNT(po_line_id) INTO @cnt FROM po_line WHERE po_header_id=old.po_header_id AND (STATUS!=1500 AND po_line_id!=old.po_line_id);
    IF @cnt=0 THEN
UPDATE po_header SET po_status=323 WHERE po_header_id=old.po_header_id;
    END IF;
    END IF;
    IF new.line_price IS NOT NULL AND old.line_price!=new.line_price THEN
UPDATE po_header SET header_amount=header_amount+NEW.line_price-OLD.line_price,tax_amount=tax_amount+new.tax_amount-old.tax_amount WHERE po_header_id=old.po_header_id;
END IF;
    END;
$$

DELIMITER ;

DELIMITER $$

USE `xbs`$$

DROP VIEW IF EXISTS `po_requisition_header_v`$$

CREATE ALGORITHM=UNDEFINED DEFINER=`i3u`@`localhost` SQL SECURITY DEFINER VIEW `po_requisition_header_v` AS (
SELECT
  `o`.`option_line_value`        AS `po_requisition_type`,
  `p`.`po_requisition_number`    AS `po_requisition_number`,
  `ps`.`po_status`               AS `po_status`,
  `o0`.`option_line_value`       AS `requisition_statusv`,
  `s`.`supplier_name`            AS `supplier_name`,
  `s0`.`supplier_site_name`      AS `supplier_site_name`,
  `p`.`buyer`                    AS `buyer`,
  `p`.`description`              AS `description`,
  `p`.`ship_to_id`               AS `ship_to_id`,
  `p`.`bill_to_id`               AS `bill_to_id`,
  `p`.`header_amount`            AS `header_amount`,
  `c`.`title`                    AS `currency`,
  `p0`.`description`             AS `payment_term`,
  `x`.`username`                 AS `creator`,
  `x0`.`username`                AS `updator`,
  `p`.`exchange_rate_type`       AS `exchange_rate_type`,
  `p`.`exchange_rate`            AS `exchange_rate`,
  `p`.`supply_org_id`            AS `supply_org_id`,
  `p`.`requisition_status`       AS `requisition_status`,
  `p`.`supplier_id`              AS `supplier_id`,
  `p`.`supplier_site_id`         AS `supplier_site_id`,
  `p`.`payment_term_id`          AS `payment_term_id`,
  `p`.`created_by`               AS `created_by`,
  `p`.`creation_date`            AS `creation_date`,
  `p`.`last_update_by`           AS `last_update_by`,
  `p`.`last_update_date`         AS `last_update_date`,
  `p`.`po_requisition_header_id` AS `po_requisition_header_id`,
  `po`.`po_header_id`            AS `po_header_id`,
  `p`.`bu_org_id`                AS `bu_org_id`
FROM ((((((((((`po_requisition_header` `p`
            LEFT JOIN `option_line` `o`
              ON ((`p`.`po_requisition_type` = `o`.`option_line_id`)))
           LEFT JOIN `supplier` `s`
             ON ((`p`.`supplier_id` = `s`.`supplier_id`)))
          LEFT JOIN `supplier_site` `s0`
            ON ((`p`.`supplier_site_id` = `s0`.`supplier_site_id`)))
         LEFT JOIN `currency` `c`
           ON ((`p`.`currency` = `c`.`currency_id`)))
        LEFT JOIN `payment_term` `p0`
          ON ((`p`.`payment_term_id` = `p0`.`payment_term_id`)))
       LEFT JOIN `option_line` `o0`
         ON ((`p`.`requisition_status` = `o0`.`option_line_id`)))
      LEFT JOIN `xerp_user` `X`
        ON ((`p`.`created_by` = `x`.`xerp_user_id`)))
     LEFT JOIN `xerp_user` `x0`
       ON ((`p`.`last_update_by` = `x0`.`xerp_user_id`)))
    LEFT JOIN `po_header` `po`
      ON ((`p`.`po_requisition_header_id` = `po`.`po_req_header_id`)))
   LEFT JOIN `poreq_po_status` `ps`
     ON ((`p`.`po_requisition_header_id` = `ps`.`po_requisition_header_id`)))
ORDER BY `p`.`po_requisition_header_id`)$$

DELIMITER ;

DELIMITER $$

USE `xbs`$$

DROP VIEW IF EXISTS `po_header_v`$$

CREATE ALGORITHM=UNDEFINED DEFINER=`i3u`@`localhost` SQL SECURITY DEFINER VIEW `po_header_v` AS (
SELECT
  `p`.`po_number`            AS `po_number`,
  `o`.`option_line_value`    AS `po_typevalue`,
  `p`.`description`          AS `description`,
  `s`.`supplier_name`        AS `supplier_name`,
  `s0`.`supplier_site_name`  AS `supplier_site_name`,
  `st`.`option_line_value`   AS `po_status_value`,
  `p0`.`payment_term`        AS `payment_term`,
  `a`.`address`              AS `ship_to_id`,
  `a0`.`address`             AS `bill_to_id`,
  `p`.`header_amount`        AS `header_amount`,
  `p`.`tax_amount`           AS `tax_amount`,
  `c0`.`title`               AS `currency`,
  `c1`.`title`               AS `doc_currency`,
  `p`.`agreement_start_date` AS `agreement_start_date`,
  `p`.`agreement_end_date`   AS `agreement_end_date`,
  `p`.`rev_number`           AS `rev_number`,
  `cbu`.`name`             AS `creator name`,
  `ubu`.`name`            AS `updator name`,
  `x`.`username`             AS `creator`,
  `x0`.`username`            AS `updator`,
  `p`.`created_by`           AS `created_by`,
  `p`.`creation_date`        AS `creation_date`,
  `p`.`last_update_by`       AS `last_update_by`,
  `p`.`last_update_date`     AS `last_update_date`,
  `p`.`po_header_id`         AS `po_header_id`,
  `p`.`po_type`              AS `po_type`,
  `p`.`po_status`            AS `po_status`,
  `p`.`bu_org_id`            AS `bu_org_id`,
  `s`.`supplier_id`          AS `supplier_id`,
  `p`.`supplier_site_id`     AS `supplier_site_id`
FROM (((((((((((`po_header` `p`
LEFT JOIN user_v cbu ON p.created_by=cbu.xerp_user_id
LEFT JOIN user_v ubu ON p.last_update_by=ubu.xerp_user_id
             LEFT JOIN `option_line` `o`
               ON ((`p`.`po_type` = `o`.`option_line_id`)))
            LEFT JOIN `supplier` `s`
              ON ((`p`.`supplier_id` = `s`.`supplier_id`)))
           LEFT JOIN `supplier_site` `s0`
             ON ((`p`.`supplier_site_id` = `s0`.`supplier_site_id`)))
          LEFT JOIN `payment_term` `p0`
            ON ((`p`.`payment_term_id` = `p0`.`payment_term_id`)))
         LEFT JOIN `address` `a`
           ON ((`p`.`ship_to_id` = `a`.`address_id`)))
        LEFT JOIN `address` `a0`
          ON ((`p`.`bill_to_id` = `a0`.`address_id`)))
       LEFT JOIN `option_line` `st`
         ON ((`p`.`po_status` = `st`.`option_line_id`)))
      LEFT JOIN `xerp_user` `x`
        ON ((`p`.`created_by` = `x`.`xerp_user_id`)))
     LEFT JOIN `xerp_user` `x0`
       ON ((`p`.`last_update_by` = `x0`.`xerp_user_id`)))
    LEFT JOIN `currency` `c0`
      ON ((`p`.`currency` = `c0`.`currency_id`)))
   LEFT JOIN `currency` `c1`
     ON ((`p`.`doc_currency` = `c1`.`currency_id`))))$$

DELIMITER ;

DELIMITER $$

USE `xbs`$$

DROP PROCEDURE IF EXISTS `wipmovetrans`$$

CREATE DEFINER=`i3u`@`localhost` PROCEDURE `wipmovetrans`(woid BIGINT,wmtid BIGINT,fromseq INT, fromseqnum INT,fromstep INT, toseq INT, toseqnum INT,tostep INT, quantity INT,remark VARCHAR(255),userid INT,orgid INT)
BEGIN
SET @fromrtid=NULL;
SET @tortid=NULL;
SET @fromrtqq=NULL;
SET @fromrtqr=NULL;
SET @fromrtqrj=NULL;
SET @fromrtqs=NULL;
SET @fromrtqm=NULL;
SET @tortid=NULL;
SET @tortqq=NULL;
SET @tortqr=NULL;
SET @tortqrj=NULL;
SET @tortqs=NULL;
SET @tortqm=NULL;
SELECT wip_wo_routing_line_id,queue_quantity,running_quantity,rejected_quantity,scrapped_quantity,tomove_quantity INTO @fromrtid,
@fromrtqq,@fromrtqr,@fromrtqrj,@fromrtqs,@fromrtqm FROM wip_wo_routing_line WHERE wip_wo_header_id=woid AND routing_sequence=fromseq AND routing_seq_num=fromseqnum;
IF(fromseq=toseq) THEN
BEGIN
IF(fromstep != tostep) THEN
SET @tortid=@fromrtid;
SET @tortqq=@fromrtqq;
SET @tortqr=@fromrtqr;
SET @tortqrj=@fromrtqrj;
SET @tortqs=@fromrtqs;
SET @tortqm=@fromrtqm;
END IF;
END;
ELSE
BEGIN
IF toseq!=0 THEN
SELECT wip_wo_routing_line_id,queue_quantity,running_quantity,rejected_quantity,scrapped_quantity,tomove_quantity INTO @tortid,
@tortqq,@tortqr,@tortqrj,@tortqs,@tortqm FROM wip_wo_routing_line WHERE wip_wo_header_id=woid AND routing_sequence=toseq AND routing_seq_num=toseqnum;
END IF;
END;
END IF;
IF(fromstep=380 AND tostep=382) THEN
BEGIN
SET @fromrtqr=@fromrtqr-quantity;
SET @tortqq=@tortqq+quantity;
IF fromseq!=0 THEN
UPDATE wip_wo_routing_line SET running_quantity=running_quantity-quantity,completed_quantity=completed_quantity+quantity WHERE wip_wo_routing_line_id=@fromrtid;
END IF;
SET @osp_cb=NULL;
SELECT COUNT(wip_wo_routing_detail_id) INTO @osp_cb FROM wip_wo_routing_detail WHERE wip_wo_routing_line_id=@fromrtid AND charge_type IN (344,346);
IF toseqnum=fromseqnum THEN
IF toseq!=0 THEN
UPDATE wip_wo_routing_line SET queue_quantity=queue_quantity+quantity WHERE wip_wo_routing_line_id=@tortid;
ELSEIF @osp_cb>0 THEN
UPDATE wip_wo_header SET completed_quantity=completed_quantity+quantity WHERE wip_wo_header_id=woid;
ELSE
SET @liid = NULL;
SET @itemid = NULL;
SET @price = NULL;
SET @uomid = NULL;
SET @amount = NULL;
SET @itemdesc = NULL;
SET @rev = NULL;
SET @subInv = NULL;
SET @locator = NULL;
SET @lotid = NULL;
SET @lotcnts=0;
INSERT INTO inv_receipt_header (receipt_number,transaction_type_id,receipt_date,carrier,vechile_number,COMMENT,reference_key_name,reference_key_value,created_by,creation_date,last_update_by,last_update_date,org_id) VALUES('','11',NOW(),'','',remark,'wip_wo_header',woid,userid,NOW(),userid,NOW(),orgid);
SELECT LAST_INSERT_ID() INTO @liid;
SELECT w.item_id_m,i.list_price,i.uom_id,i.list_price*quantity,i.item_description,i.item_rev_number INTO @itemid,@price,@uomid,@amount,@itemdesc,@rev FROM wip_wo_header w JOIN item i ON w.item_id_m=i.item_id_m WHERE wip_wo_header_id=woid;
SELECT completion_sub_inventory,completion_locator INTO @subInv,@locator FROM wip_wo_header WHERE wip_wo_header_id=woid;
#UPDATE inv_receipt_header SET receipt_number=CONCAT('RN_',orgid,'_',@liid) WHERE inv_receipt_header_id=@liid;
SELECT COUNT(inv_lot_number_id) INTO @lotcnts FROM inv_lot_number WHERE reference_key_name='wip_wo_header' AND reference_key_value=woid AND item_id_m=@itemid AND org_id=orgid;
INSERT INTO inv_lot_number (lot_number,quantity,item_id_m,generation,org_id,reference_key_name,reference_key_value,origination_type,origination_date,item_revision,created_by,creation_date,last_update_by,last_update_date) 
VALUE(CONCAT(CURDATE()+0,woid,@lotcnts+1),quantity,@itemid,'PRE_DEFINED',orgid,'wip_wo_header',woid,'WIP_COMPLETION',CURDATE(),@rev,userid,NOW(),userid,NOW());
SELECT LAST_INSERT_ID() INTO @lotid;
SET @currencyid=NULL;
SELECT currency_code INTO @currencyid FROM org_ledger_v WHERE org_id=orgid;
INSERT INTO inv_receipt_line (inv_receipt_header_id,transaction_quantity,item_id_m,revision_name,item_description,uom_id,unit_price,amount,subinventory_id,locator_id,currency,doc_currency,reference_key_name,transaction_type_id,reference_key_value,lot_number,STATUS,created_by,creation_date,last_update_by,last_update_date,org_id) VALUES(@liid,quantity,@itemid,@rev,@itemdesc,@uomid,@price,@amount,@subInv,@locator,@currencyid,@currencyid,'wip_move_transaction','11',wmtid,@lotid,1519,userid,NOW(),userid,NOW(),orgid);
UPDATE inv_receipt_header SET STATUS=1520 WHERE inv_receipt_header_id=@liid AND STATUS=1519;
UPDATE inv_receipt_line SET STATUS=1520 WHERE inv_receipt_header_id=@liid AND STATUS=1519;
#UPDATE wip_wo_header SET completed_quantity=completed_quantity+quantity WHERE wip_wo_header_id=woid;
END IF;
END IF;
END;
ELSE IF(fromstep=382 AND tostep=379) THEN
BEGIN
SET @fromq=@fromrtqq-quantity;
SET @toq=@tortqrj+quantity;
IF toseqnum=fromseqnum THEN
UPDATE wip_wo_routing_line SET queue_quantity=queue_quantity-quantity WHERE wip_wo_routing_line_id=@fromrtid;
END IF;
UPDATE wip_wo_routing_line SET running_quantity=running_quantity+quantity,completed_quantity=completed_quantity-quantity WHERE wip_wo_routing_line_id=@tortid;
END;
ELSE IF(fromstep=382 AND tostep=378) THEN
BEGIN
SET @fromq=@fromrtqq-quantity;
SET @toq=@tortqr+quantity;
UPDATE wip_wo_routing_line SET queue_quantity=@fromq WHERE wip_wo_routing_line_id=@fromrtid;
UPDATE wip_wo_routing_line SET running_quantity=@toq WHERE wip_wo_routing_line_id=@tortid;
END;
ELSE IF(fromstep=378 AND tostep=380) THEN
BEGIN
SET @lastseq=NULL;
SET @fromq=@fromrtqr-quantity;
SET @toq=@tortqm+quantity;
UPDATE wip_wo_routing_line SET running_quantity=@fromq WHERE wip_wo_routing_line_id=@fromrtid;
UPDATE wip_wo_routing_line SET tomove_quantity=@toq WHERE wip_wo_routing_line_id=@tortid;
END;
ELSE IF(fromstep=382 AND tostep=380) THEN
BEGIN
SET @lastseq=NULL;
SET @fromq=@fromrtqq-quantity;
SET @toq=@tortqm+quantity;
IF @fromrtid IS NOT NULL THEN
UPDATE wip_wo_routing_line SET queue_quantity=queue_quantity-quantity WHERE wip_wo_routing_line_id=@fromrtid;
END IF;
UPDATE wip_wo_routing_line SET running_quantity=running_quantity+quantity,completed_quantity=completed_quantity-quantity WHERE wip_wo_routing_line_id=@tortid;
END;
ELSE IF(fromstep=378 AND tostep=381) THEN
BEGIN
SET @fromq=@fromrtqr-quantity;
SET @toq=@tortqs+quantity;
UPDATE wip_wo_routing_line SET running_quantity=@fromq WHERE wip_wo_routing_line_id=@fromrtid;
UPDATE wip_wo_routing_line SET scrapped_quantity=@toq WHERE wip_wo_routing_line_id=@tortid;
UPDATE wip_wo_header SET scrapped_quantity=scrapped_quantity+quantity WHERE wip_wo_header_id=woid;
END;
END IF;
END IF;
END IF;
END IF;
END IF;
END IF;
    END$$

DELIMITER ;

DELIMITER $$

USE `xbs`$$

DROP FUNCTION IF EXISTS `wipMoveTransInsert`$$

CREATE DEFINER=`i3u`@`localhost` FUNCTION `wipMoveTransInsert`(woid BIGINT,itemIdM BIGINT,quantity INT,frs INT,frsn INT,fos INT,trs INT,trsn INT,tos INT,reason VARCHAR(255),transtype VARCHAR(50),createby INT,updateby INT,orgid INT) RETURNS BIGINT(20)
BEGIN
SET @liid=NULL;
INSERT INTO wip_move_transaction (wip_wo_header_id,item_id_m,move_quantity,from_routing_sequence,from_routing_seq_num,from_operation_step,to_routing_sequence,to_routing_seq_num,to_operation_step,reason,transaction_type,transaction_date,created_by,creation_date,last_update_by,last_update_date,org_id) 
VALUES(woid,itemIdM,quantity,frs,frsn,fos,trs,trsn,tos,reason,transtype,NOW(),createby,NOW(),updateby,NOW(),orgid);
SELECT LAST_INSERT_ID() INTO @liid;
CALL wipmovetrans(woid,@liid,frs,frsn, fos, trs,trsn, tos, quantity,reason,updateby,orgid);
IF(fos!=0 AND tos=382) THEN
CALL wipissue(woid,frs,frsn,trs,quantity,orgid,updateby);
CALL wipResTrans(woid,frs,frsn,trs,quantity,@liid,orgid,updateby);
END IF;
IF tos=382 AND trs!=0 THEN
CALL wipOSP_Trans(woid,frs,frsn,trs,trsn,quantity,@liid,orgid,updateby);
END IF;
RETURN @liid;
END$$

DELIMITER ;

DELIMITER $$

USE `xbs`$$

DROP TRIGGER /*!50032 IF EXISTS */ `inv_receipt_lineUpdate`$$

CREATE
    /*!50017 DEFINER = 'i3u'@'localhost' */
    TRIGGER `inv_receipt_lineUpdate` BEFORE UPDATE ON `inv_receipt_line` 
    FOR EACH ROW BEGIN
IF (new.status=old.status) AND new.status IN (1519,1520) AND (new.transaction_quantity!=old.transaction_quantity) AND (old.reference_key_name='wip_move_transaction') THEN
SET @woid_wmt=NULL;
SET @trs=NULL;
SET @trsn=NULL;
SELECT wip_wo_header_id,from_routing_sequence,from_routing_seq_num INTO @woid_wmt,@trs ,@trsn FROM wip_move_transaction WHERE wip_move_transaction_id=new.reference_key_value;
SELECT wipMoveTransInsert(@woid_wmt,old.item_id_m,old.transaction_quantity-new.transaction_quantity,'','',382,@trs ,@trsn,379,'wip complete reject','WIP_MOVE',new.created_by,new.last_update_by,new.org_id) INTO @xxx;
#woid ,itemIdM ,quantity ,frs ,frsn ,fos ,trs ,trsn ,tos ,reason VARCHAR(255),transtype VARCHAR(50),createby INT,updateby INT,orgid INT
#95,430,8000,30,0,380,'','',382,'','WIP_MOVE','13','13','4'
END IF;
IF (new.status=1521 AND old.status=1520) OR (new.status=1522 AND old.status=1521) THEN
IF new.inspection_status IS NULL OR (new.inspection_status=1 AND new.inspection_quality=1) THEN
SET @itemnumber=NULL;
SET @itemrev=NULL;
SET @ospinv=NULL;
SELECT item_number,revision_name INTO @itemnumber,@itemrev FROM item i LEFT JOIN inv_item_revision v ON i.item_id_m=v.item_id_m AND i.org_id=v.org_id WHERE i.item_id_m=old.item_id_m AND i.org_id=old.org_id;
#check 4 osp po receipt
SET @polid=NULL;
IF old.reference_key_name='po_line' THEN
SET @polid=old.reference_key_value;
ELSEIF old.reference_key_name='inv_receipt_line' THEN
SELECT reference_key_value INTO @polid FROM inv_receipt_line WHERE reference_key_name='po_line' AND inv_receipt_line_id=old.reference_key_value;
END IF;
SET @ospitemcost=NULL;
IF @polid IS NOT NULL THEN
SELECT reference_key_name,reference_line_id,reference_header_id INTO @refkey,@reflid,@refhid FROM po_line WHERE po_line_id=@polid;
IF @refkey='wip_wo_routing_detail' THEN
SET @standCostType=1;
SELECT SUM(amount) INTO @ospitemcost FROM cst_item_cost_d_v WHERE (item_id_m,org_id,bom_cost_type)=(old.item_id_m,new.org_id,@standCostType);
SELECT subinventory_id INTO @ospinv FROM subinventory WHERE org_id=new.org_id AND TYPE=1618 LIMIT 0,1;
IF @ospinv IS NULL THEN
INSERT INTO subinventory(org_id,TYPE,subinventory,description,created_by,creation_date,last_update_by,last_update_date) VALUES (new.org_id,1618,CONCAT('OSP_subinv',new.org_id),'OSP',new.last_update_by,NOW(),new.last_update_by,NOW());
SELECT LAST_INSERT_ID() INTO @ospinv;
IF @ospinv IS NOT NULL THEN
INSERT INTO xbs.coa_combination (coa_id,ac_usage_type,org_id,reftbltp,refid,created_by,creation_date,last_update_by,last_update_date) VALUES('1',1601,new.org_id,'subinventory',@ospinv,'14',NOW(),'14',NOW());
INSERT INTO xbs.coa_combination (coa_id,ac_usage_type,org_id,reftbltp,refid,created_by,creation_date,last_update_by,last_update_date) VALUES('1',1602,new.org_id,'subinventory',@ospinv,'14',NOW(),'14',NOW());
INSERT INTO xbs.coa_combination (coa_id,ac_usage_type,org_id,reftbltp,refid,created_by,creation_date,last_update_by,last_update_date) VALUES('1',1603,new.org_id,'subinventory',@ospinv,'14',NOW(),'14',NOW());
INSERT INTO xbs.coa_combination (coa_id,ac_usage_type,org_id,reftbltp,refid,created_by,creation_date,last_update_by,last_update_date) VALUES('1',1604,new.org_id,'subinventory',@ospinv,'14',NOW(),'14',NOW());
INSERT INTO xbs.coa_combination (coa_id,ac_usage_type,org_id,reftbltp,refid,created_by,creation_date,last_update_by,last_update_date) VALUES('1',1605,new.org_id,'subinventory',@ospinv,'14',NOW(),'14',NOW());
INSERT INTO xbs.coa_combination (coa_id,ac_usage_type,org_id,reftbltp,refid,created_by,creation_date,last_update_by,last_update_date) VALUES('1',1606,new.org_id,'subinventory',@ospinv,'14',NOW(),'14',NOW());
END IF;
END IF;
END IF;
END IF;
#set @invtransdone=0;
#if @invtransdone=0 then
IF(new.status=1521 AND old.status=1520) THEN
INSERT INTO inv_transaction (item_id_m,item_number,revision_name,uom_id,reference_key_value,quantity,unit_cost,costed_amount,lot_number_id,to_subinventory_id,to_locator_id,reason,description,reference_type,reference_key_name,created_by,creation_date,last_update_by,last_update_date,org_id,transaction_type_id,ir_line_id)
VALUE(old.item_id_m,@itemnumber,@itemrev,old.uom_id,old.reference_key_value,old.transaction_quantity,IF(@ospinv IS NULL,old.unit_price,@ospitemcost),IF(@ospinv IS NULL,old.amount,@ospitemcost*old.transaction_quantity),old.lot_number,IFNULL(@ospinv,old.subinventory_id),old.locator_id,'','','table',old.reference_key_name,new.last_update_by,NOW(),new.last_update_by,NOW(),new.org_id,old.transaction_type_id,new.inv_receipt_line_id);
ELSEIF(new.status=1522 AND old.status=1521) THEN
INSERT INTO inv_transaction (item_id_m,item_number,revision_name,uom_id,reference_key_value,quantity,unit_cost,costed_amount,lot_number_id,to_subinventory_id,to_locator_id,reason,description,reference_type,reference_key_name,created_by,creation_date,last_update_by,last_update_date,org_id,transaction_type_id,ir_line_id)
VALUE(old.item_id_m,@itemnumber,@itemrev,old.uom_id,old.reference_key_value,-old.transaction_quantity,IF(@ospinv IS NULL,old.unit_price,@ospitemcost),-IF(@ospinv IS NULL,old.amount,@ospitemcost*old.transaction_quantity),old.lot_number,IFNULL(@ospinv,old.subinventory_id),old.locator_id,'cancel','','table',old.reference_key_name,new.last_update_by,NOW(),new.last_update_by,NOW(),new.org_id,old.transaction_type_id,new.inv_receipt_line_id);
END IF;
#end if;
IF @ospinv IS NOT NULL THEN
#do osp
SET @item=NULL;
SET @frs=NULL;
SET @frsn=NULL;
SET @trs=NULL;
SET @trsn=NULL;
IF(new.status=1521 AND old.status=1520) THEN
IF new.transaction_type_id=5 THEN
#UPDATE po_line SET accepted_quantity=accepted_quantity+new.transaction_quantity,last_update_date=NOW() WHERE po_line_id=@polid;
SELECT item_id_m INTO @item FROM wip_wo_header WHERE wip_wo_header_id=@refhid;
SELECT routing_sequence,routing_seq_num INTO @frs,@frsn FROM wip_wo_routing_line wrl JOIN wip_wo_routing_detail wrd ON wrl.wip_wo_routing_line_id=wrd.wip_wo_routing_line_id WHERE wip_wo_routing_detail_id=@reflid;
SELECT MIN(routing_sequence) routing_sequence,routing_seq_num INTO @trs,@trsn FROM wip_wo_routing_line WHERE (routing_sequence BETWEEN @frs+1 AND (SELECT lastSeq FROM wip_wo_routing_first_last_v WHERE wip_wo_header_id=@refhid)) AND (routing_seq_num =0 OR routing_seq_num=@trsn) AND wip_wo_header_id=@refhid GROUP BY routing_seq_num;
#INSERT INTO wip_resource_transaction (wip_wo_header_id,wip_wo_routing_line_id,wip_wo_routing_detail_id,org_id,transaction_type,transaction_date,transaction_quantity,reason,reference,created_by,creation_date,last_update_by,last_update_date)
#SELECT woid,wip_wo_routing_line_id,wip_wo_routing_detail_id,org,'WIP_RESOURCE_TRANSACTION',NOW(),resource_usage*sets,'wip_move',mtid,userid,NOW(),userid,NOW()
#FROM wip_wo_routing_detail WHERE wip_wo_routing_detail_id=
#UPDATE wip_wo_routing_detail SET applied_quantity=applied_quantity+resource_usage*sets WHERE wip_wo_routing_detail_id=
SET @wmtid=NULL;
SELECT wipMoveTransInsert(@refhid,@item,old.transaction_quantity,@frs,@frsn,382,@frs,@frsn,378,'OSP RUN','WIP_MOVE',new.last_update_by,new.last_update_by,new.org_id) INTO @wmtidx;
SELECT wipMoveTransInsert(@refhid,@item,old.transaction_quantity,@frs,@frsn,380,IFNULL(@trs,0),IFNULL(@trsn,0),382,'OSP PO_MOVE','WIP_MOVE',new.last_update_by,new.last_update_by,new.org_id) INTO @wmtid;
IF @wmtid IS NOT NULL THEN
#set @invtransdone=1;
IF @trs IS NULL THEN
#wip completion osp receipt transtpid=11-->3;move from osp receipt subinv to wip_complete subinv
UPDATE wip_wo_header SET wo_status=373 WHERE wip_wo_header_id=@refhid AND wo_status=370 AND completed_quantity>=quantity;
INSERT INTO inv_transaction (item_id_m,item_number,revision_name,uom_id,reference_key_value,quantity,unit_cost,costed_amount,lot_number_id,from_subinventory_id,from_locator_id,to_subinventory_id,to_locator_id,reason,description,reference_type,reference_key_name,created_by,creation_date,last_update_by,last_update_date,org_id,transaction_type_id,ir_line_id)
VALUE(old.item_id_m,@itemnumber,@itemrev,old.uom_id,old.reference_key_value,old.transaction_quantity,@ospitemcost,(@ospitemcost*old.transaction_quantity),old.lot_number,@ospinv,old.locator_id,old.subinventory_id,old.locator_id,'osp move','','table',old.reference_key_name,new.last_update_by,NOW(),new.last_update_by,NOW(),new.org_id,3,new.inv_receipt_line_id);
ELSE
#WIP Assembly Return for osp items transtpid=13;
INSERT INTO inv_transaction (item_id_m,item_number,revision_name,uom_id,reference_key_value,quantity,unit_cost,costed_amount,lot_number_id,from_subinventory_id,from_locator_id,reason,description,reference_type,reference_key_name,created_by,creation_date,last_update_by,last_update_date,org_id,transaction_type_id,ir_line_id)
VALUE(old.item_id_m,@itemnumber,@itemrev,old.uom_id,old.reference_key_value,old.transaction_quantity,@ospitemcost,(@ospitemcost*old.transaction_quantity),old.lot_number,@ospinv,old.locator_id,'osp move','','table',old.reference_key_name,new.last_update_by,NOW(),new.last_update_by,NOW(),new.org_id,13,new.inv_receipt_line_id);
END IF;
END IF;
#elseif new.transaction_type_id=4 then
#OSP PO_RECEIPT 344
END IF;
ELSEIF(new.status=1522 AND old.status=1521) THEN
IF new.transaction_type_id=5 THEN
#UPDATE po_line SET accepted_quantity=accepted_quantity-new.transaction_quantity,last_update_date=NOW() WHERE po_line_id=@polid;
SELECT item_id_m INTO @item FROM wip_wo_header WHERE wip_wo_header_id=@refhid;
SELECT routing_sequence,routing_seq_num INTO @frs,@frsn FROM wip_wo_routing_line wrl JOIN wip_wo_routing_detail wrd ON wrl.wip_wo_routing_line_id=wrd.wip_wo_routing_line_id WHERE wip_wo_routing_detail_id=@reflid;
SELECT MIN(routing_sequence) routing_sequence,routing_seq_num INTO @trs,@trsn FROM wip_wo_routing_line WHERE (routing_sequence BETWEEN @frs+1 AND (SELECT lastSeq FROM wip_wo_routing_first_last_v WHERE wip_wo_header_id=@refhid)) AND (routing_seq_num =0 OR routing_seq_num=@trsn) AND wip_wo_header_id=@refhid GROUP BY routing_seq_num;
#INSERT INTO wip_resource_transaction (wip_wo_header_id,wip_wo_routing_line_id,wip_wo_routing_detail_id,org_id,transaction_type,transaction_date,transaction_quantity,reason,reference,created_by,creation_date,last_update_by,last_update_date)
#SELECT woid,wip_wo_routing_line_id,wip_wo_routing_detail_id,org,'WIP_RESOURCE_TRANSACTION',NOW(),resource_usage*sets,'wip_move',mtid,userid,NOW(),userid,NOW()
#FROM wip_wo_routing_detail WHERE wip_wo_routing_detail_id=
#UPDATE wip_wo_routing_detail SET applied_quantity=applied_quantity+resource_usage*sets WHERE wip_wo_routing_detail_id=
SET @wmtid=NULL;
SELECT wipMoveTransInsert(@refhid,@item,-old.transaction_quantity,@frs,@frsn,382,@frs,@frsn,378,'OSP RUN','WIP_MOVE',new.last_update_by,new.last_update_by,new.org_id) INTO @wmtidx;
SELECT wipMoveTransInsert(@refhid,@item,-old.transaction_quantity,@frs,@frsn,380,IFNULL(@trs,0),IFNULL(@trsn,0),382,'OSP PO_MOVE Cancel','WIP_MOVE',new.last_update_by,new.last_update_by,new.org_id) INTO @wmtid;
IF @wmtid IS NOT NULL THEN
#set @invtransdone=1;
IF @trs IS NULL THEN
#wip completion osp receipt transtpid=11-->3;move from osp receipt subinv to wip_complete subinv
UPDATE wip_wo_header SET wo_status=370 WHERE wip_wo_header_id=@refhid AND wo_status=373 AND completed_quantity<quantity;
INSERT INTO inv_transaction (item_id_m,item_number,revision_name,uom_id,reference_key_value,quantity,unit_cost,costed_amount,lot_number_id,from_subinventory_id,from_locator_id,to_subinventory_id,to_locator_id,reason,description,reference_type,reference_key_name,created_by,creation_date,last_update_by,last_update_date,org_id,transaction_type_id,ir_line_id)
VALUE(old.item_id_m,@itemnumber,@itemrev,old.uom_id,old.reference_key_value,-old.transaction_quantity,@ospitemcost,-(@ospitemcost*old.transaction_quantity),old.lot_number,@ospinv,old.locator_id,old.subinventory_id,old.locator_id,'osp move cancel','','table',old.reference_key_name,new.last_update_by,NOW(),new.last_update_by,NOW(),new.org_id,3,new.inv_receipt_line_id);
ELSE
#WIP Assembly Return for osp items transtpid=13;
INSERT INTO inv_transaction (item_id_m,item_number,revision_name,uom_id,reference_key_value,quantity,unit_cost,costed_amount,lot_number_id,from_subinventory_id,from_locator_id,reason,description,reference_type,reference_key_name,created_by,creation_date,last_update_by,last_update_date,org_id,transaction_type_id,ir_line_id)
VALUE(old.item_id_m,@itemnumber,@itemrev,old.uom_id,old.reference_key_value,-old.transaction_quantity,@ospitemcost,-(@ospitemcost*old.transaction_quantity),old.lot_number,@ospinv,old.locator_id,'osp move cancel','','table',old.reference_key_name,new.last_update_by,NOW(),new.last_update_by,NOW(),new.org_id,13,new.inv_receipt_line_id);
END IF;
END IF;
#elseif new.transaction_type_id=4 then
#OSP PO_RECEIPT 344
END IF;
END IF;
END IF;
#OSP has done inv trans
ELSEIF !(new.inspection_status=1 AND new.inspection_quality=0) THEN
SET new.status=old.status;
#else
END IF;
END IF;
    END;
$$

DELIMITER ;

DELIMITER $$

USE `xbs`$$

DROP TRIGGER /*!50032 IF EXISTS */ `inv_transactionInsert`$$

CREATE
    /*!50017 DEFINER = 'i3u'@'localhost' */
    TRIGGER `inv_transactionInsert` AFTER INSERT ON `inv_transaction` 
    FOR EACH ROW BEGIN
IF new.reference_key_name='po_line' THEN
BEGIN
IF new.transaction_type_id=21 THEN
UPDATE po_line SET accepted_quantity=accepted_quantity-new.quantity,last_update_date=NOW() WHERE po_line_id=new.reference_key_value;
ELSEIF new.transaction_type_id=5 THEN
UPDATE po_line SET received_quantity=received_quantity+new.quantity,accepted_quantity=accepted_quantity+new.quantity,last_update_date=NOW() WHERE po_line_id=new.reference_key_value;
ELSEIF new.transaction_type_id=4 THEN
UPDATE po_line SET received_quantity=received_quantity+new.quantity,last_update_date=NOW() WHERE po_line_id=new.reference_key_value;
END IF;
END;
ELSEIF new.reference_key_name='inv_receipt_line' THEN
IF new.transaction_type_id=5 THEN
UPDATE po_line SET accepted_quantity=accepted_quantity+new.quantity,last_update_date=NOW() WHERE po_line_id=(SELECT reference_key_value FROM inv_receipt_line WHERE inv_receipt_line_id=new.reference_key_value AND reference_key_name='po_line');
END IF;
ELSEIF new.reference_key_name='wip_wo_bom' THEN
IF new.transaction_type_id IN ('6','9') THEN
UPDATE wip_wo_bom SET issued_quantity=issued_quantity+new.quantity WHERE wip_wo_bom_id=new.reference_key_value;
ELSE
UPDATE wip_wo_bom SET issued_quantity=issued_quantity-new.quantity WHERE wip_wo_bom_id=new.reference_key_value;
END IF;
ELSEIF new.reference_key_name='wip_wo_header' THEN
IF new.transaction_type_id IN ('10','11') THEN
UPDATE wip_wo_header SET completed_quantity=completed_quantity+new.quantity WHERE wip_wo_header_id=new.reference_key_value;
UPDATE wip_wo_header SET wo_status=373 WHERE wip_wo_header_id=new.reference_key_value AND wo_status=370 AND completed_quantity>=quantity;
UPDATE sd_so_line SET line_status=1530 WHERE sd_so_line_id IN (SELECT demand_source_line_id FROM wip_wo_allocation WHERE demand_source_type='sd_so_header' AND (wip_wo_header_id IN (SELECT wip_wo_header_id FROM wip_wo_header WHERE wip_wo_header_id=new.reference_key_value AND quantity=completed_quantity))) AND line_status=1529;
UPDATE sd_so_header SET so_status=535 WHERE sd_so_header_id IN (SELECT sd_so_header_id FROM sd_so_line WHERE sd_so_header_id IN (SELECT demand_source_header_id FROM wip_wo_allocation WHERE demand_source_type='sd_so_header' AND (wip_wo_header_id IN (SELECT wip_wo_header_id FROM wip_wo_header WHERE wip_wo_header_id=new.reference_key_value AND quantity=completed_quantity))) AND sd_so_header_id NOT IN (SELECT sd_so_header_id FROM sd_so_line WHERE sd_so_header_id IN (SELECT demand_source_header_id FROM wip_wo_allocation WHERE demand_source_type='sd_so_header' AND (wip_wo_header_id IN (SELECT wip_wo_header_id FROM wip_wo_header WHERE wip_wo_header_id=new.reference_key_value AND quantity=completed_quantity)) AND line_status!=1530)));
END IF;
ELSEIF new.reference_key_name='wip_move_transaction' THEN
IF new.transaction_type_id IN ('10','11') THEN
SET @woid_wmt=NULL;
SELECT wip_wo_header_id INTO @woid_wmt FROM wip_move_transaction WHERE wip_move_transaction_id=new.reference_key_value;
UPDATE wip_wo_header SET completed_quantity=completed_quantity+new.quantity WHERE wip_wo_header_id=@woid_wmt;
UPDATE wip_wo_header SET wo_status=373 WHERE wip_wo_header_id=@woid_wmt AND wo_status=370 AND completed_quantity>=quantity;
UPDATE sd_so_line SET line_status=1530 WHERE sd_so_line_id IN (SELECT demand_source_line_id FROM wip_wo_allocation WHERE demand_source_type='sd_so_header' AND (wip_wo_header_id IN (SELECT wip_wo_header_id FROM wip_wo_header WHERE wip_wo_header_id=@woid_wmt AND quantity=completed_quantity))) AND line_status=1529;
UPDATE sd_so_header SET so_status=535 WHERE sd_so_header_id IN (SELECT sd_so_header_id FROM sd_so_line WHERE sd_so_header_id IN (SELECT demand_source_header_id FROM wip_wo_allocation WHERE demand_source_type='sd_so_header' AND (wip_wo_header_id IN (SELECT wip_wo_header_id FROM wip_wo_header WHERE wip_wo_header_id=@woid_wmt AND quantity=completed_quantity))) AND sd_so_header_id NOT IN (SELECT sd_so_header_id FROM sd_so_line WHERE sd_so_header_id IN (SELECT demand_source_header_id FROM wip_wo_allocation WHERE demand_source_type='sd_so_header' AND (wip_wo_header_id IN (SELECT wip_wo_header_id FROM wip_wo_header WHERE wip_wo_header_id=@woid_wmt AND quantity=completed_quantity)) AND line_status!=1530)));
END IF;
ELSEIF new.reference_key_name='sd_delivery_line' THEN
IF new.transaction_type_id=14 THEN
UPDATE sd_delivery_line SET delivery_status=536 WHERE sd_delivery_line_id=new.reference_key_value AND delivery_status=604 AND shipped_quantity=(SELECT SUM(transaction_quantity) FROM inv_issue_line WHERE reference_key_name='sd_delivery_line' AND reference_key_value=new.reference_key_value AND STATUS=1521);
END IF;
END IF;
SET @mat=NULL;
SET @res=NULL;
SET @osp=NULL;
SET @moh=NULL;
SET @oh=NULL;
SET @cst_amount=0;
SET @standCostType=1;
SELECT SUM(amount) INTO @cst_amount FROM cst_item_cost_d_v WHERE (item_id_m,org_id,bom_cost_type)=(new.item_id_m,new.org_id,@standCostType);
SELECT SUM(amount) INTO @mat FROM cst_item_cost_d_v WHERE (item_id_m,org_id,bom_cost_type,cost_element_type)=(new.item_id_m,new.org_id,@standCostType,548) OR (item_id_m,org_id,bom_cost_type,this_level_cb)=(new.item_id_m,new.org_id,@standCostType,0);
IF new.transaction_type_id NOT IN (3,4,5,15,21,23) THEN
SELECT new.quantity*SUM(amount) INTO @res FROM cst_item_cost_d_v WHERE (item_id_m,org_id,bom_cost_type,cost_element_type,this_level_cb)=(new.item_id_m,new.org_id,@standCostType,547,1);
SELECT new.quantity*SUM(amount) INTO @osp FROM cst_item_cost_d_v WHERE (item_id_m,org_id,bom_cost_type,cost_element_type,this_level_cb)=(new.item_id_m,new.org_id,@standCostType,551,1);
SELECT new.quantity*SUM(amount) INTO @moh FROM cst_item_cost_d_v WHERE (item_id_m,org_id,bom_cost_type,cost_element_type,this_level_cb)=(new.item_id_m,new.org_id,@standCostType,549,1);
SELECT new.quantity*SUM(amount) INTO @oh FROM cst_item_cost_d_v WHERE (item_id_m,org_id,bom_cost_type,cost_element_type,this_level_cb)=(new.item_id_m,new.org_id,@standCostType,550,1);
END IF;
IF @mat IS NOT NULL THEN
BEGIN
SET @ledgerid=NULL;
SET @currency=NULL;
SET @invMatACid=NULL;
SET @period=NULL;
SET @invid=new.inv_transaction_id;
SET @createby=new.last_update_by;
SET @pu=486;
SET @amount=new.quantity*@cst_amount;
SET @amount2=@amount;
SET @mat_ac=NULL;
SET @mat_ac_2=NULL;
SET @res_ac=NULL;
SET @res_ac_2=NULL;
SET @osp_ac=NULL;
SET @osp_ac_2=NULL;
SET @ppv=NULL;
SET @ppv_ac=NULL;
SELECT ledger_id,currency INTO @ledgerid,@currency FROM inventory_v WHERE org_id=new.org_id;
SELECT getCOAId(new.org_id,1572,'',0) INTO @invMatACid;
SELECT gl_period_id INTO @period FROM gl_period WHERE ledger_id=@ledgerid AND STATUS='OPEN' ORDER BY gl_period_id DESC LIMIT 0,1;
IF new.transaction_type_id IN ('1','6','12','13','15','16','18','19','21','22','24','29') THEN
BEGIN
SELECT getCOAId(new.org_id,1601,'subinventory',new.from_subinventory_id) INTO @mat_ac;
IF new.transaction_type_id IN (1,16) THEN
SET @mat_ac_2=@invMatACid;
ELSEIF new.transaction_type_id=6 THEN
SET @woag=NULL;
SET @amount=new.quantity*@mat;
SET @amount2=@amount;
SELECT wip_accounting_group_id INTO @woag FROM wip_wo_header WHERE wip_wo_header_id=new.reference_key_value;
SET @subinvtp=NULL;
SELECT TYPE INTO @subinvtp FROM subinventory WHERE subinventory_id=new.from_subinventory_id;
IF @subinvtp=1618 THEN
SELECT getCOAId(new.org_id,1620,'subinventory',new.from_subinventory_id) INTO @mat_ac_2;
ELSE
SELECT getCOAId(new.org_id,1591,'wip_accounting_group',@woag) INTO @mat_ac_2;
END IF;
IF @res IS NOT NULL THEN
SELECT getCOAId(new.org_id,1604,'subinventory',new.from_subinventory_id) INTO @res_ac;
SELECT getCOAId(new.org_id,1594,'wip_accounting_group',@woag) INTO @res_ac_2;
END IF;
IF @osp IS NOT NULL THEN
SELECT getCOAId(new.org_id,1605,'subinventory',new.from_subinventory_id) INTO @osp_ac;
SELECT getCOAId(new.org_id,1595,'wip_accounting_group',@woag) INTO @osp_ac_2;
END IF;
ELSEIF new.transaction_type_id=21 THEN
SET @subinvtp=NULL;
SELECT TYPE INTO @subinvtp FROM subinventory WHERE subinventory_id=new.from_subinventory_id;
IF @subinvtp=1618 THEN
SELECT getCOAId(new.org_id,1620,'subinventory',new.from_subinventory_id) INTO @mat_ac;
ELSE
SELECT getCOAId(new.org_id,1601,'subinventory',new.from_subinventory_id) INTO @mat_ac;
END IF;
SELECT getCOAId(new.org_id,1585,0,0) INTO @mat_ac_2;
SET @amount=new.costed_amount;
IF @amount2-@amount!=0 THEN
SET @ppv=@amount2-@amount;
SELECT getCOAId(new.org_id,1583,'',0) INTO @ppv_ac;
END IF;
ELSEIF new.transaction_type_id=15 THEN
SELECT getCOAId(new.org_id,1601,'subinventory',new.from_subinventory_id) INTO @mat_ac;
SELECT getCOAId(new.org_id,1578,'',0) INTO @mat_ac_2;
END IF;
END;
ELSEIF new.transaction_type_id IN ('2','5','7','10','11','17','20','23','25','30','33') THEN
BEGIN
SELECT getCOAId(new.org_id,1601,'subinventory',new.to_subinventory_id) INTO @mat_ac_2;
IF new.transaction_type_id IN (2,17) THEN
SET @mat_ac=@invMatACid;
ELSEIF new.transaction_type_id=5 THEN
SELECT getCOAId(new.org_id,1601,'subinventory',new.to_subinventory_id) INTO @mat_ac_2;
SET @subinvtp=NULL;
SELECT TYPE INTO @subinvtp FROM subinventory WHERE subinventory_id=new.to_subinventory_id;
IF @subinvtp=1618 THEN
SELECT getCOAId(new.org_id,1620,'subinventory',new.to_subinventory_id) INTO @mat_ac;
ELSE
SELECT getCOAId(new.org_id,1585,0,0) INTO @mat_ac;
END IF; 
SET @amount=new.costed_amount;
IF @amount2-@amount!=0 THEN
SET @ppv=@amount2-@amount;
SELECT getCOAId(new.org_id,1583,'',0) INTO @ppv_ac;
END IF;
ELSEIF new.transaction_type_id=7 THEN
SET @woag=NULL;
SET @amount=new.quantity*@mat;
SET @amount2=@amount;
SELECT wip_accounting_group_id INTO @woag FROM wip_wo_header WHERE wip_wo_header_id=new.reference_key_value;
SET @subinvtp=NULL;
SELECT TYPE INTO @subinvtp FROM subinventory WHERE subinventory_id=new.to_subinventory_id;
IF @subinvtp=1618 THEN
SELECT getCOAId(new.org_id,1620,'subinventory',new.to_subinventory_id) INTO @mat_ac_2;
ELSE
SELECT getCOAId(new.org_id,1591,'wip_accounting_group',@woag) INTO @mat_ac;
END IF;
IF @res IS NOT NULL THEN
SELECT getCOAId(new.org_id,1594,'wip_accounting_group',@woag) INTO @res_ac;
SELECT getCOAId(new.org_id,1604,'subinventory',new.to_subinventory_id) INTO @res_ac_2;
END IF;
IF @osp IS NOT NULL THEN
SELECT getCOAId(new.org_id,1595,'wip_accounting_group',@woag) INTO @osp_ac;
SELECT getCOAId(new.org_id,1605,'subinventory',new.to_subinventory_id) INTO @osp_ac_2;
END IF;
ELSEIF new.transaction_type_id IN (10,11) THEN
SET @woag=NULL;
SET @amount=new.quantity*@mat;
SET @amount2=@amount;
SELECT wip_accounting_group_id INTO @woag FROM wip_wo_header WHERE wip_wo_header_id=new.reference_key_value;
SELECT getCOAId(new.org_id,1601,'subinventory',new.to_subinventory_id) INTO @mat_ac_2;
SELECT getCOAId(new.org_id,1591,'wip_accounting_group',@woag) INTO @mat_ac;
IF @res IS NOT NULL THEN
SELECT getCOAId(new.org_id,1594,'wip_accounting_group',@woag) INTO @res_ac;
SELECT getCOAId(new.org_id,1604,'subinventory',new.to_subinventory_id) INTO @res_ac_2;
END IF;
IF @osp IS NOT NULL THEN
SELECT getCOAId(new.org_id,1595,'wip_accounting_group',@woag) INTO @osp_ac;
SELECT getCOAId(new.org_id,1605,'subinventory',new.to_subinventory_id) INTO @osp_ac_2;
END IF;
ELSEIF new.transaction_type_id=23 THEN
SELECT getCOAId(new.org_id,1578,'',0) INTO @mat_ac;
SELECT getCOAId(new.org_id,1601,'subinventory',new.to_subinventory_id) INTO @mat_ac_2;
END IF;
END;
ELSEIF new.transaction_type_id IN ('3') THEN
SELECT getCOAId(new.org_id,1601,'subinventory',new.from_subinventory_id) INTO @mat_ac;
SELECT getCOAId(new.org_id,1601,'subinventory',new.to_subinventory_id) INTO @mat_ac_2;
END IF;
IF @mat_ac IS NOT NULL AND @mat_ac_2 IS NOT NULL THEN
INSERT INTO gl_journal_header (ledger_id,currency,period_id,journal_source,journal_category,journal_name,description,balance_type,reference_type,reference_key_name,reference_key_value,STATUS,created_by,creation_date,last_update_by,last_update_date)
VALUE(@ledgerid,@currency,@period,'inv','inv_inventory',CONCAT('inv_inventory-',@invid),CONCAT('inv_inventory-',@invid,'-',NOW()),'428','table','inv_transaction',@invid,@pu,@createby,NOW(),@createby,NOW());
SET @liid = NULL;
SET @lidx = 1;
SET @coaid=NULL;
SELECT LAST_INSERT_ID() INTO @liid;
INSERT INTO gl_journal_line (gl_journal_header_id,line_num,STATUS,description,code_combination_id,total_cr,total_ac_cr,reference_type,reference_key_name,reference_key_value,created_by,creation_date,last_update_by,last_update_date)
VALUE(@liid,@lidx,@pu,CONCAT('inv transaction id ',@invid,' item_id ' , new.item_id_m),@mat_ac,@amount,@amount,'table','inv_transaction',@invid,@createby,NOW(),@createby,NOW());
SET @lidx = @lidx+1;
INSERT INTO gl_journal_line (gl_journal_header_id,line_num,STATUS,description,code_combination_id,total_dr,total_ac_dr,reference_type,reference_key_name,reference_key_value,created_by,creation_date,last_update_by,last_update_date)
VALUE(@liid,@lidx,@pu,CONCAT('inv transaction id ',@invid,' item_id ' , new.item_id_m),@mat_ac_2,@amount2,@amount2,'table','inv_transaction',@invid,@createby,NOW(),@createby,NOW());
IF @ppv IS NOT NULL AND @ppv!=0 THEN
SET @lidx = @lidx+1;
IF @ppv>0 THEN
INSERT INTO gl_journal_line (gl_journal_header_id,line_num,STATUS,description,code_combination_id,total_cr,total_ac_cr,reference_type,reference_key_name,reference_key_value,created_by,creation_date,last_update_by,last_update_date)
VALUE(@liid,@lidx,@pu,CONCAT('inv transaction id ',@invid,' item_id ' , new.item_id_m),@ppv_ac,@ppv,@ppv,'table','inv_transaction',@invid,@createby,NOW(),@createby,NOW());
ELSE
INSERT INTO gl_journal_line (gl_journal_header_id,line_num,STATUS,description,code_combination_id,total_dr,total_ac_dr,reference_type,reference_key_name,reference_key_value,created_by,creation_date,last_update_by,last_update_date)
VALUE(@liid,@lidx,@pu,CONCAT('inv transaction id ',@invid,' item_id ' , new.item_id_m),@ppv_ac,@ppv,@ppv,'table','inv_transaction',@invid,@createby,NOW(),@createby,NOW());
END IF;
END IF;
IF @res IS NOT NULL THEN
SET @lidx = @lidx+1;
INSERT INTO gl_journal_line (gl_journal_header_id,line_num,STATUS,description,code_combination_id,total_cr,total_ac_cr,reference_type,reference_key_name,reference_key_value,created_by,creation_date,last_update_by,last_update_date)
VALUE(@liid,@lidx,@pu,CONCAT('inv(res) transaction id ',@invid,' item_id ' , new.item_id_m),@res_ac,@res,@res,'table','inv_transaction',@invid,@createby,NOW(),@createby,NOW());
SET @lidx = @lidx+1;
INSERT INTO gl_journal_line (gl_journal_header_id,line_num,STATUS,description,code_combination_id,total_dr,total_ac_dr,reference_type,reference_key_name,reference_key_value,created_by,creation_date,last_update_by,last_update_date)
VALUE(@liid,@lidx,@pu,CONCAT('inv(res) transaction id ',@invid,' item_id ' , new.item_id_m),@res_ac_2,@res,@res,'table','inv_transaction',@invid,@createby,NOW(),@createby,NOW());
END IF;
IF @osp IS NOT NULL THEN
SET @lidx = @lidx+1;
INSERT INTO gl_journal_line (gl_journal_header_id,line_num,STATUS,description,code_combination_id,total_cr,total_ac_cr,reference_type,reference_key_name,reference_key_value,created_by,creation_date,last_update_by,last_update_date)
VALUE(@liid,@lidx,@pu,CONCAT('inv(osp) transaction id ',@invid,' item_id ' , new.item_id_m),@osp_ac,@osp,@osp,'table','inv_transaction',@invid,@createby,NOW(),@createby,NOW());
SET @lidx = @lidx+1;
INSERT INTO gl_journal_line (gl_journal_header_id,line_num,STATUS,description,code_combination_id,total_dr,total_ac_dr,reference_type,reference_key_name,reference_key_value,created_by,creation_date,last_update_by,last_update_date)
VALUE(@liid,@lidx,@pu,CONCAT('inv(osp) transaction id ',@invid,' item_id ' , new.item_id_m),@osp_ac_2,@osp,@osp,'table','inv_transaction',@invid,@createby,NOW(),@createby,NOW());
END IF;
END IF;
END;
END IF;
    END;
$$

DELIMITER ;

