DELIMITER $$

USE `xbs`$$

DROP PROCEDURE IF EXISTS `wipwoReleaseRL`$$

CREATE DEFINER=`i3u`@`localhost` PROCEDURE `wipwoReleaseRL`(woid BIGINT,item BIGINT,qty INT,orgid INT,userid INT)
BEGIN
DECLARE rs INT;
DECLARE rsn INT;
DECLARE rlid INT;
DECLARE done INT;
DECLARE wipwoR CURSOR FOR SELECT MIN(routing_sequence),routing_seq_num,wip_wo_routing_line_id FROM wip_wo_routing_line WHERE wip_wo_header_id=woid GROUP BY routing_seq_num;
DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = 1;
DELETE FROM xbs_log WHERE task='WO_Release' AND user_id=userid;
    OPEN wipwoR;
    BEGIN_wipwoR: LOOP
        FETCH wipwoR INTO rs,rsn,rlid;
        IF done THEN
            LEAVE BEGIN_wipwoR;
        END IF;
        IF(rs>0) THEN
INSERT INTO wip_move_transaction (wip_wo_header_id,item_id_m,move_quantity,from_routing_sequence,from_routing_seq_num,from_operation_step,reason,to_routing_sequence,to_routing_seq_num,to_operation_step,transaction_type,transaction_date,created_by,creation_date,last_update_by,last_update_date,org_id) 
SELECT woid,item,qty,0,rsn,378,'wo_release',rs,rsn,'382','WIP_MOVE',NOW(),userid,NOW(),userid,NOW(),orgid FROM wip_wo_routing_line WHERE wip_wo_routing_line_id=rlid;
UPDATE wip_wo_routing_line SET queue_quantity=qty WHERE wip_wo_routing_line_id=rlid;
CALL wipOSP_Trans(woid,0,rsn,rs,rsn,@qty,0,orgid,userid);
	END IF;
    END LOOP BEGIN_wipwoR;
    CLOSE wipwoR;
    END$$

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
  `q`.`last_update_date` AS `last_update_date`,
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

DROP PROCEDURE IF EXISTS `explodeBomRoute`$$

CREATE DEFINER=`i3u`@`localhost` PROCEDURE `explodeBomRoute`(woid BIGINT,userid BIGINT,bomId BIGINT, routId BIGINT,prods INT)
BEGIN
INSERT INTO wip_wo_bom (bom_sequence, routing_sequence, routing_seq_num,component_item_id_m, component_revision, usage_basis, usage_quantity, required_quantity,auto_request_material_cb, effective_start_date, effective_end_date, eco_number, eco_implemented_cb, planning_percentage, yield, include_in_cost_rollup_cb, wip_supply_type, supply_sub_inventory, supply_locator, ef_id, created_by, creation_date, last_update_by, last_update_date,wip_wo_header_id ) 
SELECT bom_sequence, routing_sequence,routing_seq_num, component_item_id_m, component_revision, usage_basis, usage_quantity,IF(usage_basis=351,usage_quantity*prods,usage_quantity), auto_request_material_cb, effective_start_date, effective_end_date, eco_number, eco_implemented_cb, planning_percentage, yield, include_in_cost_rollup_cb, IFNULL(bl.wip_supply_type,i.wip_supply_type) wip_supply_type, IFNULL(bl.supply_sub_inventory,i.receipt_sub_inventory) supply_sub_inventory, supply_locator, bl.ef_id, userid, NOW(), userid, NOW(),woid FROM bom_line bl JOIN bom_header bh ON bl.bom_header_id=bh.bom_header_id JOIN item i ON bl.component_item_id_m=i.item_id_m AND bh.org_id=i.org_id WHERE bh.bom_header_id=bomId;
INSERT INTO wip_wo_routing_line (wip_wo_header_id, routing_sequence,routing_seq_num, standard_operation_id, department_id, description,  count_point_cb, auto_charge_cb,   backflush_cb, yield, created_by, creation_date, last_update_by, last_update_date) SELECT woid, routing_sequence,routing_seq_num, standard_operation_id, department_id, description, count_point_cb, auto_charge_cb, backflush_cb,yield, userid, NOW(), userid,NOW() FROM bom_routing_line WHERE bom_routing_header_id=routId;
INSERT INTO wip_wo_routing_detail (wip_wo_routing_line_id,wip_wo_header_id,resource_sequence,charge_basis,resource_id,resource_usage,resource_schedule,required_quantity,charge_type,standard_rate_cb,created_by,creation_date,last_update_by,last_update_date)
SELECT (SELECT wip_wo_routing_line_id FROM wip_wo_routing_line WHERE (wip_wo_header_id,routing_sequence,routing_seq_num)=(woid,brl.routing_sequence,brl.routing_seq_num)),woid,resource_sequence,charge_basis,resource_id,resource_usage,resource_schedule,IF(charge_basis=351,resource_usage*prods,resource_usage),charge_type,standard_rate_cb, userid, NOW(), userid,NOW()
FROM bom_routing_detail brd JOIN bom_routing_line brl ON brd.bom_routing_line_id=brl.bom_routing_line_id WHERE brd.bom_routing_header_id=routId;
    END$$

DELIMITER ;

DELIMITER $$

USE `xbs`$$

DROP PROCEDURE IF EXISTS `wipwoReleaseCancel`$$

CREATE
    /*[DEFINER = { user | CURRENT_USER }]*/
    PROCEDURE `xbs`.`wipwoReleaseCancel`(woid BIGINT,orgid INT,userid INT)
    /*LANGUAGE SQL
    | [NOT] DETERMINISTIC
    | { CONTAINS SQL | NO SQL | READS SQL DATA | MODIFIES SQL DATA }
    | SQL SECURITY { DEFINER | INVOKER }
    | COMMENT 'string'*/
    BEGIN
SET @wst=NULL;
SELECT wo_status INTO @wst FROM wip_wo_header WHERE wip_wo_header_id=woid AND last_update_by=userid;
IF @wst = 370 THEN
SET @cnt=NULL;
SELECT COUNT(0) INTO @cnt FROM wip_wo_routing_line WHERE wip_wo_header_id=woid AND (running_quantity!=0 OR rejected_quantity!=0 OR scrapped_quantity!=0 OR tomove_quantity!=0 OR completed_quantity!=0);
IF @cnt=0 THEN #no operation
SELECT COUNT(0) INTO @cnt FROM wip_wo_bom WHERE wip_wo_header_id=woid AND issued_quantity!=0;
IF @cnt=0 THEN #no issue
SELECT COUNT(0) INTO @cnt FROM wip_wo_routing_detail WHERE wip_wo_header_id=woid AND applied_quantity!=0;
IF @cnt=0 THEN #no resource issue
SELECT COUNT(0) INTO @cnt FROM po_requisition_header pr JOIN wip_wo_routing_detail word ON pr.reference_key_name='wip_wo_routing_detail' AND pr.reference_key_value=word.wip_wo_routing_detail_id WHERE wip_wo_header_id=woid AND requisition_status!=322;
IF @cnt=0 THEN #no osp po
UPDATE wip_wo_routing_line SET queue_quantity=0 WHERE wip_wo_header_id=woid;
DELETE FROM wip_move_transaction WHERE wip_wo_header_id=woid;
UPDATE wip_wo_header SET wo_status=369,released_date=NULL WHERE wip_wo_header_id=woid;
END IF;
END IF;
END IF;
END IF;
END IF;
    END$$

DELIMITER ;

DELIMITER $$

USE `xbs`$$

DROP VIEW IF EXISTS `inv_issue_header_v`$$

CREATE ALGORITHM=UNDEFINED DEFINER=`i3u`@`localhost` SQL SECURITY DEFINER VIEW `inv_issue_header_v` AS (
SELECT
  `i`.`issue_number`        AS `issue_number`,
  `t`.`transaction_type`    AS `transaction_type`,
  (CASE `i`.`reference_key_name` WHEN _utf8'wip_wo_header' THEN `wo`.`wo_number` WHEN _utf8'sd_delivery_header' THEN `sdh`.`delivery_number` ELSE _utf8'' END) AS `ref_number`,
  `s`.`option_line_value`   AS `statusv`,
  `i`.`issue_date`          AS `issue_date`,
  `i`.`carrier`             AS `carrier`,
  `i`.`vechile_number`      AS `vechile_number`,
  `i`.`comment`             AS `comment`,
  `x`.`username`            AS `creator`,
  `x0`.`username`           AS `updator`,
  `i`.`created_by`          AS `created_by`,
  `i`.`creation_date`       AS `creation_date`,
  `i`.`last_update_by`      AS `last_update_by`,
  `i`.`last_update_date`    AS `last_update_date`,
  `i`.`inv_issue_header_id` AS `inv_issue_header_id`,
  `i`.`reference_key_name`  AS `reference_key_name`,
  `i`.`reference_key_value` AS `reference_key_value`,
  `i`.`transaction_type_id` AS `transaction_type_id`,
  `i`.`org_id`              AS `org_id`,
  `i`.`status`              AS `status`
FROM ((((((`inv_issue_header` `i`
        LEFT JOIN `option_line` `s`
          ON ((`i`.`status` = `s`.`option_line_id`)))
       LEFT JOIN `xerp_user` `X`
         ON ((`i`.`created_by` = `x`.`xerp_user_id`)))
      LEFT JOIN `xerp_user` `x0`
        ON ((`i`.`last_update_by` = `x0`.`xerp_user_id`)))
     LEFT JOIN `transaction_type` `t`
       ON ((`i`.`transaction_type_id` = `t`.`transaction_type_id`)))
    LEFT JOIN `wip_wo_header` `wo`
      ON (((`i`.`reference_key_name` = _utf8'wip_wo_header')
           AND (`i`.`reference_key_value` = `wo`.`wip_wo_header_id`))))
   LEFT JOIN `sd_delivery_header` `sdh`
     ON (((`i`.`reference_key_name` = _utf8'sd_delivery_header')
          AND (`i`.`reference_key_value` = `sdh`.`sd_delivery_header_id`)))))$$

DELIMITER ;

DELIMITER $$

USE `xbs`$$

DROP VIEW IF EXISTS `inv_receipt_header_v`$$

CREATE ALGORITHM=UNDEFINED DEFINER=`i3u`@`localhost` SQL SECURITY DEFINER VIEW `inv_receipt_header_v` AS (
SELECT
  `i`.`receipt_number`        AS `receipt_number`,
  `t`.`transaction_type`      AS `transaction_type`,
  (CASE `i`.`reference_key_name` WHEN _utf8'wip_wo_header' THEN `wo`.`wo_number` WHEN _utf8'po_header' THEN `po`.`po_number` ELSE _utf8'' END) AS `ref_number`,
  `s`.`option_line_value`     AS `statusv`,
  `i`.`receipt_date`          AS `receipt_date`,
  `i`.`carrier`               AS `carrier`,
  `i`.`vechile_number`        AS `vechile_number`,
  `i`.`comment`               AS `comment`,
  `x`.`username`              AS `creator`,
  `x0`.`username`             AS `updator`,
  `i`.`created_by`            AS `created_by`,
  `i`.`creation_date`         AS `creation_date`,
  `i`.`last_update_by`        AS `last_update_by`,
  `i`.`last_update_date`      AS `last_update_date`,
  `o`.`org`                   AS `org_id`,
  `i`.`inv_receipt_header_id` AS `inv_receipt_header_id`,
  `i`.`reference_key_name`    AS `reference_key_name`,
  `i`.`reference_key_value`   AS `reference_key_value`,
  `i`.`transaction_type_id`   AS `transaction_type_id`,
  `i`.`status`                AS `status`
FROM (((((((`inv_receipt_header` `i`
         LEFT JOIN `option_line` `s`
           ON ((`i`.`status` = `s`.`option_line_id`)))
        LEFT JOIN `transaction_type` `t`
          ON ((`i`.`transaction_type_id` = `t`.`transaction_type_id`)))
       LEFT JOIN `xerp_user` `X`
         ON ((`i`.`created_by` = `x`.`xerp_user_id`)))
      LEFT JOIN `xerp_user` `x0`
        ON ((`i`.`last_update_by` = `x0`.`xerp_user_id`)))
     LEFT JOIN `org` `o`
       ON ((`i`.`org_id` = `o`.`org_id`)))
    LEFT JOIN `wip_wo_header` `wo`
      ON (((`i`.`reference_key_name` = _utf8'wip_wo_header')
           AND (`i`.`reference_key_value` = `wo`.`wip_wo_header_id`))))
   LEFT JOIN `po_header` `po`
     ON (((`i`.`reference_key_name` = _utf8'po_header')
          AND (`i`.`reference_key_value` = `po`.`po_header_id`)))))$$

DELIMITER ;

DELIMITER $$

USE `xbs`$$

DROP VIEW IF EXISTS `inv_transaction_v`$$

CREATE ALGORITHM=UNDEFINED DEFINER=`i3u`@`localhost` SQL SECURITY DEFINER VIEW `inv_transaction_v` AS (
SELECT
  `i0`.`item_number`         AS `item_number`,
  `u`.`uom_name`             AS `uom_name`,
  `i`.`quantity`             AS `quantity`,
  `t`.`transaction_type`     AS `transaction_type`,
  CASE `i`.`transaction_type_id` WHEN 5 THEN irh.receipt_number WHEN 11 THEN irh.receipt_number WHEN 6 THEN iih.issue_number WHEN 14 THEN iih.issue_number END ir_number,
  `i`.`unit_cost`            AS `unit_cost`,
  `i`.`costed_amount`        AS `costed_amount`,
  `s`.`subinventory`         AS `from_subinventory`,
  `l`.`locator`              AS `from_locator`,
  `s0`.`subinventory`        AS `to_subinventory`,
  `l0`.`locator`             AS `to_locator`,
  `lt`.`lot_number`          AS `lot_number`,
  `i`.`reason`               AS `reason`,
  `i0`.`item_description`    AS `item_description`,
  `i`.`description`          AS `description`,
  `i`.`created_by`           AS `created_by`,
  `i`.`creation_date`        AS `creation_date`,
  `i`.`last_update_by`       AS `last_update_by`,
  `i`.`last_update_date`     AS `last_update_date`,
  `i`.`org_id`               AS `org_id`,
  `i0`.`item_id_m`           AS `item_id_m`,
  `i`.`from_org_id`          AS `from_org_id`,
  `i`.`from_subinventory_id` AS `from_subinventory_id`,
  `i`.`from_locator_id`      AS `from_locator_id`,
  `i`.`to_org_id`            AS `to_org_id`,
  `i`.`to_subinventory_id`   AS `to_subinventory_id`,
  `i`.`to_locator_id`        AS `to_locator_id`,
  `i`.`reference_type`       AS `reference_type`,
  `i`.`reference_key_name`   AS `reference_key_name`,
  `i`.`reference_key_value`  AS `reference_key_value`,
  `i`.`uom_id`               AS `uom_id`,
  `i`.`transaction_type_id`  AS `transaction_type_id`,
  `i`.`ir_line_id`           AS `ir_line_id`,
  `i`.`inv_transaction_id`   AS `inv_transaction_id`
FROM ((((((((`inv_transaction` `i`
          LEFT JOIN `item` `i0`
            ON ((`i`.`item_id_m` = `i0`.`item_id_m`)))
         LEFT JOIN `uom` `u`
           ON ((`i`.`uom_id` = `u`.`uom_id`)))
        LEFT JOIN `subinventory` `s`
          ON ((`i`.`from_subinventory_id` = `s`.`subinventory_id`)))
       LEFT JOIN `locator` `l`
         ON ((`i`.`from_locator_id` = `l`.`locator_id`)))
      LEFT JOIN `inv_lot_number` `lt`
        ON ((`lt`.`inv_lot_number_id` = `i`.`lot_number_id`)))
     LEFT JOIN `subinventory` `s0`
       ON ((`i`.`to_subinventory_id` = `s0`.`subinventory_id`)))
    LEFT JOIN `locator` `l0`
      ON ((`i`.`to_locator_id` = `l0`.`locator_id`)))
   LEFT JOIN `transaction_type` `t`
     ON ((`i`.`transaction_type_id` = `t`.`transaction_type_id`)))
   LEFT JOIN (inv_receipt_line irl JOIN inv_receipt_header irh ON irl.inv_receipt_header_id=irh.inv_receipt_header_id) ON (i.transaction_type_id IN (5,11) AND irl.inv_receipt_line_id=i.ir_line_id)
   LEFT JOIN (inv_issue_line iil JOIN inv_issue_header iih ON iil.inv_issue_header_id=iih.inv_issue_header_id) ON (i.transaction_type_id IN (6,14) AND iil.inv_issue_line_id=i.ir_line_id))$$

DELIMITER ;

DELIMITER $$

USE `xbs`$$

DROP TRIGGER /*!50032 IF EXISTS */ `inv_issue_lineUpdate`$$

CREATE
    /*!50017 DEFINER = 'i3u'@'localhost' */
    TRIGGER `inv_issue_lineUpdate` AFTER UPDATE ON `inv_issue_line` 
    FOR EACH ROW BEGIN
SELECT item_number,revision_name INTO @itemnumber,@itemrev FROM item i LEFT JOIN inv_item_revision v ON i.item_id_m=v.item_id_m AND i.org_id=v.org_id WHERE i.item_id_m=old.item_id_m AND i.org_id=old.org_id;
IF(new.status=1521 AND old.status=1520) THEN
SET @itemnumber=NULL;
SET @itemrev=NULL;
SET @anb=1;
SET @break=0;
#SELECT onhand FROM onhand WHERE (item_id_m,org_id,subinventory_id,locator_id)=(429,4,3,0);
#SELECT (i.allow_negative_balance_cb OR sub.allow_negative_balance_cb OR inv.allow_negative_balance_cb) xx FROM item i JOIN inventory inv ON i.org_id=inv.org_id,subinventory sub WHERE subinventory_id=3 AND item_id_m=429;
SELECT !(!IFNULL(i.allow_negative_balance_cb,1) OR !IFNULL(sub.allow_negative_balance_cb,1) OR !IFNULL(inv.allow_negative_balance_cb,1)) INTO @anb FROM item i JOIN inventory inv ON i.org_id=inv.org_id,subinventory sub WHERE subinventory_id=new.subinventory_id AND item_id_m=new.item_id_m;
IF @anb!=1 THEN
SELECT onhand INTO @onhand FROM onhand WHERE (item_id_m,org_id,subinventory_id,locator_id)=(new.item_id_m,new.org_id,new.subinventory_id,new.locator_id);
IF @onhand < new.transaction_quantity THEN
SET @break=1;
END IF;
END IF;
IF @break=0 THEN
INSERT INTO inv_transaction (item_id_m,item_number,revision_name,uom_id,reference_key_value,quantity,unit_cost,costed_amount,lot_number_id,from_subinventory_id,from_locator_id,reason,description,reference_type,reference_key_name,created_by,creation_date,last_update_by,last_update_date,org_id,transaction_type_id,ir_line_id)
VALUE(old.item_id_m,@itemnumber,@itemrev,old.uom_id,old.reference_key_value,old.transaction_quantity,old.unit_price,old.amount,old.lot_number,old.subinventory_id,old.locator_id,'','','table',old.reference_key_name,new.last_update_by,NOW(),new.last_update_by,NOW(),new.org_id,old.transaction_type_id,new.inv_issue_line_id);
ELSE
#new mysql vesion may use throw error
INSERT INTO xbs.xbs_log (log_level,task,program,msg,user_id,org_id,dt)VALUES('info','Issue_Complete','Line',CONCAT('Item ',new.item_id_m,Issue_Comlelte_Onhand_Is_NOT_Enough,new.transaction_quantity,'>',@onhand),new.last_update_by,new.org_id,NOW());
END IF;
ELSEIF(new.status=1522 AND old.status=1521) THEN
INSERT INTO inv_transaction (item_id_m,item_number,revision_name,uom_id,reference_key_value,quantity,unit_cost,costed_amount,lot_number_id,from_subinventory_id,from_locator_id,reason,description,reference_type,reference_key_name,created_by,creation_date,last_update_by,last_update_date,org_id,transaction_type_id,ir_line_id)
VALUE(old.item_id_m,@itemnumber,@itemrev,old.uom_id,old.reference_key_value,-old.transaction_quantity,old.unit_price,-old.amount,old.lot_number,old.subinventory_id,old.locator_id,'cancel','','table',old.reference_key_name,new.last_update_by,NOW(),new.last_update_by,NOW(),new.org_id,old.transaction_type_id,new.inv_issue_line_id);
END IF;
    END;
$$

DELIMITER ;

DELIMITER $$

USE `xbs`$$

DROP PROCEDURE IF EXISTS `wipissue`$$

CREATE DEFINER=`i3u`@`localhost` PROCEDURE `wipissue`(woid BIGINT,frs INT,frsn INT,trs INT,sets INT,org INT,userid INT)
BEGIN
DECLARE invitem INT;
DECLARE invusage INT;
DECLARE uomid INT;
DECLARE invqty DECIMAL(15,5);
DECLARE invsub INT;
DECLARE invloc INT;
DECLARE invsplytp INT;
DECLARE reqqty DECIMAL(15,5);
DECLARE issqty DECIMAL(15,5);
DECLARE autoreqmt INT;
DECLARE wwbid INT;
DECLARE done INT;
DECLARE itemnm VARCHAR(50);
DECLARE unitprice DOUBLE(18,2);
DECLARE anb BOOL; #alownegativebalance
DECLARE oh DECIMAL(15,5);
DECLARE wip_boms CURSOR FOR SELECT component_item_id_m,item_number,list_price,i.uom_id,usage_basis,usage_quantity,IFNULL(supply_sub_inventory,wip_supply_subinventory),IFNULL(supply_locator,wip_supply_locator),IFNULL(w.wip_supply_type,i.wip_supply_type),required_quantity,issued_quantity,auto_request_material_cb,wip_wo_bom_id,!(!IFNULL(i.allow_negative_balance_cb,1) OR !IFNULL(sub.allow_negative_balance_cb,1) OR !IFNULL(inv.allow_negative_balance_cb,1)),IFNULL(onhand,0) 
FROM wip_wo_bom w JOIN `wip_wo_header` `wo`ON `w`.`wip_wo_header_id` = `wo`.`wip_wo_header_id` JOIN item i ON (w.component_item_id_m=i.item_id_m AND wo.org_id=i.org_id) JOIN inventory inv ON i.org_id=inv.org_id JOIN subinventory sub ON sub.subinventory_id=w.supply_sub_inventory LEFT JOIN onhand ON onhand.subinventory_id=w.supply_sub_inventory AND onhand.locator_id=w.supply_locator AND onhand.item_id_m=i.item_id_m AND onhand.org_id=i.org_id WHERE w.wip_wo_header_id=woid AND ((routing_sequence=frs AND routing_seq_num=frsn AND IFNULL(w.wip_supply_type,i.wip_supply_type)=339) OR IFNULL(w.wip_supply_type,i.wip_supply_type) IN (IF(trs!=0,9999,338)));
#9999 is not a valid value, so wip_supply_type will not or should not be 9999
#SELECT osp_cb FROM wip_wo_routing_line wrl JOIN wip_wo_routing_detail wrd ON wrl.wip_wo_routing_line_id=wrd.wip_wo_routing_line_id JOIN bom_resource res ON wrd.resource_id=res.bom_resource_id WHERE (wrl.wip_wo_header_id,routing_sequence,routing_seq_num,osp_cb)=(woid,frs,frsn,1);
DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = 1;
    OPEN wip_boms;
    BEGIN_bom: LOOP
        FETCH wip_boms INTO invitem,itemnm,unitprice,uomid,invusage,invqty,invsub,invloc,invsplytp,reqqty,issqty,autoreqmt,wwbid,anb,oh;
        IF done THEN
            LEAVE begin_bom;
        END IF;
#        if(autoreqmt and invsplytp=339) then
        SET @iq=0;
        IF(invusage=351) THEN
        SET @iq=invqty*sets;
        ELSE IF(invusage=350) THEN
        IF(issqty>0) THEN
        SET @iq=0;
        ELSE
        SET @iq=invqty;
        END IF;
        END IF;
        END IF;
        IF(@iq!=0) THEN
        IF(anb OR @iq<=oh) THEN
        SET @amount=@iq*unitprice;
INSERT INTO inv_transaction (item_id_m,item_number,reference_key_value,quantity,uom_id,unit_cost,costed_amount,lot_number_id,from_subinventory_id,from_locator_id,reason,description,reference_type,reference_key_name,from_org_id,created_by,creation_date,last_update_by,last_update_date,org_id,transaction_type_id) 
VALUES(invitem,itemnm,wwbid,@iq,uomid,unitprice,@amount,'',invsub,invloc,IF(trs=0,'Assembly Pull','Operation Pull'),'','table','wip_wo_bom',org,userid,NOW(),userid,NOW(),'4',6);
#UPDATE wip_wo_bom SET issued_quantity=issued_quantity+@iq WHERE wip_wo_bom_id=wwbid; #done in inv_transaction
ELSE
#new mysql vesion may use throw error
INSERT INTO xbs.xbs_log (log_level,task,program,msg,user_id,org_id,dt)VALUES('info','WipIssue_Complete','Line',CONCAT('Item ',invitem,WipIssue_Onhand_Is_NOT_Enough,@iq,'>',oh),userid,org,NOW());
END IF;
END IF;
#end if;
    END LOOP begin_bom;
    CLOSE wip_boms;
    END$$

DELIMITER ;

DELIMITER $$

USE `xbs`$$

DROP VIEW IF EXISTS `wip_wo_routing_v`$$

CREATE ALGORITHM=UNDEFINED DEFINER=`i3u`@`localhost` SQL SECURITY DEFINER VIEW `wip_wo_routing_v` AS (
SELECT
  IF((ISNULL(`w0`.`parent_wo_id`) OR (`w0`.`parent_wo_id` = 0)),`w0`.`wo_number`,`wp`.`wo_number`) AS `wo_number`,
  `i`.`item_number`               AS `item_number`,
  `i`.`item_name`                 AS `item_name`,
  `i`.`item_specification`        AS `item_specification`,
  `i`.`item_description`          AS `item_description`,
  `st`.`option_line_value`        AS `status`,
  `w`.`queue_quantity`            AS `queue_quantity`,
  `w`.`running_quantity`          AS `running_quantity`,
  `w`.`rejected_quantity`         AS `rejected_quantity`,
  `w`.`scrapped_quantity`         AS `scrapped_quantity`,
  `w`.`completed_quantity`        AS `completed_quantity`,
  `w`.`routing_sequence`          AS `routing_sequence`,
  `w`.`routing_seq_num`           AS `routing_seq_num`,
  `b`.`standard_operation`        AS `standard_operation`,
  `b0`.`department`               AS `department`,
  `w`.`description`               AS `description`,
  `w0`.`start_date`               AS `start_date`,
  `w0`.`completion_date`          AS `completion_date`,
  `w`.`minimum_transfer_quantity` AS `minimum_transfer_quantity`,
  `w`.`yield`                     AS `yield`,
  `w`.`created_by`                AS `created_by`,
  `w`.`creation_date`             AS `creation_date`,
  `w`.`last_update_by`            AS `last_update_by`,
  `w`.`last_update_date`          AS `last_update_date`,
  `w`.`wip_wo_routing_line_id`    AS `wip_wo_routing_line_id`,
  `w`.`standard_operation_id`     AS `standard_operation_id`,
  `b0`.`bom_department_id`        AS `bom_department_id`,
  `wfl`.`firstSEQ`                AS `firstSeq`,
  `wfl`.`lastSEQ`                 AS `lastSeq`,
  (CASE WHEN `wfl`.`firstSEQ`=`wfl`.`lastSEQ` THEN 3 WHEN `w`.`routing_sequence`=`wfl`.`firstSEQ` THEN 1 WHEN `w`.`routing_sequence`=`wfl`.`lastSEQ` THEN 2 ELSE 0 END) AS `firstlast`,
  `w0`.`wo_type`                  AS `wo_type`,
  `w0`.`wo_status`                AS `wo_status`,
  `w0`.`wip_wo_header_id`         AS `wip_wo_header_id`,
  `w0`.`build_sequence`           AS `build_sequence`,
  `w0`.`line`                     AS `line`,
  `w0`.`scheduling_priority`      AS `scheduling_priority`,
  `w0`.`item_id_m`                AS `item_id_m`,
  `w0`.`org_id`                   AS `org_id`,
  IF((ISNULL(`w0`.`parent_wo_id`) OR (`w0`.`parent_wo_id` = 0)),`w0`.`wip_wo_header_id`,`wp`.`wip_wo_header_id`) AS `wo_id`
FROM (((((((`wip_wo_routing_line` `w`
         JOIN `wip_wo_routing_first_last_v` `wfl`
           ON ((`w`.`wip_wo_header_id` = `wfl`.`wip_wo_header_id`)))
        LEFT JOIN `wip_wo_header` `w0`
          ON ((`w`.`wip_wo_header_id` = `w0`.`wip_wo_header_id`)))
       LEFT JOIN `wip_wo_header` `wp`
         ON ((`w0`.`parent_wo_id` = `wp`.`wip_wo_header_id`)))
      LEFT JOIN `bom_standard_operation` `b`
        ON ((`w`.`standard_operation_id` = `b`.`bom_standard_operation_id`)))
     LEFT JOIN `bom_department` `b0`
       ON ((`w`.`department_id` = `b0`.`bom_department_id`)))
    LEFT JOIN `option_line` `st`
      ON ((`w0`.`wo_status` = `st`.`option_line_id`)))
   LEFT JOIN `item` `i`
     ON ((`w0`.`item_id_m` = `i`.`item_id_m`))))$$

