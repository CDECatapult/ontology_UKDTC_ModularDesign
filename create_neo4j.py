"""
Neo4j Knowledge Graph for Ontology-Driven UGV Platform
Defines node classes, relationships, and constraints for digital twin
"""

from neo4j import GraphDatabase
from typing import Dict, List, Optional, Tuple
from dataclasses import dataclass, asdict
from enum import Enum
import json


class NodeType(Enum):
    UGV_MODULE = "UGV_Module"
    SENSING_MODULE = "Sensing_Module"
    MANIPULATION_MODULE = "Manipulation_Module"
    PAYLOAD_MODULE = "Payload_Module"
    ACCESSORY_MODULE = "Accessory_Module"
    BASE_CHASSIS = "Base_Chassis"
    INTERFACE_SPEC = "Interface_Spec"
    MISSION_PROFILE = "Mission_Profile"
    CONSTRAINT = "Constraint"
    RESOURCE = "Resource"
    THERMAL_INTERFACE = "Thermal_Interface"
    ELECTRICAL_INTERFACE = "Electrical_Interface"
    MECHANICAL_INTERFACE = "Mechanical_Interface"
    DATA_INTERFACE = "Data_Interface"


class RelationshipType(Enum):
    IS_A = "IS_A"
    HAS_INTERFACE = "HAS_INTERFACE"
    MOUNTED_ON = "MOUNTED_ON"
    REQUIRES_RESOURCE = "REQUIRES_RESOURCE"
    CONSTRAINED_BY = "CONSTRAINED_BY"
    PART_OF_MISSION = "PART_OF_MISSION"
    COMPATIBLE_WITH = "COMPATIBLE_WITH"
    CONFLICTS_WITH = "CONFLICTS_WITH"
    DEPENDS_ON = "DEPENDS_ON"
    CONNECTS_TO = "CONNECTS_TO"


@dataclass
class PhysicalProperties:
    mass: float  # kg
    volume: float  # m³
    cg_offset: Tuple[float, float, float]  # [x, y, z]
    material: str
    surface_treatment: str = None


@dataclass
class MechanicalInterface:
    connector_class: str
    static_force_limits: Dict[str, float]  # Fx_max, Fy_max, Fz_max in N
    static_moment_limits: Dict[str, float]  # Mx_max, My_max, Mz_max in N⋅m
    dynamic_acceleration_g: float
    shock_g: float
    deflection_limit_mm: float
    mounting_stiffness_min: float  # kN/mm
    natural_freq_min: float  # Hz
    allowed_rotation_deg: float


@dataclass
class ElectricalInterface:
    power_rail: str  # "24VDC", "12VDC", "48VDC"
    max_current_a: float
    power_draw_w: float
    data_protocol: str  # "CAN-FD", "Ethernet", "RS-485"
    telemetry_rate_hz: float
    latency_requirement_ms: float


@dataclass
class ThermalInterface:
    max_heat_dissipation_w: float
    operating_temp_min_c: float
    operating_temp_max_c: float
    thermal_resistance_k_per_w: float


