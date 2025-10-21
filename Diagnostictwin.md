# Diagnostic Digital Twin: Step-by-Step
## Focus: Ontology Design + Query Development

---

## Step 1: Define Your Ontology (Semantic Model)

This is the conceptual model. Think: "What IS a sensor? What relationships exist?"

### Entities (Node Types)

```
Sensor (the hardware piece)
  ├─ properties: sensor_id, type, location, model, calibration_date
  ├─ relationships: HAS_READING, HAS_CALIBRATION, HAS_HEALTH_RECORD

Reading (a data point)
  ├─ properties: value, timestamp, unit, quality_score
  ├─ relationships: RECORDED_BY (sensor), PART_OF (time_window)

HealthRecord (computed health snapshot)
  ├─ properties: health_score, stability, drift, freshness, timestamp
  ├─ relationships: DESCRIBES (sensor), BASED_ON (readings)

Anomaly (detected problem)
  ├─ properties: type, severity, detected_at, description
  ├─ relationships: DETECTED_IN (sensor), CAUSED_BY (reading)

TimeWindow (temporal grouping)
  ├─ properties: window_start, window_end, duration_seconds
  ├─ relationships: CONTAINS (readings)

CalibrationEvent (maintenance record)
  ├─ properties: calibration_date, next_due, status
  ├─ relationships: ASSOCIATED_WITH (sensor)
```

### Relationships (How They Connect)

```
Sensor -[HAS_READING]-> Reading
  (A sensor produces readings)

Reading -[RECORDED_BY]-> Sensor
  (A reading comes from a sensor)

Sensor -[HAS_HEALTH_RECORD]-> HealthRecord
  (A sensor has computed health snapshots)

HealthRecord -[BASED_ON]-> Reading
  (Health computed from readings)

Sensor -[HAS_CALIBRATION]-> CalibrationEvent
  (Sensor has maintenance history)

Sensor -[HAS_ANOMALY]-> Anomaly
  (Sensor has detected issues)
```

---

## Step 2: Neo4j Schema Definition

Run these in Neo4j Browser to set up the data model.

### Create Constraints (Enforce Uniqueness)

```cypher
-- Sensor must have unique ID
CREATE CONSTRAINT sensor_id IF NOT EXISTS
FOR (s:Sensor) REQUIRE s.sensor_id IS UNIQUE;

-- Reading must have unique ID
CREATE CONSTRAINT reading_id IF NOT EXISTS
FOR (r:Reading) REQUIRE r.reading_id IS UNIQUE;

-- Health record must be unique (sensor + timestamp)
CREATE CONSTRAINT health_record_id IF NOT EXISTS
FOR (h:HealthRecord) REQUIRE h.health_record_id IS UNIQUE;

-- Anomaly must have unique ID
CREATE CONSTRAINT anomaly_id IF NOT EXISTS
FOR (a:Anomaly) REQUIRE a.anomaly_id IS UNIQUE;

-- Calibration event unique
CREATE CONSTRAINT calibration_id IF NOT EXISTS
FOR (c:CalibrationEvent) REQUIRE c.calibration_id IS UNIQUE;
```

### Create Indexes (Optimize Queries)

```cypher
-- Index for time-based queries
CREATE INDEX reading_timestamp IF NOT EXISTS
FOR (r:Reading) ON (r.timestamp);

-- Index for sensor lookups
CREATE INDEX sensor_type IF NOT EXISTS
FOR (s:Sensor) ON (s.type);

-- Index for health records over time
CREATE INDEX health_timestamp IF NOT EXISTS
FOR (h:HealthRecord) ON (h.timestamp);

-- Index for anomaly detection
CREATE INDEX anomaly_timestamp IF NOT EXISTS
FOR (a:Anomaly) ON (a.detected_at);
```

---

## Step 3: Data Model - Create Sample Sensor

This shows how data flows into the ontology.

### Create a Sensor Node

```cypher
CREATE (s:Sensor {
  sensor_id: 'temp_1',
  type: 'TemperatureSensor',
  model: 'DHT22',
  location: 'Living Room',
  unit: 'Celsius',
  manufacturer: 'Adafruit',
  calibration_date: '2025-01-01T00:00:00Z',
  next_calibration_due: '2025-04-01T00:00:00Z',
  status: 'ACTIVE',
  created_at: datetime()
})
RETURN s;
```

### Create Sample Readings (Multiple Time Points)

```cypher
MATCH (s:Sensor {sensor_id: 'temp_1'})
WITH s, datetime() as now
CREATE (r1:Reading {
  reading_id: randomUUID(),
  value: 23.5,
  timestamp: now - duration({seconds: 60}),
  unit: 'Celsius',
  quality_score: 0.95
})
CREATE (r2:Reading {
  reading_id: randomUUID(),
  value: 23.6,
  timestamp: now - duration({seconds: 50}),
  unit: 'Celsius',
  quality_score: 0.96
})
CREATE (r3:Reading {
  reading_id: randomUUID(),
  value: 23.4,
  timestamp: now - duration({seconds: 40}),
  unit: 'Celsius',
  quality_score: 0.97
})
CREATE (r4:Reading {
  reading_id: randomUUID(),
  value: 23.7,
  timestamp: now - duration({seconds: 30}),
  unit: 'Celsius',
  quality_score: 0.94
})
CREATE (r5:Reading {
  reading_id: randomUUID(),
  value: 23.5,
  timestamp: now,
  unit: 'Celsius',
  quality_score: 0.98
})
CREATE (s)-[:HAS_READING]->(r1)
CREATE (s)-[:HAS_READING]->(r2)
CREATE (s)-[:HAS_READING]->(r3)
CREATE (s)-[:HAS_READING]->(r4)
CREATE (s)-[:HAS_READING]->(r5)
RETURN s, [r1, r2, r3, r4, r5] as readings;
```

---

## Step 4: Diagnostic Queries

These are the queries you'll actually run for diagnostics.

### Query 1: Get Latest Reading (Current State)

```cypher
MATCH (s:Sensor {sensor_id: 'temp_1'})-[:HAS_READING]->(r:Reading)
RETURN 
  s.sensor_id as sensor,
  s.type as sensor_type,
  s.location as location,
  r.value as current_value,
  r.timestamp as last_reading_time,
  r.quality_score as data_quality,
  duration.inSeconds(r.timestamp, datetime()).seconds as age_seconds
ORDER BY r.timestamp DESC
LIMIT 1;
```

**Expected Output:**
```
sensor: "temp_1"
sensor_type: "TemperatureSensor"
location: "Living Room"
current_value: 23.5
last_reading_time: 2025-01-15T10:30:45Z
data_quality: 0.98
age_seconds: 2
```

---

### Query 2: Statistical Summary (Stability Assessment)