DELIMITER ;

DELIMITER $$

USE `xbs`$$

DROP PROCEDURE IF EXISTS `wipOSP_Trans`$$

CREATE DEFINER=`i3u`@`localhost` PROCEDURE `wipOSP_Trans`(woid BIGINT,frs INT,frsn INT,trs INT,trsn INT,sets INT,mtid BIGINT,org INT,userid INT)
BEGIN
SET @resid=NULL;
SET @price=NULL;
SET @itemIdM=NULL;
SET @uomid=NULL;
SET @rtdid=NULL;
SET @rtlid=NULL;
SELECT resource_id,wip_wo_routing_detail_id,wip_wo_routing_line_id INTO @resid,@rtdid,@rtlid 
FROM wip_wo_routing_detail wrd JOIN bom_resource res ON wrd.resource_id=res.bom_resource_id AND res.osp_cb
#JOIN item i ON (res.osp_cb AND res.osp_item_id=i.item_id_m AND res.org_id=i.org_id) 
WHERE wip_wo_routing_line_id=(SELECT wip_wo_routing_line_id FROM wip_wo_routing_line WHERE wip_wo_header_id=woid AND routing_sequence=trs AND routing_seq_num=trsn) AND wrd.charge_type IN (344,346) LIMIT 0,1;
IF @rtlid IS NOT NULL THEN
SELECT i.item_id_m,uom_id INTO @itemIdM,@uomid FROM item i JOIN bom_resource res ON (res.osp_cb AND res.osp_item_id=i.item_id_m AND res.org_id=i.org_id) WHERE bom_resource_id=@resid;
IF @itemIdM IS NULL OR @itemIdM=0 THEN
SELECT i.item_id_m,uom_id INTO @itemIdM,@uomid FROM wip_wo_header wo JOIN item i ON (wo.item_id_m=i.item_id_m AND wo.org_id=i.org_id) WHERE wip_wo_header_id=woid AND (SELECT COUNT(*) FROM wip_wo_routing_line WHERE wip_wo_header_id=woid)=1;
END IF;
IF @itemIdM IS NOT NULL AND @itemIdM!=0 THEN
SET @standCostType=1;
SELECT SUM(amount) INTO @price FROM cst_item_cost_d_v WHERE (item_id_m,org_id,bom_cost_type,cost_element_type,this_level_cb)=(@itemIdM,org,@standCostType,551,1);
SET @prqid=NULL;
SET @buorg=NULL;
IF @price THEN
SET @supplier=NULL;
SET @sps=NULL;#counts suppliers for
SET @currency=NULL;
SET @payment=NULL;
SELECT parent_org_id INTO @buorg FROM org WHERE org_id=org;
SELECT supplier_id INTO @supplier FROM xbs.po_quote_supplier_v WHERE item_id_m=@itemIdM AND bu_org_id=@buorg LIMIT 0,1;
IF @supplier IS NOT NULL THEN
SELECT COUNT(0) INTO @sps FROM xbs.po_quote_supplier_v WHERE item_id_m=@itemIdM AND bu_org_id=@buorg;
SELECT currency_id,payment_term_id INTO @currency,@payment FROM supplier_all_v WHERE supplier_id=@supplier;
END IF;
INSERT INTO po_requisition_header (po_requisition_type,reference_key_name,reference_key_value,supplier_id,supplier_site_id,buyer,description,ship_to_id,bill_to_id,currency,payment_term_id,supply_org_id,bu_org_id,requisition_status,created_by,creation_date,last_update_by,last_update_date)
 VALUES('563','wip_wo_routing_detail',@rtdid,@supplier,'','','OSP',(SELECT address_id FROM address WHERE reftbltp='org' AND usage_type=1135 AND refid=org),(SELECT address_id FROM address WHERE reftbltp='org' AND usage_type=1136 AND refid=org),@currency,@payment,'',@buorg,321,userid,NOW(),userid,NOW());
SELECT LAST_INSERT_ID() INTO @prqid;
#UPDATE po_requisition_header SET po_requisition_number=CONCAT('po_req_4osp_',org,'_',@prqid) WHERE po_requisition_header_id=@prqid AND po_requisition_number IS NULL;
INSERT INTO po_requisition_line (po_requisition_header_id,line_type,receving_org_id,item_id_m,item_description,uom_id,unit_price,price_date,line_quantity,line_price,line_description,need_by_date,reference_key_name,reference_header_id,reference_line_id,created_by,creation_date,last_update_by,last_update_date) 
SELECT @prqid,'1619',org,@itemIdM,'',@uomid,@price,'',sets,@price*sets,'',NOW(),'wip_wo_routing_detail',woid,wip_wo_routing_detail_id,userid,NOW(),userid,NOW() 
FROM wip_wo_routing_detail wrd JOIN bom_resource res ON wrd.resource_id=res.bom_resource_id  AND res.osp_cb
#JOIN item i ON (res.osp_cb AND res.osp_item_id=i.item_id_m AND res.org_id=i.org_id) 
WHERE wip_wo_routing_line_id=@rtlid;
IF @sps=1 THEN
UPDATE po_requisition_header SET requisition_status=320 WHERE po_requisition_header_id=@prqid;
END IF;
ELSE
INSERT INTO xbs.xbs_log (log_level,task,program,msg,user_id,org_id,dt)VALUES('info','WO_Release','OSP_Trans',CONCAT('OSP Item ',@itemIdM,'\'s Cost Is NULL ',woid,'_',trs,'_',trsn),userid,org,NOW());
#insert into xbs_release_osp_error (xx) values (xx);
END IF;
ELSE
INSERT INTO xbs.xbs_log (log_level,task,program,msg,user_id,org_id,dt)VALUES('info','WO_Release','OSP_Trans',CONCAT('OSP Item Do Not Find For ',woid,'_',trs,'_',trsn),userid,org,NOW());
END IF;
ELSE
INSERT INTO xbs.xbs_log (log_level,task,program,msg,user_id,org_id,dt)VALUES('info','WO_Release','OSP_Trans',CONCAT('OSP Trans NO Need For ',woid,'_',trs,'_',trsn),userid,org,NOW());
END IF;
    END$$

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
SET @orp=0;
SET @qtyr=NULL;
SET @qtya=NULL;
SET @qtyp=NULL;
SELECT IFNULL(over_receipt_percentage,0) INTO @orp FROM item WHERE (item_id_m,org_id)=(new.item_id_m,new.to_org_id);
SELECT received_quantity,accepted_quantity,line_quantity INTO @qtyr,@qtya,@qtyp FROM po_line WHERE po_line_id=new.reference_key_value;
IF new.transaction_type_id=21 THEN
UPDATE po_line SET accepted_quantity=accepted_quantity-new.quantity,last_update_date=NOW() WHERE po_line_id=new.reference_key_value;
ELSEIF new.transaction_type_id=5 THEN
IF (@qtyr+new.quantity-@qtyp)/@qtyp>@orp THEN
INSERT INTO xbs.xbs_log (log_level,task,program,msg,user_id,org_id,dt)VALUES('info','po_inv','Accept',CONCAT('Item ',new.item_id_m,PO_INV_OVER_ACCEPT,'>',@orp),new.created_by,new.org_id,NOW());
END IF;
UPDATE po_line SET received_quantity=received_quantity+new.quantity,accepted_quantity=accepted_quantity+new.quantity,last_update_date=NOW() WHERE po_line_id=new.reference_key_value;
ELSEIF new.transaction_type_id=4 THEN
IF (@qtyr+new.quantity)/@qtyp>@orp THEN
INSERT INTO xbs.xbs_log (log_level,task,program,msg,user_id,org_id,dt)VALUES('info','po_inv','Receipt',CONCAT('Item ',new.item_id_m,PO_INV_OVER_RECEIPT,'>',@orp),new.created_by,new.org_id,NOW());
END IF;
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
ELSEIF new.transaction_type_id IN ('7','8') THEN
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
IF @res IS NOT NULL THEN
SELECT getCOAId(new.org_id,1604,'subinventory',new.from_subinventory_id) INTO @res_ac;
SELECT getCOAId(new.org_id,1575,'',0) INTO @res_ac_2;
END IF;
IF @osp IS NOT NULL THEN
SELECT getCOAId(new.org_id,1605,'subinventory',new.from_subinventory_id) INTO @osp_ac;
SELECT getCOAId(new.org_id,1576,'',0) INTO @osp_ac_2;
END IF;
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
IF @res IS NOT NULL THEN
SELECT getCOAId(new.org_id,1575,'',0) INTO @res_ac;
SELECT getCOAId(new.org_id,1604,'subinventory',new.to_subinventory_id) INTO @res_ac_2;
END IF;
IF @osp IS NOT NULL THEN
SELECT getCOAId(new.org_id,1576,'',0) INTO @osp_ac;
SELECT getCOAId(new.org_id,1605,'subinventory',new.to_subinventory_id) INTO @osp_ac_2;
END IF;
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

DELIMITER $$

USE `xbs`$$

DROP FUNCTION IF EXISTS `wipMoveTransInsert`$$

CREATE DEFINER=`i3u`@`localhost` FUNCTION `wipMoveTransInsert`(woid BIGINT,itemIdM BIGINT,quantity INT,frs INT,frsn INT,fos INT,trs INT,trsn INT,tos INT,reason VARCHAR(255),transtype VARCHAR(50),createby INT,updateby INT,orgid INT) RETURNS BIGINT(20)
BEGIN
SET @liid=NULL;
SET @cntneedissued=0;
SELECT queue_quantity,running_quantity INTO @qqty,@rqty FROM wip_wo_routing_line WHERE wip_wo_header_id=woid AND (routing_sequence,routing_seq_num)=(frs,frsn);
IF tos=382 THEN
IF @rqty < quantity THEN
INSERT INTO xbs.xbs_log (log_level,task,program,msg,user_id,org_id,dt)VALUES('info','WipMove_Trans','Line',CONCAT('WO ',woid,Wip_Move_More_Than_Running),userid,org,NOW());
RETURN 0;
END IF;
SELECT COUNT(0) INTO @cntneedissued FROM xbs.wip_wo_bom WHERE issued_quantity=0 AND (wip_supply_type IS NULL OR wip_supply_type=337) AND routing_sequence=frs AND routing_seq_num=frsn AND wip_wo_header_id=woid;
END IF;
IF tos=381 THEN
IF @rqty < quantity THEN
INSERT INTO xbs.xbs_log (log_level,task,program,msg,user_id,org_id,dt)VALUES('info','WipMove_Trans','Line',CONCAT('WO ',woid,Wip_Scrap_More_Than_Running),userid,org,NOW());
RETURN 0;
END IF;
END IF;
IF tos=378 THEN
IF @qqty < quantity THEN
INSERT INTO xbs.xbs_log (log_level,task,program,msg,user_id,org_id,dt)VALUES('info','WipMove_Trans','Line',CONCAT('WO ',woid,Wip_Run_More_Than_Queueing),userid,org,NOW());
RETURN 0;
END IF;
END IF;
IF @cntneedissued=0 THEN
IF(fos!=0 AND tos=382)THEN
CALL wipissue(woid,frs,frsn,trs,quantity,orgid,updateby);
CALL wipResTrans(woid,frs,frsn,trs,quantity,@liid,orgid,updateby);
ELSEIF(fos=382 AND tos=379) THEN
CALL wipissue(woid,trs,trsn,frs,-quantity,orgid,updateby);
CALL wipResTrans(woid,trs,trsn,frs,-quantity,@liid,orgid,updateby);
END IF;
IF tos=382 AND trs!=0 THEN
CALL wipOSP_Trans(woid,frs,frsn,trs,trsn,quantity,@liid,orgid,updateby);
END IF;
INSERT INTO wip_move_transaction (wip_wo_header_id,item_id_m,move_quantity,from_routing_sequence,from_routing_seq_num,from_operation_step,to_routing_sequence,to_routing_seq_num,to_operation_step,reason,transaction_type,transaction_date,created_by,creation_date,last_update_by,last_update_date,org_id) 
VALUES(woid,itemIdM,quantity,frs,frsn,fos,trs,trsn,tos,reason,transtype,NOW(),createby,NOW(),updateby,NOW(),orgid);
SELECT LAST_INSERT_ID() INTO @liid;
CALL wipmovetrans(woid,@liid,frs,frsn, fos, trs,trsn, tos, quantity,reason,updateby,orgid);
RETURN @liid;
ELSE
INSERT INTO xbs.xbs_log (log_level,task,program,msg,user_id,org_id,dt)VALUES('info','WipMove_Trans','Line',CONCAT('WO ',woid,Wip_Must_Issue_First),userid,org,NOW());
END IF;
RETURN 0;
END$$

DELIMITER ;

DELIMITER $$

USE `xbs`$$

DROP TRIGGER /*!50032 IF EXISTS */ `invReceiptLineInsert`$$

CREATE
    /*!50017 DEFINER = 'i3u'@'localhost' */
    TRIGGER `invReceiptLineInsert` BEFORE INSERT ON `inv_receipt_line` 
    FOR EACH ROW BEGIN
SET @rrtp=NULL;
SET @linenum=NULL;
SET @qty=NULL;
SET @qty_recv=NULL;
SELECT receipt_routing,IFNULL(over_receipt_percentage,0) INTO @rrtp,@orp FROM item WHERE item_id_m=new.item_id_m AND org_id=new.org_id;
IF new.reference_key_name='po_line' THEN
SELECT pl.line_quantity,SUM(amount) INTO @qty,@qty_recv FROM inv_receipt_line irl JOIN po_line pl ON irl.reference_key_name='po_line' AND irl.reference_key_value=pl.po_line_id 
WHERE reference_key_value=new.reference_key_value AND irl.status!=1522 GROUP BY pl.po_line_id;
IF (new.transaction_quantity+@qty_recv-@qty)/@qty>@orp THEN
INSERT INTO xbs.xbs_log (log_level,task,program,msg,user_id,org_id,dt)VALUES('info','po_recv','RECEIPT',CONCAT('Item ',new.item_id_m,PO_RECEIPT_OVER,'>',@qty),new.created_by,new.org_id,NOW());
END IF;
END IF;
IF new.reference_key_name='po_line' THEN
SELECT wo.quantity,IFNULL(wo.scrapped_quantity,0),COUNT(irl.transaction_quantity) INTO @qty,@qty_scrap,@qty_recv 
FROM inv_receipt_line irl JOIN wip_move_transaction wmt ON irl.reference_key_name='wip_move_transaction' AND irl.reference_key_value=wmt.wip_move_transaction_id 
JOIN wip_wo_header wo ON wmt.wip_wo_header_id=wo.wip_wo_header_id WHERE reference_key_value=new.reference_key_value AND irl.status!=1522 GROUP BY wo.wip_wo_header_id;
IF (new.transaction_quantity+@qty_recv+@qty_scrap)>@qty THEN
INSERT INTO xbs.xbs_log (log_level,task,program,msg,user_id,org_id,dt)VALUES('info','wip_complete_recv','RECEIPT',CONCAT('Item ',new.item_id_m,WIP_COMPLETE_RECEIPT_OVER,'>',@qty),new.created_by,new.org_id,NOW());
END IF;
END IF;
IF @rrtp=300 AND new.reference_key_name!='inv_receipt_line' THEN
#need qa so change to po_receipt and qa_complete will create new one po_dlv
#set new.transaction_type_id=4;
SET new.inspection_status=0;
END IF;
SELECT MAX(line_number) INTO @linenum FROM inv_receipt_line il JOIN inv_receipt_header ih ON il.inv_receipt_header_id=ih.inv_receipt_header_id WHERE il.inv_receipt_header_id=NEW.inv_receipt_header_id AND ih.STATUS=1519;
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

DROP TRIGGER /*!50032 IF EXISTS */ `inv_receipt_lineUpdate`$$

CREATE
    /*!50017 DEFINER = 'i3u'@'localhost' */
    TRIGGER `inv_receipt_lineUpdate` BEFORE UPDATE ON `inv_receipt_line` 
    FOR EACH ROW BEGIN
IF (new.status=old.status) AND new.status IN (1519,1520) AND (new.transaction_quantity!=old.transaction_quantity) AND (old.reference_key_name='po_line') THEN
SELECT IFNULL(over_receipt_percentage,0) INTO @orp FROM item WHERE item_id_m=new.item_id_m AND org_id=new.org_id;
SELECT pl.line_quantity,SUM(amount) INTO @qty,@qty_recv FROM inv_receipt_line irl JOIN po_line pl ON irl.reference_key_name='po_line' AND irl.reference_key_value=pl.po_line_id 
WHERE reference_key_value=new.reference_key_value AND irl.status!=1522 GROUP BY pl.po_line_id;
IF (new.transaction_quantity+@qty_recv-@qty)/@qty>@orp THEN
INSERT INTO xbs.xbs_log (log_level,task,program,msg,user_id,org_id,dt)VALUES('info','po_recv','RECEIPT',CONCAT('Item ',new.item_id_m,PO_RECEIPT_OVER,'>',@qty),new.created_by,new.org_id,NOW());
END IF;
END IF;
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

#@20190109
DELIMITER $$

USE `xbs`$$

DROP PROCEDURE IF EXISTS `tbColumnAddChg`$$

CREATE DEFINER=`i3u`@`localhost` PROCEDURE `tbColumnAddChg`(
    IN dbName TINYTEXT,
    IN tableName TINYTEXT,
    IN fieldName TINYTEXT,
    IN fieldNameNew TINYTEXT,
    IN fieldDef TEXT,
    IN komt TEXT,
    IN colAfter TINYTEXT)#modify@20190125
BEGIN
    SET @ddl=CONCAT('ALTER TABLE ',dbName,'.',tableName);
    IF NOT EXISTS (SELECT * FROM information_schema.COLUMNS WHERE column_name=fieldName AND table_name=tableName AND table_schema=dbName) THEN
	IF fieldNameNew='' THEN
	    SET @ddl=CONCAT(@ddl,' ADD COLUMN ');
	ELSE 
	    SET @ddl=CONCAT(@ddl,' change ',fieldNameNew,' ');
	END IF;
    ELSE
        SET @ddl=CONCAT(@ddl,' change ',fieldName,' ');
    END IF;
    IF fieldNameNew='' THEN
	SET @ddl=CONCAT(@ddl,fieldName,' ',fieldDef);
    ELSE
	SET @ddl=CONCAT(@ddl,fieldNameNew,' ',fieldDef);
    END IF;
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

DROP TRIGGER /*!50032 if exists */ `xbs`.`sys_process_flow_line_insertB`;

CALL tbColumnAddChg('xbs','cc_co_template_line','required_cb','','TINYINT(1) DEFAULT 0','','');
#CALL tbColumnAddChg('xbs','cc_co_template_line','value_type','','ENUM(\'TEXT\',\'SELECT\',\'MULTI_SELECT\',\'TEXT_AREA\',\'CHECK_BOX\')','','');
CALL tbColumnAddChg('xbs','sys_process_flow_action','user_id','userid','INT(11) default null','','');
CALL tbColumnAddChg('xbs','cc_co_process_flow_action','user_id','userid','INT(11) default null','','');
CALL tbColumnAddChg('xbs','sys_process_flow_header','status','','TINYINT(1) DEFAULT 1','','');
CALL tbColumnAddChg('xbs','sys_process_flow_action','required_cb','','TINYINT(1) DEFAULT 0','','');
CALL tbColumnAddChg('xbs','cc_co_template_header','reftbltp','','ENUM(\'Item\',\'BOM\',\'BOM_Routing\')','','template_name');
CALL tbIndexAddModify('xbs','cc_co_header','release_number','UNIQUE','security_level,change_type,template_id');
CALL tbIndexAddModify('xbs','cc_co_header','po_header_id','UNIQUE','security_level,cc_co_header_id,template_id');
CALL tbColumnAddChg('xbs','cc_co_line_value','ref_id','','INT(11) default 0','lineid of bomline,etc','cc_co_template_line_id');
CALL tbIndexAddModify('xbs','cc_co_line_value','cc_co_line_id','UNIQUE','cc_co_line_id,cc_co_template_line_id,ref_id');

#@20190119
DELIMITER $$

DROP PROCEDURE IF EXISTS `xbs`.`tbIndexDrop` $$
CREATE PROCEDURE `xbs`.`tbIndexDrop` (tblSchema VARCHAR(64),tblName VARCHAR(64),ndxName VARCHAR(64))
BEGIN
    DECLARE IndexColumnCount INT;
    DECLARE SQLStatement VARCHAR(256);
    SELECT COUNT(1) INTO IndexColumnCount
    FROM information_schema.statistics
    WHERE table_schema = tblSchema
    AND table_name = tblName
    AND index_name = ndxName;
    IF IndexColumnCount > 0 THEN
        SET SQLStatement = CONCAT('ALTER TABLE `',tblSchema,'`.`',tblName,'` DROP INDEX`',ndxName,'`');
        SET @SQLStmt = SQLStatement;
        PREPARE s FROM @SQLStmt;
        EXECUTE s;
        DEALLOCATE PREPARE s;
    END IF;
END $$

DELIMITER ;

CALL tbIndexDrop('xbs','cc_co_process_flow_action','document_type_name');
CALL tbIndexDrop('xbs','cc_co_process_flow_action','sys_process_flow_line_id_2');
CALL tbIndexAddModify('xbs','cc_co_process_flow_action','sys_process_flow_line_id','UNIQUE','cc_co_header_id,sys_process_flow_line_id,userid');

DELIMITER $$

USE `xbs`$$

DROP TRIGGER /*!50032 IF EXISTS */ `cc_co_process_flow_action_insert`$$

CREATE
    /*!50017 DEFINER = 'i3u'@'localhost' */
    TRIGGER `cc_co_process_flow_action_insert` AFTER INSERT ON `cc_co_process_flow_action` 
    FOR EACH ROW BEGIN
SET @linetp=NULL;
SET @cntfa=NULL;
SET @cntcofa=NULL;
SELECT line_type,COUNT(fa.sys_process_flow_line_id),COUNT(cofa.cc_co_process_flow_action_id) 
INTO @linetp,@cntfa,@cntcofa 
FROM sys_process_flow_line fl 
JOIN sys_process_flow_action fa ON fa.sys_process_flow_line_id=fl.sys_process_flow_line_id AND fa.required_cb
LEFT JOIN cc_co_process_flow_action cofa ON cofa.action_number=fa.action_number AND cofa.sys_process_flow_line_id=fa.sys_process_flow_line_id 
WHERE fa.sys_process_flow_line_id=new.sys_process_flow_line_id GROUP BY fa.sys_process_flow_line_id;
IF @cntfa=@cntcofa THEN
IF @linetp='decision' THEN
UPDATE cc_co_header co JOIN sys_process_flow_line pfl ON co.process_flow_header_id=pfl.sys_process_flow_header_id AND sys_process_flow_line_id=new.sys_process_flow_line_id SET STATUS=IF(new.field_value='approval',1567,1565),current_process_flow_line_id=IF(new.field_value='approval',next_line_seq_pass,next_line_seq_fail) WHERE cc_co_header_id=new.cc_co_header_id AND STATUS=1566;
#SELECT CONCAT('update ',reftbltp,' set ',fieldvs,' where cc_co_header_id=',new.cc_co_header_id) into @tsql FROM
#(SELECT reftbltp,GROUP_CONCAT(CONCAT(field_name,'=',field_value)) fieldvs,cc_co_header_id
#FROM cc_co_line_value colv 
#JOIN cc_co_template_line cotl ON colv.cc_co_template_line_id=cotl.cc_co_template_line_id 
#JOIN cc_co_template_header coth ON cotl.cc_co_template_header_id=coth.cc_co_template_header_id
#JOIN cc_co_header coh ON cotl.cc_co_template_header_id=coh.template_id GROUP BY coth.cc_co_template_header_id) t
#WHERE cc_co_header_id=new.cc_co_header_id;
#Dynamic SQL is not allowed in stored function or trigger
#PREPARE ins FROM @tsql;
#EXECUTE ins;
END IF;
IF new.pf_action_type='approval' THEN
UPDATE cc_co_header co JOIN sys_process_flow_line pfl ON co.process_flow_header_id=pfl.sys_process_flow_header_id AND sys_process_flow_line_id=new.sys_process_flow_line_id SET STATUS=IF(new.field_value='approval',1566,1565),current_process_flow_line_id=IF(new.field_value='approval',next_line_seq_pass,next_line_seq_fail) WHERE cc_co_header_id=new.cc_co_header_id AND STATUS=1566;
END IF;
END IF;
    END;
$$

DELIMITER ;

#@20190120
CALL tbColumnAddChg('xbs','sys_pd_process_flow_action','user_id','userid','INT(11) default null','','');

#@20190121
CALL tbIndexDrop('xbs','sys_pd_header','release_number');
CALL tbIndexDrop('xbs','sys_pd_header','po_header_id');
CALL tbIndexAddModify('xbs','sys_pd_process_flow_action','sys_pd_header_id','UNIQUE','sys_pd_header_id,sys_process_flow_line_id,userid');
CALL tbIndexAddModify('xbs','sys_pd_header','primary_document','UNIQUE','primary_document,primary_document_id,security_level');

#@20190122
CALL tbColumnAddChg('xbs','sys_process_flow_header','access_org_type','','INT(11) DEFAULT NULL','','module_name');

INSERT IGNORE INTO xbs.`module_class` (`module_class_id`, `parent_id`, `name`, `module_class_link`, `description`, `module_code`, `obj_class_name`, `pmode`, `status`, `id_column_name`, `module_class_type`, `display_weight`, `created_by`, `creation_date`, `last_update_by`, `last_update_date`) VALUES('51','0','pd_process','','审批流处理IO','sys',NULL,NULL,'1',NULL,NULL,NULL,'14','2019-01-29 16:12:02','14','2019-01-29 16:12:36');

#@201900301
insert IGNORE into xbs.xerp_role (role_name_cn,role_name_eng,org_id,role_layout,created_by,creation_date,last_update_by,last_update_date) values('人力资源','hr','','layout/ucin/xbs/xbs_hr.xml','14',now(),'14',now());

DELIMITER $$

USE `xbs`$$

DROP PROCEDURE IF EXISTS `GenPayrollSch`$$

