# Linear Voltage-Controlled Multi-Function Waveform Generator

## Overview
This project involved the design, simulation, and implementation of a
linear voltage-controlled function generator (VCFG) which produces
square and triangular waveforms using only operational amplifiers and
discrete components.

The system converts a DC control voltage into a linearly proportional
output frequency and provides selectable frequency ranges and adjustable
output amplitude. The design was completed as a major project for
Electronic Circuits II (ELE 504).

## System Functionality
The waveform generator provides:
- Square and triangular waveform outputs
- Linear voltage-to-frequency control
- Two selectable frequency ranges:
  - **Range 1:** 100 Hz – 5 kHz (1000 Hz/V)
  - **Range 2:** 20 Hz – 1 kHz (200 Hz/V)
- Adjustable output amplitude from approximately 0 to 8 Vpp
- Operation from ±12 V power supplies

## Design Architecture
The system is composed of the following main blocks:
- **Bistable Comparator:** Generates a square wave using hysteresis
- **Integrator:** Produces a triangular waveform from the square wave
- **DC-to-±DC Converter & Digital Switch:** Controls integrator slope polarity
- **Frequency Range Selector:** Changes RC values to adjust frequency slope
- **Amplitude Control Stage:** Voltage divider with potentiometer scaling

The frequency of oscillation is linearly related to the control voltage,
with design equations verified through analysis, simulation, and hardware
testing.

## Tools & Technologies
- **Circuit Simulation:** NI Multisim
- **Hardware Testing:** Breadboard, oscilloscope, function generator, DMM
- **Components:** Op-amps (LM741, LM318), BJTs, resistors, capacitors,
  Zener diodes, potentiometers
- **Power Supplies:** ±12 V

## Validation & Results
- Linear voltage-to-frequency behavior confirmed in both frequency ranges
- Measured frequencies closely matched theoretical predictions
- Square and triangular outputs maintained stable amplitude
- Hardware measurements showed strong agreement with simulations

Representative oscilloscope waveforms and measured data are included in
the final report.

## Documentation
The complete design process, theoretical analysis, simulations, and
experimental results are documented in the final project report:

- **ELE 504 Design Project – Final Report (PDF)** 

## What I Learned
- How to design op-amp based oscillators using theoretical equations
- How to translate circuit analysis into a working hardware implementation
- How to troubleshoot and debug analog circuits using simulations and lab measurements
- How to compare theoretical, simulated, and experimental results to verify a design


