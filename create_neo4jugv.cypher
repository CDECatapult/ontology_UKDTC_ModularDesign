// ========================================
// NEO4J UGV KNOWLEDGE GRAPH - BUILD SEQUENCE
// Execute in order: Step 1 → Step 2 → ... → Step 20
// ========================================

// ========== STEP 1: CREATE CONSTRAINTS ==========
// Run first to enforce data integrity
CREATE CONSTRAINT module_id_unique IF NOT EXISTS FOR (m:UGV_Module)         REQUIRE m.module_id IS UNIQUE;
CREATE CONSTRAINT interface_id_unique IF NOT EXISTS FOR (i:Interface_Spec)  REQUIRE i.interface_id IS UNIQUE;
CREATE CONSTRAINT mission_id_unique IF NOT EXISTS    FOR (m:Mission_Profile) REQUIRE m.mission_id IS UNIQUE;
CREATE CONSTRAINT chassis_id_unique IF NOT EXISTS    FOR (c:Base_Chassis)    REQUIRE c.chassis_id IS UNIQUE;
CREATE CONSTRAINT constraint_id_unique IF NOT EXISTS FOR (c:Constraint)      REQUIRE c.constraint_id IS UNIQUE;

// ========== STEP 2: CREATE INDEXES ==========
// Speed up queries
CREATE INDEX module_type IF NOT EXISTS FOR (m:UGV_Module) ON (m.module_type);
CREATE INDEX module_status IF NOT EXISTS FOR (m:UGV_Module) ON (m.status);
CREATE INDEX module_power IF NOT EXISTS FOR (m:UGV_Module) ON (m.power_draw_w);
CREATE INDEX module_mass IF NOT EXISTS FOR (m:UGV_Module) ON (m.mass_kg);

CREATE INDEX mission_type IF NOT EXISTS FOR (n:Mission_Profile) ON (n.mission_type);
CREATE INDEX mission_status IF NOT EXISTS FOR (n:Mission_Profile) ON (n.validation_status);

CREATE INDEX constraint_type IF NOT EXISTS FOR (c:Constraint) ON (c.constraint_type);

// ========== STEP 3: CREATE BASE CHASSIS ==========
CREATE (chassis:Base_Chassis {
  chassis_id: "chassis_001",
  name: "UGV-X Platform",
  mass_kg: 25.0,
  volume_m3: 0.15,
  material: "Al-7075-T73",
  surface_treatment: "anodized",
  power_budget_kw: 3.5,
  thermal_limit_c: 65.0,
  num_module_slots: 3,
  baseline_power_draw_w: 500.0,
  status: "active",
  created_timestamp: datetime()
});

// ========== STEP 4: CREATE INTERFACE SPECIFICATIONS ==========
// 4a: Mechanical Interface Spec (ISO_UGV_Mount_v1)
CREATE (mech_iface:Interface_Spec {
  interface_id: "iso_ugv_mount_v1",
  interface_type: "mechanical",
  interface_version: "1.0",
  connector_class: "ISO_UGV_Mount_v1",
  
  // Load envelope (static)
  force_limit_fx_n: 1500.0,
  force_limit_fy_n: 800.0,
  force_limit_fz_n: 2000.0,
  
  // Load envelope (moments)
  moment_limit_mx_nm: 150.0,
  moment_limit_my_nm: 200.0,
  moment_limit_mz_nm: 100.0,
  
  // Dynamic limits
  dynamic_acceleration_g: 2.0,
  shock_g: 10.0,
  
  // Deflection & stiffness
  deflection_limit_mm: 1.5,
  mounting_stiffness_min_kn_mm: 10.0,
  natural_freq_min_hz: 80.0,
  allowed_rotation_deg: 0.5,
  
  // Material compatibility
  allowed_materials: ["Al-7075-T73", "Ti-6Al-4V", "CF-epoxy"],
  surface_treatment: "anodized",
  fastener_spec: "MIL-STD-1312",
  
  created_timestamp: datetime()
});

// 4b: Electrical Interface Spec (24VDC Primary)
CREATE (elec_iface_24v:Interface_Spec {
  interface_id: "electrical_24vdc_primary",
  interface_type: "electrical",
  interface_version: "1.0",
  
  power_rail: "24VDC",
  power_rail_tolerance_percent: 10.0,
  max_current_per_module_a: 30.0,
  circuit_breaker_protected: true,
  
  // Secondary rails
  secondary_12v_available: true,
  secondary_12v_max_a: 20.0,
  
  auxiliary_48v_available: true,
  auxiliary_48v_max_a: 15.0,
  
  // Power budget
  total_available_w: 3500.0,
  baseline_chassis_w: 500.0,
  module_allocation_max_soft_w: 3000.0,
  module_allocation_max_hard_w: 3200.0,
  
  // CAN-FD protocol
  data_protocol_primary: "CAN-FD",
  can_bandwidth_nominal_mbps: 1.0,
  can_bandwidth_peak_mbps: 5.0,
  latency_requirement_ms: 100.0,
  
  // Ethernet secondary
  data_protocol_secondary: "Ethernet",
  ethernet_bandwidth_mbps: 100.0,
  
  // Signal integrity
  emi_isolation: "shielded_twisted_pair",
  impedance_ohm: 120.0,
  connector_spec: "MIL-SPEC circular",
  ip_rating_mated: "IP67",
  
  created_timestamp: datetime()
});

// 4c: Thermal Interface Spec
CREATE (thermal_iface:Interface_Spec {
  interface_id: "thermal_standard",
  interface_type: "thermal",
  interface_version: "1.0",
  
  module_operating_temp_min_c: 0.0,
  module_operating_temp_max_c: 50.0,
  ambient_temp_min_c: -10.0,
  ambient_temp_max_c: 60.0,
  
  thermal_interface_resistance_k_per_w: 0.5,
  passive_cooling_via_backplate: true,
  active_cooling_available: true,
  active_cooling_additional_capacity_w: 200.0,
  
  chassis_case_temp_limit_c: 65.0,
  module_junction_temp_limit_c: 85.0,
  junction_safety_margin_c: 15.0,
  
  temp_monitoring_method: "thermistor_or_rtd",
  temp_report_via_can: true,
  
  created_timestamp: datetime()
});