CREATE DEFINER=`i3u`@`localhost` PROCEDURE `GenPayrollSch`(prid VARCHAR(10),dtStart DATE,dtEnd DATE,userid INT(11))
BEGIN
DECLARE dt DATE;
DECLARE i INT;
SET i=1;
    SELECT SUBDATE(dtStart,DATE_FORMAT(dtStart,'%d')-1) INTO dt;
WHILE dt <= dtEnd AND i<25 DO
INSERT IGNORE INTO xbs.hr_payroll_schedule (hr_payroll_id,scheduled_date,start_date,end_date,period_name,description,STATUS,created_by,creation_date,last_update_by,last_update_date) 
VALUES (prid,LAST_DAY(dt),dt,LAST_DAY(dt),CONCAT(SUBSTR(DATE_FORMAT(dt, '%M'),1,3),'-',SUBSTR(YEAR(dt),-2)),CONCAT('Generated by SYS @ ',NOW()),'OPEN',userid,NOW(),userid,NOW());
SET dt = DATE_ADD(dt, INTERVAL 1 MONTH);
SET i = i+1;
END WHILE;
    END$$

DELIMITER ;

#CALL GenPayrollSch(payrollid,NOW(),DATE_ADD(NOW(),INTERVAL 2 YEAR),14);
#@201900302
UPDATE `xbs`.`option_line` SET `value_group_id`='0' WHERE `option_line_id`='880';
UPDATE `xbs`.`option_line` SET `value_group_id`='0' WHERE `option_line_id`='881';
UPDATE `xbs`.`option_line` SET `value_group_id`='0' WHERE `option_line_id`='882';
UPDATE `xbs`.`option_line` SET `value_group_id`='1' WHERE `option_line_id`='883';
UPDATE `xbs`.`option_line` SET `value_group_id`='1' WHERE `option_line_id`='884';
UPDATE `xbs`.`option_line` SET `value_group_id`=IF(SUBSTR(option_line_code,1,1)='E','1','0') WHERE `option_header_id`=194;
CALL tbColumnAddChg('xbs','hr_compensation_element','status','','TINYINT(1) DEFAULT 1','','');
update xbs.option_header set option_type='HR_APPROVAL_STATUS',description='HR APPROVAL_STATUS ',last_update_by='14',last_update_date=now() where option_header_id='291';
CALL tbColumnAddChg('xbs','hr_employee_termination','status','','INT(11) default null','','');
CALL tbColumnAddChg('xbs','hr_expense_header','status','','INT(11) default null','','');
CALL tbColumnAddChg('xbs','hr_leave_transaction','leave_status','','INT(11) default null','','');

#@201900303
CALL tbColumnAddChg('xbs','hr_employee','employee_number','','VARCHAR(25) default null','','hr_employee_id');
UPDATE xbs.hr_employee SET employee_number=CONCAT('EN_19',LPAD((hr_employee_id), 3, '0'));
CALL tbIndexAddModify('xbs','hr_employee','employee_number','UNIQUE','employee_number');

#@201900304
DELIMITER $$

USE `xbs`$$

DROP TRIGGER /*!50032 IF EXISTS */ `sys_pd_process_flow_action_insert`$$

CREATE
    /*!50017 DEFINER = 'i3u'@'localhost' */
    TRIGGER `sys_pd_process_flow_action_insert` AFTER INSERT ON `sys_pd_process_flow_action` 
    FOR EACH ROW BEGIN
SET @linetp=NULL;
SET @cntfa=NULL;
SET @cntpdfa=NULL;
SELECT line_type,COUNT(fa.sys_process_flow_line_id),COUNT(pdfa.sys_pd_process_flow_action_id) 
INTO @linetp,@cntfa,@cntpdfa 
FROM sys_process_flow_line fl 
JOIN sys_process_flow_action fa ON fa.sys_process_flow_line_id=fl.sys_process_flow_line_id AND fa.required_cb AND fa.pf_action_type='approval' 
LEFT JOIN sys_pd_process_flow_action pdfa ON pdfa.action_number=fa.action_number AND pdfa.sys_process_flow_line_id=fa.sys_process_flow_line_id 
WHERE fa.sys_process_flow_line_id=new.sys_process_flow_line_id GROUP BY fa.sys_process_flow_line_id;
#only one can decline(325) if pd status is 327, only decision line and all its action is approval will approved(326) 
IF @linetp!='end' THEN
IF @cntfa=@cntpdfa THEN
IF @linetp='decision' THEN
UPDATE sys_pd_header pd JOIN sys_process_flow_line pfl ON pd.process_flow_header_id=pfl.sys_process_flow_header_id AND sys_process_flow_line_id=new.sys_process_flow_line_id SET STATUS=IF(new.field_value='approval',326,325),current_process_flow_line_id=IF(new.field_value='approval',next_line_seq_pass,next_line_seq_fail) WHERE sys_pd_header_id=new.sys_pd_header_id AND STATUS=327;
ELSEIF new.pf_action_type='approval' THEN
UPDATE sys_pd_header pd JOIN sys_process_flow_line pfl ON pd.process_flow_header_id=pfl.sys_process_flow_header_id AND sys_process_flow_line_id=new.sys_process_flow_line_id SET STATUS=IF(new.field_value='approval',327,325),current_process_flow_line_id=IF(new.field_value='approval',next_line_seq_pass,next_line_seq_fail) WHERE sys_pd_header_id=new.sys_pd_header_id AND STATUS=327;
END IF;
ELSE
IF new.pf_action_type='approval' AND new.field_value!='approval' THEN
UPDATE sys_pd_header pd JOIN sys_process_flow_line pfl ON pd.process_flow_header_id=pfl.sys_process_flow_header_id AND sys_process_flow_line_id=new.sys_process_flow_line_id SET STATUS=325,current_process_flow_line_id=next_line_seq_fail WHERE sys_pd_header_id=new.sys_pd_header_id AND STATUS=327;
END IF;
END IF;
SET @pd=NULL;
SET @pdid=NULL;
SET @pdstatus=NULL;
SELECT primary_document,primary_document_id,STATUS INTO @pd,@pdid,@pdstatus FROM sys_pd_header WHERE sys_pd_header_id=new.sys_pd_header_id AND STATUS IN (325,326);
#do while pd status is 325 or 326
IF @pdstatus IS NOT NULL THEN
SET @pdstatus=IF((@pdstatus=325 AND @linetp!='decision'),321,@pdstatus);
END IF;
IF @pd='po_header' THEN
UPDATE po_header ph JOIN po_line pl ON ph.po_header_id=pl.po_header_id SET po_status=@pdstatus,STATUS=IF(@pdstatus=326,1498,1497),ph.last_update_by=new.last_update_by,ph.last_update_date=NOW() WHERE ph.po_header_id=@pdid;# and po_status=324 and STATUS=1497
ELSEIF @pd='po_quote_header' THEN
UPDATE po_quote_header SET approval_status=@pdstatus,quote_status=IF(@pdstatus=326,1489,1486),last_update_by=new.last_update_by,last_update_date=NOW() WHERE po_quote_header_id=@pdid;# and quote_status=1487 and approval_status=324;
ELSEIF @pd='po_requisition_header' THEN
UPDATE po_requisition_header ph JOIN po_requisition_line pl ON ph.po_requisition_header_id=pl.po_requisition_header_id SET requisition_status=@pdstatus,ph.last_update_by=new.last_update_by,ph.last_update_date=NOW() WHERE ph.po_requisition_header_id=@pdid;# AND requisition_status=324 AND (bu_org_id='%{orgid}' or receving_org_id='%{orgid}');
ELSEIF @pd='sd_so_header' THEN
UPDATE sd_so_header so JOIN sd_so_line sl ON so.sd_so_header_id=sl.sd_so_header_id SET approval_status=@pdstatus,so.so_status=IF(@pdstatus=326,535,537),line_status=IF(@pdstatus=326,1530,1529),so.last_update_by=new.last_update_by,so.last_update_date=NOW() WHERE so.sd_so_header_id=@pdid;# and approval_status=320;
ELSEIF @pd='sd_quote_header' THEN
UPDATE sd_quote_header SET approval_status=@pdstatus,STATUS=IF(@pdstatus=326,1489,1486),last_update_by=new.last_update_by,last_update_date=NOW() WHERE sd_quote_header_id=@pdid;# and approval_status=320;
ELSEIF @pd='hr_leave_transaction' THEN  #status set to null and doc will be editable in some type docs
UPDATE hr_leave_transaction SET leave_status=IF(@pdstatus=321,NULL,IF(@pdstatus=326,1494,1495)),approved_by_employee_id=IF(@pdstatus=321,NULL,IF(@pdstatus=326,new.last_update_by,NULL)),approved_date=IF(@pdstatus=321,NULL,IF(@pdstatus=326,NOW(),NULL)) WHERE hr_leave_transaction_id=@pdid;# and approval_status=1494;
ELSEIF @pd='hr_overtime_transaction' THEN  #status set to null and doc will be editable in some type docs
UPDATE hr_overtime_transaction SET overtime_status=IF(@pdstatus=321,NULL,IF(@pdstatus=326,1494,1495)),approved_by_employee_id=IF(@pdstatus=321,NULL,IF(@pdstatus=326,new.last_update_by,NULL)),approved_date=IF(@pdstatus=321,NULL,IF(@pdstatus=326,NOW(),NULL)) WHERE hr_overtime_transaction_id=@pdid;# and approval_status=1494;
ELSEIF @pd='hr_employee_termination' THEN
UPDATE hr_employee_termination SET STATUS=IF(@pdstatus=321,NULL,IF(@pdstatus=326,1494,1495)),accpeted_by_employee_id=IF(@pdstatus=321,NULL,IF(@pdstatus=326,new.last_update_by,NULL)),accpeted_date=IF(@pdstatus=321,NULL,IF(@pdstatus=326,NOW(),NULL)) WHERE hr_employee_termination_id=@pdid;# and approval_status=1494;
ELSEIF @pd='hr_expense_header' THEN
UPDATE hr_expense_header SET STATUS=IF(@pdstatus=321,NULL,IF(@pdstatus=326,1494,1495)),approved_by_employee_id=IF(@pdstatus=321,NULL,IF(@pdstatus=326,new.last_update_by,NULL)),approved_date=IF(@pdstatus=321,NULL,IF(@pdstatus=326,NOW(),NULL)) WHERE hr_expense_header_id=@pdid;# and approval_status=1494;
END IF;
END IF;
    END;
$$

DELIMITER ;

CALL tbColumnAddChg('xbs','hr_leave_type','status','','TINYINT(1) DEFAULT 1','','');
DROP TABLE IF EXISTS xbs.`a_fake_ids`;
CREATE TABLE `a_fake_ids` (
  `fake_id` INT(11) NOT NULL AUTO_INCREMENT,
  PRIMARY KEY  (`fake_id`)
) ENGINE=MYISAM DEFAULT CHARSET=utf8;
DELIMITER $$

USE `xbs`$$

DROP PROCEDURE IF EXISTS `create_fake_ids`$$

CREATE DEFINER=`i3u`@`localhost` PROCEDURE `create_fake_ids`(cnt INT UNSIGNED)
BEGIN
DECLARE s INT UNSIGNED DEFAULT 1;
    TRUNCATE TABLE a_fake_ids;
    INSERT INTO a_fake_ids SELECT s;
    WHILE s*2<=cnt DO
        BEGIN
            INSERT INTO a_fake_ids SELECT `fake_id`+s FROM a_fake_ids;
            SET s=s*2;
        END;
    END WHILE;
    END$$

DELIMITER ;
CALL create_fake_ids(512);

DELIMITER $$

USE `xbs`$$

DROP VIEW IF EXISTS `dates_v`$$

CREATE ALGORITHM=UNDEFINED DEFINER=`i3u`@`localhost` SQL SECURITY DEFINER VIEW `dates_v` AS (
SELECT DISTINCT
  DATE_FORMAT((CURDATE() + INTERVAL (`a_fake_ids`.`fake_id` - 480) DAY),_utf8'%Y-%m-%d') AS `dtr`
FROM `a_fake_ids`
WHERE (CURDATE() + INTERVAL(`a_fake_ids`.`fake_id` - 480)DAY))$$

DELIMITER ;

DROP TABLE IF EXISTS xbs.`hr_overtime_transaction`;
CREATE TABLE xbs.`hr_overtime_transaction` (
  `hr_overtime_transaction_id` INT(12) UNSIGNED NOT NULL AUTO_INCREMENT,
  `employee_id` INT(12) NOT NULL,
  `requsted_date` DATE DEFAULT NULL,
  `approved_date` DATE DEFAULT NULL,
  `approved_by` VARCHAR(100) DEFAULT NULL,
  `approved_by_employee_id` INT(12) DEFAULT NULL,
  `overtime_status` INT(11) DEFAULT NULL,
  `overtime_type` VARCHAR(50) NOT NULL,
  `transaction_type` VARCHAR(25) DEFAULT NULL,
  `overtime_quantity` DECIMAL(20,5) NOT NULL,
  `from_datetime` DATETIME NOT NULL,
  `to_datetime` DATETIME NOT NULL,
  `reason` VARCHAR(255) DEFAULT NULL,
  `contact_details` VARCHAR(255) DEFAULT NULL,
  `sys_notification_id` INT(12) DEFAULT NULL,
  `sys_notification_group_id` INT(12) DEFAULT NULL,
  `created_by` INT(12) NOT NULL,
  `creation_date` DATETIME NOT NULL,
  `last_update_by` INT(12) NOT NULL,
  `last_update_date` DATETIME NOT NULL,
  PRIMARY KEY  (`hr_overtime_transaction_id`)
) ENGINE=INNODB DEFAULT CHARSET=utf8;
DROP TABLE IF EXISTS xbs.`hr_overtime_type`;
CREATE TABLE xbs.`hr_overtime_type` (
  `hr_overtime_type_id` INT(12) UNSIGNED NOT NULL AUTO_INCREMENT,
  `overtime_type` VARCHAR(50) NOT NULL,
  `overtime_category` VARCHAR(50) NOT NULL,
  `description` VARCHAR(255) DEFAULT NULL,
  `auto_convert_salary_cb` TINYINT(1) DEFAULT NULL,
  `status` TINYINT(1) DEFAULT '1',
  `created_by` INT(12) NOT NULL,
  `creation_date` DATETIME DEFAULT NULL,
  `last_update_by` INT(12) NOT NULL,
  `last_update_date` DATETIME DEFAULT NULL,
  PRIMARY KEY  (`hr_overtime_type_id`),
  UNIQUE KEY `overtime_type` (`overtime_type`)
) ENGINE=INNODB DEFAULT CHARSET=utf8;
DROP TABLE IF EXISTS xbs.`hr_crew`;
CREATE TABLE xbs.`hr_crew` (
  `hr_crew_id` BIGINT(20) NOT NULL AUTO_INCREMENT,
  `crew_number` VARCHAR(20) DEFAULT NULL,
  `leader_employee_id` BIGINT(20) DEFAULT NULL,
  `org_id` INT(12) DEFAULT NULL,
  `description` VARCHAR(255) DEFAULT NULL,
  `active` TINYINT(1) DEFAULT '1',
  `created_by` INT(12) NOT NULL,
  `creation_date` DATETIME DEFAULT NULL,
  `last_update_by` INT(12) NOT NULL,
  `last_update_date` DATETIME DEFAULT NULL,
  PRIMARY KEY  (`hr_crew_id`),
  UNIQUE KEY `leader_employee_id` (`leader_employee_id`)
) ENGINE=INNODB DEFAULT CHARSET=utf8;

#@201900305
DROP TABLE IF EXISTS xbs.`hr_crew_shift`;
CREATE TABLE xbs.`hr_crew_shift` (
  `hr_crew_shift_id` BIGINT(20) NOT NULL AUTO_INCREMENT,
  `hr_crew_id` BIGINT(20) NOT NULL,
  `hr_shift_id` BIGINT(20) NOT NULL,
  `from_date` DATE NOT NULL,
  `to_date` DATE NOT NULL,
  `description` VARCHAR(255) DEFAULT NULL,
  `active` TINYINT(1) DEFAULT '1',
  `created_by` INT(12) NOT NULL,
  `creation_date` DATETIME DEFAULT NULL,
  `last_update_by` INT(12) NOT NULL,
  `last_update_date` DATETIME DEFAULT NULL,
  PRIMARY KEY  (`hr_crew_shift_id`)
) ENGINE=INNODB DEFAULT CHARSET=utf8;
DROP TABLE IF EXISTS xbs.`hr_employee_crew`;
CREATE TABLE xbs.`hr_employee_crew` (
  `hr_employee_crew_id` BIGINT(20) NOT NULL AUTO_INCREMENT,
  `hr_employee_id` BIGINT(20) NOT NULL,
  `hr_crew_id` BIGINT(20) NOT NULL,
  `from_date` DATE NOT NULL,
  `to_date` DATE NOT NULL,
  `description` VARCHAR(255) DEFAULT NULL,
  `active` TINYINT(1) DEFAULT '1',
  `created_by` INT(12) NOT NULL,
  `creation_date` DATETIME DEFAULT NULL,
  `last_update_by` INT(12) NOT NULL,
  `last_update_date` DATETIME DEFAULT NULL,
  PRIMARY KEY  (`hr_employee_crew_id`)
) ENGINE=INNODB DEFAULT CHARSET=utf8;
DROP TABLE IF EXISTS xbs.`hr_shift`;
CREATE TABLE xbs.`hr_shift` (
  `hr_shift_id` BIGINT(19) NOT NULL AUTO_INCREMENT,
  `shift_name` VARCHAR(20) DEFAULT NULL,
  `shift_color` VARCHAR(32) DEFAULT NULL,
  `from_time` TIME DEFAULT NULL,
  `to_time` TIME DEFAULT NULL,
  `cross_day` TINYINT(1) NOT NULL DEFAULT '0',
  `org_id` INT(11) DEFAULT NULL,
  `status` TINYINT(1) NOT NULL DEFAULT '1',
  `created_by` INT(12) NOT NULL,
  `creation_date` DATETIME DEFAULT NULL,
  `last_update_by` INT(12) NOT NULL,
  `last_update_date` DATETIME DEFAULT NULL,
  PRIMARY KEY  (`hr_shift_id`)
) ENGINE=INNODB DEFAULT CHARSET=utf8;
DROP TABLE IF EXISTS xbs.`hr_holiday`;
CREATE TABLE xbs.`hr_holiday` (
  `hr_holiday_id` BIGINT(19) NOT NULL AUTO_INCREMENT,
  `holiday_date` DATE NOT NULL,
  `holiday_type_id` INT(11) NOT NULL,
  `description` VARCHAR(255) DEFAULT NULL,
  `status` TINYINT(1) NOT NULL DEFAULT '1',
  `org_id` INT(11) DEFAULT NULL,
  `created_by` INT(12) NOT NULL,
  `creation_date` DATETIME DEFAULT NULL,
  `last_update_by` INT(12) NOT NULL,
  `last_update_date` DATETIME DEFAULT NULL,
  PRIMARY KEY  (`hr_holiday_id`)
) ENGINE=INNODB DEFAULT CHARSET=utf8;
DELIMITER $$

USE `xbs`$$

DROP PROCEDURE IF EXISTS `GenHolidays`$$

CREATE DEFINER=`i3u`@`localhost` PROCEDURE `GenHolidays`(orgid VARCHAR(10),dtStart DATE,dtEnd DATE,userid INT(11))
BEGIN
DECLARE dt DATE;
DECLARE i INT;
SET i=1;
    SELECT SUBDATE(dtStart,DATE_FORMAT(dtStart,'%w')-7) INTO dt;
WHILE dt <= dtEnd AND i<25 DO
INSERT IGNORE INTO xbs.hr_holiday (holiday_date, holiday_type_id, description, STATUS, org_id,created_by,creation_date,last_update_by,last_update_date) 
VALUES (SUBDATE(dt,1),1,CONCAT('Generated by SYS @ ',NOW()),1,orgid,userid,NOW(),userid,NOW()),(dt,1,CONCAT('Generated by SYS @ ',NOW()),1,orgid,userid,NOW(),userid,NOW());
SET dt = ADDDATE(dt,7);
SET i = i+1;
END WHILE;
    END$$

DELIMITER ;
#CALL GenHolidays(3,DATE_ADD(CURDATE(), INTERVAL - DAY(CURDATE()) + 1 DAY),LAST_DAY(CURDATE()),17);
CALL tbColumnAddChg('xbs','bom_cal_week_start_dates','seq_num','','int(11) NOT NULL auto_increment','','');
DELIMITER $$

USE `xbs`$$

DROP PROCEDURE IF EXISTS `GenCalWeeks`$$

CREATE DEFINER=`i3u`@`localhost` PROCEDURE `GenCalWeeks`(cc VARCHAR(10),dtStart DATE,dtEnd DATE)
BEGIN
DECLARE dt DATE;
DECLARE i INT;
SET i=1;
    SELECT SUBDATE(dtStart,DATE_FORMAT(dtStart,'%w')-7) INTO dt;
WHILE dt <= dtEnd AND i<100 DO
INSERT IGNORE INTO bom_cal_week_start_dates VALUES (cc,1,NULL,dt,ADDDATE(dt,6),SUBDATE(dt,7),ADDDATE(dt,7));
SET dt = ADDDATE(dt,7);
SET i = i+1;
END WHILE;
    END$$

DELIMITER ;

#@201900305
CALL tbColumnAddChg('xbs','hr_crew','bDefault','','TINYINT(1) DEFAULT 0','','description');

#@20190404
DELIMITER $$

USE `xbs`$$

DROP VIEW IF EXISTS `employees_v`$$

CREATE ALGORITHM=UNDEFINED DEFINER=`i3u`@`localhost` SQL SECURITY DEFINER VIEW `employees_v` AS (
SELECT
  CONCAT(`he`.`last_name`,_utf8' ',`he`.`first_name`) AS `employee_name`,
  `o`.`org`             AS `org`,
  `he`.`phone`          AS `phone`,
  `he`.`email`          AS `email`,
  `dp`.`department`     AS `department`,
  `he`.`hr_employee_id` AS `hr_employee_id`,
  `o`.`org_id`          AS `org_id`,
  `dp`.`dept_id`        AS `dept_id`
FROM ((`hr_employee` `he`
    LEFT JOIN `hr_department` `dp`
      ON ((`he`.`department_id` = `dp`.`dept_id`)))
   LEFT JOIN `org` `o`
     ON ((`o`.`org_id` = `he`.`org_id`))))$$

DELIMITER ;
CALL tbColumnAddChg('xbs','sd_quote_line','customer_item_number','','VARCHAR(25) default null','','requested_date');

#@20190405
DELIMITER $$

USE `xbs`$$

DROP TRIGGER /*!50032 IF EXISTS */ `inv_receipt_headerInsertB`$$

CREATE
    /*!50017 DEFINER = 'i3u'@'localhost' */
    TRIGGER `inv_receipt_headerInsertB` BEFORE INSERT ON `inv_receipt_header` 
    FOR EACH ROW BEGIN
IF new.receipt_number IS NULL OR new.receipt_number='' THEN
SET @cnt=0;
SELECT COUNT(0) INTO @cnt FROM inv_receipt_header WHERE DATE(creation_date) BETWEEN CURDATE() AND CURDATE();
SET new.receipt_number=generate_orderNo('RN', 6, @cnt,'','');
END IF;
    END;
$$

DELIMITER ;
DELIMITER $$

USE `xbs`$$

DROP TRIGGER /*!50032 IF EXISTS */ `po_requisition_headerInsertB`$$

CREATE
    /*!50017 DEFINER = 'i3u'@'localhost' */
    TRIGGER `po_requisition_headerInsertB` BEFORE INSERT ON `po_requisition_header` 
    FOR EACH ROW BEGIN
IF new.po_requisition_number IS NULL OR new.po_requisition_number='' THEN
SET @cnt=0;
SELECT COUNT(0) INTO @cnt FROM po_requisition_header WHERE DATE(creation_date) BETWEEN CURDATE() AND CURDATE();
SET new.po_requisition_number=generate_orderNo('PR', 6, @cnt,'','');
END IF;
    END;
$$

DELIMITER ;
DELIMITER $$

USE `xbs`$$

DROP TRIGGER /*!50032 IF EXISTS */ `poQuoteHeaderInsert`$$

CREATE
    /*!50017 DEFINER = 'i3u'@'localhost' */
    TRIGGER `poQuoteHeaderInsert` BEFORE INSERT ON `po_quote_header` 
    FOR EACH ROW BEGIN
SET new.rev=(SELECT COUNT(po_quote_header_id) FROM po_quote_header WHERE (po_rfq_header_id,supplier_site_id,supplier_id)=(new.po_rfq_header_id,new.supplier_site_id,new.supplier_id))+1;
IF new.quote_number='' OR new.quote_number IS NULL THEN
SET @cnt=0;
#SELECT COUNT(0) INTO @cnt FROM po_quote_header WHERE DATE(creation_date) BETWEEN CURDATE() AND CURDATE();
SELECT SUBSTR(quote_number,-5)+0 INTO @cnt FROM po_quote_header WHERE DATE(creation_date)=CURDATE() ORDER BY quote_number DESC LIMIT 0,1;
SET new.quote_number=generate_orderNo('PQ', 6, @cnt,'','');
END IF;
    END;
$$

DELIMITER ;
DELIMITER $$

USE `xbs`$$

DROP TRIGGER /*!50032 IF EXISTS */ `sd_delivery_header_InsertB`$$

CREATE
    /*!50017 DEFINER = 'i3u'@'localhost' */
    TRIGGER `sd_delivery_header_InsertB` BEFORE INSERT ON `sd_delivery_header` 
    FOR EACH ROW BEGIN
IF new.delivery_number='' OR new.delivery_number IS NULL THEN
SET @cnt=0;
SELECT COUNT(0) INTO @cnt FROM sd_delivery_header WHERE DATE(creation_date) BETWEEN CURDATE() AND CURDATE();
SET new.delivery_number=generate_orderNo('DN', 6, @cnt,'','');
END IF;
    END;
$$

DELIMITER ;
DELIMITER $$

USE `xbs`$$

DROP TRIGGER /*!50032 IF EXISTS */ `sd_quote_header_insertB`$$

CREATE
    /*!50017 DEFINER = 'i3u'@'localhost' */
    TRIGGER `sd_quote_header_insertB` BEFORE INSERT ON `sd_quote_header` 
    FOR EACH ROW BEGIN
IF new.quote_number='' OR new.quote_number IS NULL THEN
SET @cnt=0;
SELECT COUNT(0) INTO @cnt FROM sd_quote_header WHERE DATE(creation_date) BETWEEN CURDATE() AND CURDATE();
SET new.quote_number=generate_orderNo('SQ', 6, @cnt,'','');
END IF;
    END;
$$

DELIMITER ;
DELIMITER $$

USE `xbs`$$

DROP TRIGGER /*!50032 IF EXISTS */ `sd_so_headerInsertB`$$

CREATE
    /*!50017 DEFINER = 'i3u'@'localhost' */
    TRIGGER `sd_so_headerInsertB` BEFORE INSERT ON `sd_so_header` 
    FOR EACH ROW BEGIN
IF new.so_number IS NULL OR new.so_number='' THEN
SET @cnt=0;
SELECT COUNT(0) INTO @cnt FROM sd_so_header WHERE DATE(creation_date) BETWEEN CURDATE() AND CURDATE();
SET new.so_number=generate_orderNo('SO', 6, @cnt,'','');
END IF;
    END;
$$

DELIMITER ;

DELIMITER $$

USE `xbs`$$

DROP VIEW IF EXISTS `bom_department_user_v`$$

