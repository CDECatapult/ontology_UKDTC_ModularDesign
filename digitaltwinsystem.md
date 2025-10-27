# Digital Twin System: From Twin to Platform
## How to Make It Scalable & Extensible

---

## The Problem with Single Twin

```
Current (Limited):
Arduino → Neo4j → Single Diagnostic Twin
         └─→ Fixed to one vehicle/system
         └─→ Hard to add new entity types
         └─→ Not reusable
```

**What you want:**

```
System (Extensible):
Multiple Sources → Unified Ontology → Digital Twin System
                  (Flexible Graph)    (Any entity type)
                  
Can handle:
├─ Fleet of vehicles
├─ Multiple sensor types
├─ Hierarchical relationships
├─ Different intelligence models per entity
└─ Plug-and-play expansion
```

---

## LAYER 1: Core Ontology (Hierarchical)

Extend from "sensors" to "everything".

### extended_ontology.ttl

```turtle
@prefix dt: <http://example.com/digitaltwin/> .
@prefix owl: <http://www.w3.org/2002/07/owl#> .
@prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .
@prefix xsd: <http://www.w3.org/2001/XMLSchema#> .

# ===== ROOT ENTITY =====

dt:Entity a owl:Class ;
    rdfs:label "Anything that can be modeled" .

# ===== SYSTEMS (Top Level) =====

dt:System a owl:Class ;
    rdfs:subClassOf dt:Entity ;
    rdfs:label "A collection of components (vehicle, building, industrial plant)" .

dt:Vehicle a owl:Class ;
    rdfs:subClassOf dt:System ;
    rdfs:label "Mobile system (UAV, ground rover, boat)" .

dt:Building a owl:Class ;
    rdfs:subClassOf dt:System ;
    rdfs:label "Stationary system (building, facility)" .

dt:IndustrialSystem a owl:Class ;
    rdfs:subClassOf dt:System ;
    rdfs:label "Manufacturing, SCADA, plant" .

# ===== SUBSYSTEMS (Mid Level) =====

dt:Subsystem a owl:Class ;
    rdfs:subClassOf dt:Entity ;
    rdfs:label "Part of a system (e.g., propulsion, HVAC)" .

dt:PropulsionSubsystem a owl:Class ;
    rdfs:subClassOf dt:Subsystem .

dt:PowerManagementSubsystem a owl:Class ;
    rdfs:subClassOf dt:Subsystem .

dt:SensingSubsystem a owl:Class ;
    rdfs:subClassOf dt:Subsystem .

dt:EnvironmentControlSubsystem a owl:Class ;
    rdfs:subClassOf dt:Subsystem .

# ===== DEVICES (Low Level) =====

dt:Device a owl:Class ;
    rdfs:subClassOf dt:Entity ;
    rdfs:label "Physical hardware component" .

dt:Sensor a owl:Class ;
    rdfs:subClassOf dt:Device ;
    rdfs:label "Measurement device" .

dt:Actuator a owl:Class ;
    rdfs:subClassOf dt:Device ;
    rdfs:label "Control device" .

dt:Battery a owl:Class ;
    rdfs:subClassOf dt:Device ;
    rdfs:label "Power storage" .

# ===== SENSOR SPECIALIZATIONS =====

dt:TemperatureSensor a owl:Class ;
    rdfs:subClassOf dt:Sensor .

dt:HumiditySensor a owl:Class ;
    rdfs:subClassOf dt:Sensor .

dt:PressureSensor a owl:Class ;
    rdfs:subClassOf dt:Sensor .

dt:UltrasonicSensor a owl:Class ;
    rdfs:subClassOf dt:Sensor .

dt:Motor a owl:Class ;
    rdfs:subClassOf dt:Actuator .

# ===== DATA ENTITIES =====

dt:Reading a owl:Class ;
    rdfs:label "Single measurement" .

dt:Event a owl:Class ;
    rdfs:label "Something happened" .

dt:HealthRecord a owl:Class ;
    rdfs:label "Health assessment" .

dt:Alert a owl:Class ;
    rdfs:label "Warning/anomaly" .

# ===== RELATIONSHIPS (Hierarchical) =====

dt:hasSubsystem a owl:ObjectProperty ;
    rdfs:domain dt:System ;
    rdfs:range dt:Subsystem ;
    rdfs:label "System contains subsystems" .

dt:hasDevice a owl:ObjectProperty ;
    rdfs:domain dt:Subsystem ;
    rdfs:range dt:Device ;
    rdfs:label "Subsystem contains devices" .

dt:hasReading a owl:ObjectProperty ;
    rdfs:domain dt:Device ;
    rdfs:range dt:Reading ;
    rdfs:label "Device produces readings" .

dt:hasHealthRecord a owl:ObjectProperty ;
    rdfs:domain dt:Entity ;
    rdfs:range dt:HealthRecord ;
    rdfs:label "Any entity has health" .

dt:generatesAlert a owl:ObjectProperty ;
    rdfs:domain dt:Entity ;
    rdfs:range dt:Alert ;
    rdfs:label "Entity can generate alerts" .

# ===== PROPERTIES =====

dt:entity_id a owl:DatatypeProperty ;
    rdfs:domain dt:Entity ;
    rdfs:range xsd:string .

dt:entity_type a owl:DatatypeProperty ;
    rdfs:domain dt:Entity ;
    rdfs:range xsd:string .

dt:location a owl:DatatypeProperty ;
    rdfs:domain dt:Entity ;
    rdfs:range xsd:string .

dt:status a owl:DatatypeProperty ;
    rdfs:domain dt:Entity ;
    rdfs:range xsd:string .

dt:value a owl:DatatypeProperty ;
    rdfs:domain dt:Reading ;
    rdfs:range xsd:float .

dt:timestamp a owl:DatatypeProperty ;
    rdfs:domain dt:Reading ;
    rdfs:range xsd:dateTime .

dt:health_score a owl:DatatypeProperty ;
    rdfs:domain dt:HealthRecord ;
    rdfs:range xsd:integer .
```