class UGVKnowledgeGraph:
    def __init__(self, uri: str, user: str, password: str):
        self.driver = GraphDatabase.driver(uri, auth=(user, password))
        self.session = None

    def close(self):
        if self.session:
            self.session.close()
        self.driver.close()

    def _execute_query(self, query: str, parameters: Dict = None) -> List:
        """Execute a Cypher query and return results."""
        with self.driver.session() as session:
            result = session.run(query, parameters or {})
            return [record for record in result]

    def _create_node(self, label: str, properties: Dict) -> str:
        """Create a node and return its node_id."""
        props_str = ", ".join([f"{k}: ${k}" for k in properties.keys()])
        query = f"CREATE (n:{label} {{{props_str}}}) RETURN id(n) AS node_id"
        result = self._execute_query(query, properties)
        return result[0]["node_id"] if result else None

    def _create_relationship(self, from_label: str, from_id: str, 
                            rel_type: str, to_label: str, to_id: str, 
                            rel_props: Dict = None) -> bool:
        """Create a relationship between two nodes."""
        props_str = ""
        if rel_props:
            props_str = "{" + ", ".join([f"{k}: ${k}" for k in rel_props.keys()]) + "}"
        
        query = f"""
        MATCH (a:{from_label} WHERE id(a) = $from_id)
        MATCH (b:{to_label} WHERE id(b) = $to_id)
        CREATE (a)-[r:{rel_type} {props_str}]->(b)
        RETURN r
        """
        params = {"from_id": from_id, "to_id": to_id}
        if rel_props:
            params.update(rel_props)
        
        return len(self._execute_query(query, params)) > 0

    # ==================== Schema Setup ====================
    def setup_schema(self):
        """Create indexes and constraints."""
        constraints = [
            "CREATE CONSTRAINT module_id_unique IF NOT EXISTS ON (m:UGV_Module) ASSERT m.module_id IS UNIQUE",
            "CREATE CONSTRAINT interface_id_unique IF NOT EXISTS ON (i:Interface_Spec) ASSERT i.interface_id IS UNIQUE",
            "CREATE CONSTRAINT mission_id_unique IF NOT EXISTS ON (m:Mission_Profile) ASSERT m.mission_id IS UNIQUE",
            "CREATE CONSTRAINT chassis_id_unique IF NOT EXISTS ON (c:Base_Chassis) ASSERT c.chassis_id IS UNIQUE",
        ]
        
        indexes = [
            "CREATE INDEX module_type IF NOT EXISTS ON :UGV_Module(module_type)",
            "CREATE INDEX module_status IF NOT EXISTS ON :UGV_Module(status)",
            "CREATE INDEX mission_type IF NOT EXISTS ON :Mission_Profile(mission_type)",
            "CREATE INDEX power_draw IF NOT EXISTS ON :UGV_Module(power_draw_w)",
        ]
        
        for constraint in constraints:
            try:
                self._execute_query(constraint)
            except Exception as e:
                print(f"Constraint creation note: {e}")
        
        for index in indexes:
            try:
                self._execute_query(index)
            except Exception as e:
                print(f"Index creation note: {e}")

    # ==================== Node Creation ====================
    def create_interface_spec(self, interface_id: str, interface_type: str,
                             mechanical: Optional[MechanicalInterface] = None,
                             electrical: Optional[ElectricalInterface] = None,
                             thermal: Optional[ThermalInterface] = None) -> str:
        """Create Interface_Spec node."""
        props = {
            "interface_id": interface_id,
            "interface_type": interface_type,
            "created_timestamp": "datetime()"
        }
        
        # Flatten interface objects into properties
        if mechanical:
            mech_dict = asdict(mechanical)
            props.update({f"mech_{k}": v for k, v in mech_dict.items()})
        
        if electrical:
            elec_dict = asdict(electrical)
            props.update({f"elec_{k}": v for k, v in elec_dict.items()})
        
        if thermal:
            therm_dict = asdict(thermal)
            props.update({f"therm_{k}": v for k, v in therm_dict.items()})
        
        node_id = self._create_node("Interface_Spec", props)
        print(f"[x] Created Interface_Spec: {interface_id} (node_id: {node_id})")
        return node_id

    def create_module(self, module_id: str, module_type: str, 
                     physical: PhysicalProperties,
                     mechanical_iface: Optional[MechanicalInterface] = None,
                     electrical_iface: Optional[ElectricalInterface] = None,
                     thermal_iface: Optional[ThermalInterface] = None,
                     description: str = "") -> str:
        """Create UGV_Module node with interfaces."""
        props = {
            "module_id": module_id,
            "module_type": module_type,
            "mass_kg": physical.mass,
            "volume_m3": physical.volume,
            "cg_offset_x": physical.cg_offset[0],
            "cg_offset_y": physical.cg_offset[1],
            "cg_offset_z": physical.cg_offset[2],
            "material": physical.material,
            "surface_treatment": physical.surface_treatment or "standard",
            "status": "active",
            "description": description
        }
        
        if electrical_iface:
            props["power_draw_w"] = electrical_iface.power_draw_w
            props["power_rail"] = electrical_iface.power_rail
        
        node_id = self._create_node("UGV_Module", props)
        print(f"[x] Created UGV_Module: {module_id} (type: {module_type})")
        
        # Create interface sub-nodes and relationships
        if mechanical_iface:
            mech_id = self.create_interface_spec(
                f"{module_id}_mechanical", "mechanical", mechanical=mechanical_iface
            )
            self._create_relationship("UGV_Module", node_id, "HAS_INTERFACE", 
                                     "Interface_Spec", mech_id)
        
        if electrical_iface:
            elec_id = self.create_interface_spec(
                f"{module_id}_electrical", "electrical", electrical=electrical_iface
            )
            self._create_relationship("UGV_Module", node_id, "HAS_INTERFACE", 
                                     "Interface_Spec", elec_id)
        
        if thermal_iface:
            therm_id = self.create_interface_spec(
                f"{module_id}_thermal", "thermal", thermal=thermal_iface
            )
            self._create_relationship("UGV_Module", node_id, "HAS_INTERFACE", 
                                     "Interface_Spec", therm_id)
        
        return node_id

    def create_base_chassis(self, chassis_id: str, physical: PhysicalProperties,
                           power_budget_kw: float, thermal_limit_c: float,
                           num_module_slots: int) -> str:
        """Create Base_Chassis node."""
        props = {
            "chassis_id": chassis_id,
            "mass_kg": physical.mass,
            "volume_m3": physical.volume,
            "material": physical.material,
            "power_budget_kw": power_budget_kw,
            "thermal_limit_c": thermal_limit_c,
            "num_module_slots": num_module_slots,
            "status": "active"
        }
        
        node_id = self._create_node("Base_Chassis", props)
        print(f"[x] Created Base_Chassis: {chassis_id}")
        return node_id

    def create_mission_profile(self, mission_id: str, mission_name: str,
                              mission_type: str, duration_hours: float,
                              description: str = "") -> str:
        """Create Mission_Profile node."""
        props = {
            "mission_id": mission_id,
            "mission_name": mission_name,
            "mission_type": mission_type,
            "duration_hours": duration_hours,
            "description": description,
            "validation_status": "unvalidated"
        }
        
        node_id = self._create_node("Mission_Profile", props)
        print(f"[x] Created Mission_Profile: {mission_name} ({mission_type})")
        return node_id

    def create_constraint(self, constraint_id: str, constraint_type: str,
                         limit_value: float, unit: str, description: str) -> str:
        """Create Constraint node."""
        props = {
            "constraint_id": constraint_id,
            "constraint_type": constraint_type,
            "limit_value": limit_value,
            "unit": unit,
            "description": description
        }
        
        node_id = self._create_node("Constraint", props)
        print(f"[x] Created Constraint: {constraint_id}")
        return node_id

    # ==================== Relationship Management ====================
    def mount_module_on_chassis(self, module_id: str, chassis_id: str,
                               slot_name: str, position: Tuple[float, float, float]) -> bool:
        """Mount a module on the chassis."""
        query = """
        MATCH (m:UGV_Module {module_id: $module_id})
        MATCH (c:Base_Chassis {chassis_id: $chassis_id})
        CREATE (m)-[r:MOUNTED_ON {
            slot: $slot,
            position_x: $pos_x,
            position_y: $pos_y,
            position_z: $pos_z
        }]->(c)
        RETURN r
        """
        params = {
            "module_id": module_id,
            "chassis_id": chassis_id,
            "slot": slot_name,
            "pos_x": position[0],
            "pos_y": position[1],
            "pos_z": position[2]
        }
        result = self._execute_query(query, params)
        if result:
            print(f"[x] Mounted {module_id} on {chassis_id} at slot {slot_name}")
        return len(result) > 0

    def add_module_to_mission(self, module_id: str, mission_id: str) -> bool:
        """Add module to mission profile."""
        query = """
        MATCH (m:UGV_Module {module_id: $module_id})
        MATCH (mission:Mission_Profile {mission_id: $mission_id})
        CREATE (m)-[r:PART_OF_MISSION]->(mission)
        RETURN r
        """
        result = self._execute_query(query, {"module_id": module_id, "mission_id": mission_id})
        if result:
            print(f"[x] Added {module_id} to mission {mission_id}")
        return len(result) > 0

    def add_constraint_to_module(self, module_id: str, constraint_id: str) -> bool:
        """Add constraint to module."""
        query = """
        MATCH (m:UGV_Module {module_id: $module_id})
        MATCH (c:Constraint {constraint_id: $constraint_id})
        CREATE (m)-[r:CONSTRAINED_BY]->(c)
        RETURN r
        """
        result = self._execute_query(query, {"module_id": module_id, "constraint_id": constraint_id})
        if result:
            print(f"[x] Applied constraint {constraint_id} to {module_id}")
        return len(result) > 0

    def mark_compatible(self, module_id_1: str, module_id_2: str) -> bool:
        """Mark two modules as compatible."""
        query = """
        MATCH (m1:UGV_Module {module_id: $mod1})
        MATCH (m2:UGV_Module {module_id: $mod2})
        CREATE (m1)-[r:COMPATIBLE_WITH]->(m2)
        RETURN r
        """
        result = self._execute_query(query, {"mod1": module_id_1, "mod2": module_id_2})
        if result:
            print(f"[x] Marked {module_id_1} compatible with {module_id_2}")
        return len(result) > 0

    def mark_conflict(self, module_id_1: str, module_id_2: str, reason: str) -> bool:
        """Mark two modules as conflicting."""
        query = """
        MATCH (m1:UGV_Module {module_id: $mod1})
        MATCH (m2:UGV_Module {module_id: $mod2})
        CREATE (m1)-[r:CONFLICTS_WITH {reason: $reason}]->(m2)
        RETURN r
        """
        result = self._execute_query(query, {"mod1": module_id_1, "mod2": module_id_2, "reason": reason})
        if result:
            print(f"[x] Marked {module_id_1} conflicts with {module_id_2}: {reason}")
        return len(result) > 0

    # ==================== Query & Analysis ====================
    def validate_mission_power_budget(self, mission_id: str, budget_kw: float) -> Dict:
        """Check if mission modules exceed power budget."""
        query = """
        MATCH (m:UGV_Module)-[:PART_OF_MISSION]->(mission:Mission_Profile {mission_id: $mission_id})
        RETURN 
            mission.mission_name AS mission_name,
            sum(m.power_draw_w) AS total_power_w,
            count(m) AS num_modules,
            collect(m.module_id) AS module_ids
        """
        result = self._execute_query(query, {"mission_id": mission_id})
        
        if not result:
            return {"status": "invalid", "reason": "No modules found for mission"}
        
        row = result[0]
        total_power_kw = (row["total_power_w"] or 0) / 1000
        
        return {
            "mission_name": row["mission_name"],
            "total_power_w": row["total_power_w"] or 0,
            "total_power_kw": total_power_kw,
            "budget_kw": budget_kw,
            "num_modules": row["num_modules"],
            "within_budget": total_power_kw <= budget_kw,
            "margin_kw": budget_kw - total_power_kw,
            "module_ids": row["module_ids"]
        }

    def get_mission_compatibility(self, mission_id: str) -> Dict:
        """Analyze compatibility of modules in a mission."""
        query = """
        MATCH (m1:UGV_Module)-[:PART_OF_MISSION]->(mission:Mission_Profile {mission_id: $mission_id})
        WITH collect(m1) AS modules
        WITH modules
        UNWIND modules AS m1
        UNWIND modules AS m2
        WHERE id(m1) < id(m2)
        OPTIONAL MATCH (m1)-[conf:CONFLICTS_WITH]->(m2)
        OPTIONAL MATCH (m1)-[compat:COMPATIBLE_WITH]->(m2)
        RETURN
            m1.module_id AS module_1,
            m2.module_id AS module_2,
            CASE WHEN conf IS NOT NULL THEN 'CONFLICT' 
                 WHEN compat IS NOT NULL THEN 'COMPATIBLE'
                 ELSE 'UNKNOWN' END AS relationship,
            conf.reason AS conflict_reason
        """
        result = self._execute_query(query, {"mission_id": mission_id})
        
        conflicts = [r for r in result if r["relationship"] == "CONFLICT"]
        compatible = [r for r in result if r["relationship"] == "COMPATIBLE"]
        
        return {
            "total_pairs": len(result),
            "conflicts": conflicts,
            "compatible_confirmed": compatible,
            "unknown": len([r for r in result if r["relationship"] == "UNKNOWN"]),
            "mission_viable": len(conflicts) == 0
        }

    def find_module_dependencies(self, module_id: str) -> Dict:
        """Find all dependencies and relationships for a module."""
        query = """
        MATCH (m:UGV_Module {module_id: $module_id})
        OPTIONAL MATCH (m)-[mounted:MOUNTED_ON]->(chassis:Base_Chassis)
        OPTIONAL MATCH (m)-[part_of:PART_OF_MISSION]->(mission:Mission_Profile)
        OPTIONAL MATCH (m)-[has_iface:HAS_INTERFACE]->(iface:Interface_Spec)
        OPTIONAL MATCH (m)-[conflict:CONFLICTS_WITH]->(m2:UGV_Module)
        OPTIONAL MATCH (m)-[compat:COMPATIBLE_WITH]->(m3:UGV_Module)
        RETURN
            m.module_id AS module,
            m.module_type AS type,
            m.power_draw_w AS power_w,
            chassis.chassis_id AS mounted_on,
            collect(DISTINCT mission.mission_name) AS missions,
            collect(DISTINCT iface.interface_type) AS interfaces,
            collect(DISTINCT m2.module_id) AS conflicting_modules,
            collect(DISTINCT m3.module_id) AS compatible_modules
        """
        result = self._execute_query(query, {"module_id": module_id})
        
        if not result:
            return {"status": "not_found"}
        
        row = result[0]
        return {
            "module_id": row["module"],
            "module_type": row["type"],
            "power_w": row["power_w"],
            "mounted_on": row["mounted_on"],
            "missions": row["missions"],
            "interfaces": row["interfaces"],
            "conflicts": row["conflicting_modules"],
            "compatible_with": row["compatible_modules"]
        }

    def get_mission_manifest(self, mission_id: str) -> Dict:
        """Get complete manifest for a mission."""
        query = """
        MATCH (mission:Mission_Profile {mission_id: $mission_id})
        OPTIONAL MATCH (m:UGV_Module)-[:PART_OF_MISSION]->(mission)
        OPTIONAL MATCH (m)-[:CONSTRAINED_BY]->(c:Constraint)
        RETURN
            mission.mission_name AS mission_name,
            mission.mission_type AS mission_type,
            mission.duration_hours AS duration_hours,
            collect({
                module_id: m.module_id,
                type: m.module_type,
                mass_kg: m.mass_kg,
                power_w: m.power_draw_w,
                constraints: collect(DISTINCT c.constraint_id)
            }) AS modules
        """
        result = self._execute_query(query, {"mission_id": mission_id})
        
        if not result:
            return {"status": "not_found"}
        
        row = result[0]
        total_mass = sum([m["mass_kg"] for m in row["modules"] if m["mass_kg"]])
        total_power = sum([m["power_w"] for m in row["modules"] if m["power_w"]])
        
        return {
            "mission_name": row["mission_name"],
            "mission_type": row["mission_type"],
            "duration_hours": row["duration_hours"],
            "total_mass_kg": total_mass,
            "total_power_w": total_power,
            "total_power_kw": total_power / 1000,
            "num_modules": len(row["modules"]),
            "modules": row["modules"]
        }


