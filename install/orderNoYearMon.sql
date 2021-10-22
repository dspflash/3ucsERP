DELIMITER $$

USE `xbs`$$

DROP FUNCTION IF EXISTS `generate_orderNo`$$

CREATE DEFINER=`i3u`@`localhost` FUNCTION `generate_orderNo`(orderNamePre VARCHAR(5), num INT,maxNo INT,orderTbl VARCHAR(20),orderNo VARCHAR(20)) RETURNS VARCHAR(50) CHARSET utf8
BEGIN
      DECLARE currentDate VARCHAR (15) ;
      DECLARE oldOrderNo VARCHAR (25) DEFAULT '' ;
          
      IF num = 4 THEN 
        SELECT DATE_FORMAT(NOW(), '%y%m') INTO currentDate ;
      ELSEIF num = 6 THEN 
        SELECT DATE_FORMAT(NOW(), '%y%m%d') INTO currentDate ;
      ELSEIF num = 8 THEN 
        SELECT DATE_FORMAT(NOW(), '%Y%m%d') INTO currentDate ;
      ELSEIF num = 14 THEN 
        SELECT DATE_FORMAT(NOW(), '%Y%m%d%H%i%s') INTO currentDate ; 
      ELSE 
        SELECT DATE_FORMAT(NOW(), '%Y%m%d%H%i') INTO currentDate ;
      END IF ;    
          SELECT     
            CONCAT(orderNamePre, currentDate,  LPAD((maxNo + 1), 5, '0')) INTO @newOrderNo ; 
         RETURN  @newOrderNo ;    
    END$$

DELIMITER ;

DELIMITER $$

USE `xbs`$$

DROP TRIGGER /*!50032 IF EXISTS */ `inv_issue_headerInsertB`$$

CREATE
    /*!50017 DEFINER = 'i3u'@'localhost' */
    TRIGGER `inv_issue_headerInsertB` BEFORE INSERT ON `inv_issue_header` 
    FOR EACH ROW BEGIN
IF new.issue_number IS NULL OR new.issue_number='' THEN
SET @cnt=0;
SELECT COUNT(0) INTO @cnt FROM inv_issue_header WHERE EXTRACT(YEAR_MONTH FROM creation_date)=EXTRACT(YEAR_MONTH FROM CURDATE());
SET new.issue_number=generate_orderNo('IN', 4, @cnt,'','');
END IF;
    END;
$$

DELIMITER ;

DELIMITER $$

USE `xbs`$$

DROP TRIGGER /*!50032 IF EXISTS */ `inv_receipt_headerInsertB`$$

CREATE
    /*!50017 DEFINER = 'i3u'@'localhost' */
    TRIGGER `inv_receipt_headerInsertB` BEFORE INSERT ON `inv_receipt_header` 
    FOR EACH ROW BEGIN
IF new.receipt_number IS NULL OR new.receipt_number='' THEN
SET @cnt=0;
SELECT COUNT(0) INTO @cnt FROM inv_receipt_header WHERE EXTRACT(YEAR_MONTH FROM creation_date)=EXTRACT(YEAR_MONTH FROM CURDATE());
SET new.receipt_number=generate_orderNo('GE', 4, @cnt,'','');
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
SELECT COUNT(0) INTO @cnt FROM po_requisition_header WHERE EXTRACT(YEAR_MONTH FROM creation_date)=EXTRACT(YEAR_MONTH FROM CURDATE());
SET new.po_requisition_number=generate_orderNo('BR', 4, @cnt,'','');
END IF;
    END;
$$

DELIMITER ;

DELIMITER $$

USE `xbs`$$

DROP TRIGGER /*!50032 IF EXISTS */ `po_header_insertB`$$

CREATE
    /*!50017 DEFINER = 'i3u'@'localhost' */
    TRIGGER `po_header_insertB` BEFORE INSERT ON `po_header` 
    FOR EACH ROW BEGIN