// 4d: Data/Telemetry Interface Spec
CREATE (data_iface:Interface_Spec {
  interface_id: "data_telemetry_standard",
  interface_type: "data",
  interface_version: "1.0",
  
  // Module status messages
  module_status_frequency_hz: 10.0,
  module_status_required_fields: ["module_id", "power_draw", "temperature", "health_status"],
  
  // Sensor data
  sensor_data_frequency_hz_min: 1.0,
  sensor_data_frequency_hz_max: 30.0,
  sensor_data_required_fields: ["timestamp_utc", "sensor_id", "raw_data", "confidence_interval"],
  
  // Command protocol
  command_latency_max_ms: 50.0,
  command_state_machine: ["STANDBY", "ARMED", "ACTIVE", "IDLE"],
  
  data_format_config: "JSON",
  data_format_streaming: "binary",
  
  created_timestamp: datetime()
});

// ========== STEP 5: CREATE GLOBAL CONSTRAINTS ==========
CREATE (constraint_power:Constraint {
  constraint_id: "constraint_power_global",
  constraint_type: "power_budget",
  limit_value: 3500.0,
  unit: "watts",
  description: "Maximum continuous power draw from all modules combined",
  severity: "hard",
  enforcement_point: "mission_validation"
});

CREATE (constraint_thermal:Constraint {
  constraint_id: "constraint_thermal_chassis",
  constraint_type: "thermal_budget",
  limit_value: 65.0,
  unit: "celsius",
  description: "Chassis case temperature limit to preserve battery life and operator safety",
  severity: "hard",
  enforcement_point: "thermal_model"
});

CREATE (constraint_freq:Constraint {
  constraint_id: "constraint_freq_min",
  constraint_type: "natural_frequency",
  limit_value: 80.0,
  unit: "hertz",
  description: "Minimum system natural frequency to avoid motor harmonics (50-70 Hz band)",
  severity: "hard",
  enforcement_point: "fea_analysis"
});

CREATE (constraint_deflection:Constraint {
  constraint_id: "constraint_deflection_mount",
  constraint_type: "mechanical_deflection",
  limit_value: 1.5,
  unit: "millimeters",
  description: "Maximum connector deflection to maintain alignment tolerance",
  severity: "hard",
  enforcement_point: "fea_analysis"
});

CREATE (constraint_stiffness:Constraint {
  constraint_id: "constraint_stiffness_mount",
  constraint_type: "mounting_stiffness",
  limit_value: 10.0,
  unit: "kN/mm",
  description: "Minimum connector stiffness to preserve system dynamics",
  severity: "hard",
  enforcement_point: "fea_analysis"
});

// ========== STEP 6: LINK INTERFACE SPECS TO CHASSIS ==========
MATCH (chassis:Base_Chassis {chassis_id: "chassis_001"})
MATCH (mech:Interface_Spec {interface_id: "iso_ugv_mount_v1"})
CREATE (chassis)-[:SPECIFIES_INTERFACE]->(mech);

MATCH (chassis:Base_Chassis {chassis_id: "chassis_001"})
MATCH (elec:Interface_Spec {interface_id: "electrical_24vdc_primary"})
CREATE (chassis)-[:SPECIFIES_INTERFACE]->(elec);

MATCH (chassis:Base_Chassis {chassis_id: "chassis_001"})
MATCH (thermal:Interface_Spec {interface_id: "thermal_standard"})
CREATE (chassis)-[:SPECIFIES_INTERFACE]->(thermal);

MATCH (chassis:Base_Chassis {chassis_id: "chassis_001"})
MATCH (data:Interface_Spec {interface_id: "data_telemetry_standard"})
CREATE (chassis)-[:SPECIFIES_INTERFACE]->(data);

// ========== STEP 7: LINK CONSTRAINTS TO CHASSIS ==========
MATCH (chassis:Base_Chassis {chassis_id: "chassis_001"})
MATCH (c:Constraint {constraint_id: "constraint_power_global"})
CREATE (chassis)-[:ENFORCES_CONSTRAINT]->(c);

MATCH (chassis:Base_Chassis {chassis_id: "chassis_001"})
MATCH (c:Constraint {constraint_id: "constraint_thermal_chassis"})
CREATE (chassis)-[:ENFORCES_CONSTRAINT]->(c);

MATCH (chassis:Base_Chassis {chassis_id: "chassis_001"})
MATCH (c:Constraint {constraint_id: "constraint_freq_min"})
CREATE (chassis)-[:ENFORCES_CONSTRAINT]->(c);

MATCH (chassis:Base_Chassis {chassis_id: "chassis_001"})
MATCH (c:Constraint {constraint_id: "constraint_deflection_mount"})
CREATE (chassis)-[:ENFORCES_CONSTRAINT]->(c);

MATCH (chassis:Base_Chassis {chassis_id: "chassis_001"})
MATCH (c:Constraint {constraint_id: "constraint_stiffness_mount"})
CREATE (chassis)-[:ENFORCES_CONSTRAINT]->(c);

