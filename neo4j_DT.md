# Digital Twin with Neo4j + Visualization

---

## Short Answer

**Yes to both.**

[x] **Visualization**: Both RDFLib and Neo4j support it, but Neo4j is 10x better visually.

[x] **Neo4j**: YES, use it instead of RDFLib for this project. It's more practical.

---

## Why Neo4j Over RDFLib for Your Project

### RDFLib (Pure Semantic Web)
- Pros: True OWL reasoning, SPARQL queries, semantic web standard
- Cons: Ugly graphs, harder to visualize, not designed for real-time IoT
- Use when: You need strict semantic reasoning, academic rigor

### Neo4j (Property Graph Database)
- Pros: Beautiful built-in visualization, Cypher is easier, scales better, real-time performance
- Cons: Not "pure" semantic web, property graphs ≠ RDF triples
- Use when: You want practical operational system, real-time updates, nice dashboards

**For your IoT sensor twin: Neo4j is the right choice.**

The ontology concept (what-is-a sensor, relationships) still applies, but implementation is simpler and more usable.

---

## Architecture: Neo4j Version

```
┌──────────────────────┐
│   Arduino UNO4       │
│  ┌────────────────┐  │
│  │ 6 Sensors      │  │
│  │ (temp, humid..)│  │
│  └────────────────┘  │
└──────────────┬───────┘
               │ (Ethernet: JSON)
               │
┌──────────────▼──────────────────────┐
│     Raspberry Pi 5                   │
│  ┌────────────────────────────────┐ │
│  │ Python Data Collection         │ │
│  │  - Poll Arduino every 1s       │ │
│  │  - Write to Neo4j              │ │
│  └────────────────┬───────────────┘ │
│                   │                  │
│  ┌────────────────▼───────────────┐ │
│  │ Neo4j Database                 │ │
│  │  - Nodes: Sensors, Readings    │ │
│  │  - Relationships: hasReading   │ │
│  │  - Properties: value, time     │ │
│  └────────────────┬───────────────┘ │
│                   │                  │
│  ┌────────────────▼───────────────┐ │
│  │ FastAPI + Trait Computation    │ │
│  │  - Query Neo4j via Cypher      │ │
│  │  - Compute traits (numpy)      │ │
│  │  - Return JSON                 │ │
│  └────────────────┬───────────────┘ │
└────────────────┬──────────────────────┘
                 │
    ┌────────────┼────────────┐
    │            │            │
    ▼            ▼            ▼
Neo4j Browser   FastAPI      Custom Dashboard
(built-in viz)  (HTTP API)   (Vue.js)
```

---

## Setup: Install Neo4j

### Option 1: Neo4j Desktop (Easiest for Development)