IF new.po_number IS NULL OR new.po_number='' THEN
SET @cnt=0;
#SELECT COUNT(0) INTO @cnt FROM po_header WHERE EXTRACT(YEAR_MONTH FROM creation_date)=EXTRACT(YEAR_MONTH FROM CURDATE());
SELECT SUBSTR(po_number,-5)+0 INTO @cnt FROM po_header WHERE EXTRACT(YEAR_MONTH FROM creation_date)=EXTRACT(YEAR_MONTH FROM CURDATE()) ORDER BY po_number DESC LIMIT 0,1;
SET new.po_number=generate_orderNo('PO', 4, @cnt,'','');
END IF;
    END;
$$

DELIMITER ;

DELIMITER $$

USE `xbs`$$

DROP TRIGGER /*!50032 IF EXISTS */ `po_rfq_header_insertB`$$

CREATE
    /*!50017 DEFINER = 'i3u'@'localhost' */
    TRIGGER `po_rfq_header_insertB` BEFORE INSERT ON `po_rfq_header` 
    FOR EACH ROW BEGIN
IF new.rfq_number IS NULL OR new.rfq_number='' THEN
SET @cnt=0;
SELECT COUNT(0) INTO @cnt FROM po_rfq_header WHERE EXTRACT(YEAR_MONTH FROM creation_date)=EXTRACT(YEAR_MONTH FROM CURDATE());
SET new.rfq_number=generate_orderNo('RFQ', 4, @cnt,'','');
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
#SELECT COUNT(0) INTO @cnt FROM po_quote_header WHERE EXTRACT(YEAR_MONTH FROM creation_date)=EXTRACT(YEAR_MONTH FROM CURDATE());
SELECT SUBSTR(quote_number,-5)+0 INTO @cnt FROM po_quote_header WHERE EXTRACT(YEAR_MONTH FROM creation_date)=EXTRACT(YEAR_MONTH FROM CURDATE()) ORDER BY quote_number DESC LIMIT 0,1;
SET new.quote_number=generate_orderNo('PS', 4, @cnt,'','');
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
SELECT COUNT(0) INTO @cnt FROM sd_delivery_header WHERE EXTRACT(YEAR_MONTH FROM creation_date)=EXTRACT(YEAR_MONTH FROM CURDATE());
SET new.delivery_number=generate_orderNo('SS', 4, @cnt,'','');
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
SELECT COUNT(0) INTO @cnt FROM sd_quote_header WHERE EXTRACT(YEAR_MONTH FROM creation_date)=EXTRACT(YEAR_MONTH FROM CURDATE());
SET new.quote_number=generate_orderNo('PS', 4, @cnt,'','');
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
SELECT COUNT(0) INTO @cnt FROM sd_so_header WHERE EXTRACT(YEAR_MONTH FROM creation_date)=EXTRACT(YEAR_MONTH FROM CURDATE());
SET new.so_number=generate_orderNo('OF', 4, @cnt,'','');
END IF;
    END;
$$

DELIMITER ;

DELIMITER $$

USE `xbs`$$

DROP TRIGGER /*!50032 IF EXISTS */ `wipwoinsertB`$$

CREATE
    /*!50017 DEFINER = 'i3u'@'localhost' */
    TRIGGER `wipwoinsertB` BEFORE INSERT ON `wip_wo_header` 
    FOR EACH ROW BEGIN
IF new.wo_number='' OR new.wo_number IS NULL THEN
SELECT standard_operation_id INTO @stdop FROM bom_routing_line WHERE bom_routing_header_id=new.reference_routing_item_id_m LIMIT 0,1;
SET @cnt=0;
SET @prefix=IF(new.wo_prefix IS NULL OR new.wo_prefix='','WO',new.wo_prefix);
SELECT COUNT(0) INTO @cnt FROM wip_wo_header WHERE EXTRACT(YEAR_MONTH FROM creation_date)=EXTRACT(YEAR_MONTH FROM CURDATE());
SET new.wo_number=generate_orderNo(@prefix, 4, @cnt,'','');
END IF;
    END;
$$

DELIMITER ;