// ========== STEP 8: CREATE OPTICAL CAMERA MODULE ==========
CREATE (optical_cam:UGV_Module {
  module_id: "module_optical_cam_001",
  module_name: "RGB/LWIR Dual Camera",
  module_type: "Sensing_Module",
  subtype: "Optical_Module",
  
  // Physical properties
  mass_kg: 2.5,
  volume_m3: 0.008,
  cg_offset_x: 0.05,
  cg_offset_y: 0.0,
  cg_offset_z: 0.02,
  material: "Al-6061-T6",
  surface_treatment: "anodized",
  
  // Electrical properties
  power_rail: "24VDC",
  power_draw_w: 120.0,
  max_current_a: 5.0,
  
  // Mechanical properties
  mounting_connector: "ISO_UGV_Mount_v1",
  force_limit_fx_n: 1500.0,
  force_limit_fy_n: 800.0,
  force_limit_fz_n: 2000.0,
  moment_limit_mx_nm: 150.0,
  moment_limit_my_nm: 200.0,
  moment_limit_mz_nm: 100.0,
  
  // Thermal properties
  max_heat_dissipation_w: 120.0,
  operating_temp_min_c: -10.0,
  operating_temp_max_c: 50.0,
  thermal_resistance_k_per_w: 0.5,
  
  // Data interface
  data_protocol: "CAN-FD",
  telemetry_rate_hz: 10.0,
  latency_requirement_ms: 100.0,
  
  // Capabilities
  description: "Dual RGB (day) and LWIR (thermal) camera for multi-spectrum reconnaissance",
  capabilities: ["rgb_imaging", "thermal_imaging", "night_vision", "object_detection"],
  sensors: ["RGB_camera_1080p", "LWIR_radiometric", "pan_tilt_servo"],
  
  status: "active",
  created_timestamp: datetime()
});

// ========== STEP 9: CREATE EOD ARM MODULE ==========
CREATE (eod_arm:UGV_Module {
  module_id: "module_arm_eod_001",
  module_name: "6-DOF EOD Manipulator",
  module_type: "Manipulation_Module",
  subtype: "Arm_Module",
  
  // Physical properties
  mass_kg: 18.0,
  volume_m3: 0.025,
  cg_offset_x: 0.3,
  cg_offset_y: 0.05,
  cg_offset_z: 0.15,
  material: "CF-epoxy",
  surface_treatment: "none",
  
  // Electrical properties
  power_rail: "48VDC",
  power_draw_w: 600.0,
  max_current_a: 15.0,
  
  // Mechanical properties
  mounting_connector: "ISO_UGV_Mount_v1",
  force_limit_fx_n: 2000.0,
  force_limit_fy_n: 800.0,
  force_limit_fz_n: 2500.0,
  moment_limit_mx_nm: 200.0,
  moment_limit_my_nm: 250.0,
  moment_limit_mz_nm: 250.0,
  
  // Thermal properties
  max_heat_dissipation_w: 600.0,
  operating_temp_min_c: -5.0,
  operating_temp_max_c: 45.0,
  thermal_resistance_k_per_w: 0.3,
  
  // Data interface
  data_protocol: "CAN-FD",
  telemetry_rate_hz: 20.0,
  latency_requirement_ms: 50.0,
  
  // Capabilities
  description: "6-axis articulated arm for explosive ordnance disposal and manipulation",
  capabilities: ["manipulation", "gripping", "high_precision", "force_feedback"],
  dof: 6,
  reach_m: 1.5,
  payload_capacity_kg: 5.0,
  joints: ["shoulder_roll", "shoulder_pitch", "elbow", "wrist_roll", "wrist_pitch", "wrist_yaw"],
  
  status: "active",
  created_timestamp: datetime()
});

// ========== STEP 10: CREATE BATTERY MODULE ==========
CREATE (battery:UGV_Module {
  module_id: "module_battery_extended_001",
  module_name: "Extended Battery Pack (4-hour)",
  module_type: "Accessory_Module",
  subtype: "Battery_Module",
  
  // Physical properties
  mass_kg: 12.0,
  volume_m3: 0.012,
  cg_offset_x: 0.1,
  cg_offset_y: 0.0,
  cg_offset_z: 0.01,
  material: "Al-7075-T73",
  surface_treatment: "anodized",
  
  // Electrical properties
  power_rail: "24VDC",
  power_draw_w: 0.0,
  max_current_a: 50.0,
  is_power_source: true,
  
  // Mechanical properties
  mounting_connector: "ISO_UGV_Mount_v1",
  
  // Thermal properties
  max_heat_dissipation_w: 100.0,
  operating_temp_min_c: 0.0,
  operating_temp_max_c: 40.0,
  thermal_resistance_k_per_w: 1.0,
  
  // Data interface
  data_protocol: "CAN-FD",
  telemetry_rate_hz: 1.0,
  latency_requirement_ms: 1000.0,
  
  // Capabilities
  description: "Extended capacity battery for 4-hour mission endurance",
  capabilities: ["power_storage", "voltage_regulation", "fault_monitoring"],
  battery_type: "LiPo",
  capacity_wh: 12000.0,
  endurance_hours: 4.0,
  charging_time_hours: 2.5,
  
  status: "active",
  created_timestamp: datetime()
});

// ========== STEP 11: CREATE COMMUNICATION RELAY MODULE ==========
CREATE (comm_relay:UGV_Module {
  module_id: "module_comm_relay_001",
  module_name: "High-Bandwidth Comm Relay",
  module_type: "Payload_Module",
  subtype: "Communication_Relay",
  
  mass_kg: 3.0,
  volume_m3: 0.005,
  cg_offset_x: 0.15,
  cg_offset_y: 0.1,
  cg_offset_z: 0.05,
  material: "Al-6061-T6",
  surface_treatment: "anodized",
  
  power_rail: "24VDC",
  power_draw_w: 80.0,
  max_current_a: 3.5,
  
  mounting_connector: "ISO_UGV_Mount_v1",
  
  max_heat_dissipation_w: 80.0,
  operating_temp_min_c: -10.0,
  operating_temp_max_c: 50.0,
  thermal_resistance_k_per_w: 0.6,
  
  data_protocol: "Ethernet",
  telemetry_rate_hz: 10.0,
  latency_requirement_ms: 50.0,
  
  description: "Ethernet-to-CAN gateway with fiber optic isolation for robust comms",
  capabilities: ["ethernet_gateway", "fiber_isolation", "bandwidth_expansion", "latency_reduction"],
  bandwidth_mbps: 100.0,
  isolation_type: "fiber_optic",
  
  status: "active",
  created_timestamp: datetime()
});

