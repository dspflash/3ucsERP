/*
SQLyog 企业版 - MySQL GUI v8.14 
MySQL - 5.0.51b-community-nt-log : Database - xbs
*********************************************************************
*/

/*!40101 SET NAMES utf8 */;

/*!40101 SET SQL_MODE=''*/;

/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;
/*Data for the table `cc_co_template_header` */

LOCK TABLES `cc_co_template_header` WRITE;

insert ignore into `cc_co_template_header`(`cc_co_template_header_id`,`template_name`,`reftbltp`,`org_id`,`description`,`status`,`created_by`,`creation_date`,`last_update_by`,`last_update_date`) values (1,'ECO_Item','Item',4,'44','1565',0,'2019-01-09 09:28:38',1,'2019-01-10 16:43:38'),(2,'ECO_BOM','BOM_line',4,'','1565',1,'2019-01-10 16:39:58',1,'2019-01-10 16:44:20'),(3,'ECO_BOM_Routing','BOM_routing_line',4,'','1565',1,'2019-01-10 16:44:08',1,'2019-01-10 16:44:08');

UNLOCK TABLES;

/*Data for the table `cc_co_template_line` */

LOCK TABLES `cc_co_template_line` WRITE;

insert ignore into `cc_co_template_line`(`cc_co_template_line_id`,`cc_co_template_header_id`,`field_name`,`required_cb`,`label`,`value_type`,`control_type`,`control_value`,`control_uom`,`active_cb`,`display_weight`,`list_values`,`lower_limit`,`upper_limit`,`list_value_option_type`,`created_by`,`creation_date`,`last_update_by`,`last_update_date`) values (1,1,'bom_type',0,'bom_type','int','','',0,1,NULL,'','','','',1,'2019-01-09 10:31:42',1,'2019-01-11 10:29:46'),(2,1,'item_number',0,'item_number','varchar','Select','',0,1,NULL,'SELECT item_number,item_id_m id FROM item JOIN cc_co_template_header coth ON item.org_id=coth.org_id WHERE cc_co_template_header_id=${cc_co_template_line_id[cc_co_template_header_id]} and item_status=277;','','','',1,'2019-01-09 10:35:37',1,'2019-01-18 20:33:22'),(3,1,'item_type',0,'item_type','int','','',0,1,NULL,'','','','',1,'2019-01-09 10:37:51',1,'2019-01-11 10:29:40'),(4,2,'component_item_id_m',0,'component','int','Select','',0,1,NULL,'SELECT item_number,item_id_m id FROM item JOIN cc_co_template_header coth ON item.org_id=coth.org_id WHERE cc_co_template_header_id=${cc_co_template_line_id[cc_co_template_header_id]} and item_status=277','','','',1,'2019-01-10 16:44:43',1,'2019-01-18 20:26:14'),(5,2,'usage_quantity',0,'quantity','decimal','','',0,1,NULL,'','','','',1,'2019-01-10 16:45:17',1,'2019-01-11 09:40:34'),(6,3,'standard_operation_id',0,'operation','int','Select','',0,1,NULL,'SELECT standard_operation,bom_standard_operation_id id FROM bom_standard_operation bso JOIN cc_co_template_header coth ON bso.org_id=coth.org_id WHERE cc_co_template_header_id=${cc_co_template_line_id[cc_co_template_header_id]}','','','',1,'2019-01-10 16:46:12',1,'2019-01-18 20:32:23'),(7,3,'routing_sequence',0,'routing_sequence','int','Text','',0,1,NULL,'','','','',1,'2019-01-27 14:24:08',1,'2019-01-27 14:24:08'),(8,3,'routing_seq_num',0,'routing_seq_num','int','Text','',0,1,NULL,'','','','',1,'2019-01-27 14:24:24',1,'2019-01-27 14:24:24'),(9,2,'bom_sequence',0,'bom_sequence','int','Text','',0,1,NULL,'','','','',1,'2019-01-27 14:53:50',1,'2019-01-27 14:53:50'),(10,2,'wip_supply_type',0,'wip_supply_type','int','Select','',0,1,NULL,'SELECT option_line_value,option_line_id id FROM xbs.option_line WHERE option_header_id=135 AND STATUS IS true','','','',1,'2019-01-27 14:57:11',1,'2019-01-27 17:00:50'),(11,2,'supply_sub_inventory',0,'supply_sub_inventory','int','Select','',0,1,NULL,'SELECT subinventory,subinventory_id id FROM xbs.subinventory WHERE org_id=${orgid}','','','',1,'2019-01-27 14:59:45',1,'2019-01-27 17:01:01'),(12,2,'bom_routing_line',0,'operation','int','Select','',0,1,NULL,'SELECT standard_operation,bom_routing_line_id id FROM bom_routing_line brl JOIN bom_routing_header brh ON brl.bom_routing_header_id=brh.bom_routing_header_id JOIN cc_co_line col ON brh.item_id_m=col.item_id_m JOIN cc_co_header coh ON col.cc_co_header_id=coh.cc_co_header_id AND brh.org_id=coh.org_id JOIN bom_standard_operation bso ON brl.standard_operation_id=bso.bom_standard_operation_id WHERE cc_co_line_id=${cc_co_line_id}','','','',1,'2019-01-27 15:07:49',1,'2019-01-27 17:01:13'),(13,2,'usage_basis',0,'useage_basis','int','Select','',0,1,NULL,'SELECT option_line_value,option_line_id id from xbs.option_line where option_header_id=138','','','',1,'2019-01-27 15:18:18',1,'2019-01-27 17:01:24');

UNLOCK TABLES;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;
