# Automated Battery Cell Inspection & Sorting System

A simulated industrial automation system for inspecting cylindrical battery cells and automatically classifying them as pass or reject based on voltage and dimensional measurements.

The project integrates **PLC ladder logic, HMI visualization, electrical control design, fault handling, and Python-based quality analytics** to demonstrate a complete controls workflow from machine sequencing to production data analysis.

## System Overview

The system models a battery cell inspection station where cells travel along a conveyor to an inspection position.

Each cell is evaluated using simulated:

- Cell voltage
- Cell height

Cells that meet the defined inspection limits are classified as **PASS**, while cells outside the limits are classified as **REJECT** and tracked to a downstream pneumatic rejection station.

The control system also monitors the reject sequence and generates a machine fault if a rejected cell does not arrive at the reject station within the expected time.

## Control Sequence

1. Operator starts the machine through the HMI.
2. Conveyor transports a cell to the inspection position.
3. PLC stops the conveyor when the cell is detected.
4. A timed inspection cycle begins.
5. Cell voltage and height are evaluated against configured limits.
6. Passing cells continue through the system.
7. Rejected cells are tracked to the reject station.
8. A simulated pneumatic actuator removes rejected cells.
9. Production counters track total, passed, and rejected cells.
10. A reject-arrival timeout generates a machine fault if a rejected cell fails to reach the reject station.

## PLC & HMI

The machine control logic was developed using **CODESYS V3.5** with IEC 61131-3 Ladder Diagram (LD).

Implemented control features include:

- Start/stop seal-in logic
- Conveyor sequencing
- Timed inspection cycles
- Voltage and dimensional validation
- Pass/reject classification
- Rising-edge triggered production counters
- Reject sequence control
- Reject-arrival timeout monitoring
- Latched machine fault handling
- Operator fault reset
- Emergency-stop status interlock
- HMI machine controls and status visualization

### PLC Ladder Logic

<img width="1114" height="787" alt="plc_ladder_logic_code" src="https://github.com/user-attachments/assets/1ee9f780-492c-4659-9196-ea07e4a7ad97" /><br><br>


A complete scrolling walkthrough of the PLC networks is available here:


https://github.com/user-attachments/assets/8186ccf3-3335-4874-a192-baebca944f2e


### HMI

The HMI provides operator control and real-time visualization of machine status, inspection measurements, production counts, and faults.

<img width="1582" height="584" alt="Cell_Inspection_System_HMI" src="https://github.com/user-attachments/assets/0ff4efd0-1357-4aa6-af3a-e42c26249fed" />

### HMI Functional Demo

The demo shows:

- Normal machine startup
- Inspection of a passing cell
- Detection and rejection of an out-of-specification cell
- Reject-arrival fault detection
- Machine fault response and operator reset


https://github.com/user-attachments/assets/e0c2c182-0b7c-4612-882e-6198475896fa


## Electrical Control Schematic

A conceptual electrical control schematic was developed in **AutoCAD Electrical**.

The schematic includes:

- 24 VDC control power
- PLC digital inputs and outputs
- Start and stop pushbuttons
- Emergency-stop status
- Cell position sensors
- Fault and counter reset controls
- Conveyor motor starter
- Reject solenoid valve
- Machine status outputs

<img width="1188" height="802" alt="electrical_control_schematic" src="https://github.com/user-attachments/assets/ee84a920-64e0-42d7-98dc-97f398a31bd1" />

The editable AutoCAD drawing (`.dwg`) is also included in the project files.

## Python Quality Analytics

Python was used to simulate inspection data and analyze production quality results.

The analysis:

- Generates simulated cell voltage and height measurements
- Applies the same inspection thresholds used by the PLC simulation
- Classifies cells as PASS or REJECT
- Stores inspection results in CSV format
- Calculates production statistics
- Identifies reject reasons
- Generates visualization charts using Matplotlib

### Inspection Results

<img width="640" height="480" alt="inspection_results" src="https://github.com/user-attachments/assets/52e951b3-c533-4659-b27d-4ea77343fd08" />

### Reject Reasons

<img width="640" height="480" alt="reject_reasons" src="https://github.com/user-attachments/assets/595d96d8-efc6-4f36-925b-15d68471822c" />

The Python source code and generated CSV dataset are included in the `Python_Analytics` directory.

## Inspection Criteria

For simulation purposes, the following generic acceptance ranges were used:

| Measurement | Acceptable Range |
|---|---|
| Cell Voltage | 3.5 V – 4.2 V |
| Cell Height | 79.5 mm – 80.5 mm |

These values are used solely for educational simulation and are not intended to represent specifications for any particular battery manufacturer or production cell.

## Technologies Used

- CODESYS V3.5
- IEC 61131-3 Ladder Diagram (LD)
- CODESYS Visualization / HMI
- AutoCAD Electrical 2026
- Python
- Matplotlib
- CSV data processing

## Project Structure

```text
Automated Battery Cell Inspection & Sorting System/
│
├── AutoCAD_Electrical_Schematic/
│   ├── Cell_Control_Schematic.dwg
│   └── electrical_control_schematic.png
│
├── PLC_HMI/
│   ├── Battery_Cell_Inspection_System.project
│   ├── Cell_Inspection_System_HMI.png
│   ├── plc_ladder_logic_code.png
│   ├── plc_ladder_logic_networks_walkthrough.mp4
│   └── Battery Cell Inspection System HMI Demo.mp4
│
├── Python_Analytics/
│   ├── cell_inspection_analysis.py
│   ├── cell_inspection_data.csv
│   ├── inspection_results.png
│   └── reject_reasons.png
│
└── README.md
```

## Engineering Scope

This project is a software-based educational simulation intended to demonstrate industrial controls and automation concepts.

The PLC logic, sensors, actuators, inspection measurements, and production process are simulated rather than connected to physical manufacturing equipment.

The emergency-stop signal represented in the standard PLC logic is used for simulation and status monitoring only. A real industrial machine would require appropriately designed safety-rated hardware and controls.