// ========== STEP 12: CREATE GYRO/IMU SENSOR MODULE ==========
CREATE (imu_module:UGV_Module {
  module_id: "module_imu_gyro_001",
  module_name: "9-DOF IMU/Gyro Pack",
  module_type: "Sensing_Module",
  subtype: "Gyro_Module",
  
  mass_kg: 0.5,
  volume_m3: 0.0005,
  cg_offset_x: 0.2,
  cg_offset_y: 0.0,
  cg_offset_z: 0.01,
  material: "Al-6061-T6",
  surface_treatment: "anodized",
  
  power_rail: "24VDC",
  power_draw_w: 5.0,
  max_current_a: 0.2,
  
  mounting_connector: "ISO_UGV_Mount_v1",
  
  max_heat_dissipation_w: 5.0,
  operating_temp_min_c: -20.0,
  operating_temp_max_c: 80.0,
  thermal_resistance_k_per_w: 2.0,
  
  data_protocol: "CAN-FD",
  telemetry_rate_hz: 100.0,
  latency_requirement_ms: 10.0,
  
  description: "MEMS 9-DOF inertial measurement unit for navigation and stabilization",
  capabilities: ["motion_tracking", "orientation", "acceleration_measurement", "vibration_analysis"],
  axes: 9,
  
  status: "active",
  created_timestamp: datetime()
});

// ========== STEP 13: CREATE ARMOR KIT ACCESSORY ==========
CREATE (armor_kit:UGV_Module {
  module_id: "module_armor_kit_001",
  module_name: "Ballistic Armor Kit",
  module_type: "Accessory_Module",
  subtype: "Armor_Kit",
  
  mass_kg: 8.0,
  volume_m3: 0.01,
  cg_offset_x: 0.2,
  cg_offset_y: 0.0,
  cg_offset_z: 0.03,
  material: "Ceramic-composite",
  surface_treatment: "none",
  
  power_rail: "None",
  power_draw_w: 0.0,
  max_current_a: 0.0,
  
  mounting_connector: "ISO_UGV_Mount_v1",
  
  max_heat_dissipation_w: 0.0,
  operating_temp_min_c: -20.0,
  operating_temp_max_c: 100.0,
  thermal_resistance_k_per_w: 0.0,
  
  description: "Modular ballistic protection for IED hardening",
  capabilities: ["fragmentation_protection", "impact_absorption", "thermal_isolation"],
  protection_level: "Level_IIIa",
  weight_penalty_kg: 8.0,
  
  status: "active",
  created_timestamp: datetime()
});

// ========== STEP 14: LINK MODULES TO INTERFACES ==========
MATCH (mod:UGV_Module), (iface:Interface_Spec)
WHERE mod.module_type IN ["Sensing_Module", "Manipulation_Module", "Accessory_Module", "Payload_Module"]
AND iface.interface_id = "iso_ugv_mount_v1"
CREATE (mod)-[:IMPLEMENTS_INTERFACE]->(iface);

MATCH (mod:UGV_Module), (iface:Interface_Spec)
WHERE (mod.power_draw_w > 0 OR mod.is_power_source = true)
AND iface.interface_id = "electrical_24vdc_primary"
CREATE (mod)-[:IMPLEMENTS_INTERFACE]->(iface);

MATCH (mod:UGV_Module), (iface:Interface_Spec)
WHERE iface.interface_id = "thermal_standard"
CREATE (mod)-[:IMPLEMENTS_INTERFACE]->(iface);

MATCH (mod:UGV_Module), (iface:Interface_Spec)
WHERE iface.interface_id = "data_telemetry_standard"
CREATE (mod)-[:IMPLEMENTS_INTERFACE]->(iface);

// ========== STEP 15: LINK MODULES TO CONSTRAINTS ==========
MATCH (mod:UGV_Module), (c:Constraint {constraint_type: "power_budget"})
WHERE mod.power_draw_w > 0
CREATE (mod)-[:SUBJECT_TO_CONSTRAINT]->(c);

MATCH (mod:UGV_Module), (c:Constraint {constraint_type: "thermal_budget"})
CREATE (mod)-[:SUBJECT_TO_CONSTRAINT]->(c);

MATCH (mod:UGV_Module), (c:Constraint {constraint_type: "natural_frequency"})
CREATE (mod)-[:SUBJECT_TO_CONSTRAINT]->(c);

MATCH (mod:UGV_Module), (c:Constraint {constraint_type: "mechanical_deflection"})
CREATE (mod)-[:SUBJECT_TO_CONSTRAINT]->(c);

MATCH (mod:UGV_Module), (c:Constraint {constraint_type: "mounting_stiffness"})
CREATE (mod)-[:SUBJECT_TO_CONSTRAINT]->(c);

// ========== STEP 16: MOUNT MODULES ON CHASSIS ==========
MATCH (chassis:Base_Chassis {chassis_id: "chassis_001"})
MATCH (mod:UGV_Module {module_id: "module_optical_cam_001"})
CREATE (mod)-[:MOUNTED_ON {
  slot_name: "front_mast",
  position_x: 0.0,
  position_y: 0.15,
  position_z: 0.3,
  mounting_status: "verified",
  deflection_predicted_mm: 0.8,
  frequency_predicted_hz: 95.0,
  max_stress_mpa: 185.0,
  mounted_timestamp: datetime()
}]->(chassis);