1. Download: https://neo4j.com/download/
2. Install on your laptop
3. Create new local database
4. Get connection credentials (bolt://localhost:7687)

### Option 2: Neo4j on Raspberry Pi (For Production)

```bash
# On Pi, install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Run Neo4j container
docker run -d \
  -p 7474:7474 \
  -p 7687:7687 \
  -e NEO4J_AUTH=neo4j/password123 \
  neo4j:latest
```

Then access:
- Browser UI: http://localhost:7474
- Python driver: bolt://localhost:7687

---

## Code: Neo4j Version

### 1. Define Your Graph Schema (Cypher)

Run these in Neo4j Browser to create constraints:

```cypher
-- Define node labels
CREATE CONSTRAINT IF NOT EXISTS FOR (s:Sensor) REQUIRE s.sensor_id IS UNIQUE;
CREATE CONSTRAINT IF NOT EXISTS FOR (r:Reading) REQUIRE r.reading_id IS UNIQUE;

-- Define index for queries
CREATE INDEX IF NOT EXISTS FOR (r:Reading) ON (r.timestamp);
```

---

### 2. Arduino Sketch (same as before)

```cpp
#include <Wire.h>
#include <Ethernet.h>

float readTemperature() {
  return 20.0 + (random(-10, 10) / 100.0);
}

void setup() {
  Serial.begin(9600);
  Wire.begin();
  Ethernet.begin(mac);
}

void loop() {
  float temp1 = readTemperature();
  float temp2 = readTemperature();
  
  EthernetClient client;
  if (client.connect(pi_ip, 8000)) {
    client.print("{\"temp_1\":");
    client.print(temp1);
    client.print(",\"temp_2\":");
    client.print(temp2);
    client.println("}");
    client.stop();
  }
  
  delay(1000);
}
```

---

### 3. Python: Neo4j Data Collection

```python
from neo4j import GraphDatabase
import socket
import json
from datetime import datetime
import uuid

class Neo4jSensorStore:
    def __init__(self, uri, user, password):
        self.driver = GraphDatabase.driver(uri, auth=(user, password))
    
    def close(self):
        self.driver.close()
    
    def create_sensor_if_not_exists(self, sensor_name, sensor_type):
        """Create sensor node if it doesn't exist."""
        with self.driver.session() as session:
            session.run(
                """
                MERGE (s:Sensor {sensor_id: $sensor_id})
                SET s.name = $name,
                    s.type = $type,
                    s.created_at = datetime()
                """,
                sensor_id=sensor_name,
                name=sensor_name,
                type=sensor_type
            )
    
    def store_reading(self, sensor_name, value):
        """Store a sensor reading."""
        with self.driver.session() as session:
            reading_id = str(uuid.uuid4())
            timestamp = datetime.now().isoformat()
            
            session.run(
                """
                MATCH (s:Sensor {sensor_id: $sensor_id})
                CREATE (r:Reading {
                    reading_id: $reading_id,
                    value: $value,
                    timestamp: $timestamp
                })
                CREATE (s)-[:HAS_READING]->(r)
                """,
                sensor_id=sensor_name,
                reading_id=reading_id,
                value=value,
                timestamp=timestamp
            )
    
    def get_recent_readings(self, sensor_name, limit=100):
        """Fetch last N readings for a sensor."""
        with self.driver.session() as session:
            result = session.run(
                """
                MATCH (s:Sensor {sensor_id: $sensor_id})-[:HAS_READING]->(r:Reading)
                RETURN r.value as value, r.timestamp as timestamp
                ORDER BY r.timestamp DESC
                LIMIT $limit
                """,
                sensor_id=sensor_name,
                limit=limit
            )
            return [{"value": row["value"], "timestamp": row["timestamp"]} 
                    for row in result]

# Initialize
store = Neo4jSensorStore("bolt://localhost:7687", "neo4j", "password123")

# Create sensors
for sensor in ["temp_1", "temp_2", "humidity", "pressure"]:
    store.create_sensor_if_not_exists(sensor, "TemperatureSensor")

def collect_sensor_data():
    """Listen for Arduino data, store in Neo4j."""
    server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server.bind(("0.0.0.0", 8000))
    server.listen(1)
    
    while True:
        conn, addr = server.accept()
        data = conn.recv(1024).decode()
        readings = json.loads(data)
        
        for sensor_name, value in readings.items():
            store.store_reading(sensor_name, value)
        
        conn.close()

if __name__ == "__main__":
    collect_sensor_data()
```

---

### 4. Trait Computation (Neo4j + Cypher)

```python
import numpy as np
from neo4j import GraphDatabase
from datetime import datetime, timedelta

class TraitComputer:
    def __init__(self, uri, user, password):
        self.driver = GraphDatabase.driver(uri, auth=(user, password))
    
    def compute_stability(self, sensor_name, window_seconds=60):
        """Calculate stability from Neo4j readings."""
        with self.driver.session() as session:
            # Query recent readings
            result = session.run(
                """
                MATCH (s:Sensor {sensor_id: $sensor_id})-[:HAS_READING]->(r:Reading)
                WHERE datetime(r.timestamp) > datetime() - duration({seconds: $window})
                RETURN r.value as value
                ORDER BY r.timestamp DESC
                """,
                sensor_id=sensor_name,
                window=window_seconds
            )
            
            values = [row["value"] for row in result]
            
            if len(values) < 2:
                return None
            
            std_dev = np.std(values)
            stability = 100 - min(std_dev * 10, 100)
            
            return {
                "sensor": sensor_name,
                "stability_percent": round(stability, 2),
                "std_dev": round(std_dev, 4),
                "reading_count": len(values)
            }
    
    def compute_drift(self, sensor_name, window_seconds=300):
        """Calculate drift from Neo4j."""
        with self.driver.session() as session:
            result = session.run(
                """
                MATCH (s:Sensor {sensor_id: $sensor_id})-[:HAS_READING]->(r:Reading)
                WHERE datetime(r.timestamp) > datetime() - duration({seconds: $window})
                RETURN r.value as value, r.timestamp as timestamp
                ORDER BY r.timestamp ASC
                """,
                sensor_id=sensor_name,
                window=window_seconds
            )
            
            rows = list(result)
            if len(rows) < 2:
                return None
            
            timestamps = [datetime.fromisoformat(row["timestamp"]) for row in rows]
            values = [float(row["value"]) for row in rows]
            
            x = np.array([(t - timestamps[0]).total_seconds() for t in timestamps])
            y = np.array(values)
            
            slope = np.polyfit(x, y, 1)[0]
            drift_per_minute = slope * 60
            
            return {
                "sensor": sensor_name,
                "drift_per_minute": round(drift_per_minute, 4),
                "status": "DRIFTING" if abs(drift_per_minute) > 0.1 else "STABLE",
                "reading_count": len(values)
            }
    
    def compute_freshness(self, sensor_name):
        """Check age of last reading."""
        with self.driver.session() as session:
            result = session.run(
                """
                MATCH (s:Sensor {sensor_id: $sensor_id})-[:HAS_READING]->(r:Reading)
                RETURN r.timestamp as timestamp
                ORDER BY r.timestamp DESC
                LIMIT 1
                """,
                sensor_id=sensor_name
            )
            
            row = result.single()
            if not row:
                return None
            
            last_update = datetime.fromisoformat(row["timestamp"])
            age_seconds = (datetime.now() - last_update).total_seconds()
            
            return {
                "sensor": sensor_name,
                "age_seconds": round(age_seconds, 2),
                "status": "FRESH" if age_seconds < 5 else "STALE"
            }

# Usage
traits = TraitComputer("bolt://localhost:7687", "neo4j", "password123")
print(traits.compute_stability("temp_1"))
print(traits.compute_drift("temp_1"))
print(traits.compute_freshness("temp_1"))
```

---

### 5. FastAPI (same structure, Neo4j backend)

```python
from fastapi import FastAPI
from neo4j import GraphDatabase

app = FastAPI()
traits = TraitComputer("bolt://localhost:7687", "neo4j", "password123")

@app.get("/traits/stability/{sensor_name}")
def get_stability(sensor_name: str):
    return traits.compute_stability(sensor_name)

@app.get("/traits/drift/{sensor_name}")
def get_drift(sensor_name: str):
    return traits.compute_drift(sensor_name)

@app.get("/traits/freshness/{sensor_name}")
def get_freshness(sensor_name: str):
    return traits.compute_freshness(sensor_name)

@app.get("/traits/all")
def get_all_traits():
    """Get all traits for all sensors."""
    with traits.driver.session() as session:
        result = session.run(
            "MATCH (s:Sensor) RETURN s.sensor_id as sensor_id"
        )
        sensors = [row["sensor_id"] for row in result]
    
    all_traits = {}
    for sensor in sensors:
        all_traits[sensor] = {
            "stability": traits.compute_stability(sensor),
            "drift": traits.compute_drift(sensor),
            "freshness": traits.compute_freshness(sensor)
        }
    
    return all_traits

@app.post("/query")
def cypher_query(query: str):
    """Execute raw Cypher query."""
    with traits.driver.session() as session:
        result = session.run(query)
        return [dict(record) for record in result]

# uvicorn app:app --reload
```

---

## Visualization: The Beautiful Part

### 1. Neo4j Browser (Built-in, Free)

Navigate to: http://localhost:7474

Run queries and see graphs:

```cypher
-- See all sensors and their recent readings
MATCH (s:Sensor)-[:HAS_READING]->(r:Reading)
RETURN s, r
LIMIT 50
```

**This renders a beautiful interactive graph automatically.** No extra tools needed.

Click nodes, drag them around, zoom. All built-in.

### 2. Visualization Queries

```cypher
-- Show sensor network with reading counts
MATCH (s:Sensor)-[rel:HAS_READING]->(r:Reading)
RETURN s, rel, r
LIMIT 100
```

Output: **Interactive graph showing:**
- Sensor nodes (green circles)
- Reading nodes (blue circles)
- Relationships (connecting lines)
- Click any node to inspect properties

### 3. Custom Dashboard with Python + Pyvis

For more control, generate interactive HTML graphs:

```python
from pyvis.network import Network
from neo4j import GraphDatabase

def visualize_sensor_graph():
    driver = GraphDatabase.driver("bolt://localhost:7687", 
                                  auth=("neo4j", "password123"))
    
    with driver.session() as session:
        result = session.run("""
            MATCH (s:Sensor)-[rel:HAS_READING]->(r:Reading)
            WHERE datetime(r.timestamp) > datetime() - duration({hours: 1})
            RETURN s.sensor_id as sensor_id, r.value as value, r.timestamp as timestamp
            LIMIT 200
        """)
        
        # Create Pyvis network
        net = Network(height="750px", width="100%", directed=True)
        
        # Add nodes and edges
        sensor_nodes = set()
        for record in result:
            sensor_id = record["sensor_id"]
            reading_value = record["value"]
            
            if sensor_id not in sensor_nodes:
                net.add_node(sensor_id, label=sensor_id, color="lightblue", size=30)
                sensor_nodes.add(sensor_id)
            
            reading_id = f"{sensor_id}_{record['timestamp']}"
            net.add_node(reading_id, label=f"{reading_value}°C", color="lightgreen", size=15)
            net.add_edge(sensor_id, reading_id)
        
        net.show("sensor_graph.html")
        return "sensor_graph.html"

# Generate graph
visualize_sensor_graph()
# Open browser to: file:///path/to/sensor_graph.html
```

### 4. Real-time Dashboard (Advanced)

```python
# Install: pip install streamlit
import streamlit as st
from neo4j import GraphDatabase
import plotly.express as px

st.set_page_config(page_title="Sensor Twin Dashboard", layout="wide")

driver = GraphDatabase.driver("bolt://localhost:7687", 
                              auth=("neo4j", "password123"))

st.title("Digital Twin - Sensor Dashboard")

# Column 1: Graph visualization
col1, col2 = st.columns(2)

with col1:
    st.subheader("Sensor Network")
    
    # Neo4j graph query
    with driver.session() as session:
        result = session.run("""
            MATCH (s:Sensor)-[:HAS_READING]->(r:Reading)
            WHERE datetime(r.timestamp) > datetime() - duration({hours: 1})
            RETURN s.sensor_id as sensor_id, COUNT(r) as reading_count
        """)
        
        data = [{"Sensor": row["sensor_id"], "Readings": row["reading_count"]} 
                for row in result]
        
        fig = px.bar(data, x="Sensor", y="Readings")
        st.plotly_chart(fig)

with col2:
    st.subheader("Sensor Health")
    
    # Trait computation
    traits = TraitComputer("bolt://localhost:7687", "neo4j", "password123")
    
    with driver.session() as session:
        sensors = session.run("MATCH (s:Sensor) RETURN s.sensor_id as sensor_id")
        
        for row in sensors:
            sensor_id = row["sensor_id"]
            stability = traits.compute_stability(sensor_id)
            
            if stability:
                st.metric(
                    f"{sensor_id} - Stability",
                    f"{stability['stability_percent']:.1f}%",
                    f"StdDev: {stability['std_dev']:.4f}"
                )

# Run: streamlit run dashboard.py
```

---

## Comparison: RDFLib vs Neo4j

| Feature | RDFLib | Neo4j |
|---------|--------|-------|
| **Visualization** | Poor (requires external tools) | Excellent (built-in browser) |
| **Query Language** | SPARQL | Cypher (easier) |
| **Performance** | Slow for large graphs | Fast (graph-optimized DB) |
| **Real-time updates** | Awkward | Natural |
| **Learning curve** | Steep (semantic web concepts) | Gentle (just graph thinking) |
| **Semantic reasoning** | Full OWL support | Limited (property graphs) |
| **Scalability** | Poor (in-memory) | Excellent (persistence) |
| **Production ready** | No | Yes |
| **Dashboard support** | Manual | Native + ecosystem |

**For your project: Neo4j wins on almost everything.**

---

## Install Everything

```bash
# On Pi or laptop
pip install neo4j fastapi uvicorn numpy streamlit plotly pyvis

# Download Neo4j Desktop or run Docker (see above)

# Start services
# Terminal 1
python collect_sensor_data.py

# Terminal 2
uvicorn app:app --reload

# Terminal 3 (optional dashboard)
streamlit run dashboard.py

# Open browser
# Neo4j Browser: http://localhost:7474
# FastAPI docs: http://localhost:8000/docs
# Dashboard: http://localhost:8501
```

---

## Summary

[x] **Can you visualize?** YES - Neo4j browser is incredible for this

[x] **Should you use Neo4j?** YES - much better for operational systems

[x] **Is ontology still relevant?** YES - you still model sensors, readings, relationships semantically

[x] **Difference?** Property graphs (Neo4j) vs RDF triples (RDFLib), but same conceptual ontology

**Start with Neo4j. You'll have beautiful graphs in minutes.**