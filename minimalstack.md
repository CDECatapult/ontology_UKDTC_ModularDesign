# Digital Twin: Minimal Stack
## From Your Arduino/Pi Sensors to Queryable Twin

---

## What You Have
```
Arduino UNO4
  ├─ I2C Shield
  ├─ Ethernet Shield
  └─ 6 Sensors (temp, humidity, pressure, ultrasonic, 2x temp)

Raspberry Pi 5
  ├─ Grove I2C Shield
  └─ Same 6 Sensors
```

---

## What You Need (Checklist)

### [x] Layer 1: Data Collection (You Build)
- **Arduino sketch** (C++) - Read sensors via I2C, send to Pi over ethernet
- **Pi script** (Python) - Poll Arduino, collect data, timestamp it
- **Format:** JSON (easy to convert to RDF later)

### [x] Layer 2: Semantic Model (You Define)
- **Ontology schema** (OWL, ~100 lines) - Define what a temp sensor IS, relationships
- **JSON-LD contexts** - Map sensor readings to ontology classes

### [x] Layer 3: Storage (You Choose One)
- **Option A (Simplest): RDFLib** (Python library) - In-memory RDF store, SPARQL support, no server needed
- **Option B (Better for scale): Jena Fuseki** (Java server) - Persistent triple store, separate process, robust
- **Option C (Hybrid): TinyDB** + JSON-LD - File-based, semi-structured, good for prototyping

### [x] Layer 4: Reasoning Engine (Built-in to your choice)
- RDFLib → SPARQL queries in Python
- Jena Fuseki → SPARQL HTTP endpoint
- TinyDB → Custom Python query logic

### [x] Layer 5: Trait Computation (You Build)
- Python functions that query ontology, compute derived traits
- Example: "sensor_stability = std_dev(last_100_readings)"

### [x] Layer 6: API (You Build)
- Python FastAPI wrapper - expose queries via HTTP
- Later: add Rust for performance-critical pieces

---

## Minimal Viable Setup

**Install these:**

```bash
# Python libraries (run on Pi)
pip install rdflib sparqlwrapper pydantic fastapi uvicorn

# Optional: Jena Fuseki (if you want separate store)
# Download from: https://jena.apache.org/download/
# For now: skip it, use RDFLib in-memory
```

**That's it.** No Gazebo, no Docker complexity, no cloud.

---

## Architecture Diagram

```
┌──────────────────────┐
│   Arduino UNO4       │
│  ┌────────────────┐  │
│  │ 6 Sensors      │  │
│  │ (temp, humid..)│  │
│  └────────────────┘  │
└──────────────┬───────┘
               │ (Ethernet: raw JSON)
               │
┌──────────────▼──────────────────────┐
│     Raspberry Pi 5                   │
│  ┌────────────────────────────────┐ │
│  │ Python Data Collection Script  │ │
│  │  - Poll Arduino every 1s       │ │
│  │  - Timestamp readings          │ │
│  │  - Convert to JSON             │ │
│  └────────────────┬───────────────┘ │
│                   │                  │
│  ┌────────────────▼───────────────┐ │
│  │ RDFLib Triple Store (in-memory)│ │
│  │  - Instantiate ontology        │ │
│  │  - Store sensor readings       │ │
│  │  - SPARQL query interface      │ │
│  └────────────────┬───────────────┘ │
│                   │                  │
│  ┌────────────────▼───────────────┐ │
│  │ Trait Computation Layer        │ │
│  │  - Query ontology              │ │
│  │  - Compute: stability, drift   │ │
│  │  - Cache results               │ │
│  └────────────────┬───────────────┘ │
│                   │                  │
│  ┌────────────────▼───────────────┐ │
│  │ FastAPI HTTP Interface         │ │
│  │  - GET /sensors/current        │ │
│  │  - GET /traits/stability       │ │
│  │  - POST /query (SPARQL)        │ │
│  └────────────────────────────────┘ │
└─────────────────────────────────────┘
         │
         └─→ Your laptop/dashboard
              (query the twin)
```

---

## Step-by-Step Build Path

### Phase 1: Data Collection (Week 1)
1. Arduino sketch reads I2C sensors, sends JSON over Ethernet
2. Python script on Pi receives, stores as `readings.json`
3. Verify: can see temperature readings updating every second

### Phase 2: Ontology Definition (Week 1)
1. Write minimal OWL schema (~50 lines)
   - Class: TemperatureSensor
   - Property: hasReading (value in Celsius)
   - Property: location (sensor position)
   - Property: lastUpdateTime
2. Save as `sensor_ontology.ttl`

### Phase 3: RDF Storage (Week 1)
1. Load ontology into RDFLib
2. For each sensor reading, create RDF triple:
   ```
   <sensor/temp_1> rdf:type <TemperatureSensor>
   <sensor/temp_1> <hasReading> 23.5
   <sensor/temp_1> <lastUpdateTime> "2025-01-15T10:30:45Z"
   ```
3. Query: "Show me all temperature readings in last 60 seconds"