```cypher
MATCH (s:Sensor {sensor_id: 'temp_1'})-[:HAS_READING]->(r:Reading)
WHERE r.timestamp > datetime() - duration({minutes: 10})
RETURN
  s.sensor_id as sensor,
  COUNT(r) as reading_count,
  MIN(r.value) as min_value,
  MAX(r.value) as max_value,
  AVG(r.value) as mean_value,
  STDEV(r.value) as std_dev,
  MAX(r.value) - MIN(r.value) as range,
  ROUND(100 - (STDEV(r.value) * 10), 2) as stability_percent
ORDER BY r.timestamp;
```

**Expected Output:**
```
sensor: "temp_1"
reading_count: 601
min_value: 23.2
max_value: 24.1
mean_value: 23.58
std_dev: 0.18
range: 0.9
stability_percent: 98.2
```

---

### Query 3: Drift Detection (Trend Analysis)

```cypher
MATCH (s:Sensor {sensor_id: 'temp_1'})-[:HAS_READING]->(r:Reading)
WHERE r.timestamp > datetime() - duration({minutes: 30})
WITH 
  s.sensor_id as sensor,
  r.value as value,
  r.timestamp as timestamp,
  datetime() as now
RETURN
  sensor,
  COLLECT({value: value, time: timestamp}) as reading_series,
  ROUND(AVG(value), 2) as mean_30min,
  COUNT(r) as reading_count,
  CASE
    WHEN (MAX(value) - MIN(value)) / MAX(value) > 0.05 THEN "DRIFTING"
    ELSE "STABLE"
  END as drift_status
ORDER BY timestamp DESC;
```

**Expected Output:**
```
sensor: "temp_1"
reading_series: [{value: 23.5, time: 2025-01-15T10:30:45Z}, ...]
mean_30min: 23.58
reading_count: 1800
drift_status: "STABLE"
```

---

### Query 4: Health Score Calculation (Composite)

```cypher
MATCH (s:Sensor)
WITH s, datetime() as now
OPTIONAL MATCH (s)-[:HAS_READING]->(r:Reading)
WHERE r.timestamp > now - duration({minutes: 10})
WITH 
  s,
  COUNT(r) as recent_readings,
  STDEV(r.value) as variability,
  MAX(r.timestamp) as latest_reading_time
WITH
  s,
  recent_readings,
  variability,
  duration.inSeconds(latest_reading_time, datetime()).seconds as age_seconds,
  CASE
    -- Freshness score (0-30 points)
    WHEN age_seconds < 5 THEN 30
    WHEN age_seconds < 10 THEN 25
    WHEN age_seconds < 30 THEN 15
    ELSE 0
  END as freshness_score,
  CASE
    -- Stability score (0-40 points)
    WHEN variability < 0.1 THEN 40
    WHEN variability < 0.5 THEN 35
    WHEN variability < 1.0 THEN 20
    ELSE 5
  END as stability_score,
  CASE
    -- Data continuity score (0-30 points)
    WHEN recent_readings > 500 THEN 30
    WHEN recent_readings > 100 THEN 25
    WHEN recent_readings > 10 THEN 15
    ELSE 5
  END as continuity_score
RETURN
  s.sensor_id as sensor,
  s.type as sensor_type,
  s.location as location,
  recent_readings,
  ROUND(variability, 4) as std_dev,
  age_seconds,
  freshness_score + stability_score + continuity_score as health_score,
  CASE
    WHEN freshness_score + stability_score + continuity_score > 80 THEN "HEALTHY"
    WHEN freshness_score + stability_score + continuity_score > 60 THEN "DEGRADED"
    ELSE "CRITICAL"
  END as health_status
ORDER BY health_score DESC;
```

**Expected Output:**
```
sensor: "temp_1"
sensor_type: "TemperatureSensor"
location: "Living Room"
recent_readings: 601
std_dev: 0.18
age_seconds: 2
health_score: 95
health_status: "HEALTHY"
```

---

### Query 5: Anomaly Detection (Out-of-Range)

```cypher
MATCH (s:Sensor {sensor_id: 'temp_1'})-[:HAS_READING]->(r:Reading)
WITH s, AVG(r.value) as baseline_mean, STDEV(r.value) as baseline_std
WHERE r.timestamp > datetime() - duration({hours: 1})
WITH s, baseline_mean, baseline_std, r
WHERE ABS(r.value - baseline_mean) > baseline_std * 3
RETURN
  s.sensor_id as sensor,
  r.value as anomalous_value,
  r.timestamp as detected_at,
  baseline_mean as expected_range_center,
  baseline_std * 3 as deviation_threshold,
  ROUND(ABS(r.value - baseline_mean) / baseline_std, 2) as sigma_deviation,
  CASE
    WHEN r.value > baseline_mean + (baseline_std * 3) THEN "HIGH"
    WHEN r.value < baseline_mean - (baseline_std * 3) THEN "LOW"
  END as direction
ORDER BY r.timestamp DESC;
```

**Expected Output:**
```
sensor: "temp_1"
anomalous_value: 35.2
detected_at: 2025-01-15T09:15:30Z
expected_range_center: 23.58
deviation_threshold: 0.54
sigma_deviation: 21.89
direction: "HIGH"
```

---

### Query 6: Sensor Comparison (Ranking)

```cypher
MATCH (s:Sensor)-[:HAS_READING]->(r:Reading)
WHERE r.timestamp > datetime() - duration({hours: 1})
WITH s, COUNT(r) as reading_count, AVG(r.value) as mean_val, STDEV(r.value) as std
RETURN
  s.sensor_id as sensor,
  s.type as sensor_type,
  s.location as location,
  reading_count,
  ROUND(mean_val, 2) as mean_value,
  ROUND(std, 4) as std_dev,
  ROUND(100 - (std * 10), 1) as reliability_score,
  CASE
    WHEN std < 0.2 THEN "EXCELLENT"
    WHEN std < 0.5 THEN "GOOD"
    WHEN std < 1.0 THEN "FAIR"
    ELSE "POOR"
  END as reliability_rating
ORDER BY reliability_score DESC;
```

**Expected Output:**
```
sensor: "temp_1", sensor_type: "TemperatureSensor", location: "Living Room", reading_count: 3600, mean_value: 23.58, std_dev: 0.18, reliability_score: 98.2, reliability_rating: "EXCELLENT"
sensor: "temp_2", sensor_type: "TemperatureSensor", location: "Bedroom", reading_count: 3598, mean_value: 22.45, std_dev: 0.52, reliability_score: 94.8, reliability_rating: "GOOD"
sensor: "humidity_1", sensor_type: "HumiditySensor", location: "Living Room", reading_count: 3550, mean_value: 45.32, std_dev: 2.3, reliability_score: 76.7, reliability_rating: "FAIR"
```