# ==================== Population Example ====================
def populate_knowledge_graph(kg: UGVKnowledgeGraph):
    """Populate the knowledge graph with example data."""
    
    # Create base chassis
    chassis_physical = PhysicalProperties(
        mass=25.0,
        volume=0.15,
        cg_offset=(0.2, 0, 0.05),
        material="Al-7075-T73",
        surface_treatment="anodized"
    )
    chassis_id = kg.create_base_chassis(
        chassis_id="chassis_001",
        physical=chassis_physical,
        power_budget_kw=3.5,
        thermal_limit_c=65.0,
        num_module_slots=3
    )
    
    # Create optical module
    optical_mechanical = MechanicalInterface(
        connector_class="ISO_UGV_Mount_v1",
        static_force_limits={"Fx_max": 1500, "Fy_max": 800, "Fz_max": 2000},
        static_moment_limits={"Mx_max": 150, "My_max": 200, "Mz_max": 100},
        dynamic_acceleration_g=2.0,
        shock_g=10.0,
        deflection_limit_mm=1.5,
        mounting_stiffness_min=10.0,
        natural_freq_min=80.0,
        allowed_rotation_deg=0.5
    )
    
    optical_electrical = ElectricalInterface(
        power_rail="24VDC",
        max_current_a=5.0,
        power_draw_w=120.0,
        data_protocol="CAN-FD",
        telemetry_rate_hz=10.0,
        latency_requirement_ms=100.0
    )
    
    optical_thermal = ThermalInterface(
        max_heat_dissipation_w=120.0,
        operating_temp_min_c=-10.0,
        operating_temp_max_c=50.0,
        thermal_resistance_k_per_w=0.5
    )
    
    optical_physical = PhysicalProperties(
        mass=2.5,
        volume=0.008,
        cg_offset=(0.05, 0, 0.02),
        material="Al-6061-T6",
        surface_treatment="anodized"
    )
    
    optical_id = kg.create_module(
        module_id="module_optical_cam_001",
        module_type="Optical_Module",
        physical=optical_physical,
        mechanical_iface=optical_mechanical,
        electrical_iface=optical_electrical,
        thermal_iface=optical_thermal,
        description="RGB/LWIR dual camera for reconnaissance"
    )
    
    # Create EOD arm module
    arm_electrical = ElectricalInterface(
        power_rail="48VDC",
        max_current_a=15.0,
        power_draw_w=600.0,
        data_protocol="CAN-FD",
        telemetry_rate_hz=20.0,
        latency_requirement_ms=50.0
    )
    
    arm_thermal = ThermalInterface(
        max_heat_dissipation_w=600.0,
        operating_temp_min_c=-5.0,
        operating_temp_max_c=45.0,
        thermal_resistance_k_per_w=0.3
    )
    
    arm_physical = PhysicalProperties(
        mass=18.0,
        volume=0.025,
        cg_offset=(0.3, 0.05, 0.15),
        material="CF-epoxy",
        surface_treatment="none"
    )
    
    arm_mechanical = MechanicalInterface(
        connector_class="ISO_UGV_Mount_v1",
        static_force_limits={"Fx_max": 2000, "Fy_max": 800, "Fz_max": 2500},
        static_moment_limits={"Mx_max": 200, "My_max": 250, "Mz_max": 250},
        dynamic_acceleration_g=2.0,
        shock_g=10.0,
        deflection_limit_mm=1.5,
        mounting_stiffness_min=10.0,
        natural_freq_min=85.0,
        allowed_rotation_deg=0.5
    )
    
    arm_id = kg.create_module(
        module_id="module_arm_eod_001",
        module_type="Manipulation_Module",
        physical=arm_physical,
        mechanical_iface=arm_mechanical,
        electrical_iface=arm_electrical,
        thermal_iface=arm_thermal,
        description="6-DOF articulated arm for EOD tasks"
    )
    
    # Create battery module
    battery_electrical = ElectricalInterface(
        power_rail="24VDC",
        max_current_a=50.0,
        power_draw_w=0.0,  # Power source
        data_protocol="CAN-FD",
        telemetry_rate_hz=1.0,
        latency_requirement_ms=1000.0
    )
    
    battery_thermal = ThermalInterface(
        max_heat_dissipation_w=100.0,
        operating_temp_min_c=0.0,
        operating_temp_max_c=40.0,
        thermal_resistance_k_per_w=1.0
    )
    
    battery_physical = PhysicalProperties(
        mass=12.0,
        volume=0.012,
        cg_offset=(0.1, 0, 0.01),
        material="Al-7075-T73",
        surface_treatment="anodized"
    )
    
    battery_id = kg.create_module(
        module_id="module_battery_extended_001",
        module_type="Accessory_Module",
        physical=battery_physical,
        electrical_iface=battery_electrical,
        thermal_iface=battery_thermal,
        description="Extended 4-hour battery pack"
    )
    
    # Create missions
    recon_mission_id = kg.create_mission_profile(
        mission_id="mission_recon_001",
        mission_name="Urban Reconnaissance",
        mission_type="reconnaissance",
        duration_hours=4.0,
        description="Multi-building surveillance with RGB/LWIR feed"
    )
    
    eod_mission_id = kg.create_mission_profile(
        mission_id="mission_eod_001",
        mission_name="EOD Disposal",
        mission_type="eod",
        duration_hours=2.0,
        description="Explosive device identification and safe disposal"
    )
    
    # Mount modules on chassis
    kg.mount_module_on_chassis("module_optical_cam_001", "chassis_001", "front_mast", (0, 0.15, 0.3))
    kg.mount_module_on_chassis("module_arm_eod_001", "chassis_001", "rear_aft", (0.4, 0, 0.1))
    kg.mount_module_on_chassis("module_battery_extended_001", "chassis_001", "center_belly", (0.2, 0, -0.05))
    
    # Assign modules to missions
    kg.add_module_to_mission("module_optical_cam_001", recon_mission_id)
    kg.add_module_to_mission("module_battery_extended_001", recon_mission_id)
    
    kg.add_module_to_mission("module_arm_eod_001", eod_mission_id)
    kg.add_module_to_mission("module_battery_extended_001", eod_mission_id)
    
    # Mark compatibility
    kg.mark_compatible("module_optical_cam_001", "module_arm_eod_001")
    kg.mark_compatible("module_optical_cam_001", "module_battery_extended_001")
    kg.mark_compatible("module_arm_eod_001", "module_battery_extended_001")
    
    # Create constraints
    power_constraint_id = kg.create_constraint(
        constraint_id="constraint_power_limit",
        constraint_type="power_budget",
        limit_value=3500.0,
        unit="watts",
        description="Maximum continuous power draw from all modules"
    )
    
    thermal_constraint_id = kg.create_constraint(
        constraint_id="constraint_thermal_limit",
        constraint_type="thermal_budget",
        limit_value=65.0,
        unit="celsius",
        description="Chassis case temperature limit to preserve battery life"
    )
    
    freq_constraint_id = kg.create_constraint(
        constraint_id="constraint_freq_min",
        constraint_type="natural_frequency",
        limit_value=80.0,
        unit="hertz",
        description="Minimum system natural frequency to avoid motor harmonics"
    )
    
    # Apply constraints
    kg.add_constraint_to_module("module_optical_cam_001", power_constraint_id)
    kg.add_constraint_to_module("module_optical_cam_001", thermal_constraint_id)
    kg.add_constraint_to_module("module_optical_cam_001", freq_constraint_id)
    
    kg.add_constraint_to_module("module_arm_eod_001", power_constraint_id)
    kg.add_constraint_to_module("module_arm_eod_001", thermal_constraint_id)
    kg.add_constraint_to_module("module_arm_eod_001", freq_constraint_id)
    
    kg.add_constraint_to_module("module_battery_extended_001", power_constraint_id)
    kg.add_constraint_to_module("module_battery_extended_001", thermal_constraint_id)
    
    print("\n[x] Knowledge graph population complete!")