**What this adds:**
- Hierarchy: System → Subsystem → Device → Reading
- Domain types: Vehicle, Building, IndustrialSystem
- Reusable pattern for ANY entity

---

## LAYER 2: Neo4j Multi-Tenant Schema

Support multiple systems in one graph.

### system_schema.cypher

```cypher
-- ===== HIERARCHICAL CONSTRAINTS =====

-- Systems are unique globally
CREATE CONSTRAINT system_id_unique IF NOT EXISTS
FOR (s:System) REQUIRE s.system_id IS UNIQUE;

-- Subsystems unique per system
CREATE CONSTRAINT subsystem_id_unique IF NOT EXISTS
FOR (ss:Subsystem) REQUIRE ss.subsystem_id IS UNIQUE;

-- Devices unique per subsystem
CREATE CONSTRAINT device_id_unique IF NOT EXISTS
FOR (d:Device) REQUIRE d.device_id IS UNIQUE;

-- Readings globally unique (immutable data)
CREATE CONSTRAINT reading_id_unique IF NOT EXISTS
FOR (r:Reading) REQUIRE r.reading_id IS UNIQUE;

-- ===== PERFORMANCE INDEXES =====

CREATE INDEX system_status IF NOT EXISTS
FOR (s:System) ON (s.status);

CREATE INDEX reading_timestamp IF NOT EXISTS
FOR (r:Reading) ON (r.timestamp);

CREATE INDEX device_type IF NOT EXISTS
FOR (d:Device) ON (d.device_type);

CREATE INDEX entity_location IF NOT EXISTS
FOR (e:Entity) ON (e.location);

-- ===== TEXT SEARCH (for querying across systems) =====

CREATE INDEX entity_search IF NOT EXISTS
FOR (e:Entity) ON (e.entity_id, e.entity_type);
```

---

## LAYER 3: Core Data Model (System)

Think of this as a template that ANY system follows.

### Create a Vehicle System (Example 1)