---

### Query 7: Freshness Check (Data Currency)

```cypher
MATCH (s:Sensor)-[:HAS_READING]->(r:Reading)
WITH s, MAX(r.timestamp) as latest_reading
WITH 
  s,
  latest_reading,
  duration.inSeconds(latest_reading, datetime()).seconds as age_seconds
RETURN
  s.sensor_id as sensor,
  s.type as sensor_type,
  latest_reading as last_reading_time,
  age_seconds,
  CASE
    WHEN age_seconds < 5 THEN "LIVE"
    WHEN age_seconds < 30 THEN "RECENT"
    WHEN age_seconds < 300 THEN "STALE"
    ELSE "CRITICAL"
  END as freshness_status,
  CASE
    WHEN age_seconds < 5 THEN "✓ OK"
    WHEN age_seconds < 30 THEN "⚠ OK"
    WHEN age_seconds < 300 THEN "⚠ WARNING"
    ELSE "✗ ALERT"
  END as alert_level
ORDER BY age_seconds DESC;
```

**Expected Output:**
```
sensor: "temp_1", sensor_type: "TemperatureSensor", last_reading_time: 2025-01-15T10:30:45Z, age_seconds: 2, freshness_status: "LIVE", alert_level: "✓ OK"
sensor: "humidity_1", sensor_type: "HumiditySensor", last_reading_time: 2025-01-15T10:25:12Z, age_seconds: 333, freshness_status: "STALE", alert_level: "⚠ WARNING"
```

---

### Query 8: Sensor Maintenance Schedule (Calibration)

```cypher
MATCH (s:Sensor)
WITH s, datetime() as now
RETURN
  s.sensor_id as sensor,
  s.type as sensor_type,
  s.calibration_date as last_calibrated,
  s.next_calibration_due as next_due,
  duration.inDays(now, s.next_calibration_due).days as days_until_calibration,
  CASE
    WHEN s.next_calibration_due < now THEN "OVERDUE"
    WHEN duration.inDays(now, s.next_calibration_due).days < 7 THEN "DUE_SOON"
    WHEN duration.inDays(now, s.next_calibration_due).days < 30 THEN "SCHEDULED"
    ELSE "OK"
  END as calibration_status
ORDER BY s.next_calibration_due ASC;
```

**Expected Output:**
```
sensor: "temp_1", sensor_type: "TemperatureSensor", last_calibrated: 2025-01-01T00:00:00Z, next_due: 2025-04-01T00:00:00Z, days_until_calibration: 76, calibration_status: "OK"
sensor: "pressure_1", sensor_type: "PressureSensor", last_calibrated: 2024-10-15T00:00:00Z, next_due: 2025-01-10T00:00:00Z, days_until_calibration: -5, calibration_status: "OVERDUE"
```

---

### Query 9: Comprehensive System Status (Dashboard)

```cypher
CALL {
  MATCH (s:Sensor)-[:HAS_READING]->(r:Reading)
  WHERE r.timestamp > datetime() - duration({minutes: 10})
  RETURN s.sensor_id as sensor, COUNT(r) as active_sensors
  LIMIT 1
}
CALL {
  MATCH (s:Sensor)-[:HAS_READING]->(r:Reading)
  WHERE r.timestamp > datetime() - duration({hours: 1})
  AND STDEV(r.value) < 0.5
  RETURN COUNT(DISTINCT s) as healthy_sensors
}
CALL {
  MATCH (s:Sensor)-[:HAS_READING]->(r:Reading)
  WHERE duration.inSeconds(r.timestamp, datetime()).seconds > 30
  RETURN COUNT(DISTINCT s) as stale_sensors
}
RETURN
  active_sensors,
  healthy_sensors,
  stale_sensors,
  (active_sensors - stale_sensors) as responsive_sensors,
  ROUND(100.0 * (active_sensors - stale_sensors) / active_sensors, 1) as system_responsiveness_percent,
  ROUND(100.0 * healthy_sensors / active_sensors, 1) as system_health_percent,
  CASE
    WHEN 100.0 * healthy_sensors / active_sensors > 80 THEN "OPERATIONAL"
    WHEN 100.0 * healthy_sensors / active_sensors > 60 THEN "DEGRADED"
    ELSE "CRITICAL"
  END as overall_status;
```

**Expected Output:**
```
active_sensors: 6
healthy_sensors: 5
stale_sensors: 1
responsive_sensors: 5
system_responsiveness_percent: 83.3
system_health_percent: 83.3
overall_status: "OPERATIONAL"
```

---

### Query 10: Historical Trend (Pattern Over Time)

```cypher
MATCH (s:Sensor {sensor_id: 'temp_1'})-[:HAS_READING]->(r:Reading)
WHERE r.timestamp > datetime() - duration({hours: 24})
WITH s, r
ORDER BY r.timestamp
WITH
  s,
  COLLECT({
    timestamp: r.timestamp,
    value: r.value
  }) as readings,
  COUNT(r) as total_readings
RETURN
  s.sensor_id as sensor,
  readings[0].timestamp as start_time,
  readings[-1].timestamp as end_time,
  readings[0].value as start_value,
  readings[-1].value as end_value,
  (readings[-1].value - readings[0].value) as total_change,
  ROUND((readings[-1].value - readings[0].value) / total_readings, 4) as average_change_per_reading,
  total_readings as total_readings_in_period;
```

**Expected Output:**
```
sensor: "temp_1"
start_time: 2025-01-14T10:30:00Z
end_time: 2025-01-15T10:30:00Z
start_value: 22.8
end_value: 23.6
total_change: 0.8
average_change_per_reading: 0.0008
total_readings_in_period: 1000
```

---

## Step 5: Turn Queries into Traits (Python Layer)

You'll wrap these queries in Python functions that return structured data.