MATCH (chassis:Base_Chassis {chassis_id: "chassis_001"})
MATCH (mod:UGV_Module {module_id: "module_arm_eod_001"})
CREATE (mod)-[:MOUNTED_ON {
  slot_name: "rear_aft",
  position_x: 0.4,
  position_y: 0.0,
  position_z: 0.1,
  mounting_status: "verified",
  deflection_predicted_mm: 1.1,
  frequency_predicted_hz: 92.0,
  max_stress_mpa: 285.0,
  mounted_timestamp: datetime()
}]->(chassis);

MATCH (chassis:Base_Chassis {chassis_id: "chassis_001"})
MATCH (mod:UGV_Module {module_id: "module_battery_extended_001"})
CREATE (mod)-[:MOUNTED_ON {
  slot_name: "center_belly",
  position_x: 0.2,
  position_y: 0.0,
  position_z: -0.05,
  mounting_status: "verified",
  deflection_predicted_mm: 0.5,
  frequency_predicted_hz: 110.0,
  max_stress_mpa: 120.0,
  mounted_timestamp: datetime()
}]->(chassis);

MATCH (chassis:Base_Chassis {chassis_id: "chassis_001"})
MATCH (mod:UGV_Module {module_id: "module_imu_gyro_001"})
CREATE (mod)-[:MOUNTED_ON {
  slot_name: "central_processor",
  position_x: 0.2,
  position_y: 0.0,
  position_z: 0.08,
  mounting_status: "verified",
  deflection_predicted_mm: 0.2,
  frequency_predicted_hz: 150.0,
  max_stress_mpa: 50.0,
  mounted_timestamp: datetime()
}]->(chassis);

// ========== STEP 17: CREATE MISSION PROFILES ==========
CREATE (mission_recon:Mission_Profile {
  mission_id: "mission_recon_001",
  mission_name: "Urban Multi-Building Reconnaissance",
  mission_type: "reconnaissance",
  duration_hours: 4.0,
  description: "Multi-building surveillance with RGB/LWIR feed for threat assessment",
  priority: "high",
  threat_environment: "urban",
  operator_count: 1,
  validation_status: "unvalidated",
  created_timestamp: datetime()
});

CREATE (mission_eod:Mission_Profile {
  mission_id: "mission_eod_001",
  mission_name: "Explosive Ordnance Disposal",
  mission_type: "eod",
  duration_hours: 2.0,
  description: "Explosive device identification, assessment, and safe disposal via manipulator",
  priority: "critical",
  threat_environment: "contested",
  operator_count: 2,
  validation_status: "unvalidated",
  created_timestamp: datetime()
});

CREATE (mission_logistics:Mission_Profile {
  mission_id: "mission_logistics_001",
  mission_name: "Supply Logistics Transport",
  mission_type: "logistics",
  duration_hours: 3.0,
  description: "Autonomous supply transport across 2km range with passive sensing",
  priority: "medium",
  threat_environment: "semi_hostile",
  operator_count: 1,
  validation_status: "unvalidated",
  created_timestamp: datetime()
});

// ========== STEP 18: ASSIGN MODULES TO MISSIONS ==========
// Reconnaissance mission
MATCH (m:UGV_Module {module_id: "module_optical_cam_001"})
MATCH (mission:Mission_Profile {mission_id: "mission_recon_001"})
CREATE (m)-[:PART_OF_MISSION {
  role: "primary_sensor",
  criticality: "essential",
  assigned_timestamp: datetime()
}]->(mission);

MATCH (m:UGV_Module {module_id: "module_battery_extended_001"})
MATCH (mission:Mission_Profile {mission_id: "mission_recon_001"})
CREATE (m)-[:PART_OF_MISSION {
  role: "power_source",
  criticality: "essential",
  assigned_timestamp: datetime()
}]->(mission);

MATCH (m:UGV_Module {module_id: "module_imu_gyro_001"})
MATCH (mission:Mission_Profile {mission_id: "mission_recon_001"})
CREATE (m)-[:PART_OF_MISSION {
  role: "navigation_support",
  criticality: "important",
  assigned_timestamp: datetime()
}]->(mission);

MATCH (m:UGV_Module {module_id: "module_comm_relay_001"})
MATCH (mission:Mission_Profile {mission_id: "mission_recon_001"})
CREATE (m)-[:PART_OF_MISSION {
  role: "telemetry_relay",
  criticality: "important",
  assigned_timestamp: datetime()
}]->(mission);

// EOD mission
MATCH (m:UGV_Module {module_id: "module_arm_eod_001"})
MATCH (mission:Mission_Profile {mission_id: "mission_eod_001"})
CREATE (m)-[:PART_OF_MISSION {
  role: "primary_manipulator",
  criticality: "essential",
  assigned_timestamp: datetime()
}]->(mission);

MATCH (m:UGV_Module {module_id: "module_optical_cam_001"})
MATCH (mission:Mission_Profile {mission_id: "mission_eod_001"})
CREATE (m)-[:PART_OF_MISSION {
  role: "visual_guidance",
  criticality: "essential",
  assigned_timestamp: datetime()
}]->(mission);

MATCH (m:UGV_Module {module_id: "module_battery_extended_001"})
MATCH (mission:Mission_Profile {mission_id: "mission_eod_001"})
CREATE (m)-[:PART_OF_MISSION {
  role: "power_source",
  criticality: "essential",
  assigned_timestamp: datetime()
}]->(mission);

MATCH (m:UGV_Module {module_id: "module_armor_kit_001"})
MATCH (mission:Mission_Profile {mission_id: "mission_eod_001"})
CREATE (m)-[:PART_OF_MISSION {
  role: "ied_hardening",
  criticality: "essential",
  assigned_timestamp: datetime()
}]->(mission);

MATCH (m:UGV_Module {module_id: "module_imu_gyro_001"})
MATCH (mission:Mission_Profile {mission_id: "mission_eod_001"})
CREATE (m)-[:PART_OF_MISSION {
  role: "stability_monitoring",
  criticality: "important",
  assigned_timestamp: datetime()
}]->(mission);