# ==================== Cypher Query Examples ====================
def run_example_queries(kg: UGVKnowledgeGraph):
    """Run example queries and analysis."""
    
    print("\n" + "="*60)
    print("MISSION POWER BUDGET ANALYSIS")
    print("="*60)
    
    recon_power = kg.validate_mission_power_budget("mission_recon_001", 3.5)
    print("\nReconnaissance Mission:")
    print(f"  Total Power: {recon_power['total_power_w']} W ({recon_power['total_power_kw']:.2f} kW)")
    print(f"  Budget: {recon_power['budget_kw']} kW")
    print(f"  Margin: {recon_power['margin_kw']:.2f} kW")
    print(f"  Status: {'PASS' if recon_power['within_budget'] else 'FAIL'}")
    print(f"  Modules: {recon_power['num_modules']}")
    
    eod_power = kg.validate_mission_power_budget("mission_eod_001", 3.5)
    print("\nEOD Mission:")
    print(f"  Total Power: {eod_power['total_power_w']} W ({eod_power['total_power_kw']:.2f} kW)")
    print(f"  Budget: {eod_power['budget_kw']} kW")
    print(f"  Margin: {eod_power['margin_kw']:.2f} kW")
    print(f"  Status: {'PASS' if eod_power['within_budget'] else 'FAIL'}")
    print(f"  Modules: {eod_power['num_modules']}")
    
    print("\n" + "="*60)
    print("MISSION COMPATIBILITY ANALYSIS")
    print("="*60)
    
    recon_compat = kg.get_mission_compatibility("mission_recon_001")
    print("\nReconnaissance Mission Compatibility:")
    print(f"  Total Module Pairs: {recon_compat['total_pairs']}")
    print(f"  Conflicts: {len(recon_compat['conflicts'])}")
    print(f"  Confirmed Compatible: {len(recon_compat['compatible_confirmed'])}")
    print(f"  Unknown: {recon_compat['unknown']}")
    print(f"  Mission Viable: {'YES' if recon_compat['mission_viable'] else 'NO'}")
    
    eod_compat = kg.get_mission_compatibility("mission_eod_001")
    print("\nEOD Mission Compatibility:")
    print(f"  Total Module Pairs: {eod_compat['total_pairs']}")
    print(f"  Conflicts: {len(eod_compat['conflicts'])}")
    print(f"  Confirmed Compatible: {len(eod_compat['compatible_confirmed'])}")
    print(f"  Unknown: {eod_compat['unknown']}")
    print(f"  Mission Viable: {'YES' if eod_compat['mission_viable'] else 'NO'}")
    
    print("\n" + "="*60)
    print("MODULE DEPENDENCY GRAPH")
    print("="*60)
    
    optical_deps = kg.find_module_dependencies("module_optical_cam_001")
    print("\nOptical Camera Module:")
    print(f"  Type: {optical_deps['module_type']}")
    print(f"  Power: {optical_deps['power_w']} W")
    print(f"  Mounted On: {optical_deps['mounted_on']}")
    print(f"  Missions: {optical_deps['missions']}")
    print(f"  Interfaces: {optical_deps['interfaces']}")
    print(f"  Compatible With: {optical_deps['compatible_with']}")
    print(f"  Conflicts: {optical_deps['conflicts']}")
    
    arm_deps = kg.find_module_dependencies("module_arm_eod_001")
    print("\nEOD Arm Module:")
    print(f"  Type: {arm_deps['module_type']}")
    print(f"  Power: {arm_deps['power_w']} W")
    print(f"  Mounted On: {arm_deps['mounted_on']}")
    print(f"  Missions: {arm_deps['missions']}")
    print(f"  Interfaces: {arm_deps['interfaces']}")
    print(f"  Compatible With: {arm_deps['compatible_with']}")
    
    print("\n" + "="*60)
    print("MISSION MANIFESTS")
    print("="*60)
    
    recon_manifest = kg.get_mission_manifest("mission_recon_001")
    print(f"\n{recon_manifest['mission_name']} ({recon_manifest['mission_type']}):")
    print(f"  Duration: {recon_manifest['duration_hours']} hours")
    print(f"  Total Mass: {recon_manifest['total_mass_kg']} kg")
    print(f"  Total Power: {recon_manifest['total_power_kw']:.2f} kW")
    print(f"  Modules: {recon_manifest['num_modules']}")
    for mod in recon_manifest['modules']:
        print(f"    - {mod['module_id']} ({mod['type']}): {mod['power_w']}W, {mod['mass_kg']}kg")
    
    eod_manifest = kg.get_mission_manifest("mission_eod_001")
    print(f"\n{eod_manifest['mission_name']} ({eod_manifest['mission_type']}):")
    print(f"  Duration: {eod_manifest['duration_hours']} hours")
    print(f"  Total Mass: {eod_manifest['total_mass_kg']} kg")
    print(f"  Total Power: {eod_manifest['total_power_kw']:.2f} kW")
    print(f"  Modules: {eod_manifest['num_modules']}")
    for mod in eod_manifest['modules']:
        print(f"    - {mod['module_id']} ({mod['type']}): {mod['power_w']}W, {mod['mass_kg']}kg")