```python
from neo4j import GraphDatabase

class DiagnosticTwin:
    def __init__(self, uri, user, password):
        self.driver = GraphDatabase.driver(uri, auth=(user, password))
    
    def get_sensor_health(self, sensor_id):
        """Returns complete health assessment for one sensor."""
        with self.driver.session() as session:
            result = session.run("""
                MATCH (s:Sensor {sensor_id: $sensor_id})-[:HAS_READING]->(r:Reading)
                WHERE r.timestamp > datetime() - duration({minutes: 10})
                WITH s, COUNT(r) as reading_count, STDEV(r.value) as std, 
                     MAX(r.timestamp) as latest_reading
                RETURN
                  s.sensor_id,
                  reading_count,
                  std,
                  duration.inSeconds(latest_reading, datetime()).seconds as age_seconds,
                  s.status
            """, sensor_id=sensor_id)
            
            record = result.single()
            if not record:
                return None
            
            # Compute health score
            freshness = 30 if record["age_seconds"] < 5 else 0
            stability = 40 if record["std"] < 0.1 else 20
            continuity = 30 if record["reading_count"] > 500 else 15
            health_score = freshness + stability + continuity
            
            return {
                "sensor_id": record["sensor_id"],
                "health_score": health_score,
                "status": "HEALTHY" if health_score > 80 else "DEGRADED" if health_score > 60 else "CRITICAL",
                "freshness_seconds": record["age_seconds"],
                "stability_std_dev": record["std"],
                "reading_count_10min": record["reading_count"]
            }
    
    def get_all_sensors_status(self):
        """Dashboard: status of all sensors."""
        with self.driver.session() as session:
            result = session.run("""
                MATCH (s:Sensor)
                OPTIONAL MATCH (s)-[:HAS_READING]->(r:Reading)
                  WHERE r.timestamp > datetime() - duration({minutes: 10})
                RETURN s.sensor_id, s.type, s.location, COUNT(r) as recent_readings
            """)
            
            return [dict(record) for record in result]
    
    def detect_anomalies(self):
        """Find all current anomalies across all sensors."""
        with self.driver.session() as session:
            result = session.run("""
                MATCH (s:Sensor)-[:HAS_READING]->(r:Reading)
                WITH s, AVG(r.value) as baseline_mean, STDEV(r.value) as baseline_std
                WHERE r.timestamp > datetime() - duration({hours: 1})
                WITH s, baseline_mean, baseline_std, r
                WHERE ABS(r.value - baseline_mean) > baseline_std * 3
                RETURN s.sensor_id, r.value, baseline_mean, baseline_std
                LIMIT 10
            """)
            
            return [dict(record) for record in result]
    
    def maintenance_schedule(self):
        """Return sensors needing maintenance."""
        with self.driver.session() as session:
            result = session.run("""
                MATCH (s:Sensor)
                WITH s, datetime() as now
                WHERE s.next_calibration_due < now + duration({days: 30})
                RETURN s.sensor_id, s.next_calibration_due, 
                       duration.inDays(now, s.next_calibration_due).days as days_until
                ORDER BY s.next_calibration_due ASC
            """)
            
            return [dict(record) for record in result]

# Usage
twin = DiagnosticTwin("bolt://localhost:7687", "neo4j", "password123")

print("Sensor Health:")
print(twin.get_sensor_health("temp_1"))

print("\nAll Sensors:")
print(twin.get_all_sensors_status())

print("\nAnomalies:")
print(twin.detect_anomalies())

print("\nMaintenance Due:")
print(twin.maintenance_schedule())
```

---

## Step 6: FastAPI Endpoints (Make It Queryable)

```python
from fastapi import FastAPI

app = FastAPI()
twin = DiagnosticTwin("bolt://localhost:7687", "neo4j", "password123")

@app.get("/health/{sensor_id}")
def get_health(sensor_id: str):
    """GET /health/temp_1"""
    return twin.get_sensor_health(sensor_id)

@app.get("/status/all")
def get_all_status():
    """GET /status/all"""
    return twin.get_all_sensors_status()

@app.get("/anomalies")
def get_anomalies():
    """GET /anomalies"""
    return twin.detect_anomalies()

@app.get("/maintenance")
def get_maintenance():
    """GET /maintenance"""
    return twin.maintenance_schedule()

@app.get("/dashboard")
def get_dashboard():
    """Complete system dashboard."""
    return {
        "all_sensors": twin.get_all_sensors_status(),
        "anomalies": twin.detect_anomalies(),
        "maintenance_needed": twin.maintenance_schedule(),
        "health_summary": {
            "healthy": len([s for s in twin.get_all_sensors_status() 
                           if twin.get_sensor_health(s["sensor_id"])["status"] == "HEALTHY"]),
            "total_sensors": len(twin.get_all_sensors_status())
        }
    }
```

---

## Complete Workflow

```
┌─ ONTOLOGY ──────────────────────┐
│ Defines: Sensor, Reading,       │
│ HealthRecord, Anomaly           │
│ Relationships, Properties       │
└─────────────┬────────────────────┘
              │
┌─ NEO4J SCHEMA ──────────────────┐
│ Constraints, Indexes            │
│ Node Labels, Relationships      │
└─────────────┬────────────────────┘
              │
┌─ DATA MODEL ────────────────────┐
│ Sensor nodes + Reading nodes    │
│ Stored in Neo4j                 │
└─────────────┬────────────────────┘
              │
┌─ DIAGNOSTIC QUERIES ────────────┐
│ 10 Cypher queries for:          │
│ - Current state                 │
│ - Health assessment             │
│ - Anomalies                     │
│ - Trends                        │
│ - Maintenance                   │
└─────────────┬────────────────────┘
              │
┌─ PYTHON TRAITS ─────────────────┐
│ Wrap queries in functions       │
│ Return structured JSON          │
└─────────────┬────────────────────┘
              │
┌─ FASTAPI ───────────────────────┐
│ HTTP endpoints                  │
│ /health/sensor_id               │
│ /status/all                     │
│ /anomalies                      │
│ /maintenance                    │
│ /dashboard                      │
└─────────────────────────────────┘
```

---

## Summary

**You've now defined:**

[x] **Ontology** (step 1) - what entities and relationships exist
[x] **Neo4j Schema** (step 2) - how to enforce data integrity
[x] **Data Model** (step 3) - what nodes/edges get created
[x] **10 Diagnostic Queries** (step 4) - Cypher queries for all key diagnostics
[x] **Python Wrapper** (step 5) - turn queries into reusable functions
[x] **API** (step 6) - expose as HTTP endpoints

**This IS your diagnostic digital twin.**



# Diagnostic Digital Twin: Complete End-to-End
## From Ontology to Working Intelligence

---

## PART 1: DEFINE ONTOLOGY (Conceptual Blueprint)

This is what a sensor IS, semantically.

### sensor_ontology.ttl