CREATE ALGORITHM=UNDEFINED DEFINER=`i3u`@`localhost` SQL SECURITY DEFINER VIEW `bom_department_user_v` AS (
SELECT
  `org`.`org`                     AS `org`,
  `d`.`department`                AS `department`,
  GROUP_CONCAT(DISTINCT `b`.`standard_operation` SEPARATOR ',') AS `standard_operation`,
  GROUP_CONCAT(DISTINCT `x`.`username` SEPARATOR ',') AS `username`,
  (`d`.`status` AND `b`.`status` AND `u`.`active`) AS `active`,
  `d`.`description`               AS `description`,
  `d`.`org_id`                    AS `org_id`,
  `x`.`xerp_user_id`              AS `xerp_user_id`,
  `d`.`status`                    AS `bd_status`,
  `b`.`status`                    AS `bo_status`,
  `u`.`active`                    AS `bu_active`,
  `d`.`bom_department_id`         AS `bom_department_id`,
  `b`.`bom_standard_operation_id` AS `bom_standard_operation_id`,
  `u`.`user_bom_department_id`    AS `user_bom_department_id`
FROM ((((`bom_department` `d`
      LEFT JOIN `user_bom_department` `u`
        ON ((`u`.`bom_department_id` = `d`.`bom_department_id`)))
     LEFT JOIN `xerp_user` `X`
       ON ((`u`.`xerp_user_id` = `x`.`xerp_user_id`)))
    LEFT JOIN `org`
      ON ((`org`.`org_id` = `d`.`org_id`)))
   LEFT JOIN `bom_standard_operation` `b`
     ON ((`b`.`department_id` = `d`.`bom_department_id`)))
GROUP BY `d`.`department`)$$

DELIMITER ;

DELIMITER $$

USE `xbs`$$

DROP VIEW IF EXISTS `hr_employee_v`$$

CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `hr_employee_v` AS 
SELECT
  CONCAT(`he`.`last_name`,_utf8' ',`he`.`first_name`) AS `name`,
  `he`.`employee_number`        AS `employee_number`,
  `he`.`first_name`             AS `first_name`,
  `he`.`last_name`              AS `last_name`,
  `u`.`username`                AS `username`,
  `org_v`.`org`                 AS `org`,
  `d`.`department`              AS `department`,
  CONCAT(`hs`.`last_name`,_utf8' ',`hs`.`first_name`) AS `supervisor`,
  `he`.`identification_id`      AS `identification_id`,
  `he`.`start_date`             AS `emp_start_date`,
  `he`.`citizen_number`         AS `citizen_number`,
  `he`.`phone`                  AS `phone`,
  `he`.`email`                  AS `emp_email`,
  `u`.`email`                   AS `email`,
  `u`.`status`                  AS `status`,
  `he`.`gender`                 AS `gender`,
  `he`.`person_type`            AS `person_type`,
  `he`.`hr_employee_id`         AS `hr_employee_id`,
  `he`.`org_id`                 AS `org_id`,
  `he`.`job_id`                 AS `job_id`,
  `u`.`xerp_user_id`            AS `xerp_user_id`,
  `he`.`department_id`          AS `department_id`,
  `he`.`position_id`            AS `position_id`,
  `he`.`expense_ac_id`          AS `expense_ac_id`,
  `he`.`supervisor_employee_id` AS `supervisor_employee_id`
FROM ((((`hr_employee` `he`
      LEFT JOIN `hr_department` `d`
        ON ((`he`.`department_id` = `d`.`dept_id`)))
     LEFT JOIN `xerp_user` `u`
       ON ((`he`.`hr_employee_id` = `u`.`hr_employee_id`)))
    LEFT JOIN `hr_employee` `hs`
      ON ((`he`.`supervisor_employee_id` = `hs`.`hr_employee_id`)))
   LEFT JOIN `org_v`
     ON ((`org_v`.`org_id` = `he`.`org_id`)))$$

DELIMITER ;

UPDATE xbs.hr_employee SET STATUS=1;

#@20190626
DELIMITER $$

USE `xbs`$$

DROP VIEW IF EXISTS `invonhand_v`$$

CREATE ALGORITHM=UNDEFINED DEFINER=`i3u`@`localhost` SQL SECURITY DEFINER VIEW `invonhand_v` AS (
SELECT
  `i`.`item_number`         AS `item_number`,
  `i`.`item_name`           AS `item_name`,
  `i`.`item_specification`  AS `item_specification`,
  `i`.`item_description`    AS `item_description`,
  `u`.`uom_name`            AS `uom_name`,
  `o`.`onhand`              AS `onhand`,
  `org`.`org`               AS `org`,
  `s`.`subinventory`        AS `subinventory`,
  `l`.`locator`             AS `locator`,
  `i0`.`lot_number`         AS `lot_number`,
  `i1`.`serial_number`      AS `serial_number`,
  `o`.`reservable_onhand`   AS `reservable_onhand`,
  `o`.`transactable_onhand` AS `transactable_onhand`,
  `o`.`lot_status`          AS `lot_status`,
  `o`.`serial_status`       AS `serial_status`,
  `o`.`secondary_uom_id`    AS `secondary_uom_id`,
  `o`.`onhand_status`       AS `onhand_status`,
  `o`.`onhand_id`           AS `onhand_id`,
  `o`.`uom_id`              AS `uom_id`,
  `o`.`subinventory_id`     AS `subinventory_id`,
  `o`.`locator_id`          AS `locator_id`,
  `o`.`lot_id`              AS `lot_id`,
  `o`.`serial_id`           AS `serial_id`,
  `i`.`item_id_m`           AS `item_id_m`,
  `o`.`revision_name`       AS `revision_name`,
  `i`.`item_type`           AS `item_type`,
  `i`.`item_category`       AS `item_category`,
  `i`.`item_status`         AS `item_status`,
  `i`.`make_buy`            AS `make_buy`,
  `i`.`inventory_item_cb`   AS `inventory_item_cb`,
  `i`.`org_id`              AS `org_id`,
  `o`.`last_update_date`    AS `last_update_date`,
  (TO_DAYS(CURDATE()) - TO_DAYS(`o`.`last_update_date`)) AS `sluggish`
FROM (((((((`item` `i`
         LEFT JOIN `onhand` `o`
           ON ((`o`.`item_id_m` = `i`.`item_id_m`)))
        LEFT JOIN `uom` `u`
          ON ((`o`.`uom_id` = `u`.`uom_id`)))
       LEFT JOIN `subinventory` `s`
         ON ((`o`.`subinventory_id` = `s`.`subinventory_id`)))
      LEFT JOIN `locator` `l`
        ON ((`o`.`locator_id` = `l`.`locator_id`)))
     LEFT JOIN `inv_lot_number` `i0`
       ON ((`o`.`lot_id` = `i0`.`inv_lot_number_id`)))
    LEFT JOIN `org`
      ON ((`i`.`org_id` = `org`.`org_id`)))
   LEFT JOIN `inv_serial_number` `i1`
     ON ((`o`.`serial_id` = `i1`.`inv_serial_number_id`))))$$

DELIMITER ;

DELIMITER $$

USE `xbs`$$

DROP VIEW IF EXISTS `inv_transaction_v`$$

CREATE ALGORITHM=UNDEFINED DEFINER=`i3u`@`localhost` SQL SECURITY DEFINER VIEW `inv_transaction_v` AS (
SELECT
  `i0`.`item_number`         AS `item_number`,
  `u`.`uom_name`             AS `uom_name`,
  `i`.`quantity`             AS `quantity`,
  `t`.`transaction_type`     AS `transaction_type`,
  (CASE `t`.`transaction_action` WHEN 27 THEN `irh`.`receipt_number` WHEN 1 THEN `iih`.`issue_number` END) AS `ir_number`,
  `i`.`unit_cost`            AS `unit_cost`,
  `i`.`costed_amount`        AS `costed_amount`,
  `s`.`subinventory`         AS `from_subinventory`,
  `l`.`locator`              AS `from_locator`,
  `s0`.`subinventory`        AS `to_subinventory`,
  `l0`.`locator`             AS `to_locator`,
  `lt`.`lot_number`          AS `lot_number`,
  `i`.`reason`               AS `reason`,
  `i0`.`item_description`    AS `item_description`,
  `xu`.`username`            AS `trans_by`,
  `i`.`description`          AS `description`,
  `i`.`created_by`           AS `created_by`,
  `i`.`creation_date`        AS `creation_date`,
  `i`.`last_update_by`       AS `last_update_by`,
  `i`.`last_update_date`     AS `last_update_date`,
  `i`.`org_id`               AS `org_id`,
  `i0`.`item_id_m`           AS `item_id_m`,
  `i`.`from_org_id`          AS `from_org_id`,
  `i`.`from_subinventory_id` AS `from_subinventory_id`,
  `i`.`from_locator_id`      AS `from_locator_id`,
  `i`.`to_org_id`            AS `to_org_id`,
  `i`.`to_subinventory_id`   AS `to_subinventory_id`,
  `i`.`to_locator_id`        AS `to_locator_id`,
  `i`.`reference_type`       AS `reference_type`,
  `i`.`reference_key_name`   AS `reference_key_name`,
  `i`.`reference_key_value`  AS `reference_key_value`,
  `i`.`uom_id`               AS `uom_id`,
  `i`.`transaction_type_id`  AS `transaction_type_id`,
  `i`.`ir_line_id`           AS `ir_line_id`,
  `i`.`inv_transaction_id`   AS `inv_transaction_id`,
  `t`.`transaction_action`   AS `transaction_action`
FROM (((((((((((`inv_transaction` `i`
             LEFT JOIN `item` `i0`
               ON ((`i`.`item_id_m` = `i0`.`item_id_m`)))
            LEFT JOIN `uom` `u`
              ON ((`i`.`uom_id` = `u`.`uom_id`)))
           LEFT JOIN `subinventory` `s`
             ON ((`i`.`from_subinventory_id` = `s`.`subinventory_id`)))
          LEFT JOIN `locator` `l`
            ON ((`i`.`from_locator_id` = `l`.`locator_id`)))
         LEFT JOIN `inv_lot_number` `lt`
           ON ((`lt`.`inv_lot_number_id` = `i`.`lot_number_id`)))
        LEFT JOIN `subinventory` `s0`
          ON ((`i`.`to_subinventory_id` = `s0`.`subinventory_id`)))
       LEFT JOIN `locator` `l0`
         ON ((`i`.`to_locator_id` = `l0`.`locator_id`)))
      LEFT JOIN `xerp_user` `xu`
        ON ((`i`.`created_by` = `xu`.`xerp_user_id`)))
     LEFT JOIN `transaction_type` `t`
       ON ((`i`.`transaction_type_id` = `t`.`transaction_type_id`)))
    LEFT JOIN (`inv_receipt_line` `irl`
               JOIN `inv_receipt_header` `irh`
                 ON ((`irl`.`inv_receipt_header_id` = `irh`.`inv_receipt_header_id`)))
      ON (((`t`.`transaction_action` = 27)
           AND (`irl`.`inv_receipt_line_id` = `i`.`ir_line_id`))))
   LEFT JOIN (`inv_issue_line` `iil`
              JOIN `inv_issue_header` `iih`
                ON ((`iil`.`inv_issue_header_id` = `iih`.`inv_issue_header_id`)))
     ON (((`t`.`transaction_action` = 1)
          AND (`iil`.`inv_issue_line_id` = `i`.`ir_line_id`)))))$$

DELIMITER ;

CALL tbColumnAddChg('xbs','sd_shipping_control','rev_enabled','','TINYINT(1) DEFAULT 0','','');

#@20190701
CALL tbColumnAddChg('xbs','bom_calendars','created_by','','INT(11) DEFAULT 0','','');
CALL tbColumnAddChg('xbs','bom_calendars','creation_date','','DATETIME DEFAULT NULL','','');
CALL tbColumnAddChg('xbs','bom_calendars','last_update_by','','INT(11) DEFAULT 0','','');
CALL tbColumnAddChg('xbs','bom_calendars','last_update_date','','DATETIME DEFAULT NULL','','');
CALL tbColumnAddChg('xbs','bom_cal_week_start_dates','created_by','','INT(11) DEFAULT 0','','');
CALL tbColumnAddChg('xbs','bom_cal_week_start_dates','creation_date','','DATETIME DEFAULT NULL','','');
CALL tbColumnAddChg('xbs','bom_cal_week_start_dates','last_update_by','','INT(11) DEFAULT 0','','');
CALL tbColumnAddChg('xbs','bom_cal_week_start_dates','last_update_date','','DATETIME DEFAULT NULL','','');
CALL tbColumnAddChg('xbs','bom_calendar_exceptions','created_by','','INT(11) DEFAULT 0','','');
CALL tbColumnAddChg('xbs','bom_calendar_exceptions','creation_date','','DATETIME DEFAULT NULL','','');
CALL tbColumnAddChg('xbs','bom_calendar_exceptions','last_update_by','','INT(11) DEFAULT 0','','');
CALL tbColumnAddChg('xbs','bom_calendar_exceptions','last_update_date','','DATETIME DEFAULT NULL','','');
DELIMITER $$

USE `xbs`$$

DROP PROCEDURE IF EXISTS `GenCalWeeks`$$

CREATE DEFINER=`i3u`@`localhost` PROCEDURE `GenCalWeeks`(cc VARCHAR(10),dtStart DATE,dtEnd DATE)
BEGIN
DECLARE dt DATE;
DECLARE i INT;
IF cc!='' THEN
IF dtStart IS NULL AND dtEnd IS NULL THEN
SELECT calendar_start_date,calendar_end_date INTO dtStart,dtEnd FROM bom_calendars WHERE calendar_code=cc;
END IF;
IF dtStart IS NOT NULL AND dtEnd IS NOT NULL THEN
SET i=1;
    SELECT SUBDATE(dtStart,DATE_FORMAT(dtStart,'%w')-7) INTO dt;
WHILE dt <= dtEnd AND i<100 DO
INSERT IGNORE INTO bom_cal_week_start_dates VALUES (cc,1,i,dt,ADDDATE(dt,6),SUBDATE(dt,7),ADDDATE(dt,7));
SET dt = ADDDATE(dt,7);
SET i = i+1;
END WHILE;
END IF;
END IF;
    END$$

DELIMITER ;

DELIMITER $$

USE `xbs`$$

DROP VIEW IF EXISTS `fp_mrp_planned_order_v`$$

CREATE ALGORITHM=UNDEFINED DEFINER=`i3u`@`localhost` SQL SECURITY DEFINER VIEW `fp_mrp_planned_order_v` AS (
SELECT
  `f0`.`mrp_name`                 AS `mrp_name`,
  `f`.`order_type`                AS `order_type`,
  `f`.`order_action`              AS `order_action`,
  `i`.`item_number`               AS `material`,
  `i`.`item_name`                 AS `item_name`,
  `i`.`item_specification`        AS `item_specification`,
  `i`.`item_description`          AS `item_description`,
  `f`.`order_date`                AS `order_date`,
  `f`.`need_by_date`              AS `requested_date`,
  `f`.`quantity`                  AS `quantity`,
  `i0`.`item_number`              AS `component`,
  `i1`.`item_number`              AS `product`,
  `i`.`receipt_sub_inventory`     AS `receipt_sub_inventory`,
  `f`.`source_type`               AS `source_type`,
  `f`.`primary_source_type`       AS `primary_source_type`,
  `f`.`source_header_id`          AS `source_header_id`,
  `f`.`source_line_id`            AS `source_line_id`,
  `f`.`supplier_id`               AS `supplier_id`,
  `f`.`supplier_site_id`          AS `supplier_site_id`,
  `f`.`fp_mrp_planned_order_id`   AS `fp_mrp_planned_order_id`,
  `o`.`org`                       AS `org`,
  `f`.`fp_mrp_header_id`          AS `fp_mrp_header_id`,
  `f`.`item_id_m`                 AS `material_id`,
  `f`.`demand_item_id_m`          AS `component_id`,
  `f`.`toplevel_demand_item_id_m` AS `product_id`,
  `f`.`org_id`                    AS `org_id`,
  `f`.`created_by`                AS `created_by`,
  `f`.`creation_date`             AS `creation_date`,
  `f`.`last_update_by`            AS `last_update_by`,
  `f`.`last_update_date`          AS `last_update_date`
FROM (((((`fp_mrp_planned_order` `f`
       LEFT JOIN `fp_mrp_header` `f0`
         ON ((`f`.`fp_mrp_header_id` = `f0`.`fp_mrp_header_id`)))
      LEFT JOIN `item` `i`
        ON (((`f`.`item_id_m` = `i`.`item_id_m`)
             AND (`i`.`org_id` = `f`.`org_id`))))
     LEFT JOIN `item` `i0`
       ON (((`f`.`demand_item_id_m` = `i0`.`item_id_m`)
            AND (`i0`.`org_id` = `f`.`org_id`))))
    LEFT JOIN `item` `i1`
      ON (((`f`.`toplevel_demand_item_id_m` = `i1`.`item_id_m`)
           AND (`i1`.`org_id` = `f`.`org_id`))))
   LEFT JOIN `org` `o`
     ON ((`f`.`org_id` = `o`.`org_id`)))
ORDER BY `f`.`fp_mrp_planned_order_id`)$$

DELIMITER ;

#@20190701
CALL tbColumnAddChg('xbs','fp_mrp_planned_order','onhandconsume','','DECIMAL(20,5) DEFAULT 0','','');

#@20190703
DELIMITER $$

USE `xbs`$$

DROP VIEW IF EXISTS `fp_mrp_planned_order_v`$$

CREATE ALGORITHM=UNDEFINED DEFINER=`i3u`@`localhost` SQL SECURITY DEFINER VIEW `fp_mrp_planned_order_v` AS (
SELECT
  `f0`.`mrp_name`                 AS `mrp_name`,
  `f`.`order_type`                AS `order_type`,
  `f`.`order_action`              AS `order_action`,
  `i`.`item_number`               AS `material`,
  `i`.`item_name`                 AS `item_name`,
  `i`.`item_specification`        AS `item_specification`,
  `i`.`item_description`          AS `item_description`,
  `f`.`order_date`                AS `order_date`,
  `f`.`need_by_date`              AS `requested_date`,
  `f`.`quantity`                  AS `quantity`,
  IFNULL(`f`.`onhandconsume`,0)   AS `onhandconsume`,
  `i0`.`item_number`              AS `component`,
  `i1`.`item_number`              AS `product`,
  `i`.`receipt_sub_inventory`     AS `receipt_sub_inventory`,
  `f`.`source_type`               AS `source_type`,
  `f`.`primary_source_type`       AS `primary_source_type`,
  `f`.`source_header_id`          AS `source_header_id`,
  `f`.`source_line_id`            AS `source_line_id`,
  `f`.`supplier_id`               AS `supplier_id`,
  `f`.`supplier_site_id`          AS `supplier_site_id`,
  `f`.`fp_mrp_planned_order_id`   AS `fp_mrp_planned_order_id`,
  `o`.`org`                       AS `org`,
  `f`.`fp_mrp_header_id`          AS `fp_mrp_header_id`,
  `f`.`item_id_m`                 AS `material_id`,
  `f`.`demand_item_id_m`          AS `component_id`,
  `f`.`toplevel_demand_item_id_m` AS `product_id`,
  `f`.`org_id`                    AS `org_id`,
  `f`.`created_by`                AS `created_by`,
  `f`.`creation_date`             AS `creation_date`,
  `f`.`last_update_by`            AS `last_update_by`,
  `f`.`last_update_date`          AS `last_update_date`,
  (TO_DAYS(CURDATE()) - TO_DAYS(`o`.`last_update_date`)) AS `sluggish`
FROM (((((`fp_mrp_planned_order` `f`
       LEFT JOIN `fp_mrp_header` `f0`
         ON ((`f`.`fp_mrp_header_id` = `f0`.`fp_mrp_header_id`)))
      LEFT JOIN `item` `i`
        ON (((`f`.`item_id_m` = `i`.`item_id_m`)
             AND (`i`.`org_id` = `f`.`org_id`))))
     LEFT JOIN `item` `i0`
       ON (((`f`.`demand_item_id_m` = `i0`.`item_id_m`)
            AND (`i0`.`org_id` = `f`.`org_id`))))
    LEFT JOIN `item` `i1`
      ON (((`f`.`toplevel_demand_item_id_m` = `i1`.`item_id_m`)
           AND (`i1`.`org_id` = `f`.`org_id`))))
   LEFT JOIN `org` `o`
     ON ((`f`.`org_id` = `o`.`org_id`)))
ORDER BY `f`.`fp_mrp_planned_order_id`)$$

DELIMITER ;

DELIMITER $$

USE `xbs`$$

DROP PROCEDURE IF EXISTS `mrp_demand_cal4components`$$

CREATE DEFINER=`i3u`@`localhost` PROCEDURE `mrp_demand_cal4components`(fmdId INT,item BIGINT,ddt DATE,qty DECIMAL(15,5),qtyOnhandConsume DECIMAL(15,5),itemPri BIGINT,srctpPri VARCHAR(50),srcHid BIGINT,srcLid BIGINT,userid INT,orgid INT)
BEGIN
DECLARE cpitem BIGINT;
DECLARE makebuy VARCHAR(5);
DECLARE cpusage INT;
DECLARE cpqty DECIMAL(15,5);
DECLARE cpprocessTotal_lt INT;
DECLARE cpprocessing_lt INT;
DECLARE done INT;
DECLARE cpitemrev VARCHAR(50);
DECLARE unitprice DOUBLE(18,2);
DECLARE so2mds CURSOR FOR SELECT component_item_id_m,usage_basis,usage_quantity,make_buy,processTotal_lt,processing_lt FROM item_component_v WHERE item_id_m=item AND org_id=orgid;
DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = 1;
SET @@max_sp_recursion_depth = 100;
    OPEN so2mds;
    BEGIN_so2mds: LOOP
        FETCH so2mds INTO cpitem,cpusage,cpqty,makebuy,cpprocessTotal_lt,cpprocessing_lt;
        IF done THEN
            LEAVE BEGIN_so2mds;
        END IF;
	CALL mrp_demand_order(fmdId,item,ddt,qty,qtyOnhandConsume,itemPri,srctpPri,srcHid,srcLid,userid,orgid,cpitem,cpusage,cpqty,makebuy,cpprocessTotal_lt,cpprocessing_lt);
    END LOOP BEGIN_so2mds;
    CLOSE so2mds;
    END$$

DELIMITER ;

DELIMITER $$

USE `xbs`$$

DROP PROCEDURE IF EXISTS `mrp_check`$$

CREATE DEFINER=`i3u`@`localhost` PROCEDURE `mrp_check`(fmhId BIGINT,userid BIGINT)
BEGIN
DECLARE makebuy VARCHAR(5);
DECLARE totalLt INT;
DECLARE processingLt INT;
DECLARE itemId INT;
DECLARE demandDT DATE;
DECLARE qty DECIMAL(15,5);
DECLARE sourceType VARCHAR(20);
DECLARE sourceHeaderId INT;
DECLARE sourceLineId INT;
DECLARE orgId INT;
DECLARE done INT;
DECLARE mchk CURSOR FOR SELECT make_buy,(pre_processing_lt+post_processing_lt+processing_lt) total_lt,processing_lt,dl.item_id_m,demand_date,quantity,source_type,source_header_id,source_line_id,dh.org_id
FROM fp_mds_line dl JOIN fp_mds_header dh ON dl.fp_mds_header_id=dh.fp_mds_header_id
JOIN fp_mrp_header rh ON rh.demand_source=dh.fp_mds_header_id
JOIN item i ON i.item_id_m=dl.item_id_m AND i.org_id=dh.org_id WHERE fp_mrp_header_id=fmhId;
DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = 1;
    OPEN mchk;
    BEGIN_mchk: LOOP
        FETCH mchk INTO makebuy,totalLt,processingLt,itemId,demandDT,qty,sourceType,sourceHeaderId,sourceLineId,orgId;
        IF done THEN
            LEAVE BEGIN_mchk;
        END IF;
CALL mrp_demand_order(fmhId,itemId,demandDT,qty,0,itemId,sourceType,sourceHeaderId,sourceLineId,userid,orgId,itemId,351,1, makebuy,totalLt,processingLt);
    END LOOP BEGIN_mchk;
    CLOSE mchk;
    END$$

DELIMITER ;

DELIMITER $$

USE `xbs`$$

DROP TRIGGER /*!50032 IF EXISTS */ `invReceiptLineInsert`$$

CREATE
    /*!50017 DEFINER = 'i3u'@'localhost' */
    TRIGGER `invReceiptLineInsert` BEFORE INSERT ON `inv_receipt_line` 
    FOR EACH ROW BEGIN
SET @rrtp=NULL;
SET @linenum=NULL;
SET @qty=NULL;
SET @qty_recv=NULL;
SELECT receipt_routing,IFNULL(over_receipt_percentage,0) INTO @rrtp,@orp FROM item WHERE item_id_m=new.item_id_m AND org_id=new.org_id;
IF new.reference_key_name='po_line' THEN #next receipt should do after pre receipt complete or cancel, inv_receipt_headerInsert gen pl.line_quantity-pl.accepted_quantity as next qty to receive
SELECT pl.line_quantity,SUM(amount) INTO @qty,@qty_recv FROM inv_receipt_line irl JOIN po_line pl ON irl.reference_key_name='po_line' AND irl.reference_key_value=pl.po_line_id 
WHERE reference_key_value=new.reference_key_value AND irl.status!=1522 GROUP BY pl.po_line_id;
IF (new.transaction_quantity+@qty_recv-@qty)/@qty>@orp THEN
INSERT INTO xbs.xbs_log (log_level,task,program,msg,user_id,org_id,dt)VALUES('info','po_recv','RECEIPT',CONCAT('Item ',new.item_id_m,PO_RECEIPT_OVER,'>',@qty),new.created_by,new.org_id,NOW());
END IF;
END IF;
IF new.reference_key_name='po_line' THEN
SELECT wo.quantity,IFNULL(wo.scrapped_quantity,0),COUNT(irl.transaction_quantity) INTO @qty,@qty_scrap,@qty_recv 
FROM inv_receipt_line irl JOIN wip_move_transaction wmt ON irl.reference_key_name='wip_move_transaction' AND irl.reference_key_value=wmt.wip_move_transaction_id 
JOIN wip_wo_header wo ON wmt.wip_wo_header_id=wo.wip_wo_header_id WHERE wo.item_id_m=new.item_id_m AND reference_key_value=new.reference_key_value AND irl.status!=1522 GROUP BY wo.wip_wo_header_id;
IF (new.transaction_quantity+@qty_recv+@qty_scrap)>@qty THEN
INSERT INTO xbs.xbs_log (log_level,task,program,msg,user_id,org_id,dt)VALUES('info','wip_complete_recv','RECEIPT',CONCAT('Item ',new.item_id_m,WIP_COMPLETE_RECEIPT_OVER,'>',@qty),new.created_by,new.org_id,NOW());
END IF;
END IF;
IF @rrtp=300 AND new.reference_key_name!='inv_receipt_line' THEN
#need qa so change to po_receipt and qa_complete will create new one po_dlv
#set new.transaction_type_id=4;
SET new.inspection_status=0;
END IF;
SELECT MAX(line_number) INTO @linenum FROM inv_receipt_line il JOIN inv_receipt_header ih ON il.inv_receipt_header_id=ih.inv_receipt_header_id WHERE il.inv_receipt_header_id=NEW.inv_receipt_header_id AND ih.STATUS=1519;
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

DROP TRIGGER /*!50032 IF EXISTS */ `bom_routing_line_updateB`$$

CREATE
    /*!50017 DEFINER = 'i3u'@'localhost' */
    TRIGGER `bom_routing_line_updateB` BEFORE UPDATE ON `bom_routing_line` 
    FOR EACH ROW BEGIN
UPDATE bom_line SET routing_sequence=new.routing_sequence,routing_seq_num=new.routing_seq_num,last_update_by=new.last_update_by,last_update_date=NOW() 
WHERE (bom_header_id, routing_sequence,routing_seq_num) IN (
SELECT bom_header_id, routing_sequence,routing_seq_num  FROM xbs.bom_header bh
LEFT JOIN xbs.bom_routing_header brh ON brh.item_id_m=bh.item_id_m AND brh.org_id=bh.org_id 
LEFT JOIN xbs.bom_routing_line brll ON brll.bom_routing_header_id=brh.bom_routing_header_id
WHERE bom_routing_line_id=new.bom_routing_line_id);
    END;