```cypher
-- Create Vehicle (top-level system)
CREATE (v:System:Vehicle {
  system_id: 'vehicle_001',
  entity_id: 'vehicle_001',
  entity_type: 'Vehicle',
  name: 'Rover-Alpha',
  location: 'Field A',
  status: 'OPERATIONAL',
  created_at: datetime(),
  model: 'Modular Ground Rover',
  owner: 'Research Team'
})
RETURN v;

-- Create Subsystems under Vehicle
WITH v
CREATE (prop:Subsystem:PropulsionSubsystem {
  subsystem_id: 'vehicle_001:propulsion',
  entity_id: 'vehicle_001:propulsion',
  entity_type: 'PropulsionSubsystem',
  name: 'Propulsion',
  status: 'OPERATIONAL'
})
CREATE (power:Subsystem:PowerManagementSubsystem {
  subsystem_id: 'vehicle_001:power',
  entity_id: 'vehicle_001:power',
  entity_type: 'PowerManagementSubsystem',
  name: 'Power Management',
  status: 'OPERATIONAL'
})
CREATE (sensing:Subsystem:SensingSubsystem {
  subsystem_id: 'vehicle_001:sensing',
  entity_id: 'vehicle_001:sensing',
  entity_type: 'SensingSubsystem',
  name: 'Sensing',
  status: 'OPERATIONAL'
})
CREATE (v)-[:HAS_SUBSYSTEM]->(prop)
CREATE (v)-[:HAS_SUBSYSTEM]->(power)
CREATE (v)-[:HAS_SUBSYSTEM]->(sensing)
RETURN prop, power, sensing;

-- Create Devices under Subsystems
MATCH (prop:Subsystem {subsystem_id: 'vehicle_001:propulsion'})
CREATE (motor1:Device:Motor {
  device_id: 'vehicle_001:motor:left',
  entity_id: 'vehicle_001:motor:left',
  entity_type: 'Motor',
  name: 'Left Motor',
  model: 'EC-90flat',
  status: 'OPERATIONAL'
})
CREATE (motor2:Device:Motor {
  device_id: 'vehicle_001:motor:right',
  entity_id: 'vehicle_001:motor:right',
  entity_type: 'Motor',
  name: 'Right Motor',
  model: 'EC-90flat',
  status: 'OPERATIONAL'
})
CREATE (prop)-[:HAS_DEVICE]->(motor1)
CREATE (prop)-[:HAS_DEVICE]->(motor2)
RETURN motor1, motor2;

MATCH (sensing:Subsystem {subsystem_id: 'vehicle_001:sensing'})
CREATE (temp:Device:TemperatureSensor {
  device_id: 'vehicle_001:sensor:temp',
  entity_id: 'vehicle_001:sensor:temp',
  entity_type: 'TemperatureSensor',
  name: 'Internal Temperature',
  model: 'DHT22'
})
CREATE (humid:Device:HumiditySensor {
  device_id: 'vehicle_001:sensor:humidity',
  entity_id: 'vehicle_001:sensor:humidity',
  entity_type: 'HumiditySensor',
  name: 'Humidity Monitor',
  model: 'DHT22'
})
CREATE (sensing)-[:HAS_DEVICE]->(temp)
CREATE (sensing)-[:HAS_DEVICE]->(humid)
RETURN temp, humid;
```

### Create a Building System (Example 2)

```cypher
-- Same structure, different domain
CREATE (b:System:Building {
  system_id: 'building_001',
  entity_id: 'building_001',
  entity_type: 'Building',
  name: 'Lab Building',
  location: 'Campus A',
  status: 'OPERATIONAL'
})
WITH b
CREATE (hvac:Subsystem:EnvironmentControlSubsystem {
  subsystem_id: 'building_001:hvac',
  entity_id: 'building_001:hvac',
  entity_type: 'EnvironmentControlSubsystem',
  name: 'HVAC System'
})
CREATE (b)-[:HAS_SUBSYSTEM]->(hvac)
WITH hvac
CREATE (temp:Device:TemperatureSensor {
  device_id: 'building_001:sensor:temp_floor1',
  entity_type: 'TemperatureSensor',
  name: 'Floor 1 Temperature'
})
CREATE (hvac)-[:HAS_DEVICE]->(temp)
RETURN b;
```

---

## LAYER 4: Unified Intelligence Layer

One intelligence engine that works on ANY entity.

### core_intelligence.py