// Logistics mission
MATCH (m:UGV_Module {module_id: "module_battery_extended_001"})
MATCH (mission:Mission_Profile {mission_id: "mission_logistics_001"})
CREATE (m)-[:PART_OF_MISSION {
  role: "power_source",
  criticality: "essential",
  assigned_timestamp: datetime()
}]->(mission);

MATCH (m:UGV_Module {module_id: "module_imu_gyro_001"})
MATCH (mission:Mission_Profile {mission_id: "mission_logistics_001"})
CREATE (m)-[:PART_OF_MISSION {
  role: "autonomous_navigation",
  criticality: "essential",
  assigned_timestamp: datetime()
}]->(mission);

// ========== STEP 19: MARK MODULE COMPATIBILITY ==========
// Optical camera compatible with arm
MATCH (m1:UGV_Module {module_id: "module_optical_cam_001"})
MATCH (m2:UGV_Module {module_id: "module_arm_eod_001"})
CREATE (m1)-[:COMPATIBLE_WITH {
  reason: "complementary_functions_visual_guidance_for_manipulation",
  validation_status: "verified_fea",
  combined_power_w: 720.0,
  combined_mass_kg: 20.5,
  interference_risk: "none",
  verified_timestamp: datetime()
}]->(m2);

// Optical camera compatible with battery
MATCH (m1:UGV_Module {module_id: "module_optical_cam_001"})
MATCH (m2:UGV_Module {module_id: "module_battery_extended_001"})
CREATE (m1)-[:COMPATIBLE_WITH {
  reason: "no_physical_conflict_shared_24vdc_rail",
  validation_status: "verified_fea",
  combined_power_w: 120.0,
  combined_mass_kg: 14.5,
  interference_risk: "none",
  verified_timestamp: datetime()
}]->(m2);

// ARM compatible with battery
MATCH (m1:UGV_Module {module_id: "module_arm_eod_001"})
MATCH (m2:UGV_Module {module_id: "module_battery_extended_001"})
CREATE (m1)-[:COMPATIBLE_WITH {
  reason: "arm_uses_48vdc_battery_provides_24vdc_no_conflict",
  validation_status: "verified_fea",
  combined_power_w: 600.0,
  combined_mass_kg: 30.0,
  interference_risk: "low_thermal_load",
  verified_timestamp: datetime()
}]->(m2);

// ARM compatible with armor
MATCH (m1:UGV_Module {module_id: "module_arm_eod_001"})
MATCH (m2:UGV_Module {module_id: "module_armor_kit_001"})
CREATE (m1)-[:COMPATIBLE_WITH {
  reason: "armor_passive_aft_mounting_arm_aft_compatible",
  validation_status: "verified_fea",
  combined_power_w: 600.0,
  combined_mass_kg: 26.0,
  interference_risk: "none",
  verified_timestamp: datetime()
}]->(m2);

// IMU compatible with all modules (lightweight, non-intrusive)
MATCH (m1:UGV_Module {module_id: "module_imu_gyro_001"})
MATCH (m2:UGV_Module)
WHERE m2.module_id <> "module_imu_gyro_001"
CREATE (m1)-[:COMPATIBLE_WITH {
  reason: "imu_low_mass_power_minimal_thermal_universal_integration",
  validation_status: "verified_design",
  verified_timestamp: datetime()
}]->(m2);

// Comm relay compatible with high-bandwidth sensors
MATCH (m1:UGV_Module {module_id: "module_comm_relay_001"})
MATCH (m2:UGV_Module {module_id: "module_optical_cam_001"})
CREATE (m1)-[:COMPATIBLE_WITH {
  reason: "comm_relay_enables_video_stream_from_optical_module",
  validation_status: "verified_design",
  verified_timestamp: datetime()
}]->(m2);

// ========== STEP 20: MARK CONFLICTS (if any) ==========
// ARM high torque reaction might conflict with lightweight camera if co-mounted forward
// (but we've placed them in different slots, so no active conflict)

// ========== STEP 21: CREATE VALIDATION RULES ==========
CREATE (val_rule_power:Validation_Rule {
  rule_id: "rule_validate_power_budget",
  rule_type: "constraint_enforcement",
  rule_name: "Power Budget Check",
  description: "Sum of module power draws must not exceed chassis budget",
  query: "MATCH (mission:Mission_Profile)-[:INCLUDES_MODULE]->(m:UGV_Module) WHERE mission.mission_id=$mission_id RETURN sum(m.power_draw_w) AS total_power",
  threshold: 3500.0,
  threshold_operator: "<=",
  severity_if_violated: "FAIL_MISSION",
  enforcement_point: "pre_deployment"
});

CREATE (val_rule_thermal:Validation_Rule {
  rule_id: "rule_validate_thermal",
  rule_type: "constraint_enforcement",
  rule_name: "Thermal Budget Check",
  description: "Predicted chassis case temperature must not exceed limit",
  threshold: 65.0,
  threshold_operator: "<=",
  unit: "celsius",
  severity_if_violated: "FAIL_MISSION",
  enforcement_point: "thermal_simulation"
});

CREATE (val_rule_frequency:Validation_Rule {
  rule_id: "rule_validate_frequency",
  rule_type: "constraint_enforcement",
  rule_name: "Natural Frequency Check",
  description: "System natural frequency must exceed minimum to avoid motor harmonics",
  threshold: 80.0,
  threshold_operator: ">=",
  unit: "hertz",
  severity_if_violated: "DESIGN_CHANGE_REQUIRED",
  enforcement_point: "fea_analysis"
});

// ========== STEP 22: LINK VALIDATION RULES TO MISSIONS ==========
MATCH (rule:Validation_Rule {rule_id: "rule_validate_power_budget"})
MATCH (mission:Mission_Profile)
CREATE (mission)-[:MUST_SATISFY]->(rule);