# ==================== Graph Analysis Queries ====================
def advanced_query_examples(kg: UGVKnowledgeGraph):
    """Advanced Cypher queries for deep analysis."""
    
    print("\n" + "="*60)
    print("ADVANCED GRAPH ANALYSIS")
    print("="*60)
    
    # Query 1: Find all modules exceeding power threshold
    query_high_power = """
    MATCH (m:UGV_Module)
    WHERE m.power_draw_w > 300
    RETURN m.module_id, m.module_type, m.power_draw_w
    ORDER BY m.power_draw_w DESC
    """
    print("\n[Query] Modules exceeding 300W power draw:")
    result = kg._execute_query(query_high_power)
    for row in result:
        print(f"  {row['m.module_id']}: {row['m.power_draw_w']}W ({row['m.module_type']})")
    
    # Query 2: Longest dependency chains
    query_deps = """
    MATCH path = (m:UGV_Module)-[:MOUNTED_ON*0..3]->(c:Base_Chassis)
    RETURN 
        m.module_id AS module,
        length(path) AS chain_depth,
        [n IN nodes(path) | n.module_id + '::' + labels(n)[0]] AS path_nodes
    ORDER BY chain_depth DESC
    LIMIT 5
    """
    print("\n[Query] Dependency chain depth:")
    result = kg._execute_query(query_deps)
    for row in result:
        print(f"  {row['module']}: depth {row['chain_depth']}")
    
    # Query 3: Module utilization across missions
    query_util = """
    MATCH (m:UGV_Module)-[:PART_OF_MISSION]->(mission:Mission_Profile)
    WITH m, count(mission) AS mission_count
    RETURN m.module_id, m.module_type, mission_count
    ORDER BY mission_count DESC
    """
    print("\n[Query] Module utilization (missions per module):")
    result = kg._execute_query(query_util)
    for row in result:
        print(f"  {row['m.module_id']}: used in {row['mission_count']} mission(s)")
    
    # Query 4: Interface coverage analysis
    query_iface = """
    MATCH (m:UGV_Module)-[has:HAS_INTERFACE]->(i:Interface_Spec)
    RETURN 
        m.module_id,
        collect(DISTINCT i.interface_type) AS interfaces,
        count(DISTINCT i.interface_type) AS interface_count
    ORDER BY interface_count DESC
    """
    print("\n[Query] Interface coverage per module:")
    result = kg._execute_query(query_iface)
    for row in result:
        print(f"  {row['m.module_id']}: {row['interface_count']} interfaces - {row['interfaces']}")


# ==================== Main Execution ====================
if __name__ == "__main__":
    # Connection parameters - update with your Neo4j instance
    NEO4J_URI = "bolt://localhost:7687"
    NEO4J_USER = "neo4j"
    NEO4J_PASSWORD = "password"
    
    try:
        # Initialize knowledge graph
        kg = UGVKnowledgeGraph(NEO4J_URI, NEO4J_USER, NEO4J_PASSWORD)
        
        # Setup schema
        print("Setting up Neo4j schema...")
        kg.setup_schema()
        
        # Populate with example data
        print("\nPopulating knowledge graph with UGV data...")
        populate_knowledge_graph(kg)
        
        # Run example queries
        print("\nRunning validation and analysis queries...")
        run_example_queries(kg)
        
        # Run advanced queries
        advanced_query_examples(kg)
        
        print("\n" + "="*60)
        print("Knowledge graph ready for use!")
        print("="*60)
        
    except Exception as e:
        print(f"Error: {e}")
        import traceback
        traceback.print_exc()
    finally:
        kg.close()