```python
from neo4j import GraphDatabase
import numpy as np

class UnifiedDiagnosticTwin:
    """
    Works on ANY entity in the system.
    Pass entity_id, get diagnostics.
    """
    
    def __init__(self, uri, user, password):
        self.driver = GraphDatabase.driver(uri, auth=(user, password))
    
    def get_entity_hierarchy(self, entity_id):
        """Get full path: System > Subsystem > Device"""
        with self.driver.session() as session:
            result = session.run(
                """
                MATCH (e:Entity {entity_id: $entity_id})
                OPTIONAL MATCH (parent)-[:HAS_SUBSYSTEM|:HAS_DEVICE*]->(e)
                RETURN e, COLLECT(parent) as ancestors
                """,
                entity_id=entity_id
            )
            return dict(result.single())
    
    def get_all_readings_for_entity(self, entity_id, minutes=60):
        """Get readings from this entity OR its children."""
        with self.driver.session() as session:
            result = session.run(
                """
                MATCH (e:Entity {entity_id: $entity_id})
                -- Find all descendants (devices under subsystems under this entity)
                OPTIONAL MATCH (e)-[:HAS_SUBSYSTEM|:HAS_DEVICE*]->(d:Device)
                -- Find their readings
                OPTIONAL MATCH (d)-[:HAS_READING]->(r:Reading)
                  WHERE r.timestamp > datetime() - duration({minutes: $minutes})
                OPTIONAL MATCH (e)-[:HAS_READING]->(r2:Reading)
                  WHERE r2.timestamp > datetime() - duration({minutes: $minutes})
                RETURN COALESCE(r, r2) as reading, d.entity_id as device_id
                """,
                entity_id=entity_id,
                minutes=minutes
            )
            return [dict(row) for row in result]
    
    def compute_entity_health(self, entity_id):
        """
        Compute health for ANY entity:
        - Sensor → based on readings
        - Device → based on all its readings
        - Subsystem → based on all devices' health
        - System → based on all subsystems' health
        """
        
        # Get entity type
        with self.driver.session() as session:
            entity_result = session.run(
                "MATCH (e:Entity {entity_id: $entity_id}) RETURN e.entity_type as type",
                entity_id=entity_id
            )
            entity_type = entity_result.single()["type"]
        
        if entity_type in ['TemperatureSensor', 'HumiditySensor', 'Motor']:
            # Leaf node: compute from readings
            return self._compute_device_health(entity_id)
        
        elif entity_type == 'Subsystem':
            # Mid node: compute from children
            return self._compute_subsystem_health(entity_id)
        
        elif entity_type in ['System', 'Vehicle', 'Building']:
            # Top node: compute from all children
            return self._compute_system_health(entity_id)
    
    def _compute_device_health(self, device_id):
        """Health of a single device (sensor/actuator)."""
        readings = self.get_all_readings_for_entity(device_id, minutes=60)
        
        if not readings or not readings[0]["reading"]:
            return {"device": device_id, "health_score": 0, "status": "NO_DATA"}
        
        values = [r["reading"]["value"] for r in readings if r["reading"]]
        values = np.array(values)
        
        stability = max(0, 100 - (np.std(values) * 30))
        freshness = 100 if len(values) > 0 else 0
        
        health_score = (stability * 0.6 + freshness * 0.4)
        
        return {
            "entity": device_id,
            "entity_type": "Device",
            "health_score": round(health_score, 1),
            "status": "HEALTHY" if health_score > 80 else "DEGRADED",
            "readings_count": len(values),
            "data": {"stability": stability}
        }
    
    def _compute_subsystem_health(self, subsystem_id):
        """Health of subsystem = average of all devices."""
        with self.driver.session() as session:
            result = session.run(
                """
                MATCH (ss:Subsystem {entity_id: $subsystem_id})
                OPTIONAL MATCH (ss)-[:HAS_DEVICE]->(d:Device)
                RETURN COLLECT(d.entity_id) as device_ids
                """,
                subsystem_id=subsystem_id
            )
            device_ids = result.single()["device_ids"]
        
        if not device_ids:
            return {"subsystem": subsystem_id, "health_score": 0, "status": "NO_DEVICES"}
        
        device_healths = [self._compute_device_health(d) for d in device_ids]
        avg_health = np.mean([h["health_score"] for h in device_healths])
        
        return {
            "entity": subsystem_id,
            "entity_type": "Subsystem",
            "health_score": round(avg_health, 1),
            "status": "HEALTHY" if avg_health > 80 else "DEGRADED",
            "device_count": len(device_ids),
            "child_health": device_healths
        }
    
    def _compute_system_health(self, system_id):
        """Health of system = average of all subsystems."""
        with self.driver.session() as session:
            result = session.run(
                """
                MATCH (s:System {entity_id: $system_id})
                OPTIONAL MATCH (s)-[:HAS_SUBSYSTEM]->(ss:Subsystem)
                RETURN COLLECT(ss.entity_id) as subsystem_ids
                """,
                system_id=system_id
            )
            subsystem_ids = result.single()["subsystem_ids"]
        
        if not subsystem_ids:
            return {"system": system_id, "health_score": 0, "status": "NO_SUBSYSTEMS"}
        
        subsystem_healths = [self._compute_subsystem_health(ss) for ss in subsystem_ids]
        avg_health = np.mean([h["health_score"] for h in subsystem_healths])
        
        return {
            "entity": system_id,
            "entity_type": "System",
            "health_score": round(avg_health, 1),
            "status": "HEALTHY" if avg_health > 80 else "DEGRADED",
            "subsystem_count": len(subsystem_ids),
            "child_health": subsystem_healths
        }
    
    def store_health_record(self, entity_id, health_data):
        """Store computed health in Neo4j."""
        with self.driver.session() as session:
            session.run(
                """
                MATCH (e:Entity {entity_id: $entity_id})
                CREATE (h:HealthRecord {
                    health_id: randomUUID(),
                    timestamp: datetime(),
                    health_score: $score,
                    status: $status
                })
                CREATE (e)-[:HAS_HEALTH_RECORD]->(h)
                """,
                entity_id=entity_id,
                score=health_data["health_score"],
                status=health_data["status"]
            )

# Usage
twin = UnifiedDiagnosticTwin("bolt://localhost:7687", "neo4j", "password123")

# Query ANY entity
print(twin.compute_entity_health('vehicle_001'))  # Whole vehicle
print(twin.compute_entity_health('vehicle_001:sensing'))  # Subsystem
print(twin.compute_entity_health('vehicle_001:sensor:temp'))  # Sensor
```