$$

DELIMITER ;

CREATE TABLE IF NOT EXISTS `fp_mrp_planned_sources` (
  `fp_mrp_planned_sources_id` BIGINT(20) NOT NULL AUTO_INCREMENT,
  `source_type` ENUM('fp_forecast_header','sd_so_header') DEFAULT NULL,
  `source_header_id` BIGINT(20) DEFAULT NULL,
  `source_line_id` BIGINT(20) DEFAULT NULL,
  `source_date` DATE DEFAULT NULL,
  `deleted` TINYINT(1) NOT NULL DEFAULT '0',
  `decription` VARCHAR(50) DEFAULT NULL,
  `org_id` INT(12) NOT NULL,
  `created_by` INT(11) NOT NULL,
  `creation_date` DATETIME NOT NULL,
  `last_update_by` INT(11) NOT NULL,
  `last_update_date` DATETIME NOT NULL,
  PRIMARY KEY  (`fp_mrp_planned_sources_id`),
  UNIQUE KEY `source_type` (`source_type`,`source_header_id`,`source_line_id`,`deleted`)
) ENGINE=MYISAM DEFAULT CHARSET=utf8;

DELIMITER $$

USE `xbs`$$

DROP PROCEDURE IF EXISTS `load_so_to_mds`$$

CREATE DEFINER=`i3u`@`localhost` PROCEDURE `load_so_to_mds`(fdhId INT,userid INT,orgid INT,plandays INT)
BEGIN
INSERT IGNORE INTO fp_mds_line (fp_mds_header_id,item_id_m,demand_date,quantity,source_type,source_header_id,source_line_id,created_by,creation_date,last_update_by,last_update_date)
SELECT fdhId,item_id_m,schedule_ship_date,line_quantity,'sd_so_header',sd_so_header_id,sd_so_line_id,userid,NOW(),userid,NOW() FROM sd_so_line WHERE line_status IN (1530) AND (schedule_ship_date BETWEEN CURDATE() AND ADDDATE(CURDATE(),plandays)) AND shipping_org_id=orgid 
AND sd_so_line_id NOT IN (SELECT source_line_id FROM fp_mrp_planned_sources WHERE source_type='sd_so_header' AND !deleted);
    END$$

DELIMITER ;

DELIMITER $$

USE `xbs`$$

DROP PROCEDURE IF EXISTS `load_fp_to_mds`$$

CREATE DEFINER=`i3u`@`localhost` PROCEDURE `load_fp_to_mds`(fdhId INT,userid INT,orgid INT,plandays INT)
BEGIN
INSERT IGNORE INTO fp_mds_line (fp_mds_header_id,item_id_m,demand_date,quantity,source_type,source_header_id,source_line_id,created_by,creation_date,last_update_by,last_update_date)
SELECT fdhId,fcl.item_id_m,fcld.forecast_date,fcld.current_quantity,'fp_forecast_header',fcl.fp_forecast_line_id,fcld.fp_forecast_line_date_id,userid,NOW(),userid,NOW()
FROM fp_mds_header mds LEFT JOIN fp_source_list_header slh ON mds.fp_source_list_header_id=slh.fp_source_list_header_id
LEFT JOIN fp_source_list_line sll ON slh.fp_source_list_header_id=sll.fp_source_list_header_id
LEFT JOIN fp_forecast_header fc ON sll.source_list_id=fc.fp_forecast_header_id AND source_list_line_type=577
LEFT JOIN fp_forecast_line fcl ON fc.fp_forecast_header_id=fcl.fp_forecast_header_id
LEFT JOIN fp_forecast_line_date fcld ON fcl.fp_forecast_line_id=fcld.fp_forecast_line_id WHERE fp_mds_header_id=fdhId AND (forecast_date BETWEEN CURDATE() AND ADDDATE(CURDATE(),plandays)) 
AND fp_forecast_line_date_id NOT IN (SELECT source_line_id FROM fp_mrp_planned_sources WHERE source_type='fp_forecast_header' AND !deleted);
    END$$

DELIMITER ;

DELIMITER $$

USE `xbs`$$

DROP PROCEDURE IF EXISTS `mrp_planning`$$

CREATE DEFINER=`i3u`@`localhost` PROCEDURE `mrp_planning`(fmhId BIGINT,userid BIGINT,orgid BIGINT,planlevel INT)
BEGIN
    SET @ds=NULL;
    SET @mdsId=NULL;
    SET @phDays=7;
DELETE FROM xbs_log WHERE task='mrp_planning' AND user_id=userid;
INSERT INTO xbs.xbs_log (log_level,task,program,msg,user_id,org_id,dt)VALUES('info','mrp_planning','planning','Begin...',userid,orgId,NOW());
SELECT demand_source,planning_horizon_days INTO @mdsId,@phDays FROM fp_mrp_header WHERE fp_mrp_header_id=fmhId LIMIT 1;
IF @mdsId IS NOT NULL THEN
IF(planlevel>0) THEN
#delete FROM fp_mds_header WHERE fp_mds_header_id=@ds;
DELETE FROM fp_mds_line WHERE fp_mds_header_id=@mdsId;
#else
#select fp_mds_header_id into @mdsId from fp_mds_header where fp_mds_header_id=@ds;
END IF;
END IF;
IF @mdsId IS NULL THEN
#    SELECT MAX(fp_mds_header_id) INTO @mdsId FROM fp_mds_header;
#    IF @mdsId IS NULL THEN
#    SET @mdsId = 1;
#    ELSE
#    SET @mdsId = @mdsId+1;
#    END IF;
INSERT INTO fp_mds_header  (org_id,mds_name,description,fp_source_list_header_id,include_so_cb,STATUS,created_by,creation_date,last_update_by,last_update_date) VALUES
(orgid,'','description',NULL,1,1,userid,NOW(),userid,NOW());
SELECT LAST_INSERT_ID() INTO @mdsId;
INSERT INTO xbs.xbs_log (log_level,task,program,msg,user_id,org_id,dt)VALUES('info','mrp_planning','planning','Create MDS!',userid,orgid,NOW());
UPDATE fp_mrp_header SET demand_source=@mdsId WHERE fp_mrp_header_id=fmhId;
CALL loadSO2MDS(@mdsId,userid,orgid,@phDays);
CALL load_fp_to_mds(@mdsId,userid,orgid,@phDays);
ELSEIF (planlevel>0) THEN
CALL loadSO2MDS(@mdsId,userid,orgid,@phDays);
CALL load_fp_to_mds(@mdsId,userid,orgid,@phDays);
END IF;
IF(planlevel>1) THEN
DELETE FROM fp_mrp_planned_order WHERE fp_mrp_header_id=fmhId;
END IF;
DELETE FROM fp_mrp_demand WHERE fp_mrp_header_id=fmhId;
DELETE FROM fp_mrp_planned_order WHERE fp_mrp_header_id=fmhId AND order_type='prq';
DELETE FROM fp_mrp_exception WHERE fp_mrp_header_id=fmhId;
INSERT INTO fp_mrp_exception(org_id,fp_mrp_header_id,exception_message,detailed_message,exception_type,created_by,creation_date,last_update_by,last_update_date)
 VALUE(orgid,fmhId,'Info','mrp_planning','Begin...',userid,NOW(),userid,NOW());
SET @cntmds=0;
SELECT COUNT(fp_mds_line_id) INTO @cntmds FROM fp_mds_line dl JOIN fp_mds_header dh ON dl.fp_mds_header_id=dh.fp_mds_header_id
JOIN fp_mrp_header rh ON rh.demand_source=dh.fp_mds_header_id WHERE fp_mrp_header_id=fmhId;
IF(@cntmds>0) THEN
CALL mrp_check(fmhId,userid);
ELSE
INSERT INTO fp_mrp_exception(org_id,fp_mrp_header_id,exception_message,detailed_message,exception_type,created_by,creation_date,last_update_by,last_update_date)
 VALUE(orgid,fmhId,'NO Source Found','NO Source Found for MRP Check','NO_Source',userid,NOW(),userid,NOW());
 END IF;
INSERT INTO fp_mrp_exception(org_id,fp_mrp_header_id,exception_message,detailed_message,exception_type,created_by,creation_date,last_update_by,last_update_date)
 VALUE(orgid,fmhId,'Info','mrp_planning','Finished!',userid,NOW(),userid,NOW());
INSERT INTO xbs.xbs_log (log_level,task,program,msg,user_id,org_id,dt)VALUES('info','mrp_planning','planning','Finished!',userid,orgid,NOW());
    END$$

DELIMITER ;

DELIMITER $$

USE `xbs`$$

DROP TRIGGER /*!50032 IF EXISTS */ `wip_wo_headerUpdate`$$

CREATE
    /*!50017 DEFINER = 'i3u'@'localhost' */
    TRIGGER `wip_wo_headerUpdate` AFTER UPDATE ON `wip_wo_header` 
    FOR EACH ROW BEGIN
    IF old.quantity!=new.quantity THEN
    UPDATE wip_wo_bom SET required_quantity=usage_quantity*new.quantity WHERE wip_wo_header_id=new.wip_wo_header_id;
    UPDATE wip_wo_routing_detail SET required_quantity=resource_usage*new.quantity WHERE wip_wo_header_id=new.wip_wo_header_id;
    END IF;
    IF old.wo_status=369 AND new.wo_status=370 THEN
    CALL wipwoReleaseRL(new.wip_wo_header_id,new.item_id_m,new.quantity,new.org_id,new.last_update_by);
    END IF;
    END;
$$

DELIMITER ;

DELIMITER $$

USE `xbs`$$

DROP PROCEDURE IF EXISTS `convertPOfromPRQLine`$$

CREATE DEFINER=`i3u`@`localhost` PROCEDURE `convertPOfromPRQLine`(rqHid BIGINT,rqLid BIGINT,userid BIGINT,orgid BIGINT)
BEGIN
SET @poid=NULL;
SET @spid=NULL;
SET @sptid=NULL;
SET @unitprice=NULL;
SET @itmid=NULL;
IF NOT EXISTS(SELECT po_line_id FROM po_line WHERE po_req_line_id=rqLid) THEN
SELECT item_id_m,IF(supplier_id=0,NULL,supplier_id),IF(supplier_site_id=0,NULL,supplier_site_id) INTO @itmid,@spid,@sptid FROM po_requisition_line prl JOIN po_requisition_header prh ON prl.po_requisition_header_id=prh.po_requisition_header_id WHERE po_requisition_line_id=rqLid;
IF @spid IS NULL THEN
# lowest of all newest quotes of suppliers
SELECT supplier_id,quote_unit_price INTO @spid,@unitprice FROM (SELECT supplier_id,quote_unit_price,MAX(last_update_date) FROM xbs.po_quote_supplier_v WHERE item_id_m=@itmid AND bu_org_id=orgid GROUP BY supplier_id) t ORDER BY quote_unit_price DESC LIMIT 0,1;
END IF;
IF @spid IS NOT NULL THEN
SELECT po_header_id INTO @poid FROM supplier_quote_po_v WHERE (item_id_m,supplier_id,bu_org_id,created_by)=(@itmid,@spid,orgid,userid) ORDER BY po_header_id DESC LIMIT 0,1;
IF @poid IS NULL THEN
SET @currency=NULL;
SET @payment=NULL;
SELECT currency_id,payment_term_id,supplier_site_id INTO @currency,@payment,@sptid FROM supplier_all_v WHERE supplier_id=@spid;
SELECT currency_code INTO @currencyLedger FROM org_ledger_v WHERE org_id=orgid;
SET @exchange_rate=NULL;
SET @exchange_rate_cvid=NULL;
IF @currencyLedger=@currency THEN
SET @exchange_rate=1;
ELSE
SELECT rate exchange_rate,gl_currency_conversion_id INTO @exchange_rate,@exchange_rate_cvid FROM xbs.gl_currency_conversion WHERE from_currency=@currency AND to_currency=@currencyLedger;
END IF;
INSERT INTO po_header (bu_org_id, po_type,supplier_id, supplier_site_id, ship_to_id, bill_to_id, currency,doc_currency, payment_term_id, exchange_rate_type, exchange_rate, po_status, created_by, creation_date, last_update_by, last_update_date)
 SELECT bu_org_id, 319, @spid, @sptid, ship_to_id, bill_to_id,@currencyLedger, @currency,@payment,@exchange_rate_cvid, @exchange_rate, 321, userid, NOW(), userid, NOW() FROM po_requisition_header WHERE po_requisition_header_id=rqHid;
SELECT LAST_INSERT_ID() INTO @poid;
END IF;
ELSE
INSERT INTO xbs.xbs_log (log_level,task,program,msg,user_id,org_id,dt)VALUES('error','PRQ2PO','PoPRQLine',CONCAT('Item(',@itmid,') -- Find Supplier Failed!'),userid,orgId,NOW());
END IF;
IF @poid IS NOT NULL THEN
SET @taxcodeid=NULL;
SET @taxpercent=NULL;
SELECT valid_date,unit_price,tax_code_id INTO @price_date,@unitprice,@taxcodeid FROM po_quote_v WHERE (rev AND quote_status=1489) AND supplier_id=@spid AND item_id_m=@itmid ORDER BY unit_price,valid_date DESC LIMIT 0,1;
IF @taxcodeid IS NOT NULL THEN
SELECT percentage INTO @taxpercent FROM mdm_tax_code WHERE mdm_tax_code_id=@taxcodeid;
END IF;
SELECT line_quantity INTO @line_quantity FROM po_requisition_line WHERE po_requisition_line_id=rqLid;
SET @linePrice=@unitprice*@line_quantity;
SET @taxAmount=IF(@taxpercent IS NULL,0,@taxpercent*@unitprice*@line_quantity/100);
INSERT INTO po_line (po_header_id,po_req_line_id, line_number, receving_org_id, item_id_m, item_description, line_quantity, price_list_header_id, price_date, unit_price, line_price,tax_code_id,tax_amount,gl_line_price,gl_tax_amount, reference_doc_type, reference_doc_number, line_type, line_description, uom_id, STATUS, shipment_number, subinventory_id, locator_id, requestor, ship_to_location_id, quantity, need_by_date, promise_date, charge_ac_id, accrual_ac_id, budget_ac_id, ppv_ac_id, received_quantity, accepted_quantity, delivered_quantity, invoiced_quantity, paid_quantity, reference_key_name, reference_header_id, reference_line_id, created_by, creation_date, last_update_by, last_update_date, rev_enabled_cb, rev_number)
SELECT 	@poid,po_requisition_line_id, line_number, receving_org_id, item_id_m, item_description, line_quantity, NULL, @price_date, @unitprice, @unitprice*line_quantity,@taxcodeid,@taxAmount, IFNULL(@exchange_rate*@linePrice,@linePrice), IFNULL(@exchange_rate*@taxAmount,@taxAmount),reference_doc_type, reference_doc_number, line_type, line_description, uom_id, 1497, shipment_number, subinventory_id, locator_id, created_by, ship_to_location_id, quantity, need_by_date, promise_date, charge_ac_id, accrual_ac_id, budget_ac_id, ppv_ac_id, received_quantity, accepted_quantity, delivered_quantity, invoiced_quantity, paid_quantity, reference_key_name, reference_header_id, reference_line_id, userid, NOW(), userid, NOW(), rev_enabled_cb, rev_number FROM po_requisition_line WHERE po_requisition_line_id=rqLid;
END IF;
END IF;
    END$$

DELIMITER ;

DELIMITER $$

USE `xbs`$$

DROP VIEW IF EXISTS `poreq_po_status`$$

CREATE ALGORITHM=UNDEFINED DEFINER=`i3u`@`localhost` SQL SECURITY DEFINER VIEW `poreq_po_status` AS (
SELECT
  `preql`.`po_requisition_header_id` AS `po_requisition_header_id`,
  GROUP_CONCAT(IFNULL(`ps`.`option_line_value`,0) SEPARATOR ',') AS `po_status`
FROM (((`po_requisition_line` `preql`
     LEFT JOIN (`po_line` `pl` JOIN `po_header` `ph`
      ON ((`pl`.`po_header_id` = `ph`.`po_header_id`) AND (`ph`.`po_status` <> 322)))
       ON ((`preql`.`po_requisition_line_id` = `pl`.`po_req_line_id`))))
   LEFT JOIN `option_line` `ps`
     ON ((`ps`.`option_line_id` = `ph`.`po_status`)))
GROUP BY `preql`.`po_requisition_header_id`)$$

DELIMITER ;

DELIMITER $$

USE `xbs`$$

DROP PROCEDURE IF EXISTS `ConvertPlannedOdr`$$

CREATE DEFINER=`i3u`@`localhost` PROCEDURE `ConvertPlannedOdr`(odrId BIGINT,onchandChk BOOLEAN,userid INT,orgid INT)
BEGIN
SET @uomid=NULL;
SELECT order_type,order_action,item_id_m,need_by_date,CEIL(quantity-onhandconsume),demand_item_id_m,toplevel_demand_item_id_m,source_type,primary_source_type,source_header_id,source_line_id,org_id
INTO @order_type,@order_action,@item_id_m,@need_by_date,@quantity,@demand_item_id_m,@toplevel_demand_item_id_m,@source_type,@primary_source_type,@source_header_id,@source_line_id ,@org_id
FROM fp_mrp_planned_order WHERE fp_mrp_planned_order_id= odrId;
INSERT IGNORE INTO xbs.fp_mrp_planned_sources VALUES (NULL,@primary_source_type,@source_header_id,@source_line_id,@need_by_date,0,'',orgid,userid,NOW(),userid,NOW());
IF @quantity>0 THEN
IF @uomid IS NULL THEN
SELECT uom_id INTO @uomid FROM item WHERE (item_id_m,org_id)=(@item_id_m,@org_id);
END IF;
SELECT address_id INTO @ship2id FROM address WHERE reftbltp='org' AND usage_type=1135 AND refid=@org_id;
SELECT address_id INTO @bill2id FROM address WHERE reftbltp='org' AND usage_type=1136 AND refid=@org_id;
IF(@order_type='wo') THEN
SELECT wip_accounting_group_id INTO @waccid FROM xbs.wip_accounting_group WHERE wo_type='368' AND org_id=@org_id;
SELECT bom_header_id INTO @bomId FROM bom_header WHERE item_id_m=@item_id_m AND org_id=@org_id;
SELECT bom_routing_header_id,completion_subinventory,completion_locator INTO @routeId,@subinv,@loc FROM bom_routing_header WHERE item_id_m=@item_id_m AND org_id=@org_id;
IF @subinv IS NULL OR @subinv=0 THEN
SELECT receipt_sub_inventory INTO @subinv FROM item WHERE (item_id_m,org_id)=(@item_id_m,@org_id);
END IF;
IF(@bomId IS NOT NULL AND @routeId IS NOT NULL) THEN
INSERT INTO wip_wo_header (item_id_m,wo_number,revision_name,org_id,wip_accounting_group_id,wo_type,wo_status,start_date,completion_date,quantity,nettable_quantity,reference_bom_item_id_m,bom_exploded_cb,routing_exploded_cb,reference_routing_item_id_m,completion_sub_inventory,completion_locator,schedule_group,build_sequence,created_by,creation_date,last_update_by,last_update_date)
 VALUES (@item_id_m,'',NULL,@org_id,@waccid,368,369,NOW(),@need_by_date,@quantity,@quantity,@bomId,NULL,NULL,@routeId,@subinv,@loc,NULL,NULL,userid,NOW(),userid,NOW());
SELECT LAST_INSERT_ID() INTO @woid;
INSERT INTO xbs.wip_wo_allocation (wip_wo_header_id,item_id_m,demand_source_type,demand_source_header_id,demand_source_line_id,org_id)
 VALUE(@woid,@item_id_m,@primary_source_type,@source_header_id,@source_line_id ,@org_id);
END IF;
ELSEIF(@order_type='prq') THEN
SET @prqid=NULL;
SET @buorg=NULL;
SET @orgtp=NULL;
SELECT TYPE INTO @orgtp FROM org WHERE org_id=orgid;
IF @orgtp=74 THEN
SELECT parent_org_id INTO @buorg FROM org WHERE org_id=orgid;
SELECT po_requisition_header_id INTO @prqid FROM po_requisition_header WHERE (created_by,requisition_status)=(userid,321) ORDER BY creation_date DESC LIMIT 0,1;
IF @prqid IS NULL THEN
INSERT INTO po_requisition_header (po_requisition_type,reference_key_name,reference_key_value,description,ship_to_id,bill_to_id,currency,payment_term_id,supply_org_id,bu_org_id,requisition_status,created_by,creation_date,last_update_by,last_update_date)
 VALUES('563',NULL,NULL,'',@ship2id,@bill2id,NULL,NULL,'',@buorg,321,userid,NOW(),userid,NOW());
SELECT LAST_INSERT_ID() INTO @prqid;
END IF;
INSERT INTO po_requisition_line (po_requisition_header_id,line_type,receving_org_id,item_id_m,item_description,uom_id,unit_price,price_date,line_quantity,line_price,line_description,need_by_date,reference_key_name,reference_header_id,reference_line_id,created_by,creation_date,last_update_by,last_update_date) 
 VALUES(@prqid,'329',@org_id,@item_id_m,'',@uomid,NULL,NULL,@quantity,NULL,'',@need_by_date,@primary_source_type,@source_header_id,@source_line_id,userid,NOW(),userid,NOW());
ELSEIF @orgtp=73 THEN
SET @spid=NULL;
SET @currency=NULL;
SET @unitprice=NULL;
SET @payment=NULL;
SET @buorg=orgid;
SET @poid=NULL;
SELECT supplier_id,quote_unit_price INTO @spid,@unitprice FROM xbs.po_quote_supplier_v WHERE item_id_m=@item_id_m AND bu_org_id=orgid ORDER BY quote_unit_price LIMIT 0,1;
IF @spid IS NOT NULL THEN
SELECT currency_id,payment_term_id INTO @currency,@payment FROM supplier_all_v WHERE supplier_id=@spid;
SELECT po_header_id INTO @poid FROM supplier_quote_po_v WHERE (item_id_m,supplier_id,bu_org_id,created_by)=(@item_id_m,@spid,orgid,userid);
IF @poid IS NULL THEN
SELECT currency_code INTO @currencyLedger FROM org_ledger_v WHERE org_id=orgid;
SET @exchange_rate=NULL;
SET @exchange_rate_cvid=NULL;
IF @currencyLedger=@currency THEN
SET @exchange_rate=1;
ELSE
SELECT rate exchange_rate,gl_currency_conversion_id INTO @exchange_rate,@exchange_rate_cvid FROM xbs.gl_currency_conversion WHERE from_currency=@currency AND to_currency=@currencyLedger;
END IF;
INSERT INTO xbs.po_header (po_type,description,supplier_id,supplier_site_id,payment_term_id,ship_to_id,bill_to_id,currency,doc_currency,exchange_rate_type,exchange_rate,agreement_start_date,agreement_end_date,rev_number,po_req_header_id,po_number,created_by,creation_date,last_update_by,last_update_date,po_status,bu_org_id) 
VALUES('319','',@spid,'',@payment,@ship2id,@bill2id,@currencyLedger,@currency,@exchange_rate_cvid, @exchange_rate,NOW(),NOW(),'','','',userid,NOW(),userid,NOW(),321,orgid);
SELECT LAST_INSERT_ID() INTO @poid;
END IF;
ELSE
INSERT INTO xbs.xbs_log (log_level,task,program,msg,user_id,org_id,dt)VALUES('error','MRP_ODRS','PoMRP-OrderLine',CONCAT('Item(',@item_id_m,') -- Find Supplier Failed!'),userid,orgId,NOW());
END IF;
IF @poid IS NOT NULL THEN
SET @taxcodeid=NULL;
SET @taxpercent=NULL;
SELECT valid_date,tax_code_id INTO @price_date,@taxcodeid FROM po_quote_v WHERE (rev AND quote_status=1489) AND supplier_id=@spid AND item_id_m=@item_id_m;
IF @taxcodeid IS NOT NULL THEN
SELECT percentage INTO @taxpercent FROM mdm_tax_code WHERE mdm_tax_code_id=@taxcodeid;
END IF;
SET @linePrice=@unitprice*@quantity;
SET @taxAmount=IF(@taxpercent IS NULL,0,@taxpercent*@unitprice*@quantity/100);
INSERT INTO xbs.po_line (po_header_id,line_type,receving_org_id,item_id_m,item_description,uom_id,price_date,unit_price,line_quantity,line_price,tax_code_id,tax_amount,gl_line_price,gl_tax_amount,line_description,need_by_date,reference_key_name,reference_header_id,reference_line_id,po_req_line_id,STATUS,created_by,creation_date,last_update_by,last_update_date) 
VALUES(@poid,'329',@org_id,@item_id_m,'',@uomid,@price_date,@unitprice,@quantity,@linePrice,@taxcodeid,@taxAmount, IFNULL(@exchange_rate*@linePrice,@linePrice),IFNULL(@exchange_rate*@taxAmount,@taxAmount),'',@need_by_date,@primary_source_type,@source_header_id,@source_line_id,'',1497,userid,NOW(),userid,NOW());
END IF;
END IF;
END IF;
END IF;
    END$$

DELIMITER ;

#@20190706
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
    IF(new.accepted_quantity != old.accepted_quantity) THEN
    IF new.accepted_quantity>=old.line_quantity THEN 
    SET new.status=1500;
    SELECT COUNT(po_line_id) INTO @cnt FROM po_line WHERE po_header_id=old.po_header_id AND (STATUS!=1500 AND po_line_id!=old.po_line_id);
    IF @cnt=0 THEN
	UPDATE po_header SET po_status=323 WHERE po_header_id=old.po_header_id;
    END IF;
    END IF;
    IF old.po_req_line_id>0 THEN
	UPDATE po_requisition_line SET accepted_quantity=new.accepted_quantity,STATUS=new.status WHERE po_requisition_line_id=new.po_req_line_id;
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

DROP TRIGGER /*!50032 IF EXISTS */ `poRequisitionLindUpdate`$$

CREATE
    /*!50017 DEFINER = 'i3u'@'localhost' */
    TRIGGER `poRequisitionLindUpdate` BEFORE UPDATE ON `po_requisition_line` 
    FOR EACH ROW BEGIN
    IF new.line_price IS NOT NULL THEN
UPDATE po_requisition_header SET header_amount=header_amount+NEW.line_price-OLD.line_price WHERE po_requisition_header_id=old.po_requisition_header_id;
IF new.status != old.status THEN
    SELECT COUNT(po_requisition_line_id) INTO @cnt FROM po_requisition_line WHERE po_requisition_header_id=old.po_requisition_header_id AND (STATUS!=1500 AND po_requisition_line_id!=old.po_requisition_line_id);
    IF @cnt=0 THEN
	UPDATE po_requisition_header SET requisition_status=323 WHERE po_requisition_header_id=old.po_requisition_header_id;
    END IF;
END IF;
END IF;
    END;
$$

DELIMITER ;

UPDATE xbs.po_requisition_line prl JOIN xbs.po_line pl ON prl.po_requisition_line_id=pl.po_req_line_id SET prl.accepted_quantity=pl.accepted_quantity,prl.STATUS=pl.status;

DELIMITER $$

USE `xbs`$$

DROP FUNCTION IF EXISTS `calOnhandDT`$$