MATCH (rule:Validation_Rule {rule_id: "rule_validate_thermal"})
MATCH (mission:Mission_Profile)
CREATE (mission)-[:MUST_SATISFY]->(rule);

MATCH (rule:Validation_Rule {rule_id: "rule_validate_frequency"})
MATCH (mission:Mission_Profile)
CREATE (mission)-[:MUST_SATISFY]->(rule);

// ========== STEP 23: VERIFICATION QUERIES ==========
// Query 1: List all modules
MATCH (m:UGV_Module)
RETURN 
  m.module_id AS module_id,
  m.module_type AS type,
  m.mass_kg AS mass_kg,
  m.power_draw_w AS power_w
ORDER BY m.module_type, m.module_id;

// Query 2: Show chassis with mounted modules
MATCH (chassis:Base_Chassis)
OPTIONAL MATCH (m:UGV_Module)-[mounted:MOUNTED_ON]->(chassis)
RETURN 
  chassis.chassis_id AS chassis,
  chassis.power_budget_kw AS budget_kw,
  count(m) AS modules_mounted,
  collect(m.module_id) AS module_list;

// Query 3: Mission composition - Reconnaissance
MATCH (mission:Mission_Profile {mission_id: "mission_recon_001"})
OPTIONAL MATCH (m:UGV_Module)-[part:PART_OF_MISSION]->(mission)
RETURN 
  mission.mission_name AS mission,
  m.module_id AS module,
  m.module_type AS type,
  m.power_draw_w AS power_w,
  m.mass_kg AS mass_kg,
  part.role AS role,
  part.criticality AS criticality
ORDER BY part.criticality DESC;

// Query 4: Mission composition - EOD
MATCH (mission:Mission_Profile {mission_id: "mission_eod_001"})
OPTIONAL MATCH (m:UGV_Module)-[part:PART_OF_MISSION]->(mission)
RETURN 
  mission.mission_name AS mission,
  m.module_id AS module,
  m.module_type AS type,
  m.power_draw_w AS power_w,
  m.mass_kg AS mass_kg,
  part.role AS role,
  part.criticality AS criticality
ORDER BY part.criticality DESC;

// Query 5: Mission composition - Logistics
MATCH (mission:Mission_Profile {mission_id: "mission_logistics_001"})
OPTIONAL MATCH (m:UGV_Module)-[part:PART_OF_MISSION]->(mission)
RETURN 
  mission.mission_name AS mission,
  m.module_id AS module,
  m.module_type AS type,
  m.power_draw_w AS power_w,
  m.mass_kg AS mass_kg,
  part.role AS role,
  part.criticality AS criticality
ORDER BY part.criticality DESC;

// ========== STEP 24: POWER BUDGET VALIDATION QUERIES ==========
// Reconnaissance mission power check
MATCH (mission:Mission_Profile {mission_id: "mission_recon_001"})
MATCH (m:UGV_Module)-[:PART_OF_MISSION]->(mission)
WITH mission, sum(m.power_draw_w) AS total_power_w
RETURN 
  mission.mission_name AS mission_name,
  total_power_w / 1000.0 AS total_power_kw,
  3.5 AS budget_kw,
  (3.5 - (total_power_w / 1000.0)) AS margin_kw,
  CASE 
    WHEN (total_power_w / 1000.0) <= 3.5 THEN "PASS"
    ELSE "FAIL"
  END AS validation_status;

// EOD mission power check
MATCH (mission:Mission_Profile {mission_id: "mission_eod_001"})
MATCH (m:UGV_Module)-[:PART_OF_MISSION]->(mission)
WITH mission, sum(m.power_draw_w) AS total_power_w
RETURN 
  mission.mission_name AS mission_name,
  total_power_w / 1000.0 AS total_power_kw,
  3.5 AS budget_kw,
  (3.5 - (total_power_w / 1000.0)) AS margin_kw,
  CASE 
    WHEN (total_power_w / 1000.0) <= 3.5 THEN "PASS"
    ELSE "FAIL"
  END AS validation_status;

// Logistics mission power check
MATCH (mission:Mission_Profile {mission_id: "mission_logistics_001"})
MATCH (m:UGV_Module)-[:PART_OF_MISSION]->(mission)
WITH mission, sum(m.power_draw_w) AS total_power_w
RETURN 
  mission.mission_name AS mission_name,
  total_power_w / 1000.0 AS total_power_kw,
  3.5 AS budget_kw,
  (3.5 - (total_power_w / 1000.0)) AS margin_kw,
  CASE 
    WHEN (total_power_w / 1000.0) <= 3.5 THEN "PASS"
    ELSE "FAIL"
  END AS validation_status;

// ========== STEP 25: MASS BUDGET VALIDATION QUERIES ==========
// Total mass for each mission
MATCH (mission:Mission_Profile)
OPTIONAL MATCH (m:UGV_Module)-[:PART_OF_MISSION]->(mission)
WITH mission, sum(m.mass_kg) AS total_mass_kg, count(m) AS num_modules
RETURN 
  mission.mission_name AS mission_name,
  mission.mission_type AS mission_type,
  total_mass_kg + 25.0 AS total_ugv_mass_kg,
  num_modules AS num_modules,
  mission.duration_hours AS duration_hours
ORDER BY total_mass_kg DESC;

// ========== STEP 26: COMPATIBILITY MATRIX ==========
// Show which modules can work together
MATCH (m1:UGV_Module)-[compat:COMPATIBLE_WITH]->(m2:UGV_Module)
RETURN 
  m1.module_id AS module_1,
  m2.module_id AS module_2,
  compat.reason AS compatibility_reason,
  compat.validation_status AS validation_status
ORDER BY m1.module_id, m2.module_id;