---

## LAYER 5: Unified API (Query Any System)

```python
from fastapi import FastAPI

app = FastAPI()
twin = UnifiedDiagnosticTwin("bolt://localhost:7687", "neo4j", "password123")

@app.get("/system/{system_id}/health")
def get_system_health(system_id: str):
    """Get full health tree for any system."""
    return twin.compute_entity_health(system_id)

@app.get("/entity/{entity_id}/health")
def get_entity_health(entity_id: str):
    """Get health for ANY entity (vehicle, building, device, sensor)."""
    return twin.compute_entity_health(entity_id)

@app.get("/entity/{entity_id}/hierarchy")
def get_entity_hierarchy(entity_id: str):
    """See where this entity fits in the system."""
    return twin.get_entity_hierarchy(entity_id)

@app.get("/all-systems")
def get_all_systems():
    """List all systems in the graph."""
    with twin.driver.session() as session:
        result = session.run(
            "MATCH (s:System) RETURN s.entity_id, s.entity_type, s.status"
        )
        return [dict(row) for row in result]

@app.get("/system-health-tree/{system_id}")
def get_tree(system_id: str):
    """Get nested tree of health for full system."""
    return twin.compute_entity_health(system_id)
```

**Queries:**
```bash
# Get health of whole vehicle
curl http://localhost:8000/entity/vehicle_001/health

# Get health of just the sensing subsystem
curl http://localhost:8000/entity/vehicle_001:sensing/health

# Get health of one temperature sensor
curl http://localhost:8000/entity/vehicle_001:sensor:temp/health

# Get health of the building
curl http://localhost:8000/entity/building_001/health

# See all systems
curl http://localhost:8000/all-systems
```

---

## LAYER 6: Query Language (Ask Questions About System)