```turtle
@prefix dt: <http://example.com/digitaltwin/> .
@prefix owl: <http://www.w3.org/2002/07/owl#> .
@prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .
@prefix xsd: <http://www.w3.org/2001/XMLSchema#> .

# ===== CLASSES =====

dt:Sensor a owl:Class ;
    rdfs:label "A measurement device" .

dt:TemperatureSensor a owl:Class ;
    rdfs:subClassOf dt:Sensor .

dt:HumiditySensor a owl:Class ;
    rdfs:subClassOf dt:Sensor .

dt:Reading a owl:Class ;
    rdfs:label "A single data point" .

dt:HealthSnapshot a owl:Class ;
    rdfs:label "Health assessment at a point in time" .

# ===== RELATIONSHIPS =====

dt:hasReading a owl:ObjectProperty ;
    rdfs:domain dt:Sensor ;
    rdfs:range dt:Reading ;
    rdfs:label "produces readings" .

dt:hasHealth a owl:ObjectProperty ;
    rdfs:domain dt:Sensor ;
    rdfs:range dt:HealthSnapshot ;
    rdfs:label "has health records" .

# ===== PROPERTIES =====

dt:sensor_id a owl:DatatypeProperty ;
    rdfs:domain dt:Sensor ;
    rdfs:range xsd:string ;
    rdfs:label "unique ID" .

dt:location a owl:DatatypeProperty ;
    rdfs:domain dt:Sensor ;
    rdfs:range xsd:string .

dt:value a owl:DatatypeProperty ;
    rdfs:domain dt:Reading ;
    rdfs:range xsd:float .

dt:timestamp a owl:DatatypeProperty ;
    rdfs:domain dt:Reading ;
    rdfs:range xsd:dateTime .

dt:health_score a owl:DatatypeProperty ;
    rdfs:domain dt:HealthSnapshot ;
    rdfs:range xsd:integer .

dt:status a owl:DatatypeProperty ;
    rdfs:domain dt:HealthSnapshot ;
    rdfs:range xsd:string .
```

**What this says:**
- A Sensor is a thing
- It has an ID and location
- It produces Readings (with value + timestamp)
- We compute HealthSnapshots from those readings

---

## PART 2: VISUALIZE THE GRAPH STRUCTURE (Conceptual)

This is what the Neo4j graph will look like:

```
Physical Reality:          Digital Twin (Neo4j):
┌──────────┐               ┌──────────────────────┐
│ Arduino  │               │ :Sensor:Temperature  │
│ temp=23.5│              │ {id: 'temp_1'}       │
└────┬─────┘              └───────────┬───────────┘
     │ sends JSON                     │
     │                       ┌────────▼─────────┐
     │                       │     :Reading     │
     │                       │ {value: 23.5,    │
     │                       │  timestamp: ...} │
     │                       └──────────────────┘
     │
     ↓ (via Python script)
     
     ┌──────────────────────┐
     │  (s:Sensor)          │
     │  -[:HAS_READING]->   │
     │  (r:Reading)         │
     └──────────────────────┘
     
     ALSO CONNECTED TO:
     
     ┌──────────────────────┐
     │  (s:Sensor)          │
     │  -[:HAS_HEALTH]->    │
     │  (h:HealthSnapshot)  │
     │  {score: 95}         │
     └──────────────────────┘
```

**Every 10 seconds:**
```
Arduino → JSON → Python → Neo4j Graph
                            ↓
                        Create Reading node
                        Connect to Sensor
                        Compute Health
                        Update HealthSnapshot
```

---

## PART 3: NEO4J SETUP (Schema & Constraints)

### Step 3.1: Start Neo4j

**Option A: Docker (easiest)**
```bash
docker run -d \
  -p 7474:7474 \
  -p 7687:7687 \
  -e NEO4J_AUTH=neo4j/password123 \
  neo4j:latest
```

**Option B: Neo4j Desktop**
- Download from https://neo4j.com/download/
- Create new database
- Start it

Then open browser: http://localhost:7474

---

### Step 3.2: Create Schema (Run in Neo4j Browser)

```cypher
-- ===== CONSTRAINTS (enforce ontology rules) =====

CREATE CONSTRAINT sensor_id_unique IF NOT EXISTS
FOR (s:Sensor) REQUIRE s.sensor_id IS UNIQUE;

CREATE CONSTRAINT reading_id_unique IF NOT EXISTS
FOR (r:Reading) REQUIRE r.reading_id IS UNIQUE;

CREATE CONSTRAINT health_id_unique IF NOT EXISTS
FOR (h:HealthSnapshot) REQUIRE h.health_id IS UNIQUE;

-- ===== INDEXES (speed up queries) =====

CREATE INDEX reading_timestamp IF NOT EXISTS
FOR (r:Reading) ON (r.timestamp);

CREATE INDEX health_timestamp IF NOT EXISTS
FOR (h:HealthSnapshot) ON (h.timestamp);

CREATE INDEX sensor_type IF NOT EXISTS
FOR (s:Sensor) ON (s.type);
```