CREATE DEFINER=`i3u`@`localhost` FUNCTION `calOnhandDT`(item INT,dt DATE,org INT) RETURNS FLOAT
BEGIN
SELECT purchased_cb,customer_ordered_cb,make_buy INTO @purchase,@orderable,@makebuy FROM item WHERE (item_id_m,org_id)=(item,org);
SET @onhand=NULL;
SET @need=NULL;
SELECT SUM(onhand) INTO @onhand FROM onhand WHERE item_id_m=item AND org_id=org;
SET @onhand=IFNULL(@onhand,0);
SELECT SUM(required_quantity-issued_quantity) INTO @need FROM wip_wo_bom_v WHERE (material_id=item AND org_id=org) AND (IF(dt IS NULL,1,start_date<dt) AND wo_status<374);
SET @onhand=@onhand-IFNULL(@need,0);
SET @need=NULL;
IF @orderable THEN
SELECT SUM(line_quantity-shipped_quantity) INTO @need FROM sd_so_line WHERE (item_id_m=item AND shipping_org_id=org) AND (IF(dt IS NULL,1,IFNULL(schedule_ship_date,promise_date)<dt)) AND line_status IN (1529,1530,1531,1532,1534);
SET @onhand=@onhand-IFNULL(@need,0);
END IF;
SET @recving=NULL;
IF @purchase THEN
SELECT SUM(line_quantity-accepted_quantity) INTO @recving FROM po_line_v WHERE (item_id_m=item AND org_id=org) AND IF(dt IS NULL,1,promise_date<dt) AND STATUS NOT IN (1499,1500)AND line_type!=1619;
SET @onhand=@onhand+IFNULL(@recving,0);
SET @recving=NULL;
END IF;
IF @makebuy='make' THEN
SELECT SUM(quantity-completed_quantity) INTO @recving FROM wip_wo_header WHERE (item_id_m=item AND org_id=org) AND IF(dt IS NULL,1,completion_date<dt) AND wo_status<374;
SET @onhand=@onhand+IFNULL(@recving,0);
END IF;
RETURN @onhand;
    END$$

DELIMITER ;

DELIMITER $$

USE `xbs`$$

DROP VIEW IF EXISTS `fp_mrp_planned_sources_v`$$

CREATE ALGORITHM=UNDEFINED DEFINER=`i3u`@`localhost` SQL SECURITY DEFINER VIEW `fp_mrp_planned_sources_v` AS (
SELECT
  `ps`.`source_type`               AS `source_type`,
  IF((`ps`.`source_type` = _utf8'sd_so_header'),`so`.`so_number`,`fc`.`forecast`) AS `source_order`,
  IF((`ps`.`source_type` = _utf8'sd_so_header'),CONCAT(`si`.`item_number`,'_',`ps`.`source_date`),CONCAT(`fi`.`item_number`,'_',`ps`.`source_date`)) AS `source_detail`,
  `ps`.`source_header_id`          AS `source_header_id`,
  `ps`.`source_line_id`            AS `source_line_id`,
  `ps`.`source_date`               AS `source_date`,
  `ps`.`deleted`                   AS `deleted`,
  `ps`.`decription`                AS `decription`,
  `ps`.`org_id`                    AS `org_id`,
  `ps`.`created_by`                AS `created_by`,
  `ps`.`creation_date`             AS `creation_date`,
  `ps`.`last_update_by`            AS `last_update_by`,
  `ps`.`last_update_date`          AS `last_update_date`,
  `ps`.`fp_mrp_planned_sources_id` AS `fp_mrp_planned_sources_id`
FROM (((((((`fp_mrp_planned_sources` `ps`
         LEFT JOIN `sd_so_header` `so`
           ON (((`ps`.`source_type` = _utf8'sd_so_header')
                AND (`ps`.`source_header_id` = `so`.`sd_so_header_id`))))
        LEFT JOIN `sd_so_line` `sl`
          ON (((`ps`.`source_type` = _utf8'sd_so_header')
               AND (`ps`.`source_line_id` = `sl`.`sd_so_line_id`))))
       LEFT JOIN `item` `si`
         ON (((`sl`.`item_id_m` = `si`.`item_id_m`)
              AND (`sl`.`shipping_org_id` = `si`.`org_id`))))
      LEFT JOIN `fp_forecast_line` `fl`
        ON (((`ps`.`source_type` = _utf8'fp_forecast_header')
             AND (`ps`.`source_header_id` = `fl`.`fp_forecast_line_id`))))
     LEFT JOIN `fp_forecast_header` `fc`
       ON ((`fl`.`fp_forecast_header_id` = `fc`.`fp_forecast_header_id`)))
    LEFT JOIN `fp_forecast_line_date` `fld`
      ON ((`fld`.`fp_forecast_line_date_id` = `ps`.`source_line_id`)))
   LEFT JOIN `item` `fi`
     ON (((`fl`.`item_id_m` = `fi`.`item_id_m`)
          AND (`fc`.`org_id` = `fi`.`org_id`)))))$$

DELIMITER ;

#@20190708
DELETE FROM  xbs.option_line WHERE option_header_id IN (312,313);
INSERT IGNORE INTO xbs.option_header (option_header_id,module_code,option_type,description,created_by,creation_date,last_update_by,last_update_date) 
VALUES(312,'inv','INV_COUNT_APPROVAL','INV Count Approval Option','14',NOW(),'14',NOW());
INSERT IGNORE INTO xbs.option_line (option_header_id,option_line_id,option_line_code,option_line_value,description,STATUS,created_by,creation_date,last_update_by,last_update_date) 
VALUES('312',1623,'NEVER','从不','','1','14',NOW(),'14',NOW())
,('312',1624,'ALWAYS','总是','','1','14',NOW(),'14',NOW())
,('312',1625,'OUT_OF_TOLERANCE_ALL','全部超限','','1','14',NOW(),'14',NOW())
,('312',1626,'OUT_OF_TOLERANCE_ANY','任一超限','','1','14',NOW(),'14',NOW());
INSERT IGNORE INTO xbs.option_header (option_header_id,module_code,option_type,description,created_by,creation_date,last_update_by,last_update_date) 
VALUES(313,'inv','INV_COUNT_STATUS','INV Count Status','14',NOW(),'14',NOW());
INSERT IGNORE INTO xbs.option_line (option_header_id,option_line_id,option_line_code,option_line_value,description,STATUS,created_by,creation_date,last_update_by,last_update_date) 
VALUES('313',1630,'IMCOMPLETE','编辑','','1','14',NOW(),'14',NOW())
,('313',1631,'SCHEDULE','已计划','','1','14',NOW(),'14',NOW())
,('313',1632,'COUNTED','已盘点','','1','14',NOW(),'14',NOW())
,('313',1633,'APPROVED','已批准','','1','14',NOW(),'14',NOW())
,('313',1634,'POSTED','已更新','','1','14',NOW(),'14',NOW())
,('313',1635,'CANCEL','已取消','','1','14',NOW(),'14',NOW());
CALL xbs.tbColumnAddChg('xbs','inv_count_header','status','','SMALLINT(6) DEFAULT 1630','','');

#@20190709
DELIMITER $$

USE `xbs`$$

DROP VIEW IF EXISTS `po_requisition_header_v`$$