```cypher
-- "Show all sensors in vehicle_001 that are DEGRADED"
MATCH (v:System {entity_id: 'vehicle_001'})
      -[:HAS_SUBSYSTEM]->()
      -[:HAS_DEVICE]->(sensor:Sensor)
      -[:HAS_HEALTH_RECORD]->(h:HealthRecord)
WHERE h.status = 'DEGRADED'
RETURN sensor.entity_id, h.health_score, h.timestamp
ORDER BY h.timestamp DESC;

-- "Which systems are currently CRITICAL?"
MATCH (system:System)
      -[:HAS_SUBSYSTEM]->()
      -[:HAS_DEVICE]->()
      -[:HAS_HEALTH_RECORD]->(h:HealthRecord)
WHERE h.status = 'CRITICAL'
RETURN DISTINCT system.entity_id, system.entity_type
ORDER BY system.entity_id;

-- "Get full health snapshot of vehicle_001 right now"
MATCH (v:System {entity_id: 'vehicle_001'})
      -[:HAS_SUBSYSTEM]->(ss:Subsystem)
      -[:HAS_DEVICE]->(d:Device)
OPTIONAL MATCH (d)-[:HAS_HEALTH_RECORD]->(h:HealthRecord)
RETURN v.entity_id, ss.entity_id, d.entity_id, h.health_score, h.timestamp
ORDER BY h.timestamp DESC
LIMIT 1;

-- "Compare health across all vehicles"
MATCH (v:System:Vehicle)
      -[:HAS_SUBSYSTEM]->()
      -[:HAS_DEVICE]->()
      -[:HAS_HEALTH_RECORD]->(h)
WITH v.entity_id as vehicle, AVG(h.health_score) as avg_health
RETURN vehicle, avg_health
ORDER BY avg_health DESC;
```

---

## COMPLETE SYSTEM ARCHITECTURE

```
┌─────────────────────────────────────────────────────┐
│           ONTOLOGY (Extended)                       │
│  System > Subsystem > Device > Reading              │
│  Vehicle, Building, IndustrialSystem                │
└────────────────┬────────────────────────────────────┘
                 │
┌────────────────▼────────────────────────────────────┐
│           NEO4J GRAPH DATABASE                      │
│  Multi-tenant, hierarchical, scalable               │
│  Constraints, indexes for performance               │
└────────────────┬────────────────────────────────────┘
                 │
┌────────────────▼────────────────────────────────────┐
│      DATA INGESTION (Multiple Sources)              │
│  Vehicle sensors → Neo4j                            │
│  Building HVAC → Neo4j                              │
│  Industrial plant → Neo4j                           │
└────────────────┬────────────────────────────────────┘
                 │
┌────────────────▼────────────────────────────────────┐
│  UNIFIED INTELLIGENCE LAYER                         │
│  One engine, any entity type                        │
│  Recursive health computation                       │
│  Anomaly detection                                  │
└────────────────┬────────────────────────────────────┘
                 │
┌────────────────▼────────────────────────────────────┐
│           UNIFIED API                               │
│  /entity/{id}/health                                │
│  /system/{id}/health                                │
│  /all-systems                                       │
│  /entity/{id}/hierarchy                             │
└────────────────┬────────────────────────────────────┘
                 │
┌────────────────▼────────────────────────────────────┐
│      VISUALIZATION & ANALYSIS                       │
│  Neo4j Browser (graph view)                         │
│  REST API (JSON responses)                          │
│  Cypher queries (ad-hoc analysis)                   │
└─────────────────────────────────────────────────────┘
```

---

## How to Expand

### Add New System Type

```cypher
-- Add drone fleet
CREATE (drone1:System:Vehicle {
  system_id: 'drone_001',
  entity_id: 'drone_001',
  entity_type: 'Vehicle',
  model: 'Quadcopter'
})
-- Same structure as rover
```

### Add New Sensor Type

```cypher
-- Extend ontology
CREATE (gps:Device:GPSSensor {
  device_id: 'vehicle_001:gps',
  entity_type: 'GPSSensor'
})
```

### Add New Intelligence

```python
# New trait function (same pattern)
def compute_gps_accuracy(device_id):
    readings = self.get_all_readings_for_entity(device_id)
    # Your logic
    return health_score
```

### Add New Domain

```cypher
-- Medical equipment system
CREATE (hospital:System:MedicalFacility {
  system_id: 'hospital_001',
  entity_type: 'MedicalFacility'
})
-- Same hierarchical pattern
```

---

## Key Principles

[x] **One Ontology, Many Systems** - Framework works for any domain
[x] **Hierarchical Graph** - System > Subsystem > Device > Reading
[x] **Recursive Intelligence** - Health computed at any level
[x] **Unified API** - Query anything with same endpoint
[x] **Extensible** - Add new entities/sensors without core changes
[x] **Queryable** - Cypher enables ad-hoc analysis

**This is a platform, not a project.**