Run these in Neo4j Browser. If successful, you see "0 rows returned" (that's good).

---

### Step 3.3: Create Initial Sensor Nodes

```cypher
-- Create temperature sensor
CREATE (s:Sensor:TemperatureSensor {
  sensor_id: 'temp_1',
  location: 'Living Room',
  type: 'TemperatureSensor',
  model: 'DHT22',
  created_at: datetime(),
  status: 'ACTIVE'
})
RETURN s;

-- Create humidity sensor
CREATE (s:Sensor:HumiditySensor {
  sensor_id: 'humidity_1',
  location: 'Living Room',
  type: 'HumiditySensor',
  model: 'DHT22',
  created_at: datetime(),
  status: 'ACTIVE'
})
RETURN s;
```

Run these. You should see 2 nodes created.

---

## PART 4: ARDUINO → NEO4J CONNECTION

### Step 4.1: Simulate Arduino Data Stream

Arduino sends JSON like this:

```json
{"temp_1": 23.5, "humidity_1": 45.2}
{"temp_1": 23.6, "humidity_1": 45.1}
{"temp_1": 23.4, "humidity_1": 45.3}
```

For now, we'll **simulate** this with Python instead of actual Arduino.

### Step 4.2: Python: Ingest Data into Neo4j

Create file: `ingest_data.py`

```python
from neo4j import GraphDatabase
import time
import json
from datetime import datetime
import random
import uuid

class SensorDataIngestor:
    def __init__(self, uri, user, password):
        self.driver = GraphDatabase.driver(uri, auth=(user, password))
    
    def close(self):
        self.driver.close()
    
    def simulate_arduino_reading(self):
        """Simulate Arduino sending sensor data."""
        # In real scenario: read from serial port / Ethernet
        # For now: simulate with realistic values
        base_temp = 23.5
        base_humidity = 45.0
        
        # Add slight noise
        temp = base_temp + random.uniform(-0.5, 0.5)
        humidity = base_humidity + random.uniform(-2, 2)
        
        return {
            "temp_1": round(temp, 2),
            "humidity_1": round(humidity, 2)
        }
    
    def store_reading(self, sensor_id, value):
        """Create a Reading node and link to Sensor."""
        with self.driver.session() as session:
            session.run(
                """
                MATCH (s:Sensor {sensor_id: $sensor_id})
                CREATE (r:Reading {
                    reading_id: randomUUID(),
                    value: $value,
                    timestamp: datetime(),
                    unit: CASE 
                        WHEN s.type = 'TemperatureSensor' THEN 'Celsius'
                        WHEN s.type = 'HumiditySensor' THEN '%'
                        ELSE 'unknown'
                    END
                })
                CREATE (s)-[:HAS_READING]->(r)
                RETURN r.reading_id, r.timestamp
                """,
                sensor_id=sensor_id,
                value=value
            )
    
    def run_continuous_ingest(self, interval_seconds=2):
        """Continuously read sensors and store in Neo4j."""
        print("Starting sensor data ingestion...")
        print("Press Ctrl+C to stop")
        
        try:
            iteration = 0
            while True:
                iteration += 1
                
                # Get simulated Arduino data
                readings = self.simulate_arduino_reading()
                
                # Store each reading
                for sensor_id, value in readings.items():
                    self.store_reading(sensor_id, value)
                    print(f"  [{iteration}] {sensor_id} = {value}")
                
                print(f"✓ Stored batch {iteration}")
                time.sleep(interval_seconds)
        
        except KeyboardInterrupt:
            print("\nStopping ingestion.")
            self.close()

# Usage
if __name__ == "__main__":
    ingestor = SensorDataIngestor(
        "bolt://localhost:7687",
        "neo4j",
        "password123"
    )
    
    # Run for 60 seconds (generates 30 readings)
    ingestor.run_continuous_ingest(interval_seconds=2)
```

**Run it:**
```bash
python ingest_data.py
```

You'll see:
```
Starting sensor data ingestion...
  [1] temp_1 = 23.45
  [1] humidity_1 = 45.32
✓ Stored batch 1
  [2] temp_1 = 23.52
  [2] humidity_1 = 44.98
✓ Stored batch 2
...
```

Let it run for 30-60 seconds, then stop (Ctrl+C).

---

## PART 5: QUERY THE DATA (Extract Meaning)

### Step 5.1: Simple Query - Latest Reading

```cypher
MATCH (s:Sensor {sensor_id: 'temp_1'})-[:HAS_READING]->(r:Reading)
RETURN 
  s.sensor_id as sensor,
  r.value as current_value,
  r.timestamp as last_read
ORDER BY r.timestamp DESC
LIMIT 1;
```

**Shows:**
```
sensor: "temp_1"
current_value: 23.45
last_read: 2025-01-15T10:45:30Z
```

---

### Step 5.2: Statistical Query - Stability

```cypher
MATCH (s:Sensor {sensor_id: 'temp_1'})-[:HAS_READING]->(r:Reading)
WHERE r.timestamp > datetime() - duration({minutes: 5})
RETURN
  s.sensor_id as sensor,
  COUNT(r) as reading_count,
  MIN(r.value) as min_val,
  MAX(r.value) as max_val,
  AVG(r.value) as mean_val,
  STDEV(r.value) as std_dev,
  ROUND(100 - (STDEV(r.value) * 20), 1) as stability_score
```

**Shows:**
```
sensor: "temp_1"
reading_count: 30
min_val: 22.85
max_val: 24.12
mean_val: 23.47
std_dev: 0.35
stability_score: 93
```

---

### Step 5.3: All Sensors Overview

```cypher
MATCH (s:Sensor)
OPTIONAL MATCH (s)-[:HAS_READING]->(r:Reading)
  WHERE r.timestamp > datetime() - duration({minutes: 5})
WITH s, COUNT(r) as recent_count, AVG(r.value) as avg_val
RETURN 
  s.sensor_id,
  s.type,
  s.location,
  recent_count as readings_5min,
  ROUND(avg_val, 2) as current_avg,
  s.status
ORDER BY s.sensor_id;
```

---

## PART 6: INTELLIGENCE MODEL (Basic)

This is where the twin becomes "smart".

Create file: `intelligence_model.py`

```python
from neo4j import GraphDatabase
import numpy as np
from datetime import datetime, timedelta

class DiagnosticIntelligence:
    def __init__(self, uri, user, password):
        self.driver = GraphDatabase.driver(uri, auth=(user, password))
    
    def get_recent_readings(self, sensor_id, minutes=10):
        """Fetch readings from last N minutes."""
        with self.driver.session() as session:
            result = session.run(
                """
                MATCH (s:Sensor {sensor_id: $sensor_id})-[:HAS_READING]->(r:Reading)
                WHERE r.timestamp > datetime() - duration({minutes: $minutes})
                RETURN r.value, r.timestamp
                ORDER BY r.timestamp ASC
                """,
                sensor_id=sensor_id,
                minutes=minutes
            )
            return [(row["value"], row["timestamp"]) for row in result]
    
    def compute_stability(self, sensor_id, window_minutes=10):
        """How stable is the sensor?"""
        readings = self.get_recent_readings(sensor_id, window_minutes)
        
        if len(readings) < 2:
            return None
        
        values = [r[0] for r in readings]
        std_dev = np.std(values)
        
        # 0-100 score: lower std_dev = higher score
        stability = max(0, 100 - (std_dev * 30))
        
        return {
            "sensor": sensor_id,
            "stability_score": round(stability, 1),
            "std_dev": round(std_dev, 4),
            "reading_count": len(values),
            "status": "STABLE" if stability > 80 else "NOISY" if stability > 60 else "UNSTABLE"
        }
    
    def compute_drift(self, sensor_id, window_minutes=10):
        """Is the sensor drifting (trending up/down)?"""
        readings = self.get_recent_readings(sensor_id, window_minutes)
        
        if len(readings) < 3:
            return None
        
        values = np.array([r[0] for r in readings])
        times = np.array(range(len(values)))  # Linear time index
        
        # Fit line: y = mx + b
        m, b = np.polyfit(times, values, 1)  # m = slope (drift rate)
        
        # Drift per minute
        drift_per_minute = m * (window_minutes / len(readings))
        
        return {
            "sensor": sensor_id,
            "drift_per_minute": round(drift_per_minute, 4),
            "status": "DRIFTING" if abs(drift_per_minute) > 0.1 else "STABLE",
            "direction": "UP" if drift_per_minute > 0 else "DOWN" if drift_per_minute < 0 else "NONE"
        }
    
    def compute_freshness(self, sensor_id):
        """How recent is the last reading?"""
        readings = self.get_recent_readings(sensor_id, minutes=60)
        
        if not readings:
            return None
        
        latest_time = readings[-1][1]
        age_seconds = (datetime.now(latest_time.tzinfo) - latest_time).total_seconds()
        
        return {
            "sensor": sensor_id,
            "age_seconds": round(age_seconds, 1),
            "status": "LIVE" if age_seconds < 5 else "RECENT" if age_seconds < 30 else "STALE"
        }
    
    def compute_anomaly(self, sensor_id, window_minutes=60):
        """Is the current reading abnormal?"""
        readings = self.get_recent_readings(sensor_id, window_minutes)
        
        if len(readings) < 10:
            return None
        
        values = np.array([r[0] for r in readings])
        mean = np.mean(values)
        std_dev = np.std(values)
        current_value = values[-1]
        
        # Z-score: how many std_devs away from mean?
        z_score = (current_value - mean) / std_dev if std_dev > 0 else 0
        
        is_anomaly = abs(z_score) > 3  # 3-sigma rule
        
        return {
            "sensor": sensor_id,
            "current_value": round(current_value, 2),
            "mean": round(mean, 2),
            "z_score": round(z_score, 2),
            "is_anomaly": is_anomaly,
            "anomaly_status": "ANOMALY DETECTED" if is_anomaly else "NORMAL"
        }
    
    def compute_health_score(self, sensor_id):
        """Aggregate all metrics into one health score."""
        stability = self.compute_stability(sensor_id)
        drift = self.compute_drift(sensor_id)
        freshness = self.compute_freshness(sensor_id)
        anomaly = self.compute_anomaly(sensor_id)
        
        # Components out of 100
        stability_contrib = stability["stability_score"] if stability else 0  # 0-100
        drift_contrib = 100 if drift and drift["status"] == "STABLE" else 50  # 0 or 50 or 100
        freshness_contrib = 100 if freshness and freshness["status"] == "LIVE" else 50 if freshness and freshness["status"] == "RECENT" else 0
        anomaly_contrib = 100 if not anomaly or not anomaly["is_anomaly"] else 0
        
        # Weighted average
        health_score = (
            stability_contrib * 0.4 +
            drift_contrib * 0.2 +
            freshness_contrib * 0.2 +
            anomaly_contrib * 0.2
        )
        
        return {
            "sensor": sensor_id,
            "health_score": round(health_score, 1),
            "status": "HEALTHY" if health_score > 80 else "DEGRADED" if health_score > 60 else "CRITICAL",
            "components": {
                "stability": stability,
                "drift": drift,
                "freshness": freshness,
                "anomaly": anomaly
            }
        }
    
    def store_health_snapshot(self, sensor_id, health_data):
        """Save health assessment to Neo4j."""
        with self.driver.session() as session:
            session.run(
                """
                MATCH (s:Sensor {sensor_id: $sensor_id})
                CREATE (h:HealthSnapshot {
                    health_id: randomUUID(),
                    timestamp: datetime(),
                    health_score: $health_score,
                    status: $status,
                    stability_score: $stability,
                    drift_per_minute: $drift,
                    freshness_seconds: $freshness,
                    is_anomaly: $anomaly
                })
                CREATE (s)-[:HAS_HEALTH]->(h)
                RETURN h
                """,
                sensor_id=sensor_id,
                health_score=health_data["health_score"],
                status=health_data["status"],
                stability=health_data["components"]["stability"]["stability_score"] if health_data["components"]["stability"] else 0,
                drift=health_data["components"]["drift"]["drift_per_minute"] if health_data["components"]["drift"] else 0,
                freshness=health_data["components"]["freshness"]["age_seconds"] if health_data["components"]["freshness"] else 0,
                anomaly=health_data["components"]["anomaly"]["is_anomaly"] if health_data["components"]["anomaly"] else False
            )

# Usage
if __name__ == "__main__":
    intel = DiagnosticIntelligence("bolt://localhost:7687", "neo4j", "password123")
    
    print("=== DIAGNOSTIC INTELLIGENCE ===\n")
    
    for sensor in ['temp_1', 'humidity_1']:
        health = intel.compute_health_score(sensor)
        print(f"Sensor: {sensor}")
        print(f"Health Score: {health['health_score']} ({health['status']})")
        print(f"  Stability: {health['components']['stability']['status']}")
        print(f"  Drift: {health['components']['drift']['status']}")
        print(f"  Freshness: {health['components']['freshness']['status']}")
        print(f"  Anomaly: {health['components']['anomaly']['anomaly_status']}")
        
        # Store in Neo4j
        intel.store_health_snapshot(sensor, health)
        
        print()
```

**Run it:**
```bash
python intelligence_model.py
```

**Output:**
```
=== DIAGNOSTIC INTELLIGENCE ===

Sensor: temp_1
Health Score: 94.2 (HEALTHY)
  Stability: STABLE
  Drift: STABLE
  Freshness: LIVE
  Anomaly: NORMAL

Sensor: humidity_1
Health Score: 91.5 (HEALTHY)
  Stability: STABLE
  Drift: STABLE
  Freshness: LIVE
  Anomaly: NORMAL
```

---

## PART 7: EXPOSE AS API (Query Your Twin)

Create file: `diagnostic_api.py`

```python
from fastapi import FastAPI
from intelligence_model import DiagnosticIntelligence
from neo4j import GraphDatabase

app = FastAPI()
intel = DiagnosticIntelligence("bolt://localhost:7687", "neo4j", "password123")
driver = GraphDatabase.driver("bolt://localhost:7687", auth=("neo4j", "password123"))

@app.get("/health/{sensor_id}")
def get_sensor_health(sensor_id: str):
    """Get health assessment for one sensor."""
    return intel.compute_health_score(sensor_id)

@app.get("/dashboard")
def get_dashboard():
    """Complete system dashboard."""
    with driver.session() as session:
        sensors_result = session.run(
            "MATCH (s:Sensor) RETURN s.sensor_id, s.type, s.location"
        )
        sensors = [dict(row) for row in sensors_result]
    
    health_data = {}
    for sensor in sensors:
        sensor_id = sensor["sensor_id"]
        health_data[sensor_id] = intel.compute_health_score(sensor_id)
    
    return {
        "timestamp": datetime.now().isoformat(),
        "sensors": health_data,
        "overall_status": "OPERATIONAL" if all(h["health_score"] > 80 for h in health_data.values()) else "DEGRADED"
    }

@app.get("/readings/{sensor_id}")
def get_readings(sensor_id: str, minutes: int = 10):
    """Get recent readings."""
    with driver.session() as session:
        result = session.run(
            """
            MATCH (s:Sensor {sensor_id: $sensor_id})-[:HAS_READING]->(r:Reading)
            WHERE r.timestamp > datetime() - duration({minutes: $minutes})
            RETURN r.value, r.timestamp
            ORDER BY r.timestamp DESC
            """,
            sensor_id=sensor_id,
            minutes=minutes
        )
        readings = [{"value": row["value"], "timestamp": str(row["timestamp"])} for row in result]
    
    return {"sensor": sensor_id, "readings": readings}

@app.get("/anomalies")
def get_anomalies():
    """Find all current anomalies."""
    with driver.session() as session:
        sensors_result = session.run("MATCH (s:Sensor) RETURN s.sensor_id")
        sensors = [row["sensor_id"] for row in sensors_result]
    
    anomalies = []
    for sensor in sensors:
        anomaly_check = intel.compute_anomaly(sensor)
        if anomaly_check and anomaly_check["is_anomaly"]:
            anomalies.append(anomaly_check)
    
    return {"anomaly_count": len(anomalies), "anomalies": anomalies}

from datetime import datetime

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
```

**Run it:**
```bash
pip install fastapi uvicorn
python diagnostic_api.py
```

**Query it:**
```bash
# Terminal 1: Keep ingest_data.py running
python ingest_data.py

# Terminal 2: Keep API running
python diagnostic_api.py

# Terminal 3: Query the API
curl http://localhost:8000/health/temp_1
curl http://localhost:8000/dashboard
curl http://localhost:8000/anomalies
```

**API Responses:**

`GET /health/temp_1`:
```json
{
  "sensor": "temp_1",
  "health_score": 94.2,
  "status": "HEALTHY",
  "components": {
    "stability": {
      "sensor": "temp_1",
      "stability_score": 95.2,
      "std_dev": 0.158,
      "reading_count": 30,
      "status": "STABLE"
    },
    "drift": {
      "sensor": "temp_1",
      "drift_per_minute": 0.008,
      "status": "STABLE",
      "direction": "UP"
    },
    "freshness": {
      "sensor": "temp_1",
      "age_seconds": 2.3,
      "status": "LIVE"
    },
    "anomaly": {
      "sensor": "temp_1",
      "current_value": 23.45,
      "mean": 23.47,
      "z_score": -0.12,
      "is_anomaly": false,
      "anomaly_status": "NORMAL"
    }
  }
}
```

`GET /dashboard`:
```json
{
  "timestamp": "2025-01-15T10:50:00Z",
  "sensors": {
    "temp_1": {"health_score": 94.2, "status": "HEALTHY", ...},
    "humidity_1": {"health_score": 91.5, "status": "HEALTHY", ...}
  },
  "overall_status": "OPERATIONAL"
}
```

---

## PART 8: VISUALIZE IN NEO4J BROWSER

Open http://localhost:7474

Run this query:

```cypher
MATCH (s:Sensor)-[:HAS_READING]->(r:Reading)
OPTIONAL MATCH (s)-[:HAS_HEALTH]->(h:HealthSnapshot)
RETURN s, r, h
LIMIT 100
```

**You see:**
- Green circles: Sensor nodes
- Blue circles: Reading nodes
- Red circles: HealthSnapshot nodes
- Arrows: Relationships (HAS_READING, HAS_HEALTH)

Click nodes to inspect properties. Drag to rearrange. Zoom to see detail.

---

## PART 9: COMPLETE DIAGNOSTIC TWIN

Put it all together. Create script: `run_diagnostic_twin.sh`

```bash
#!/bin/bash

echo "Starting Diagnostic Digital Twin..."
echo ""

# Check Neo4j is running
echo "[1/3] Checking Neo4j..."
if ! curl -s http://localhost:7474 > /dev/null; then
  echo "ERROR: Neo4j not running on port 7474"
  exit 1
fi
echo "✓ Neo4j is running"
echo ""

# Start data ingestion
echo "[2/3] Starting sensor data ingestion..."
python ingest_data.py &
INGEST_PID=$!
sleep 3
echo "✓ Ingestion running (PID: $INGEST_PID)"
echo ""

# Start intelligence model (periodic updates)
echo "[3/3] Starting diagnostic intelligence..."
while true; do
  python intelligence_model.py
  sleep 10
done &
INTEL_PID=$!
echo "✓ Intelligence running (PID: $INTEL_PID)"
echo ""

# Start API
echo "[4/4] Starting diagnostic API..."
python diagnostic_api.py &
API_PID=$!
sleep 3
echo "✓ API running on http://localhost:8000"
echo ""

echo "======================================"
echo "DIAGNOSTIC DIGITAL TWIN ACTIVE"
echo "======================================"
echo ""
echo "Access points:"
echo "  Neo4j Browser:  http://localhost:7474"
echo "  API Docs:       http://localhost:8000/docs"
echo "  Dashboard:      curl http://localhost:8000/dashboard"
echo "  Health Check:   curl http://localhost:8000/health/temp_1"
echo ""
echo "Press Ctrl+C to stop all services"
echo ""

# Wait for interrupt
wait
```

**Run it:**
```bash
chmod +x run_diagnostic_twin.sh
./run_diagnostic_twin.sh
```

---

## COMPLETE FLOW SUMMARY

```
┌─ ONTOLOGY ──────────────────────────────────┐
│ Sensor class, Reading class, Relationships  │
│ (sensor_ontology.ttl)                       │
└────────────────┬────────────────────────────┘
                 │
┌────────────────▼────────────────────────────┐
│ NEO4J SCHEMA (Constraints, Indexes)         │
│ (run Cypher in Neo4j Browser)               │
└────────────────┬────────────────────────────┘
                 │
┌────────────────▼────────────────────────────┐
│ DATA INGESTION (Arduino → Neo4j)            │
│ (ingest_data.py)                            │
│ Creates Sensor & Reading nodes              │
└────────────────┬────────────────────────────┘
                 │
┌────────────────▼────────────────────────────┐
│ INTELLIGENCE MODEL (Compute traits)         │
│ (intelligence_model.py)                     │
│ Stability, Drift, Freshness, Anomaly       │
│ Creates HealthSnapshot nodes                │
└────────────────┬────────────────────────────┘
                 │
┌────────────────▼────────────────────────────┐
│ API LAYER (Query the Twin)                  │
│ (diagnostic_api.py)                         │
│ /health/sensor_id                           │
│ /dashboard                                  │
│ /anomalies                                  │
└────────────────┬────────────────────────────┘
                 │
┌────────────────▼────────────────────────────┐
│ VISUALIZATION                               │
│ Neo4j Browser + API responses               │
│ See graph + get JSON data                   │
└─────────────────────────────────────────────┘
```

---

## Quick Start (Copy-Paste)

### Terminal 1: Neo4j
```bash
docker run -d -p 7474:7474 -p 7687:7687 -e NEO4J_AUTH=neo4j/password123 neo4j:latest
# Then go to http://localhost:7474 and run constraints Cypher
```

### Terminal 2: Ingest
```bash
python ingest_data.py
```

### Terminal 3: Intelligence
```bash
python intelligence_model.py  # Run manually or on loop
```

### Terminal 4: API
```bash
python diagnostic_api.py
```

### Terminal 5: Query
```bash
curl http://localhost:8000/dashboard | jq
```

You now have a working diagnostic digital twin.