### Phase 4: Trait Computation (Week 2)
1. Implement 3-4 traits:
   - **Sensor_Stability**: std_dev of readings (low = stable, high = noisy)
   - **Sensor_Drift**: slope of readings over time (drifting if slope > 0.1°C/min)
   - **Data_Freshness**: time since last reading (should be < 5s)
   - **Environmental_State**: is temp/humidity in normal range?
2. Queries return: "temp_sensor_1 is STABLE (drift 0.01°C/min)"

### Phase 5: API Wrapper (Week 2)
1. FastAPI endpoint: `GET /traits/sensor_stability`
   - Returns: `{"sensor_1": "stable", "sensor_2": "drifting", ...}`
2. Endpoint: `GET /ontology/query?sparql=...`
   - Execute arbitrary SPARQL queries

---

## Sample Code (Minimal Example)

### 1. Arduino Sketch (C++)
```cpp
#include <Wire.h>
#include <Ethernet.h>

// Simulate sensor reading (replace with real I2C reads)
float readTemperature() {
  return 20.0 + (random(-10, 10) / 100.0);  // 20°C ± 0.1
}

void setup() {
  Serial.begin(9600);
  Wire.begin();
  Ethernet.begin(mac);
}

void loop() {
  float temp1 = readTemperature();
  float temp2 = readTemperature();
  
  // Send JSON to Pi over ethernet
  EthernetClient client;
  if (client.connect(pi_ip, 8000)) {
    client.print("{\"temp_1\":");
    client.print(temp1);
    client.print(",\"temp_2\":");
    client.print(temp2);
    client.println("}");
    client.stop();
  }
  
  delay(1000);  // Send every 1 second
}
```

### 2. Pi Data Collection (Python)
```python
import socket
import json
from datetime import datetime
import rdflib
from rdflib.namespace import RDF, RDFS

# Load ontology
g = rdflib.Graph()
g.parse("sensor_ontology.ttl", format="ttl")

# Define namespace
SENS = rdflib.Namespace("http://example.com/sensors/")

def collect_sensor_data():
    """Listen for Arduino data, store in RDF graph."""
    server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server.bind(("0.0.0.0", 8000))
    server.listen(1)
    
    while True:
        conn, addr = server.accept()
        data = conn.recv(1024).decode()
        readings = json.loads(data)
        
        # Add to RDF graph
        timestamp = datetime.now().isoformat()
        
        for sensor_name, value in readings.items():
            sensor_uri = SENS[sensor_name]
            
            # Create RDF triples
            g.add((sensor_uri, RDF.type, SENS.TemperatureSensor))
            g.add((sensor_uri, SENS.hasReading, rdflib.Literal(value)))
            g.add((sensor_uri, SENS.lastUpdateTime, rdflib.Literal(timestamp)))
        
        conn.close()

if __name__ == "__main__":
    collect_sensor_data()
```

### 3. Ontology Schema (OWL)
```turtle
@prefix sens: <http://example.com/sensors/> .
@prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
@prefix owl: <http://www.w3.org/2002/07/owl#> .
@prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .

# Classes
sens:Sensor a owl:Class .
sens:TemperatureSensor a owl:Class ;
    rdfs:subClassOf sens:Sensor .
sens:HumiditySensor a owl:Class ;
    rdfs:subClassOf sens:Sensor .

# Properties
sens:hasReading a owl:DatatypeProperty ;
    rdfs:domain sens:Sensor ;
    rdfs:range xsd:float .

sens:location a owl:DatatypeProperty ;
    rdfs:domain sens:Sensor ;
    rdfs:range xsd:string .

sens:lastUpdateTime a owl:DatatypeProperty ;
    rdfs:domain sens:Sensor ;
    rdfs:range xsd:dateTime .
```