CREATE ALGORITHM=UNDEFINED DEFINER=`i3u`@`localhost` SQL SECURITY DEFINER VIEW `po_requisition_header_v` AS (
SELECT
  `o`.`option_line_value`        AS `po_requisition_type`,
  `p`.`po_requisition_number`    AS `po_requisition_number`,
  MAX(`pl`.`need_by_date`)       AS `need_by_date`,
  MAX(`pl`.`promise_date`)       AS `promise_date`,
  `o0`.`option_line_value`       AS `requisition_statusv`,
  `ps`.`po_status`               AS `po_status`,
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
FROM (((((((((((`po_requisition_header` `p`
             LEFT JOIN `po_requisition_line` `pl`
               ON ((`p`.`po_requisition_header_id` = `pl`.`po_requisition_header_id`)))
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
GROUP BY `p`.`po_requisition_header_id`
ORDER BY `p`.`po_requisition_header_id`)$$

DELIMITER ;

DELIMITER $$

USE `xbs`$$

DROP VIEW IF EXISTS `po_requisition_line_v`$$

CREATE ALGORITHM=UNDEFINED DEFINER=`i3u`@`localhost` SQL SECURITY DEFINER VIEW `po_requisition_line_v` AS (
SELECT
  `ph`.`po_requisition_number`    AS `po_requisition_number`,
  `po`.`po_number`                AS `po_number`,
  `i`.`item_number`               AS `item_number`,
  `i`.`item_name`                 AS `item_name`,
  `p`.`line_quantity`             AS `line_quantity`,
  `pl`.`received_quantity`        AS `received_quantity`,
  `pl`.`accepted_quantity`        AS `accepted_quantity`,
  `u`.`uom_name`                  AS `uom_name`,
  `p`.`need_by_date`              AS `need_by_date`,
  `pl`.`promise_date`             AS `promise_date`,
  `prs`.`option_line_value`       AS `requisition_statusv`,
  `ps`.`option_line_value`        AS `po_statusv`,
  `i`.`item_specification`        AS `item_specification`,
  `i`.`item_description`          AS `item_description`,
  `p`.`line_number`               AS `line_number`,
  `p`.`line_description`          AS `line_description`,
  `o1`.`option_line_value`        AS `STATUS`,
  `o`.`option_line_value`         AS `line_type`,
  `o0`.`org`                      AS `receving_org`,
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
  `p`.`price_date`                AS `price_date`,
  `p`.`line_price`                AS `line_price`,
  `p`.`created_by`                AS `created_by`,
  `p`.`creation_date`             AS `creation_date`,
  `p`.`last_update_by`            AS `last_update_by`,
  `p`.`last_update_date`          AS `last_update_date`
FROM (((((((((`po_requisition_line` `p`
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
    LEFT JOIN (`po_line` `pl`
               JOIN `po_header` `po`
                 ON (((`pl`.`po_header_id` = `po`.`po_header_id`)
                      AND (`po`.`po_status` <> 322))))
      ON ((`p`.`po_requisition_line_id` = `pl`.`po_req_line_id`)))
   LEFT JOIN `option_line` `ps`
     ON ((`po`.`po_status` = `ps`.`option_line_id`))))$$

DELIMITER ;

CALL xbs.tbColumnAddChg('xbs','fp_forecast_group','status','','TINYINT(1) DEFAULT 1','','');

#@20190711

DELIMITER $$

USE `xbs`$$

DROP TRIGGER /*!50032 IF EXISTS */ `fp_forecast_line_insertA`$$

CREATE
    /*!50017 DEFINER = 'i3u'@'localhost' */
    TRIGGER `fp_forecast_line_insertA` AFTER INSERT ON `fp_forecast_line` 
    FOR EACH ROW BEGIN
IF new.bucket_type=568 THEN
INSERT INTO xbs.fp_forecast_line_date (forecast_date,original_quantity,current_quantity,fp_forecast_line_id,source,created_by,creation_date,last_update_by,last_update_date) 
SELECT week_start_date,new.original,new.original,new.fp_forecast_line_id,'Forecast',new.created_by,NOW(),new.last_update_by,NOW() 
FROM (SELECT WEEK(dt) seq_num,SUBDATE(dt,wd) week_start_date,ADDDATE(dt,6-wd) week_end_date FROM (
SELECT DATE_FORMAT(CURDATE(),'%w') wd,ADDDATE(CURDATE(),7*(fake_id-1)) dt FROM a_fake_ids WHERE fake_id<5
) t 
) cwsd WHERE week_start_date BETWEEN new.start_date AND new.end_date;
ELSEIF new.bucket_type=567 THEN
INSERT INTO xbs.fp_forecast_line_date (forecast_date,original_quantity,current_quantity,fp_forecast_line_id,source,created_by,creation_date,last_update_by,last_update_date) 
SELECT dt,new.original,new.original,new.fp_forecast_line_id,'Forecast',new.created_by,NOW(),new.last_update_by,NOW() 
FROM ((SELECT @num:=@num+1,DATE_FORMAT(ADDDATE(new.start_date, INTERVAL @num DAY),'%Y-%m-%d') AS dt FROM a_fake_ids,(SELECT @num:=-1) t WHERE ADDDATE(new.start_date, INTERVAL @num DAY) < new.end_date) dtbl);
END IF;
    END;
$$

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
  `ph`.`supplier_id`      AS `supplier_id`,
  `ph`.`created_by`       AS `created_by`,
  `ph`.`creation_date`    AS `creation_date`,
  `ph`.`last_update_by`   AS `last_update_by`,
  `ph`.`last_update_date` AS `last_update_date`
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

DROP PROCEDURE IF EXISTS `forecastConsumeLineDate`$$

CREATE DEFINER=`i3u`@`localhost` PROCEDURE `forecastConsumeLineDate`(solid BIGINT,INOUT qty DECIMAL(20,5),itemId BIGINT,fcgroup INT,dtS DATE,dtE DATE,userid INT,orgid INT)
BEGIN
DECLARE fclid INT;
DECLARE fcldtid INT;
DECLARE fcdt DATE;
DECLARE fcqtyo DECIMAL(20,5);
DECLARE fcqtyc DECIMAL(20,5);
DECLARE fcitem INT;
DECLARE fcgrp INT;
DECLARE done INT;
DECLARE fcdts CURSOR FOR SELECT fld.fp_forecast_line_id,fld.fp_forecast_line_date_id,fld.forecast_date, fld.original_quantity, fld.current_quantity, fl.item_id_m,fh.forecast_group_id 
FROM fp_forecast_line_date fld,fp_forecast_line fl,fp_forecast_header fh LEFT JOIN fp_forecast_group fg ON fg.fp_forecast_group_id = fh.forecast_group_id 
WHERE fl.fp_forecast_line_id = fld.fp_forecast_line_id AND fh.fp_forecast_header_id = fl.fp_forecast_header_id AND fl.item_id_m = itemId AND IF(dtE IS NULL,(fld.forecast_date = dtS),(fld.forecast_date >= dtS AND fld.forecast_date <= dtE )) AND IF(fcgroup IS NULL,1,fh.forecast_group_id = fcgroup);
DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = 1;
OPEN fcdts;
  BEGIN_fcdts: LOOP
  FETCH fcdts INTO fclid,fcldtid,fcdt,fcqtyo,fcqtyc,fcitem,fcgrp;
#INSERT INTO xbs.xbs_log (log_level,task,program,msg,user_id,org_id,dt)VALUES('info','fp_consume','consuming',CONCAT('FC LineDT:',IFNULL(itemId,'NULL'),dtS,'_',IFNULL(dtE,''),'_',solid,'_',IFNULL(fcqtyc,'NULL'),' ...'),userid,orgId,NOW());
    IF done THEN
      LEAVE BEGIN_fcdts;
    END IF;
    IF fcqtyc>0 THEN
      IF fcqtyc>qty THEN
        SET @qty2cs=qty;
        SET qty=0;
      ELSE
        SET @qty2cs=fcqtyc;
        SET qty=qty-@qty2cs;
      END IF;
      INSERT INTO fp_forecast_consumption (fp_forecast_line_date_id,fp_forecast_line_id,fp_forecast_group_id,sd_so_line_id,quantity,created_by,creation_date,last_update_by,last_update_date) 
      VALUES(fcldtid,fclid,fcgrp,solid,@qty2cs,userid,NOW(),userid,NOW());
      UPDATE fp_forecast_line_date SET current_quantity = current_quantity-@qty2cs WHERE fp_forecast_line_date_id=fcldtid;
INSERT INTO xbs.xbs_log (log_level,task,program,msg,user_id,org_id,dt)VALUES('info','fp_consume','consuming',CONCAT('FC LineDT:',fcldtid,'_',@qty2cs,'_',fcdt,' Done'),userid,orgId,NOW());
    END IF;
    IF qty<=0 THEN
	LEAVE BEGIN_fcdts;
    END IF;
    END LOOP BEGIN_fcdts;
CLOSE fcdts;
END$$

DELIMITER ;

DELIMITER $$

USE `xbs`$$

DROP PROCEDURE IF EXISTS `forecastConsumeRemoveLineDate`$$

CREATE DEFINER=`i3u`@`localhost` PROCEDURE `forecastConsumeRemoveLineDate`(solid BIGINT,INOUT qty DECIMAL(20,5),itemId BIGINT,fcgroup INT,dtS DATE,dtE DATE,userid INT,orgid INT)
BEGIN
DECLARE fclid INT;
DECLARE fcldtid INT;
DECLARE fcdt DATE;
DECLARE fcqtyo DECIMAL(20,5);
DECLARE fcqtyc DECIMAL(20,5);
DECLARE fcitem INT;
DECLARE fcgrp INT;
DECLARE done INT;
DECLARE fcdts CURSOR FOR SELECT fld.fp_forecast_line_id,fld.fp_forecast_line_date_id,fld.forecast_date, fld.original_quantity, fld.current_quantity, fl.item_id_m,fh.forecast_group_id 
FROM fp_forecast_line_date fld,fp_forecast_line fl,fp_forecast_header fh LEFT JOIN fp_forecast_group fg ON fg.fp_forecast_group_id = fh.forecast_group_id 
WHERE fl.fp_forecast_line_id = fld.fp_forecast_line_id AND fh.fp_forecast_header_id = fl.fp_forecast_header_id AND fl.item_id_m = itemId AND IF(dtE IS NULL,(fld.forecast_date = dtS),(fld.forecast_date >= dtS AND fld.forecast_date <= dtE )) AND IF(fcgroup IS NULL,1,fh.forecast_group_id = fcgroup);
DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = 1;
OPEN fcdts;
  BEGIN_fcdts: LOOP
  FETCH fcdts INTO fclid,fcldtid,fcdt,fcqtyo,fcqtyc,fcitem,fcgrp;
    IF done THEN
      LEAVE BEGIN_fcdts;
    END IF;
    IF fcqtyo>0 THEN
      IF fcqtyo>ABS(qty) THEN
        SET @qty2cs=qty;
        SET qty=0;
      ELSE
        SET @qty2cs=-fcqtyo;
        SET qty=qty-@qty2cs;
      END IF;
      INSERT INTO fp_forecast_consumption (fp_forecast_line_date_id,fp_forecast_line_id,fp_forecast_group_id,sd_so_line_id,quantity,created_by,creation_date,last_update_by,last_update_date) 
      VALUES(fcldtid,fclid,fcgrp,solid,@qty2cs,userid,NOW(),userid,NOW());
      UPDATE fp_forecast_line_date SET current_quantity = current_quantity-@qty2cs WHERE fp_forecast_line_date_id=fcldtid;
INSERT INTO xbs.xbs_log (log_level,task,program,msg,user_id,org_id,dt)VALUES('info','fp_consume','consuming',CONCAT('FC LineDT:',fcldtid,'_',@qty2cs,'_',fcdt,' Remove'),userid,orgId,NOW());
    END IF;
    IF qty<=0 THEN
	LEAVE BEGIN_fcdts;
    END IF;
    END LOOP BEGIN_fcdts;
CLOSE fcdts;
END$$

DELIMITER ;

DELIMITER $$

USE `xbs`$$

DROP PROCEDURE IF EXISTS `forecastConsumeSO`$$

CREATE DEFINER=`i3u`@`localhost` PROCEDURE `forecastConsumeSO`(fcgroup INT(11),itemId INT,itemOrgId INT,date_from DATE,userid INT,orgid INT)
BEGIN
SET @backdays=28;
SET @forwarddays=28;
IF fcgroup IS NOT NULL THEN 
SELECT backward_days,forward_days INTO @backdays,@forwarddays FROM xbs.fp_forecast_group WHERE fp_forecast_group_id=fcgroup;
END IF;
    SET @solid=0;
    SET @solidseq=0;
    WHILE @solid IS NOT NULL DO
    SET @solid=NULL;
    SELECT sd_so_line_id,line_quantity,item_id_m,schedule_ship_date INTO @solid,@solqty,@solitemid,@solssdt 
    FROM xbs.sd_so_line WHERE shipping_org_id = itemOrgId AND schedule_ship_date IS NOT NULL AND item_id_m = itemId AND IF(date_from IS NULL,1,(schedule_ship_date >= date_from)) AND sd_so_line_id>@solidseq ORDER BY sd_so_line_id LIMIT 0,1;
    IF @solid IS NOT NULL THEN
      SET @solidseq=@solid;
      SET @total_consumed=0;
      SELECT IFNULL(SUM(quantity),0) INTO @total_consumed FROM xbs.fp_forecast_consumption WHERE sd_so_line_id = @solid AND quantity > 0 AND IF(fcgroup IS NULL,1,fp_forecast_group_id = fcgroup);
      SET @qty_tobe_consumed=@solqty-@total_consumed;
INSERT INTO xbs.xbs_log (log_level,task,program,msg,user_id,org_id,dt)VALUES('info','fp_consume','consuming',CONCAT('SO Line:',@solid,'_',@qty_tobe_consumed,'_',@solssdt,@solitemid,' Begin'),userid,orgId,NOW());
     IF @qty_tobe_consumed < 0 THEN
	CALL forecastConsumeRemoveLineDate(@solid,@qty_tobe_consumed,@solitemid,fcgroup,@solssdt,NULL,userid,orgid);
	IF @qty_tobe_consumed>0 THEN
	  CALL forecastConsumeRemoveLineDate(@solid,@qty_tobe_consumed,@solitemid,fcgroup,SUBDATE(@solssdt,@backdays),@solssdt,userid,orgid);
	END IF;
	IF @qty_tobe_consumed>0 THEN
	  CALL forecastConsumeRemoveLineDate(@solid,@qty_tobe_consumed,@solitemid,fcgroup,@solssdt,ADDDATE(@solssdt,@forwarddays),userid,orgid);
	END IF;
      END IF;
      IF @qty_tobe_consumed > 0 THEN
	CALL forecastConsumeLineDate(@solid,@qty_tobe_consumed,@solitemid,fcgroup,@solssdt,NULL,userid,orgid);
	IF @qty_tobe_consumed>0 THEN
	  CALL forecastConsumeLineDate(@solid,@qty_tobe_consumed,@solitemid,fcgroup,SUBDATE(@solssdt,@backdays),@solssdt,userid,orgid);
	END IF;
	IF @qty_tobe_consumed>0 THEN
	  CALL forecastConsumeLineDate(@solid,@qty_tobe_consumed,@solitemid,fcgroup,@solssdt,ADDDATE(@solssdt,@forwarddays),userid,orgid);
	END IF;
      END IF;
INSERT INTO xbs.xbs_log (log_level,task,program,msg,user_id,org_id,dt)VALUES('info','fp_consume','consuming',CONCAT('SO Line:',@solid,'_',@qty_tobe_consumed,' END'),userid,orgId,NOW());
    END IF;
    END WHILE;
    END$$

DELIMITER ;

DELIMITER $$

USE `xbs`$$

DROP PROCEDURE IF EXISTS `forecastConsume`$$

CREATE DEFINER=`i3u`@`localhost` PROCEDURE `forecastConsume`(fcgroup INT(11),fcorgid INT(11),date_from DATE,offset_days TINYINT(4),userid INT,orgid INT)
BEGIN
DECLARE itemId INT;
DECLARE itemOrgId INT;
DECLARE done INT;
DECLARE fcitems CURSOR FOR SELECT DISTINCT(ffl.item_id_m), ffg.org_id FROM fp_forecast_line ffl ,fp_forecast_header ffh,fp_forecast_group ffg
WHERE ffh.fp_forecast_header_id = ffl.fp_forecast_header_id AND ffh.forecast_group_id = ffg.fp_forecast_group_id AND IF(fcgroup IS NULL,1,ffg.fp_forecast_group_id = fcgroup);
DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = 1;
DELETE FROM xbs_log WHERE task='fp_consume' AND user_id=userid;
INSERT INTO xbs.xbs_log (log_level,task,program,msg,user_id,org_id,dt)VALUES('info','fp_consume','consuming',CONCAT(fcgroup,' Begin...'),userid,orgId,NOW());
IF offset_days!=0 THEN
SET date_from=ADDDATE(date_from,offset_days);
END IF;
OPEN fcitems;
  BEGIN_fcitems: LOOP
  FETCH fcitems INTO itemId,itemOrgId;
    IF done THEN
      LEAVE BEGIN_fcitems;
    END IF;
INSERT INTO xbs.xbs_log (log_level,task,program,msg,user_id,org_id,dt)VALUES('info','fp_consume','consuming',CONCAT('Item:',itemId,'_',itemOrgId,' Begin'),userid,orgId,NOW());
	CALL forecastConsumeSO(fcgroup,itemId,itemOrgId,date_from,userid,orgId);
INSERT INTO xbs.xbs_log (log_level,task,program,msg,user_id,org_id,dt)VALUES('info','fp_consume','consuming',CONCAT('Item:',itemId,'_',itemOrgId,' End'),userid,orgId,NOW());
    END LOOP BEGIN_fcitems;
INSERT INTO xbs.xbs_log (log_level,task,program,msg,user_id,org_id,dt)VALUES('info','fp_consume','consuming','End',userid,orgId,NOW());
    CLOSE fcitems;
    END$$

DELIMITER ;

DELIMITER $$

USE `xbs`$$

DROP PROCEDURE IF EXISTS `ConvertPlannedOrder`$$

CREATE DEFINER=`i3u`@`localhost` PROCEDURE `ConvertPlannedOrder`(odrtp VARCHAR(10),odrItem INT,odrNeedDT DATE,odrQtY DECIMAL(20,5),odrPriSrcTp INT,odrSrcHdrId INT,odrSrcLineId BIGINT,odrOrgId INT,userid INT,orgid INT)
BEGIN
INSERT INTO xbs.xbs_log (log_level,task,program,msg,user_id,org_id,dt)VALUES('info','MRP_ODRS','ConvertPlannedOrder',CONCAT(odrtp,',',odrItem,',',odrNeedDT,',',odrQtY,',',odrPriSrcTp,',',odrSrcHdrId,',',odrSrcLineId,',',odrOrgId),userid,orgId,NOW());
SET @uomid=NULL;
IF odrQtY>0 THEN
IF @uomid IS NULL THEN
SELECT uom_id INTO @uomid FROM item WHERE (item_id_m,org_id)=(odrItem,odrOrgId);
END IF;
SELECT address_id INTO @ship2id FROM address WHERE reftbltp='org' AND usage_type=1135 AND refid=odrOrgId;
SELECT address_id INTO @bill2id FROM address WHERE reftbltp='org' AND usage_type=1136 AND refid=odrOrgId;
IF(odrtp='wo') THEN
SET @haswo=NULL;
SELECT wip_allocation_id INTO @haswo FROM wip_wo_allocation WHERE item_id_m=odrItem AND org_id=odrOrgId AND demand_source_type=odrPriSrcTp AND demand_source_header_id=odrSrcHdrId AND (demand_source_line_id=0 OR demand_source_line_id=odrSrcLineId) LIMIT 1;
IF(@haswo IS NULL) THEN
SELECT wip_accounting_group_id INTO @waccid FROM xbs.wip_accounting_group WHERE wo_type='368' AND org_id=odrOrgId;
SELECT bom_header_id INTO @bomId FROM bom_header WHERE item_id_m=odrItem AND org_id=odrOrgId;
SELECT bom_routing_header_id,completion_subinventory,completion_locator INTO @routeId,@subinv,@loc FROM bom_routing_header WHERE item_id_m=odrItem AND org_id=odrOrgId;
IF @subinv IS NULL OR @subinv=0 THEN
SELECT receipt_sub_inventory INTO @subinv FROM item WHERE (item_id_m,org_id)=(odrItem,odrOrgId);
END IF;
IF(@bomId IS NOT NULL AND @routeId IS NOT NULL) THEN
INSERT INTO wip_wo_header (item_id_m,wo_number,revision_name,org_id,wip_accounting_group_id,wo_type,wo_status,start_date,completion_date,quantity,nettable_quantity,reference_bom_item_id_m,bom_exploded_cb,routing_exploded_cb,reference_routing_item_id_m,completion_sub_inventory,completion_locator,schedule_group,build_sequence,created_by,creation_date,last_update_by,last_update_date)
 VALUES (odrItem,'',NULL,odrOrgId,@waccid,368,369,NOW(),odrNeedDT,odrQtY,odrQtY,@bomId,NULL,NULL,@routeId,@subinv,@loc,NULL,NULL,userid,NOW(),userid,NOW());
SELECT LAST_INSERT_ID() INTO @woid;
INSERT INTO xbs.wip_wo_allocation (wip_wo_header_id,item_id_m,demand_source_type,demand_source_header_id,demand_source_line_id,org_id)
 VALUE(@woid,odrItem,odrPriSrcTp,odrSrcHdrId,odrSrcLineId ,odrOrgId);
END IF;
END IF;
ELSEIF(odrtp='prq') THEN
SET @haspo=NULL;
SELECT po_requisition_line_id INTO @haspo FROM po_requisition_line WHERE item_id_m=odrItem AND receving_org_id=odrOrgId AND reference_key_name=odrPriSrcTp AND reference_header_id=odrSrcHdrId AND (reference_line_id=0 OR reference_line_id=odrSrcLineId) LIMIT 1;
IF(@haspo IS NULL) THEN
SELECT po_line_id INTO @haspo FROM po_line WHERE item_id_m=odrItem AND receving_org_id=odrOrgId AND reference_key_name=odrPriSrcTp AND reference_header_id=odrSrcHdrId AND (reference_line_id=0 OR reference_line_id=odrSrcLineId) LIMIT 1;
END IF;
IF(@haspo IS NULL) THEN
SET @prqid=NULL;
SET @buorg=NULL;
SET @orgtp=NULL;
SELECT TYPE INTO @orgtp FROM org WHERE org_id=orgid;
IF @orgtp=74 THEN
SELECT parent_org_id INTO @buorg FROM org WHERE org_id=orgid;
SELECT po_requisition_header_id INTO @prqid FROM po_requisition_header WHERE (created_by,requisition_status)=(userid,321) ORDER BY creation_date DESC LIMIT 0,1;
IF @prqid IS NULL THEN
INSERT INTO po_requisition_header (po_requisition_type,reference_key_name,reference_key_value,description,ship_to_id,bill_to_id,currency,payment_term_id,supply_org_id,bu_org_id,requisition_status,created_by,creation_date,last_update_by,last_update_date)
 VALUES('563',NULL,NULL,'',@ship2id,@bill2id,NULL,NULL,'',@buorg,321,userid,NOW(),userid,NOW());
SELECT LAST_INSERT_ID() INTO @prqid;
END IF;
INSERT INTO po_requisition_line (po_requisition_header_id,line_type,receving_org_id,item_id_m,item_description,uom_id,unit_price,price_date,line_quantity,line_price,line_description,need_by_date,reference_key_name,reference_header_id,reference_line_id,created_by,creation_date,last_update_by,last_update_date) 
 VALUES(@prqid,'329',odrOrgId,odrItem,'',@uomid,NULL,NULL,odrQtY,NULL,'',odrNeedDT,odrPriSrcTp,odrSrcHdrId,odrSrcLineId,userid,NOW(),userid,NOW());
ELSEIF @orgtp=73 THEN
SET @spid=NULL;
SET @currency=NULL;
SET @unitprice=NULL;
SET @payment=NULL;
SET @buorg=orgid;
SET @poid=NULL;
SELECT supplier_id,quote_unit_price INTO @spid,@unitprice FROM xbs.po_quote_supplier_v WHERE item_id_m=odrItem AND bu_org_id=orgid ORDER BY quote_unit_price LIMIT 0,1;
IF @spid IS NOT NULL THEN
SELECT currency_id,payment_term_id INTO @currency,@payment FROM supplier_all_v WHERE supplier_id=@spid;
SELECT po_header_id INTO @poid FROM supplier_quote_po_v WHERE (item_id_m,supplier_id,bu_org_id,created_by)=(odrItem,@spid,orgid,userid);
IF @poid IS NULL THEN
SELECT currency_code INTO @currencyLedger FROM org_ledger_v WHERE org_id=orgid;
SET @exchange_rate=NULL;
SET @exchange_rate_cvid=NULL;
IF @currencyLedger=@currency THEN
SET @exchange_rate=1;
ELSE
SELECT rate exchange_rate,gl_currency_conversion_id INTO @exchange_rate,@exchange_rate_cvid FROM xbs.gl_currency_conversion WHERE from_currency=@currency AND to_currency=@currencyLedger;
END IF;
INSERT INTO xbs.po_header (po_type,description,supplier_id,supplier_site_id,payment_term_id,ship_to_id,bill_to_id,currency,doc_currency,exchange_rate_type,exchange_rate,agreement_start_date,agreement_end_date,rev_number,po_req_header_id,po_number,created_by,creation_date,last_update_by,last_update_date,po_status,bu_org_id) 
VALUES('319','',@spid,'',@payment,@ship2id,@bill2id,@currencyLedger,@currency,@exchange_rate_cvid, @exchange_rate,NOW(),NOW(),'','','',userid,NOW(),userid,NOW(),321,orgid);
SELECT LAST_INSERT_ID() INTO @poid;
END IF;
ELSE
INSERT INTO xbs.xbs_log (log_level,task,program,msg,user_id,org_id,dt)VALUES('error','MRP_ODRS','PoMRP-OrderLine',CONCAT('Item(',odrItem,') -- Find Supplier Failed!'),userid,orgId,NOW());
END IF;
IF @poid IS NOT NULL THEN
SET @taxcodeid=NULL;
SET @taxpercent=NULL;
SELECT valid_date,tax_code_id INTO @price_date,@taxcodeid FROM po_quote_v WHERE (rev AND quote_status=1489) AND supplier_id=@spid AND item_id_m=odrItem;
IF @taxcodeid IS NOT NULL THEN
SELECT percentage INTO @taxpercent FROM mdm_tax_code WHERE mdm_tax_code_id=@taxcodeid;
END IF;
SET @linePrice=@unitprice*odrQtY;
SET @taxAmount=IF(@taxpercent IS NULL,0,@taxpercent*@unitprice*odrQtY/100);
INSERT INTO xbs.po_line (po_header_id,line_type,receving_org_id,item_id_m,item_description,uom_id,price_date,unit_price,line_quantity,line_price,tax_code_id,tax_amount,gl_line_price,gl_tax_amount,line_description,need_by_date,reference_key_name,reference_header_id,reference_line_id,po_req_line_id,STATUS,created_by,creation_date,last_update_by,last_update_date) 
VALUES(@poid,'329',odrOrgId,odrItem,'',@uomid,@price_date,@unitprice,odrQtY,@linePrice,@taxcodeid,@taxAmount, IFNULL(@exchange_rate*@linePrice,@linePrice),IFNULL(@exchange_rate*@taxAmount,@taxAmount),'',odrNeedDT,odrPriSrcTp,odrSrcHdrId,odrSrcLineId,'',1497,userid,NOW(),userid,NOW());
END IF;
END IF;
END IF;
END IF;
END IF;
    END$$

DELIMITER ;

#@20190718
DELIMITER $$

USE `xbs`$$

DROP TRIGGER /*!50032 IF EXISTS */ `sys_pd_process_flow_action_insert`$$

CREATE
    /*!50017 DEFINER = 'i3u'@'localhost' */
    TRIGGER `sys_pd_process_flow_action_insert` AFTER INSERT ON `sys_pd_process_flow_action` 
    FOR EACH ROW BEGIN
SET @linetp=NULL;
SET @cntfa=NULL;
SET @cntpdfa=NULL;
SELECT line_type,COUNT(fa.sys_process_flow_line_id),COUNT(pdfa.sys_pd_process_flow_action_id) 
INTO @linetp,@cntfa,@cntpdfa 
FROM sys_process_flow_line fl 
JOIN sys_process_flow_action fa ON fa.sys_process_flow_line_id=fl.sys_process_flow_line_id AND fa.required_cb AND fa.pf_action_type='approval' 
LEFT JOIN sys_pd_process_flow_action pdfa ON pdfa.action_number=fa.action_number AND pdfa.sys_process_flow_line_id=fa.sys_process_flow_line_id 
WHERE fa.sys_process_flow_line_id=new.sys_process_flow_line_id GROUP BY fa.sys_process_flow_line_id;
#only one can decline(325) if pd status is 327, only decision line and all its action is approval will approved(326) 
IF @linetp!='end' THEN
IF @cntfa=@cntpdfa THEN
IF @linetp='decision' THEN
UPDATE sys_pd_header pd JOIN sys_process_flow_line pfl ON pd.process_flow_header_id=pfl.sys_process_flow_header_id AND sys_process_flow_line_id=new.sys_process_flow_line_id SET STATUS=IF(new.field_value='approval',326,325),current_process_flow_line_id=IF(new.field_value='approval',next_line_seq_pass,next_line_seq_fail) WHERE sys_pd_header_id=new.sys_pd_header_id AND STATUS=327;
ELSEIF new.pf_action_type='approval' THEN
UPDATE sys_pd_header pd JOIN sys_process_flow_line pfl ON pd.process_flow_header_id=pfl.sys_process_flow_header_id AND sys_process_flow_line_id=new.sys_process_flow_line_id SET STATUS=IF(new.field_value='approval',327,325),current_process_flow_line_id=IF(new.field_value='approval',next_line_seq_pass,next_line_seq_fail) WHERE sys_pd_header_id=new.sys_pd_header_id AND STATUS=327;
END IF;
ELSE
IF new.pf_action_type='approval' AND new.field_value!='approval' THEN
UPDATE sys_pd_header pd JOIN sys_process_flow_line pfl ON pd.process_flow_header_id=pfl.sys_process_flow_header_id AND sys_process_flow_line_id=new.sys_process_flow_line_id SET STATUS=325,current_process_flow_line_id=next_line_seq_fail WHERE sys_pd_header_id=new.sys_pd_header_id AND STATUS=327;
END IF;
END IF;
SET @pd=NULL;
SET @pdid=NULL;
SET @pdstatus=NULL;
SELECT primary_document,primary_document_id,STATUS INTO @pd,@pdid,@pdstatus FROM sys_pd_header WHERE sys_pd_header_id=new.sys_pd_header_id AND STATUS IN (325,326);
#do while pd status is 325 or 326
IF @pdstatus IS NOT NULL THEN
SET @pdstatus=IF((@pdstatus=325 AND @linetp!='decision'),321,@pdstatus);
END IF;
IF @pd='po_header' THEN
UPDATE po_header ph JOIN po_line pl ON ph.po_header_id=pl.po_header_id SET po_status=@pdstatus,STATUS=IF(@pdstatus=326,1498,1497),ph.last_update_by=new.last_update_by,ph.last_update_date=NOW() WHERE ph.po_header_id=@pdid;# and po_status=324 and STATUS=1497
ELSEIF @pd='po_quote_header' THEN
UPDATE po_quote_header SET approval_status=@pdstatus,quote_status=IF(@pdstatus=326,1489,1486),last_update_by=new.last_update_by,last_update_date=NOW() WHERE po_quote_header_id=@pdid;# and quote_status=1487 and approval_status=324;
ELSEIF @pd='po_requisition_header' THEN
UPDATE po_requisition_header ph JOIN po_requisition_line pl ON ph.po_requisition_header_id=pl.po_requisition_header_id SET requisition_status=@pdstatus,ph.last_update_by=new.last_update_by,ph.last_update_date=NOW() WHERE ph.po_requisition_header_id=@pdid;# AND requisition_status=324 AND (bu_org_id='%{orgid}' or receving_org_id='%{orgid}');
ELSEIF @pd='sd_so_header' THEN
UPDATE sd_so_header so JOIN sd_so_line sl ON so.sd_so_header_id=sl.sd_so_header_id SET approval_status=@pdstatus,so.so_status=IF(@pdstatus=326,535,537),line_status=IF(@pdstatus=326,1530,1529),so.last_update_by=new.last_update_by,so.last_update_date=NOW() WHERE so.sd_so_header_id=@pdid;# and approval_status=320;
ELSEIF @pd='sd_quote_header' THEN
UPDATE sd_quote_header SET approval_status=@pdstatus,STATUS=IF(@pdstatus=326,1489,1486),last_update_by=new.last_update_by,last_update_date=NOW() WHERE sd_quote_header_id=@pdid;# and approval_status=320;
ELSEIF @pd='hr_leave_transaction' THEN  #status set to null and doc will be editable in some type docs
UPDATE hr_leave_transaction SET leave_status=IF(@pdstatus=321,NULL,IF(@pdstatus=326,1494,1495)),approved_by_employee_id=IF(@pdstatus=321,NULL,IF(@pdstatus=326,new.last_update_by,NULL)),approved_date=IF(@pdstatus=321,NULL,IF(@pdstatus=326,NOW(),NULL)) WHERE hr_leave_transaction_id=@pdid;# and approval_status=1494;
ELSEIF @pd='hr_overtime_transaction' THEN  #status set to null and doc will be editable in some type docs
UPDATE hr_overtime_transaction SET overtime_status=IF(@pdstatus=321,NULL,IF(@pdstatus=326,1494,1495)),approved_by_employee_id=IF(@pdstatus=321,NULL,IF(@pdstatus=326,new.last_update_by,NULL)),approved_date=IF(@pdstatus=321,NULL,IF(@pdstatus=326,NOW(),NULL)) WHERE hr_overtime_transaction_id=@pdid;# and approval_status=1494;
ELSEIF @pd='hr_employee_termination' THEN
UPDATE hr_employee_termination SET STATUS=IF(@pdstatus=321,NULL,IF(@pdstatus=326,1494,1495)),accpeted_by_employee_id=IF(@pdstatus=321,NULL,IF(@pdstatus=326,new.last_update_by,NULL)),accpeted_date=IF(@pdstatus=321,NULL,IF(@pdstatus=326,NOW(),NULL)) WHERE hr_employee_termination_id=@pdid;# and approval_status=1494;
ELSEIF @pd='hr_expense_header' THEN
UPDATE hr_expense_header SET STATUS=IF(@pdstatus=321,NULL,IF(@pdstatus=326,1494,1495)),approved_by_employee_id=IF(@pdstatus=321,NULL,IF(@pdstatus=326,new.last_update_by,NULL)),approved_date=IF(@pdstatus=321,NULL,IF(@pdstatus=326,NOW(),NULL)) WHERE hr_expense_header_id=@pdid;# and approval_status=1494;
ELSEIF @pd='inv_count_header' THEN
UPDATE inv_count_header SET STATUS=IF(@pdstatus=321,NULL,IF(@pdstatus=326,1633,1630)),last_update_by=IF(@pdstatus=321,NULL,IF(@pdstatus=326,new.last_update_by,NULL)),last_update_date=IF(@pdstatus=321,NULL,IF(@pdstatus=326,NOW(),NULL)) WHERE inv_count_header_id=@pdid;# and approval_status=1494;
END IF;
END IF;
    END;
$$

DELIMITER ;

DELIMITER $$

USE `xbs`$$

DROP VIEW IF EXISTS `cc_co_line_value_v`$$

CREATE
    /*[ALGORITHM = {UNDEFINED | MERGE | TEMPTABLE}]
    [DEFINER = { user | CURRENT_USER }]
    [SQL SECURITY { DEFINER | INVOKER }]*/
    VIEW `xbs`.`cc_co_line_value_v` 
    AS
SELECT bi.item_number,ctl.label,bli.item_number ref,
(CASE WHEN ctl.control_type=_utf8'Select' THEN 
(CASE WHEN (ctl.field_name='component_item_id_m') THEN bli.item_number 
WHEN ctl.field_name='bom_routing_line' THEN cblrlso.standard_operation 
WHEN ctl.field_name='supply_sub_inventory' THEN csbi.subinventory 
WHEN ctl.field_name='wip_supply_type' THEN cwst.option_line_value 
WHEN ctl.field_name='usage_basis' THEN opt.option_line_value END) 
ELSE c.field_value  END) cur_value,
(CASE WHEN ctl.control_type=_utf8'Select' THEN 
(CASE WHEN (ctl.field_name='component_item_id_m') THEN item.item_number 
WHEN ctl.field_name='bom_routing_line' THEN blrlso.standard_operation 
WHEN ctl.field_name='supply_sub_inventory' THEN sbi.subinventory 
WHEN ctl.field_name IN ('wip_supply_type','','usage_basis') THEN opt.option_line_value END) 
ELSE c.field_value  END) new_value,
c.ref_id,c.field_value,u.NAME created_by,c.creation_date,u0.NAME last_update_by,c.last_update_date,c.cc_co_template_line_id,c.cc_co_line_value_id,c.cc_co_line_id  
FROM xbs.cc_co_line_value c 
JOIN xbs.cc_co_template_line ctl ON c.cc_co_template_line_id=ctl.cc_co_template_line_id 
JOIN xbs.cc_co_template_header cth ON ctl.cc_co_template_header_id=cth.cc_co_template_header_id AND cth.reftbltp='bom_line'
JOIN xbs.bom_line bl ON bl.bom_line_id=c.ref_id 
JOIN xbs.bom_header bh ON bl.bom_header_id=bh.bom_header_id 
JOIN xbs.item bi ON bh.item_id_m=bi.item_id_m AND bh.org_id=bi.org_id 
LEFT JOIN xbs.item bli ON bli.item_id_m=bl.component_item_id_m AND bli.org_id=bh.org_id  
LEFT JOIN xbs.item ON item.item_id_m=c.field_value AND item.org_id=bh.org_id AND (ctl.field_name='item_number' OR ctl.field_name='component_item_id_m') 
LEFT JOIN xbs.bom_routing_line blrl ON blrl.bom_routing_line_id=c.field_value AND ctl.field_name='bom_routing_line' 
LEFT JOIN xbs.bom_standard_operation blrlso ON blrl.standard_operation_id=blrlso.bom_standard_operation_id 
LEFT JOIN xbs.option_line opt ON opt.option_line_id=c.field_value AND ctl.field_name IN ('wip_supply_type','usage_basis') 
LEFT JOIN xbs.subinventory sbi ON sbi.subinventory_id=c.field_value AND ctl.field_name='supply_sub_inventory'
LEFT JOIN (xbs.bom_routing_line cblrl JOIN xbs.bom_routing_header cblrh ON cblrl.bom_routing_header_id=cblrh.bom_routing_header_id) ON (cblrl.routing_sequence=bl.routing_sequence AND cblrl.routing_seq_num=bl.routing_seq_num AND cblrh.item_id_m=bh.item_id_m AND cblrh.org_id=bh.org_id)
LEFT JOIN xbs.bom_standard_operation cblrlso ON cblrl.standard_operation_id=cblrlso.bom_standard_operation_id 
LEFT JOIN xbs.option_line cwst ON bl.wip_supply_type=cwst.option_line_id
LEFT JOIN xbs.option_line cusage ON bl.usage_basis=cusage.option_line_id
LEFT JOIN xbs.subinventory csbi ON bl.supply_sub_inventory=csbi.subinventory
LEFT JOIN xbs.user_v u ON c.created_by=u.xerp_user_id 
LEFT JOIN xbs.user_v u0 ON c.last_update_by=u0.xerp_user_id 
UNION 
SELECT bi.item_number,ctl.label,brlso.standard_operation ref,
(CASE WHEN ctl.control_type=_utf8'Select' THEN 
(CASE WHEN ctl.field_name='standard_operation_id' THEN brlso.standard_operation END) 
ELSE c.field_value  END) cur_value,
(CASE WHEN ctl.control_type=_utf8'Select' THEN 
(CASE WHEN ctl.field_name='standard_operation_id' THEN bso.standard_operation END) 
ELSE c.field_value  END) new_value,
c.ref_id,c.field_value,u.NAME created_by,c.creation_date,u0.NAME last_update_by,c.last_update_date,c.cc_co_template_line_id,c.cc_co_line_value_id,c.cc_co_line_id  
FROM xbs.cc_co_line_value c 
JOIN xbs.cc_co_template_line ctl ON c.cc_co_template_line_id=ctl.cc_co_template_line_id 
JOIN xbs.cc_co_template_header cth ON ctl.cc_co_template_header_id=cth.cc_co_template_header_id AND cth.reftbltp='bom_routing_line'
JOIN xbs.bom_routing_line brl ON brl.bom_routing_line_id=c.ref_id 
JOIN xbs.bom_routing_header brh ON brl.bom_routing_header_id=brh.bom_routing_header_id 
JOIN xbs.item bi ON brh.item_id_m=bi.item_id_m AND brh.org_id=bi.org_id 
LEFT JOIN xbs.bom_standard_operation brlso ON brlso.bom_standard_operation_id=brl.standard_operation_id AND brlso.org_id=brh.bom_routing_header_id 
LEFT JOIN xbs.bom_standard_operation bso ON bso.bom_standard_operation_id=c.field_value AND ctl.field_name='standard_operation_id' 
LEFT JOIN xbs.user_v u ON c.created_by=u.xerp_user_id 
LEFT JOIN xbs.user_v u0 ON c.last_update_by=u0.xerp_user_id$$

DELIMITER ;


LOCK TABLES `cc_co_template_header` WRITE;

insert ignore into `cc_co_template_header`(`cc_co_template_header_id`,`template_name`,`reftbltp`,`org_id`,`description`,`status`,`created_by`,`creation_date`,`last_update_by`,`last_update_date`) values (1,'ECO_Item','Item',4,'44','1565',0,'2019-01-09 09:28:38',1,'2019-01-10 16:43:38'),(2,'ECO_BOM','BOM_line',4,'','1565',1,'2019-01-10 16:39:58',1,'2019-01-10 16:44:20'),(3,'ECO_BOM_Routing','BOM_routing_line',4,'','1565',1,'2019-01-10 16:44:08',1,'2019-01-10 16:44:08');

UNLOCK TABLES;

/*Data for the table `cc_co_template_line` */

LOCK TABLES `cc_co_template_line` WRITE;

insert ignore into `cc_co_template_line`(`cc_co_template_line_id`,`cc_co_template_header_id`,`field_name`,`required_cb`,`label`,`value_type`,`control_type`,`control_value`,`control_uom`,`active_cb`,`display_weight`,`list_values`,`lower_limit`,`upper_limit`,`list_value_option_type`,`created_by`,`creation_date`,`last_update_by`,`last_update_date`) values (1,1,'bom_type',0,'bom_type','int','','',0,1,NULL,'','','','',1,'2019-01-09 10:31:42',1,'2019-01-11 10:29:46'),(2,1,'item_number',0,'item_number','varchar','Select','',0,1,NULL,'SELECT item_number,item_id_m id FROM item JOIN cc_co_template_header coth ON item.org_id=coth.org_id WHERE cc_co_template_header_id=${cc_co_template_line_id[cc_co_template_header_id]} and item_status=277;','','','',1,'2019-01-09 10:35:37',1,'2019-01-18 20:33:22'),(3,1,'item_type',0,'item_type','int','','',0,1,NULL,'','','','',1,'2019-01-09 10:37:51',1,'2019-01-11 10:29:40'),(4,2,'component_item_id_m',0,'component','int','Select','',0,1,NULL,'SELECT item_number,item_id_m id FROM item JOIN cc_co_template_header coth ON item.org_id=coth.org_id WHERE cc_co_template_header_id=${cc_co_template_line_id[cc_co_template_header_id]} and item_status=277','','','',1,'2019-01-10 16:44:43',1,'2019-01-18 20:26:14'),(5,2,'usage_quantity',0,'quantity','decimal','','',0,1,NULL,'','','','',1,'2019-01-10 16:45:17',1,'2019-01-11 09:40:34'),(6,3,'standard_operation_id',0,'operation','int','Select','',0,1,NULL,'SELECT standard_operation,bom_standard_operation_id id FROM bom_standard_operation bso JOIN cc_co_template_header coth ON bso.org_id=coth.org_id WHERE cc_co_template_header_id=${cc_co_template_line_id[cc_co_template_header_id]}','','','',1,'2019-01-10 16:46:12',1,'2019-01-18 20:32:23'),(7,3,'routing_sequence',0,'routing_sequence','int','Text','',0,1,NULL,'','','','',1,'2019-01-27 14:24:08',1,'2019-01-27 14:24:08'),(8,3,'routing_seq_num',0,'routing_seq_num','int','Text','',0,1,NULL,'','','','',1,'2019-01-27 14:24:24',1,'2019-01-27 14:24:24'),(9,2,'bom_sequence',0,'bom_sequence','int','Text','',0,1,NULL,'','','','',1,'2019-01-27 14:53:50',1,'2019-01-27 14:53:50'),(10,2,'wip_supply_type',0,'wip_supply_type','int','Select','',0,1,NULL,'SELECT option_line_value,option_line_id id FROM xbs.option_line WHERE option_header_id=135 AND STATUS IS true','','','',1,'2019-01-27 14:57:11',1,'2019-01-27 17:00:50'),(11,2,'supply_sub_inventory',0,'supply_sub_inventory','int','Select','',0,1,NULL,'SELECT subinventory,subinventory_id id FROM xbs.subinventory WHERE org_id=${orgid}','','','',1,'2019-01-27 14:59:45',1,'2019-01-27 17:01:01'),(12,2,'bom_routing_line',0,'operation','int','Select','',0,1,NULL,'SELECT standard_operation,bom_routing_line_id id FROM bom_routing_line brl JOIN bom_routing_header brh ON brl.bom_routing_header_id=brh.bom_routing_header_id JOIN cc_co_line col ON brh.item_id_m=col.item_id_m JOIN cc_co_header coh ON col.cc_co_header_id=coh.cc_co_header_id AND brh.org_id=coh.org_id JOIN bom_standard_operation bso ON brl.standard_operation_id=bso.bom_standard_operation_id WHERE cc_co_line_id=${cc_co_line_id}','','','',1,'2019-01-27 15:07:49',1,'2019-01-27 17:01:13'),(13,2,'usage_basis',0,'useage_basis','int','Select','',0,1,NULL,'SELECT option_line_value,option_line_id id from xbs.option_line where option_header_id=138','','','',1,'2019-01-27 15:18:18',1,'2019-01-27 17:01:24');

UNLOCK TABLES;

DELIMITER $$

USE `xbs`$$

DROP PROCEDURE IF EXISTS `mrp_demand_order`$$

CREATE DEFINER=`i3u`@`localhost` PROCEDURE `mrp_demand_order`(fmdId INT,item BIGINT,ddt DATE,qty DECIMAL(15,5),qtyOnhandConsume DECIMAL(15,5),itemPri BIGINT,srctpPri VARCHAR(50),srcHid BIGINT,srcLid BIGINT,userid INT,orgid INT,cpitem BIGINT,cpusage INT,cpqty DECIMAL(15,5),makebuy VARCHAR(5),cpprocessTotal_lt INT,cpprocessing_lt INT)
BEGIN
	SET @quantity=qty*cpqty;
	SET @qty2CSD=(qty-qtyOnhandConsume)*cpqty;
	SET @ddt=ddt;
	SET @srctp='Dependent';
SET @onhandx=0;
SET @onhandconsume=0;
SELECT IFNULL(calOnhandDT(cpitem,ddt,orgid),0) INTO @onhandx;
SELECT IFNULL(SUM(onhandconsume),0) INTO @onhandconsume FROM fp_mrp_planned_order WHERE (item_id_m,org_id,fp_mrp_header_id)=(cpitem,orgid,fmdId) AND need_by_date<ddt;
SET @onhandconsumed = @onhandx-@onhandconsume;
IF @onhandconsumed > @qty2CSD  THEN
	SET @onhandconsumed = @qty2CSD;
END IF;
SET @onhandconsumed=@onhandconsumed+(qtyOnhandConsume*cpqty);
IF(makebuy='buy') THEN
SET @haspo=NULL;
SELECT po_requisition_line_id INTO @haspo FROM po_requisition_line WHERE item_id_m=cpitem AND receving_org_id=orgid AND reference_key_name=srctpPri AND reference_header_id=srcHid AND (reference_line_id=0 OR reference_line_id=srcLid) LIMIT 1;
IF(@haspo IS NULL) THEN
SELECT po_line_id INTO @haspo FROM po_line WHERE item_id_m=cpitem AND receving_org_id=orgid AND reference_key_name=srctpPri AND reference_header_id=srcHid AND (reference_line_id=0 OR reference_line_id=srcLid) LIMIT 1;
END IF;
IF(@haspo IS NULL) THEN
        SET @pdt=ddt;
	IF(cpprocessTotal_lt IS NOT NULL) THEN
	SET @pdt=DATE_SUB(ddt,INTERVAL cpprocessTotal_lt DAY);
	END IF;
INSERT INTO fp_mrp_demand (org_id,fp_mrp_header_id,item_id_m,demand_date,quantity,demand_item_id_m,toplevel_demand_item_id_m,source_type,primary_source_type,source_header_id,source_line_id,created_by,creation_date,last_update_by,last_update_date)
VALUES (orgid,fmdId,cpitem,@ddt,@quantity,item,itemPri,@srctp,srctpPri,srcHid,srcLid,userid,NOW(),userid,NOW());
SELECT item_number INTO @cpitemn FROM item WHERE item_id_m=cpitem AND org_id=orgid;
	IF(@ddt<CURDATE() AND (@quantity>@onhandconsumed)) THEN
	SET @exmsg=CONCAT('Item ',@cpitemn,'(id:',cpitem,') is past due');
	INSERT INTO fp_mrp_exception(org_id,fp_mrp_header_id,exception_message,detailed_message,exception_type,created_by,creation_date,last_update_by,last_update_date) 
	VALUE(orgid,fmdId,@exmsg,CONCAT(@exmsg,' ,Demand date was ',@ddt),'PAST_DUE',userid,NOW(),userid,NOW());
	END IF;
INSERT INTO fp_mrp_planned_order (fp_mrp_header_id,order_type,item_id_m,order_date,need_by_date,quantity,demand_item_id_m,toplevel_demand_item_id_m,source_type,primary_source_type,source_header_id,source_line_id,supplier_id,supplier_site_id,created_by,creation_date,last_update_by,last_update_date,org_id,onhandconsume)
VALUES (fmdId,'prq',cpitem,@pdt,@ddt,@quantity,item,itemPri,@srctp,srctpPri,srcHid,srcLid,0,0,userid,NOW(),userid,NOW(),orgid,@onhandconsumed);
	IF(@pdt<CURDATE() AND (@quantity>@onhandconsumed)) THEN
	SET @exmsg=CONCAT('Planned Order (Id : ',(SELECT LAST_INSERT_ID()),') is compressed');
	INSERT INTO fp_mrp_exception(org_id,fp_mrp_header_id,exception_message,detailed_message,exception_type,created_by,creation_date,last_update_by,last_update_date) 
	VALUE(orgid,fmdId,@exmsg,CONCAT(@exmsg,'Item ',@cpitemn,'(id:',cpitem,') should before ',@pdt),'COMPRESSED_LT',userid,NOW(),userid,NOW());
	END IF;
ELSE
INSERT INTO fp_warning (warning) VALUE(CONCAT('haspo',@haspo));
END IF;
ELSE IF(makebuy='make') THEN
	IF(cpprocessing_lt IS NOT NULL) THEN
	SET @pdt=DATE_SUB(ddt,INTERVAL cpprocessing_lt DAY);
	END IF;
SET @haswo=NULL;
SELECT wip_allocation_id INTO @haswo FROM wip_wo_allocation WHERE item_id_m=cpitem AND org_id=orgid AND demand_source_type=srctpPri AND demand_source_header_id=srcHid AND (demand_source_line_id=0 OR demand_source_line_id=srcLid) LIMIT 1;
IF(@haswo IS NULL) THEN
SET @odrdt=NULL;
SELECT order_date INTO @odrdt FROM fp_mrp_planned_order WHERE fp_mrp_header_id=fmdId AND item_id_m=cpitem AND org_id=orgid AND primary_source_type=srctpPri AND source_header_id=srcHid AND (source_line_id IS NULL OR source_line_id=srcLid) LIMIT 1;
IF @odrdt IS NOT NULL THEN
SET @pdt=@odrdt;
ELSE
INSERT INTO fp_mrp_planned_order (fp_mrp_header_id,order_type,item_id_m,order_date,need_by_date,quantity,demand_item_id_m,toplevel_demand_item_id_m,source_type,primary_source_type,source_header_id,source_line_id,supplier_id,supplier_site_id,created_by,creation_date,last_update_by,last_update_date,org_id,onhandconsume)
VALUES (fmdId,'wo',cpitem,@pdt,@ddt,@quantity,item,itemPri,@srctp,srctpPri,srcHid,srcLid,0,0,userid,NOW(),userid,NOW(),orgid,@onhandconsumed);
SELECT item_number INTO @cpitemn FROM item WHERE item_id_m=cpitem AND org_id=orgid;
	IF(@pdt<CURDATE() AND (@quantity>@onhandconsumed)) THEN
	SET @exmsg=CONCAT('Planned Order (Id : ',(SELECT LAST_INSERT_ID()),') is compressed');
	INSERT INTO fp_mrp_exception(org_id,fp_mrp_header_id,exception_message,detailed_message,exception_type,created_by,creation_date,last_update_by,last_update_date) 
	VALUE(orgid,fmdId,@exmsg,CONCAT(@exmsg,'Item ',@cpitemn,'(id:',cpitem,') should before ',@pdt),'COMPRESSED_LT',userid,NOW(),userid,NOW());
	END IF;
END IF;
END IF;
CALL mrp_demand_cal4components(fmdId,cpitem,@pdt,@quantity,@onhandconsumed,itemPri,srctpPri,srcHid,srcLid,userid,orgid);
	END IF;
        END IF;
    END$$

DELIMITER ;

DELIMITER $$

USE `xbs`$$

DROP PROCEDURE IF EXISTS `convertOdrs4MRP`$$

CREATE DEFINER=`i3u`@`localhost` PROCEDURE `convertOdrs4MRP`(mrpid BIGINT,grossdemand BOOLEAN,odrtp VARCHAR(5),srcOrder BOOLEAN,userid BIGINT,orgid INT)
BEGIN
DECLARE odrId BIGINT;
DECLARE odrItem INT;
DECLARE odrNeedDT DATE;
DECLARE odrQtY DECIMAL(20,5);
DECLARE odrPriSrcTp INT;
DECLARE odrSrcHdrId INT;
DECLARE odrSrcLineId BIGINT;
DECLARE odrOrgId INT;
#DECLARE reqQty DECIMAL(20,5);
DECLARE done INT;
DECLARE mrpOdrs CURSOR FOR SELECT fp_mrp_planned_order_id,order_type,item_id_m,MIN(need_by_date),IF(grossdemand,CEIL(quantity-onhandconsume),quantity),primary_source_type,source_header_id,source_line_id,org_id
FROM fp_mrp_planned_order mpo JOIN (SELECT WEEK(dt) seq_num,SUBDATE(dt,wd) week_start_date,ADDDATE(dt,6-wd) week_end_date FROM (
SELECT DATE_FORMAT(CURDATE(),'%w') wd,ADDDATE(CURDATE(),7*(fake_id-1)) dt FROM a_fake_ids WHERE fake_id<5
) t ) cwsd ON (mpo.need_by_date BETWEEN week_start_date AND week_end_date) WHERE fp_mrp_header_id=mrpid AND IF(odrtp!='',order_type=odrtp,1) GROUP BY item_id_m,seq_num,IF(srcOrder,1,primary_source_type),IF(srcOrder,1,source_line_id);
DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = 1;
DELETE FROM xbs.xbs_log WHERE task='MRP_ODRS' AND user_id=userid;
INSERT INTO xbs.xbs_log (log_level,task,program,msg,user_id,org_id,dt)VALUES('info','MRP_ODRS','','Begin...',userid,orgId,NOW());
INSERT IGNORE INTO xbs.fp_mrp_planned_sources SELECT NULL,primary_source_type,source_header_id,source_line_id,need_by_date,0,'',orgid,userid,NOW(),userid,NOW() FROM fp_mrp_planned_order WHERE fp_mrp_header_id=mrpid;
    OPEN mrpOdrs;
    BEGIN_mrpOdrs: LOOP
        FETCH mrpOdrs INTO odrId,odrtp,odrItem,odrNeedDT,odrQtY,odrPriSrcTp,odrSrcHdrId,odrSrcLineId,odrOrgId;
        IF done THEN
            LEAVE BEGIN_mrpOdrs;
        END IF;
#        IF(reqQty>0) THEN
        CALL ConvertPlannedOrder(odrtp,odrItem,odrNeedDT,odrQtY,odrPriSrcTp,odrSrcHdrId,odrSrcLineId,odrOrgId,userid,orgId);
#        END IF;
    END LOOP BEGIN_mrpOdrs;
    CLOSE mrpOdrs;
INSERT INTO xbs.xbs_log (log_level,task,program,msg,user_id,org_id,dt)VALUES('info','MRP_ODRS','','Finished!',userid,orgId,NOW());
    END$$

DELIMITER ;

#@20190921
insert ignore into xbs.`xerp_role` (`role_id`, `role_name_cn`, `role_name_eng`, `role_layout`, `org_id`, `created_by`, `creation_date`, `last_update_by`, `last_update_date`) values('19','数据仓库','xdw','layout/ucin/xbs/index_xdw.xml','0','14','2019-09-03 08:59:09','14','2019-09-03 08:59:09');
insert ignore into xbs.`xerp_role` (`role_id`, `role_name_cn`, `role_name_eng`, `role_layout`, `org_id`, `created_by`, `creation_date`, `last_update_by`, `last_update_date`) values('20','售后服务','helpdesk','layout/ucin/xbs/xbs_hd.xml','0','14','2019-09-03 08:59:09','14','2019-09-03 08:59:09');
insert ignore into xbs.`xerp_user` (`xerp_user_id`, `person_id`, `username`, `password`, `first_name`, `last_name`, `assigned_ip`, `phone`, `email`, `user_language`, `date_format`, `hr_employee_id`, `block_notif_count`, `supplier_id`, `default_theme`, `use_personal_db_cb`, `ar_customer_id`, `lms_student_id`, `use_personal_color_cb`, `mandatory_field_color`, `heading_color`, `content_color`, `bg_image_file_id`, `bg_opacity`, `show_bg_image_cb`, `debug_mode`, `prices_dec`, `qty_dec`, `rates_dec`, `percent_dec`, `show_gl`, `show_codes`, `show_hints`, `last_visit_date`, `query_size`, `image_file_id`, `pos`, `print_profile`, `rep_popup`, `auth_provider_name`, `auth_provider_id`, `status`, `created_by`, `creation_date`, `last_update_by`, `last_update_date`, `revision_enabled`, `revision_number`) values('20',NULL,'xdw','e10adc3949ba59abbe56e057f20f883e',NULL,NULL,NULL,NULL,'tex',NULL,'0','0',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'2','2','4','1','1','0','0',NULL,'10',NULL,'1','1','1',NULL,NULL,'1','14','2019-09-03 08:57:00','14','2019-09-03 08:57:00','N',NULL);
insert ignore into xbs.`xerp_user` (`xerp_user_id`, `person_id`, `username`, `password`, `first_name`, `last_name`, `assigned_ip`, `phone`, `email`, `user_language`, `date_format`, `hr_employee_id`, `block_notif_count`, `supplier_id`, `default_theme`, `use_personal_db_cb`, `ar_customer_id`, `lms_student_id`, `use_personal_color_cb`, `mandatory_field_color`, `heading_color`, `content_color`, `bg_image_file_id`, `bg_opacity`, `show_bg_image_cb`, `debug_mode`, `prices_dec`, `qty_dec`, `rates_dec`, `percent_dec`, `show_gl`, `show_codes`, `show_hints`, `last_visit_date`, `query_size`, `image_file_id`, `pos`, `print_profile`, `rep_popup`, `auth_provider_name`, `auth_provider_id`, `status`, `created_by`, `creation_date`, `last_update_by`, `last_update_date`, `revision_enabled`, `revision_number`) values('21',NULL,'helpdesk','e10adc3949ba59abbe56e057f20f883e',NULL,NULL,NULL,NULL,'hd@3ucs.com',NULL,'0','0',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'2','2','4','1','1','0','0',NULL,'10',NULL,'1','1','1',NULL,NULL,'1','14','2019-09-03 08:57:00','14','2019-09-03 08:57:00','N',NULL);
insert ignore into xbs.`user_role` (`user_role_id`, `role_code`, `user_id`, `created_by`, `creation_date`, `last_update_by`, `last_update_date`) values('20','19','20','0','2019-09-03 09:00:24','0','2019-09-03 09:00:24');
insert ignore into xbs.`user_role` (`user_role_id`, `role_code`, `user_id`, `created_by`, `creation_date`, `last_update_by`, `last_update_date`) values('21','20','21','0','2019-09-03 09:00:24','0','2019-09-03 09:00:24');

CREATE TABLE if not exists `docsharel` (
  `idx` int(11) NOT NULL auto_increment,
  `doc_id` int(11) default NULL,
  `shared2` int(11) default NULL,
  `type` tinyint(1) default '0' COMMENT '1 for group;0 for user',
  `dt2share` datetime default NULL,
  `sharedby` int(11) default NULL,
  `id_corp` int(11) default '1',
  PRIMARY KEY  (`idx`),
  UNIQUE KEY `doc_id` (`doc_id`,`shared2`,`type`),
  KEY `id_corp` (`id_corp`),
  KEY `shared2` (`shared2`),
  KEY `sharedby` (`sharedby`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;

CREATE TABLE if not exists `documents` (
  `idx` int(11) NOT NULL auto_increment,
  `owner_id` int(11) NOT NULL,
  `path` varchar(50) default NULL,
  `filenameany` varchar(50) NOT NULL,
  `keywords` varchar(50) NOT NULL,
  `up_dt` datetime default NULL,
  `expire_dt` datetime default NULL,
  `id_corp` int(11) default '1',
  PRIMARY KEY  (`idx`),
  UNIQUE KEY `filenameany` (`path`,`filenameany`),
  KEY `owner_id` (`owner_id`),
  KEY `id_corp` (`id_corp`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;

#@20191115
DELIMITER $$

USE `xbs`$$

DROP TRIGGER /*!50032 IF EXISTS */ `inv_transactionInsert`$$

CREATE
    /*!50017 DEFINER = 'i3u'@'localhost' */
    TRIGGER `inv_transactionInsert` AFTER INSERT ON `inv_transaction` 
    FOR EACH ROW BEGIN
IF new.reference_key_name='po_line' THEN
BEGIN
SET @orp=0;
SET @qtyr=NULL;
SET @qtya=NULL;
SET @qtyp=NULL;
SELECT IFNULL(over_receipt_percentage,0) INTO @orp FROM item WHERE (item_id_m,org_id)=(new.item_id_m,new.to_org_id);
SELECT received_quantity,accepted_quantity,line_quantity INTO @qtyr,@qtya,@qtyp FROM po_line WHERE po_line_id=new.reference_key_value;
IF new.transaction_type_id=21 THEN
UPDATE po_line SET accepted_quantity=accepted_quantity-new.quantity,last_update_date=NOW() WHERE po_line_id=new.reference_key_value;
ELSEIF new.transaction_type_id=5 THEN
IF (@qtyr+new.quantity-@qtyp)/@qtyp>@orp THEN
INSERT INTO xbs.xbs_log (log_level,task,program,msg,user_id,org_id,dt)VALUES('info','po_inv','Accept',CONCAT('Item ',new.item_id_m,PO_INV_OVER_ACCEPT,'>',@orp),new.created_by,new.org_id,NOW());
END IF;
UPDATE po_line SET received_quantity=received_quantity+new.quantity,accepted_quantity=accepted_quantity+new.quantity,last_update_date=NOW() WHERE po_line_id=new.reference_key_value;
ELSEIF new.transaction_type_id=4 THEN
IF (@qtyr+new.quantity)/@qtyp>@orp THEN
INSERT INTO xbs.xbs_log (log_level,task,program,msg,user_id,org_id,dt)VALUES('info','po_inv','Receipt',CONCAT('Item ',new.item_id_m,PO_INV_OVER_RECEIPT,'>',@orp),new.created_by,new.org_id,NOW());
END IF;
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
ELSEIF new.transaction_type_id IN ('7','8') THEN
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
IF @cst_amount IS NULL THEN #use item price if no cost val
SELECT list_price INTO @cst_amount FROM item WHERE (item_id_m,org_id)=(new.item_id_m,new.org_id);
SELECT @cst_amount INTO @mat;
INSERT INTO xbs.xbs_log (log_level,task,program,msg,user_id,org_id,dt)VALUES('info','inv_trans','inv_trans',CONCAT('Item ',new.item_id_m,' COST Not Found, Use its listprice in item'),new.created_by,new.org_id,NOW());
END IF;
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
IF @res IS NOT NULL THEN
SELECT getCOAId(new.org_id,1604,'subinventory',new.from_subinventory_id) INTO @res_ac;
SELECT getCOAId(new.org_id,1575,'',0) INTO @res_ac_2;
END IF;
IF @osp IS NOT NULL THEN
SELECT getCOAId(new.org_id,1605,'subinventory',new.from_subinventory_id) INTO @osp_ac;
SELECT getCOAId(new.org_id,1576,'',0) INTO @osp_ac_2;
END IF;
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
IF @res IS NOT NULL THEN
SELECT getCOAId(new.org_id,1575,'',0) INTO @res_ac;
SELECT getCOAId(new.org_id,1604,'subinventory',new.to_subinventory_id) INTO @res_ac_2;
END IF;
IF @osp IS NOT NULL THEN
SELECT getCOAId(new.org_id,1576,'',0) INTO @osp_ac;
SELECT getCOAId(new.org_id,1605,'subinventory',new.to_subinventory_id) INTO @osp_ac_2;
END IF;
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

DELIMITER $$

USE `xbs`$$

DROP TRIGGER /*!50032 IF EXISTS */ `inv_receipt_lineUpdate`$$

CREATE
    /*!50017 DEFINER = 'i3u'@'localhost' */
    TRIGGER `inv_receipt_lineUpdate` BEFORE UPDATE ON `inv_receipt_line` 
    FOR EACH ROW BEGIN
IF (new.status=old.status) AND new.status IN (1519,1520) AND (new.transaction_quantity!=old.transaction_quantity) AND (old.reference_key_name='po_line') THEN
SELECT IFNULL(over_receipt_percentage,0) INTO @orp FROM item WHERE item_id_m=new.item_id_m AND org_id=new.org_id;
SELECT pl.line_quantity,SUM(amount) INTO @qty,@qty_recv FROM inv_receipt_line irl JOIN po_line pl ON irl.reference_key_name='po_line' AND irl.reference_key_value=pl.po_line_id 
WHERE reference_key_value=new.reference_key_value AND irl.status!=1522 GROUP BY pl.po_line_id;
IF (new.transaction_quantity+@qty_recv-@qty)/@qty>@orp THEN
INSERT INTO xbs.xbs_log (log_level,task,program,msg,user_id,org_id,dt)VALUES('info','po_recv','RECEIPT',CONCAT('Item ',new.item_id_m,PO_RECEIPT_OVER,'>',@qty),new.created_by,new.org_id,NOW());
END IF;
END IF;
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
IF @ospitemcost IS NULL THEN #use item price if no cost val
SELECT list_price INTO @ospitemcost FROM item WHERE (item_id_m,org_id)=(old.item_id_m,new.org_id);
INSERT INTO xbs.xbs_log (log_level,task,program,msg,user_id,org_id,dt)VALUES('info','po_recv','RECEIPT',CONCAT('Item ',new.item_id_m,' COST Not Found, Use its listprice in item'),new.created_by,new.org_id,NOW());
END IF;
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

ALTER TABLE `xbs`.`xerp_role`  ENGINE=INNODB CHECKSUM=1 AUTO_INCREMENT=101 COMMENT='' DELAY_KEY_WRITE=1 ROW_FORMAT=DYNAMIC CHARSET=utf8 COLLATE=utf8_general_ci ;
ALTER TABLE `xbs`.`user_role`  ENGINE=INNODB CHECKSUM=1 AUTO_INCREMENT=101 COMMENT='' DELAY_KEY_WRITE=1 ROW_FORMAT=DYNAMIC CHARSET=utf8 COLLATE=utf8_general_ci ;
ALTER TABLE `xbs`.`xerp_user`  ENGINE=INNODB CHECKSUM=1 AUTO_INCREMENT=101 COMMENT='' DELAY_KEY_WRITE=1 ROW_FORMAT=DYNAMIC CHARSET=utf8 COLLATE=utf8_general_ci ;

#@20200209
DELIMITER $$

USE `xbs`$$

DROP VIEW IF EXISTS `bom_department_user_v`$$

CREATE ALGORITHM=UNDEFINED DEFINER=`i3u`@`localhost` SQL SECURITY DEFINER VIEW `bom_department_user_v` AS (
SELECT
  `org`.`org`                     AS `org`,
  `d`.`department`                AS `department`,
  `b`.`standard_operation` AS `standard_operation`,
  `x`.`username` AS `username`,
  (`d`.`status` AND `b`.`status` AND `u`.`active`) AS `active`,
  `d`.`description`               AS `description`,
  `d`.`org_id`                    AS `org_id`,
  `x`.`xerp_user_id`              AS `xerp_user_id`,
  `d`.`status`                    AS `bd_status`,
  `b`.`status`                    AS `bo_status`,
  `u`.`active`                    AS `bu_active`,
  `d`.`bom_department_id`         AS `bom_department_id`,
  `b`.`bom_standard_operation_id` AS `bom_standard_operation_id`,
  `u`.`user_bom_department_id`    AS `user_bom_department_id`
FROM ((((`bom_department` `d`
      LEFT JOIN `user_bom_department` `u`
        ON ((`u`.`bom_department_id` = `d`.`bom_department_id`)))
     LEFT JOIN `xerp_user` `X`
       ON ((`u`.`xerp_user_id` = `x`.`xerp_user_id`)))
    LEFT JOIN `org`
      ON ((`org`.`org_id` = `d`.`org_id`)))
   LEFT JOIN `bom_standard_operation` `b`
     ON ((`b`.`department_id` = `d`.`bom_department_id`))))$$

DELIMITER ;

#@20200209
DELIMITER $$

USE `xbs`$$

DROP TRIGGER /*!50032 IF EXISTS */ `ar_transaction_lineUpdate`$$

CREATE
    /*!50017 DEFINER = 'i3u'@'localhost' */
    TRIGGER `ar_transaction_lineUpdate` AFTER UPDATE ON `ar_transaction_line` 
    FOR EACH ROW BEGIN
IF(new.status=1527 AND old.status=1526) THEN
    SET @invid=new.ar_transaction_header_id;
    SET @amount=new.inv_line_price;
    SET @tax_amount=new.tax_amount;
    SET @createby=new.created_by;
    SET @pu=486;
    SELECT ar_customer_id,ledger_id,period_id,currency,transaction_class,bu_org_id INTO @customerid,@ledgerid,@period,@currency,@transtp,@buorgid FROM ar_transaction_header WHERE ar_transaction_header_id=new.ar_transaction_header_id;
SET @JournalId=NULL;
SET @lidx = 0;
CALL _createJournal('ar','AR_TRANSACTIONS',428,'ar_transaction_header',@invid,@JournalId,@lidx,new.created_by,@buorgid,@ledgerid,@period,@currency);
SET @coaid=NULL;
SET @fromacid=NULL;
SET @taxacid=NULL;
SET @detail_number=0;
SET @iscr=1;
SET @dnum=0;
WHILE @detail_number IS NOT NULL DO
SET @detail_number=NULL;
SELECT ar_transaction_detail_id,detail_number,amount,detail_ac_id INTO @detailid,@detail_number,@amount,@acid FROM ar_transaction_detail WHERE ar_transaction_line_id=new.ar_transaction_line_id AND detail_number>@dnum ORDER BY detail_number LIMIT 0,1;
IF @detail_number IS NOT NULL THEN
SET @lidx = @lidx+1;
SET @dnum=@detail_number;
CALL _createJournalLine(@JournalId,@lidx,@iscr,'ar_transaction_detail',@detailid,@acid,@amount,new.item_id_m,new.created_by,@buorgid);
END IF;
END WHILE;
#SET @lidx = @lidx+1;#tax
#SELECT getCOAId(@buorgid,1607,'customer',@customerid) INTO @acid;
#CALL _createJournalLine(@JournalId,@lidx,@iscr,'ar_transaction_line',new.ar_transaction_line_id,@acid,new.tax_amount,new.item_id_m,new.created_by,@buorgid);
SET @iscr=0;
SET @lidx = @lidx+1;#Receviable(dr)
SELECT getCOAId(@buorgid,1612,'supplier',@supplierid) INTO @acid;
CALL _createJournalLine(@JournalId,@lidx,@iscr,'ar_transaction_header',new.ar_transaction_header_id,@acid,new.inv_line_price+new.tax_amount,new.item_id_m,new.created_by,@buorgid);
IF @transtp=512 THEN
UPDATE sd_so_line SET invoiced_quantity=invoiced_quantity+new.inv_line_quantity WHERE sd_so_line_id=new.reference_key_value;
END IF;
ELSE IF(new.status=1526 AND old.status=1526) THEN
UPDATE ar_transaction_header SET header_amount=header_amount+NEW.inv_line_price-old.inv_line_price,tax_amount=tax_amount+new.tax_amount-old.tax_amount WHERE ar_transaction_header_id=NEW.ar_transaction_header_id;
END IF;
END IF;
    END;
$$

DELIMITER ;

DELIMITER $$

USE `xbs`$$

DROP TRIGGER /*!50032 IF EXISTS */ `ap_transaction_lineUpdate`$$

CREATE
    /*!50017 DEFINER = 'i3u'@'localhost' */
    TRIGGER `ap_transaction_lineUpdate` AFTER UPDATE ON `ap_transaction_line` 
    FOR EACH ROW BEGIN
IF(new.status=1527 AND old.status=1526) THEN
    SET @invid=new.ap_transaction_header_id;
    SET @amount=new.inv_line_price;
    SET @tax_amount=new.tax_amount;
    SET @createby=new.created_by;
    SET @pu=486;
SELECT supplier_id,ledger_id,period_id,currency,transaction_type,bu_org_id INTO @supplierid,@ledgerid,@period,@currency,@transtp,@buorgid FROM ap_transaction_header WHERE ap_transaction_header_id=new.ap_transaction_header_id;
SET @JournalId=NULL;
SET @lidx = 0;
CALL _createJournal('ap','AP_TRANSACTIONS',428,'ap_transaction_header',@invid,@JournalId,@lidx,new.created_by,@buorgid,@ledgerid,@period,@currency);
SET @coaid=NULL;
SET @fromacid=NULL;
SET @taxacid=NULL;
SET @iscr=0;
SET @detail_number=0;
SET @dnum=0;
WHILE @detail_number IS NOT NULL DO
SET @detail_number=NULL;
SELECT ap_transaction_detail_id,detail_number,amount,detail_ac_id INTO @detailid,@detail_number,@amount,@acid FROM ap_transaction_detail WHERE ap_transaction_line_id=new.ap_transaction_line_id AND detail_number>@dnum ORDER BY detail_number LIMIT 0,1;
IF @detail_number IS NOT NULL THEN
SET @lidx = @lidx+1;
SET @dnum=@detail_number;
CALL _createJournalLine(@JournalId,@lidx,@iscr,'ap_transaction_detail',@detailid,@acid,@amount,new.item_id_m,new.created_by,@buorgid);
END IF;
END WHILE;
SET @iscr=1;
SET @lidx = @lidx+1;
SELECT getCOAId(@buorgid,1613,'supplier',@supplierid) INTO @acid;
CALL _createJournalLine(@JournalId,@lidx,@iscr,'ap_transaction_header',new.ap_transaction_header_id,@acid,new.inv_line_price+new.tax_amount,new.item_id_m,new.created_by,@buorgid);
IF @transtp=496 THEN
UPDATE po_line SET invoiced_quantity=invoiced_quantity+new.inv_line_quantity WHERE po_line_id=new.reference_key_value;
END IF;
ELSEIF(new.status=1526 AND old.status=1526) THEN
UPDATE ap_transaction_header SET header_amount=header_amount+NEW.inv_line_price-old.inv_line_price,tax_amount=tax_amount+new.tax_amount-old.tax_amount WHERE ap_transaction_header_id=NEW.ap_transaction_header_id;
END IF;
    END;
$$

DELIMITER ;