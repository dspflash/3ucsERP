////// transaction data	////////////////////////////////////////
TRUNCATE TABLE inv_lot_number;
TRUNCATE TABLE inv_lot_onhand;
TRUNCATE TABLE `onhand`;
TRUNCATE TABLE `po_line`;
TRUNCATE TABLE `po_header`;
TRUNCATE TABLE `po_rfq_header`;
TRUNCATE TABLE `po_rfq_line`;
TRUNCATE TABLE `po_rfq_detail`;
TRUNCATE TABLE sd_so_header;
TRUNCATE TABLE sd_so_line;
TRUNCATE TABLE sd_delivery_header;
TRUNCATE TABLE sd_delivery_line;

TRUNCATE TABLE `inv_transaction`;
TRUNCATE TABLE `inv_receipt_header`;
TRUNCATE TABLE `inv_receipt_line`;
TRUNCATE TABLE `inv_issue_header`;
TRUNCATE TABLE `inv_issue_line`;
TRUNCATE TABLE `wip_wo_header`;
TRUNCATE TABLE `wip_wo_bom`;
TRUNCATE TABLE `wip_wo_routing_line`;
TRUNCATE TABLE `wip_move_transaction`;
TRUNCATE TABLE `wip_wo_allocation`;

TRUNCATE TABLE gl_balance;
TRUNCATE TABLE gl_budget;
TRUNCATE TABLE `gl_journal_header`;
TRUNCATE TABLE `gl_journal_line`;

TRUNCATE TABLE `fp_mds_header`;
TRUNCATE TABLE `fp_mds_line`;
TRUNCATE TABLE `fp_mrp_header`;
TRUNCATE TABLE `fp_mrp_demand`;
TRUNCATE TABLE `fp_mrp_planned_order`;
TRUNCATE TABLE `fp_mrp_exception`;

TRUNCATE TABLE ap_transaction_line;
TRUNCATE TABLE ap_transaction_header;
TRUNCATE TABLE ap_payment_header;
TRUNCATE TABLE ap_payment_line;
TRUNCATE TABLE ar_transaction_header;
TRUNCATE TABLE ar_transaction_line;
TRUNCATE TABLE ar_receipt_header;
TRUNCATE TABLE ar_receipt_line;

//////////////////////////////////////////////////////////////////////////////////////////////////////////////
TRUNCATE TABLE bom_header;
TRUNCATE TABLE bom_line;
TRUNCATE TABLE bom_routing_header;
TRUNCATE TABLE bom_routing_line;
TRUNCATE TABLE po_quote_header;
TRUNCATE TABLE po_quote_line;
TRUNCATE TABLE sd_quote_header;
TRUNCATE TABLE sd_quote_line;
TRUNCATE TABLE gl_calendar;
TRUNCATE TABLE gl_period;

////	Base Data	//////////////////////////////////////////////////////////////////////////////////////////////////////////
TRUNCATE TABLE bom_standard_operation;
TRUNCATE TABLE bom_department;
TRUNCATE TABLE item;
TRUNCATE TABLE category;
TRUNCATE TABLE item_properties;
TRUNCATE TABLE item_property;
TRUNCATE TABLE org;
TRUNCATE TABLE enterprise;
TRUNCATE TABLE legal;
TRUNCATE TABLE business;
TRUNCATE TABLE inventory;
TRUNCATE TABLE subinventory;
TRUNCATE TABLE `locator`;
TRUNCATE TABLE supplier;
TRUNCATE TABLE supplier_bu;
TRUNCATE TABLE supplier_site;
TRUNCATE TABLE ar_customer;
TRUNCATE TABLE ar_customer_bu;
TRUNCATE TABLE ar_customer_site;
TRUNCATE TABLE mdm_bank_account;
TRUNCATE TABLE address;
TRUNCATE TABLE contact;
TRUNCATE TABLE xerp_user;
TRUNCATE TABLE xerp_role;
TRUNCATE TABLE user_bom_department;
TRUNCATE TABLE hr_department;
TRUNCATE TABLE hr_position;
TRUNCATE TABLE hr_employee;
TRUNCATE TABLE hr_employee_education;
TRUNCATE TABLE hr_employee_experience;
TRUNCATE TABLE hr_employee_termination;