### 4. Trait Computation (Python)
```python
import numpy as np
from datetime import datetime, timedelta

class TraitComputer:
    def __init__(self, rdf_graph):
        self.g = rdf_graph
    
    def compute_stability(self, sensor_uri, window_seconds=60):
        """Calculate stability as inverse of std_dev."""
        query = f"""
        SELECT ?value ?time
        WHERE {{
            <{sensor_uri}> <http://example.com/sensors/hasReading> ?value .
            <{sensor_uri}> <http://example.com/sensors/lastUpdateTime> ?time .
            FILTER(?time > NOW() - PT{window_seconds}S)
        }}
        ORDER BY ?time
        """
        
        results = self.g.query(query)
        values = [float(row[0]) for row in results]
        
        if len(values) < 2:
            return None
        
        std_dev = np.std(values)
        stability = 100 - min(std_dev * 10, 100)  # Scale to 0-100
        
        return {
            "sensor": str(sensor_uri),
            "stability_percent": stability,
            "reading_count": len(values),
            "std_dev": std_dev
        }
    
    def compute_drift(self, sensor_uri, window_seconds=300):
        """Calculate drift as slope of readings."""
        query = f"""
        SELECT ?value ?time
        WHERE {{
            <{sensor_uri}> <http://example.com/sensors/hasReading> ?value .
            <{sensor_uri}> <http://example.com/sensors/lastUpdateTime> ?time .
            FILTER(?time > NOW() - PT{window_seconds}S)
        }}
        ORDER BY ?time
        """
        
        results = self.g.query(query)
        if len(results) < 2:
            return None
        
        times = [datetime.fromisoformat(str(row[1])) for row in results]
        values = [float(row[0]) for row in results]
        
        # Linear regression: slope = drift rate
        x = np.array([(t - times[0]).total_seconds() for t in times])
        y = np.array(values)
        
        slope = np.polyfit(x, y, 1)[0]  # degrees per second
        drift_per_minute = slope * 60
        
        return {
            "sensor": str(sensor_uri),
            "drift_per_minute": drift_per_minute,
            "status": "DRIFTING" if abs(drift_per_minute) > 0.1 else "STABLE"
        }
    
    def compute_freshness(self, sensor_uri):
        """Check how old the last reading is."""
        query = f"""
        SELECT ?time
        WHERE {{
            <{sensor_uri}> <http://example.com/sensors/lastUpdateTime> ?time .
        }}
        ORDER BY DESC(?time)
        LIMIT 1
        """
        
        results = list(self.g.query(query))
        if not results:
            return None
        
        last_update = datetime.fromisoformat(str(results[0][0]))
        age_seconds = (datetime.now() - last_update).total_seconds()
        
        freshness = "FRESH" if age_seconds < 5 else "STALE"
        
        return {
            "sensor": str(sensor_uri),
            "age_seconds": age_seconds,
            "status": freshness
        }

# Usage
traits = TraitComputer(g)
print(traits.compute_stability("http://example.com/sensors/temp_1"))
print(traits.compute_drift("http://example.com/sensors/temp_1"))
print(traits.compute_freshness("http://example.com/sensors/temp_1"))
```

### 5. FastAPI Wrapper (Python)
```python
from fastapi import FastAPI
from rdflib import Graph

app = FastAPI()
g = Graph()
g.parse("sensor_ontology.ttl", format="ttl")
traits = TraitComputer(g)

@app.get("/traits/stability/{sensor_name}")
def get_stability(sensor_name: str):
    sensor_uri = f"http://example.com/sensors/{sensor_name}"
    return traits.compute_stability(sensor_uri)

@app.get("/traits/drift/{sensor_name}")
def get_drift(sensor_name: str):
    sensor_uri = f"http://example.com/sensors/{sensor_name}"
    return traits.compute_drift(sensor_uri)

@app.get("/traits/all")
def get_all_traits():
    """Return all traits for all sensors."""
    query = """
    SELECT ?sensor
    WHERE {
        ?sensor rdf:type <http://example.com/sensors/Sensor> .
    }
    """
    results = g.query(query)
    sensors = [str(row[0]) for row in results]
    
    all_traits = {}
    for sensor in sensors:
        all_traits[sensor] = {
            "stability": traits.compute_stability(sensor),
            "drift": traits.compute_drift(sensor),
            "freshness": traits.compute_freshness(sensor)
        }
    
    return all_traits

@app.post("/query")
def sparql_query(sparql_query: str):
    """Execute SPARQL query against ontology."""
    results = g.query(sparql_query)
    return [dict(row) for row in results]

# Run: uvicorn app:app --reload
```

---

## Testing It

```bash
# Terminal 1: Start data collection
python collect_sensor_data.py

# Terminal 2: Start API server
uvicorn app:app --reload

# Terminal 3: Query it
curl http://localhost:8000/traits/stability/temp_1
curl http://localhost:8000/traits/all
```

Example response:
```json
{
  "http://example.com/sensors/temp_1": {
    "stability": {
      "sensor": "http://example.com/sensors/temp_1",
      "stability_percent": 87.5,
      "reading_count": 60,
      "std_dev": 0.125
    },
    "drift": {
      "sensor": "http://example.com/sensors/temp_1",
      "drift_per_minute": 0.02,
      "status": "STABLE"
    },
    "freshness": {
      "sensor": "http://example.com/sensors/temp_1",
      "age_seconds": 1.3,
      "status": "FRESH"
    }
  }
}
```

---

## What This Gives You

[x] **Real working digital twin** - sensors → semantic model → trait queries

[x] **Queryable data model** - SPARQL: "Show me all unstable sensors"

[x] **Operational intelligence** - detect drift, stability, freshness automatically

[x] **Foundation for scale** - same architecture scales to 100 sensors, multiple Pi's, fleet of vehicles

[x] **Proof of concept** - show what digital twin actually *does* before building the UAV version

---

## Rust Opportunity

Once you have this working in Python, **rewrite the trait computation in Rust:**

```rust
// Compute stability efficiently
fn compute_stability(readings: &[f32]) -> f32 {
    let mean = readings.iter().sum::<f32>() / readings.len() as f32;
    let variance: f32 = readings.iter()
        .map(|v| (v - mean).powi(2))
        .sum::<f32>() / readings.len() as f32;
    
    let std_dev = variance.sqrt();
    100.0 - (std_dev * 10.0).min(100.0)
}
```

Expose via PyO3 so Python can call it. Rust handles the math, Python handles I/O.