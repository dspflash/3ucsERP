USE `xbs`;
delete from address;
delete from ap_payment_header;
delete from ap_payment_line;
delete from ap_transaction_detail;
delete from ap_transaction_header;
delete from ap_transaction_line;
delete from ar_customer;
delete from ar_customer_bu;
delete from ar_customer_relation;
delete from ar_customer_site;
delete from ar_receipt_header;
delete from ar_receipt_line;
delete from ar_sales_region;
delete from ar_transaction_header;
delete from ar_transaction_line;
delete from ar_transaction_type;
delete from bom_cal_week_start_dates;
delete from bom_calendar_exceptions;
delete from bom_calendars;
delete from bom_commonbom_line;
delete from bom_config_header;
delete from bom_config_line;
delete from bom_cost_type;
delete from bom_department;
delete from bom_dept_res_assignment;
delete from bom_exception_sets;
delete from bom_header;
delete from bom_line;
delete from bom_material_element;
delete from bom_oh_rate_assignment;
delete from bom_oh_res_assignment;
delete from bom_overhead;
delete from bom_period_start_dates;
delete from bom_resource;
delete from bom_resource_cost;
delete from bom_routing_detail;
delete from bom_routing_header;
delete from bom_routing_line;
delete from bom_standard_operation;
delete from bom_stnd_op_res_assignment;
delete from business;
delete from category;
delete from category_reference;
delete from coa_combination;
delete from coa_segment_values;
delete from common_bom_line;
delete from contact;
delete from country;
delete from cst_item_cost_header;
delete from cst_item_cost_line;
delete from cst_item_cost_line_pre;
delete from currency;
delete from enterprise;
delete from fp_forecast_consumption;
delete from fp_forecast_group;
delete from fp_forecast_header;
delete from fp_forecast_line;
delete from fp_forecast_line_date;
delete from fp_kanban_demand;
delete from fp_kanban_header;
delete from fp_kanban_line;
delete from fp_kanban_planner_header;
delete from fp_kanban_release;
delete from fp_mds_header;
delete from fp_mds_line;
delete from fp_minmax_demand;
delete from fp_minmax_header;
delete from fp_minmax_line;
delete from fp_mrp_demand;
delete from fp_mrp_exception;
delete from fp_mrp_header;
delete from fp_mrp_lowlevel_code;
delete from fp_mrp_planned_order;
delete from fp_mrp_planned_wip_wo;
delete from fp_mrp_supply;
delete from fp_planning_control;
delete from fp_source_list_header;
delete from fp_source_list_line;
delete from fp_urgent_card;
delete from fp_warning;
delete from gl_account;
delete from gl_account_type;
delete from gl_balance;
delete from gl_budget;
delete from gl_budget_ac_header;
delete from gl_budget_ac_line;
delete from gl_budget_entry;
delete from gl_calendar;
delete from gl_currency_conversion;
delete from gl_journal_header;
delete from gl_journal_interface;
delete from gl_journal_line;
delete from gl_ledger;
delete from gl_ledger_balancing_values;
delete from gl_period;
delete from hr_approval_limit_assign;
delete from hr_approval_limit_header;
delete from hr_approval_limit_line;
delete from hr_approval_object;
delete from hr_attendance;
delete from hr_compensation_element;
delete from hr_control;
delete from hr_department;
delete from hr_element_entry_header;
delete from hr_element_entry_line;
delete from hr_element_entry_tpl_header;
delete from hr_element_entry_tpl_line;
delete from hr_element_history_header;
delete from hr_element_history_line;
delete from hr_employee;
delete from hr_employee_education;
delete from hr_employee_experience;
delete from hr_employee_termination;
delete from hr_event_header;
delete from hr_event_line;
delete from hr_expense_header;
delete from hr_expense_line;
delete from hr_expense_tpl_header;
delete from hr_expense_tpl_line;
delete from hr_grade;
delete from hr_job;
delete from hr_leave_balance;
delete from hr_leave_entitlement_header;
delete from hr_leave_entitlement_line;
delete from hr_leave_transaction;
delete from hr_leave_type;
delete from hr_location;
delete from hr_payroll;
delete from hr_payroll_payment_method;
delete from hr_payroll_process;
delete from hr_payroll_schedule;
delete from hr_payslip_header;
delete from hr_payslip_line;
delete from hr_perdiem_rate;
delete from hr_pos_hierarchy_header;
delete from hr_pos_hierarchy_line;
delete from hr_position;
delete from hr_team_header;
delete from hr_team_line;
delete from hr_timesheet_header;
delete from hr_timesheet_line;
delete from hr_timesheet_period;
delete from inv_abc_assignment_header;
delete from inv_abc_assignment_line;
delete from inv_abc_valuation;
delete from inv_abc_valuation_result;
delete from inv_count_abc_ref;
delete from inv_count_entries;
delete from inv_count_header;
delete from inv_count_schedule;
delete from inv_intorg_transfer_header;
delete from inv_intorg_transfer_line;
delete from inv_issue_header;
delete from inv_issue_line;
delete from inv_item_relation;
delete from inv_item_revision;
delete from inv_location_default;
delete from inv_lot_number;
delete from inv_lot_onhand;
delete from inv_lot_transaction;
delete from inv_moveorder_header;
delete from inv_moveorder_line;
delete from inv_receipt_header;
delete from inv_receipt_line;
delete from inv_reservation;
delete from inv_serial_number;
delete from inv_serial_transaction;
delete from inv_transaction;
delete from inventory;
delete from item;
delete from item_properties;
delete from item_property;
delete from item_status;
delete from legal;
delete from locator;
delete from mdm_bank_account;
delete from mdm_bank_header;
delete from mdm_bank_site;
delete from mdm_discount_header;
delete from mdm_discount_line;
delete from mdm_discount_value;
delete from mdm_price_list_detail;
delete from mdm_price_list_header;
delete from mdm_price_list_line;
delete from mdm_tax_code;
delete from mdm_tax_region;
delete from mdm_tax_rule;
delete from onhand;
delete from org;
delete from page;
delete from payment_term;
delete from payment_term_discount;
delete from payment_term_schedule;
delete from pm_batch_byproduct;
delete from pm_batch_header;
delete from pm_batch_ingredient;
delete from pm_batch_line;
delete from pm_batch_operation_detail;
delete from pm_batch_operation_line;
delete from pm_formula_byproduct;
delete from pm_formula_header;
delete from pm_formula_ingredient;
delete from pm_formula_line;
delete from pm_process_operation_detail;
delete from pm_process_operation_header;
delete from pm_process_operation_line;
delete from pm_process_routing_header;
delete from pm_process_routing_line;
delete from pm_recipe_customer;
delete from pm_recipe_header;
delete from pm_recipe_line;
delete from pm_recipe_material_header;
delete from pm_recipe_material_line;
delete from pm_resource_transaction;
delete from po_asl_document;
delete from po_asl_header;
delete from po_asl_line;
delete from po_detailx;
delete from po_header;
delete from po_line;
delete from po_linex;
delete from po_purchasing_control;
delete from po_quote_detail;
delete from po_quote_header;
delete from po_quote_line;
delete from po_requisition_detailx;
delete from po_requisition_header;
delete from po_requisition_interface;
delete from po_requisition_line;
delete from po_rfq_detail;
delete from po_rfq_header;
delete from po_rfq_line;
delete from po_sourcing_rule_header;
delete from po_sourcing_rule_line;
delete from pos_barcode_list_header;
delete from pos_barcode_list_line;
delete from pos_inv_control;
delete from pos_terminal;
delete from pos_transaction_header;
delete from pos_transaction_line;
delete from product;
delete from qa_ce_action;
delete from qa_ce_action_type;
delete from qa_ce_bgm_calibration_reading;
delete from qa_ce_enc_rating;
delete from qa_ce_header;
delete from qa_ce_higher_bandwidth1;
delete from qa_ce_line;
delete from qa_ce_lower_bandwidth1;
delete from qa_ce_lower_bandwidth2;
delete from qa_ce_quality_rating;
delete from qa_ce_result;
delete from qa_ce_resultx;
delete from qa_ce_spectra_reading;
delete from qa_ce_spectrum_range;
delete from qa_cp_assignment_header;
delete from qa_cp_assignment_line;
delete from qa_cp_header;
delete from qa_cp_line;
delete from qa_result;
delete from qa_results;
delete from qa_results_line;
delete from qa_specification_header;
delete from qa_specification_line;
delete from role_access;
delete from role_path;
delete from sd_delivery_header;
delete from sd_delivery_line;
delete from sd_document_relation;
delete from sd_document_type;
delete from sd_lead;
delete from sd_opportunity;
delete from sd_quote_header;
delete from sd_quote_line;
delete from sd_sales_control;
delete from sd_shipping_control;
delete from sd_so_header;
delete from sd_so_line;
delete from sd_store;
delete from sd_store_subinventory;
delete from site_info;
delete from subinventory;
delete from supplier;
delete from supplier_bu;
delete from supplier_site;
delete from sys_catalog_header;
delete from sys_catalog_line;
delete from sys_catalog_value;
delete from sys_document_sequence;
delete from sys_dynamic_block_header;
delete from sys_dynamic_block_line;
delete from sys_extra_field;
delete from sys_extra_field_instance;
delete from sys_hold;
delete from sys_hold_reference;
delete from sys_message_format;
delete from sys_notification;
delete from sys_notification_group;
delete from sys_pd_header;
delete from sys_pd_pflow_action_val;
delete from sys_pd_process_flow_action;
delete from sys_permission;
delete from sys_pflow_action_val;
delete from sys_printer;
delete from sys_process_flow_action;
delete from sys_process_flow_header;
delete from sys_process_flow_line;
delete from sys_profile_header;
delete from sys_profile_line;
delete from sys_program;
delete from sys_program_schedule;
delete from sys_program_status;
delete from sys_rfid_interface;
delete from sys_role_permission;
delete from sys_secondary_field;
delete from sys_secondary_field_inst;
delete from sys_spd_header;
delete from sys_spd_process_flow_action;
delete from sys_value_group_header;
delete from sys_value_group_line;
delete from system_path;
delete from transaction_type;
delete from uom;
delete from user_bom_department;
delete from user_dashboard_config;
delete from user_favourite;
delete from user_group;
delete from user_group_access;
delete from user_password_reset;
delete from user_role;
delete from user_subinventory;
delete from user_supplier;
delete from view_path;
delete from wip_accounting_group;
delete from wip_control;
delete from wip_move_transaction;
delete from wip_resource_transaction;
delete from wip_wo_allocation;
delete from wip_wo_bom;
delete from wip_wo_header;
delete from wip_wo_routing_detail;
delete from wip_wo_routing_line;
delete from wip_wol_transaction;
delete from xerp_role;
delete from xerp_user;
