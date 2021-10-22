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