// ========== STEP 27: INTERFACE COMPLIANCE ==========
// Verify all modules implement required interfaces
MATCH (m:UGV_Module)
OPTIONAL MATCH (m)-[:IMPLEMENTS_INTERFACE]->(i:Interface_Spec)
RETURN 
  m.module_id AS module,
  m.module_type AS type,
  collect(i.interface_type) AS implemented_interfaces,
  count(i) AS interface_count
ORDER BY interface_count DESC, m.module_id;

// ========== STEP 28: CONSTRAINT ENFORCEMENT ==========
// Show which constraints apply to each module
MATCH (m:UGV_Module)-[:SUBJECT_TO_CONSTRAINT]->(c:Constraint)
RETURN 
  m.module_id AS module,
  c.constraint_type AS constraint_type,
  c.limit_value AS limit,
  c.unit AS unit,
  c.severity AS severity
ORDER BY m.module_id, c.constraint_type;

// ========== STEP 29: MOUNTING VERIFICATION ==========
// Verify all module mounting predictions are within spec
MATCH (m:UGV_Module)-[mounted:MOUNTED_ON]->(chassis:Base_Chassis)
RETURN 
  m.module_id AS module,
  mounted.slot_name AS slot,
  mounted.deflection_predicted_mm AS deflection_mm,
  m.module_type AS type,
  CASE 
    WHEN mounted.deflection_predicted_mm <= 1.5 THEN "PASS"
    ELSE "FAIL"
  END AS deflection_status,
  mounted.frequency_predicted_hz AS frequency_hz,
  CASE 
    WHEN mounted.frequency_predicted_hz >= 80.0 THEN "PASS"
    ELSE "FAIL"
  END AS frequency_status,
  mounted.max_stress_mpa AS stress_mpa
ORDER BY m.module_id;

// ========== STEP 30: MISSION READINESS SUMMARY ==========
// Generate mission readiness report
MATCH (mission:Mission_Profile)
OPTIONAL MATCH (m:UGV_Module)-[part:PART_OF_MISSION]->(mission)
WITH mission, 
     count(m) AS num_modules,
     sum(m.power_draw_w) AS total_power_w,
     sum(m.mass_kg) AS total_mass_kg,
     collect({
       module_id: m.module_id,
       type: m.module_type,
       role: part.role,
       criticality: part.criticality
     }) AS modules
RETURN 
  mission.mission_id AS mission_id,
  mission.mission_name AS mission_name,
  mission.mission_type AS mission_type,
  mission.duration_hours AS duration_hours,
  num_modules AS module_count,
  (total_power_w / 1000.0) AS total_power_kw,
  (total_mass_kg + 25.0) AS total_mass_kg,
  CASE 
    WHEN (total_power_w / 1000.0) <= 3.5 THEN "POWER OK"
    ELSE "POWER FAIL"
  END AS power_status,
  modules
ORDER BY mission.mission_type;

// ========== STEP 31: MODULE DEPENDENCY ANALYSIS ==========
// Find dependencies for each module
MATCH (m:UGV_Module)
OPTIONAL MATCH (m)-[:MOUNTED_ON]->(chassis:Base_Chassis)
OPTIONAL MATCH (m)-[:PART_OF_MISSION]->(mission:Mission_Profile)
OPTIONAL MATCH (m)-[:COMPATIBLE_WITH]->(compatible:UGV_Module)
OPTIONAL MATCH (m)-[:SUBJECT_TO_CONSTRAINT]->(constraint:Constraint)
RETURN 
  m.module_id AS module_id,
  m.module_type AS type,
  chassis.chassis_id AS mounted_on,
  collect(DISTINCT mission.mission_name) AS missions,
  collect(DISTINCT compatible.module_id) AS compatible_modules,
  collect(DISTINCT constraint.constraint_type) AS constraints
ORDER BY m.module_id;

// ========== STEP 32: THERMAL LOAD ANALYSIS ==========
// Calculate total thermal load per mission
MATCH (mission:Mission_Profile)
OPTIONAL MATCH (m:UGV_Module)-[:PART_OF_MISSION]->(mission)
WITH mission, sum(m.max_heat_dissipation_w) AS total_thermal_w
RETURN 
  mission.mission_name AS mission,
  total_thermal_w AS total_thermal_dissipation_w,
  CASE 
    WHEN total_thermal_w <= 2000.0 THEN "PASSIVE_COOLING_OK"
    WHEN total_thermal_w <= 2200.0 THEN "ACTIVE_COOLING_NEEDED"
    ELSE "THERMAL_OVERLOAD"
  END AS cooling_requirement
ORDER BY total_thermal_w DESC;

// ========== STEP 33: DATA BANDWIDTH ANALYSIS ==========
// Calculate CAN bus load per mission
MATCH (mission:Mission_Profile)
OPTIONAL MATCH (m:UGV_Module)-[:PART_OF_MISSION]->(mission)
WITH mission, 
     count(m) AS num_modules,
     sum(m.telemetry_rate_hz) AS total_telemetry_hz
RETURN 
  mission.mission_name AS mission,
  num_modules AS num_modules,
  total_telemetry_hz AS combined_telemetry_hz,
  CASE 
    WHEN total_telemetry_hz <= 100.0 THEN "CAN_OK"
    WHEN total_telemetry_hz <= 150.0 THEN "CAN_MARGIN_TIGHT"
    ELSE "CAN_OVERLOAD"
  END AS can_bandwidth_status
ORDER BY total_telemetry_hz DESC;

// ========== STEP 34: CRITICAL PATH ANALYSIS ==========
// Identify essential vs optional modules per mission
MATCH (mission:Mission_Profile)
MATCH (m:UGV_Module)-[part:PART_OF_MISSION]->(mission)
RETURN 
  mission.mission_name AS mission,
  part.criticality AS criticality,
  count(m) AS module_count,
  collect(m.module_id) AS modules
ORDER BY mission.mission_name, part.criticality DESC;