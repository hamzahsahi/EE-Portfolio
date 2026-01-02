# Autonomous Maze Navigation Robot (EEBOT)

## Overview
This project involved programming an EEBOT mobile robot to autonomously
navigate a maze by following a guide line and responding to obstacles.
The robot was controlled using an HCS12 microcontroller and programmed
in assembly language using CodeWarrior.

The primary focus of this project was the software implementation
of robot behavior using a state-machine based control system that
processes sensor inputs and generates motor control outputs in real time.

## System Capabilities
- Line following using guider sensor readings
- Obstacle detection using bumper switches
- Autonomous decision-making using a finite state machine
- Motor direction and speed control through microcontroller I/O
- Real-time system feedback displayed on an LCD

## Control Strategy (Software Design)
The robot behavior is implemented entirely in software using a
finite state machine. Each state represents a specific robot behavior,
and transitions occur based on sensor readings and bumper inputs.

Primary states include:
- **START:** Waits for user input to begin operation
- **FWD:** Drives forward while following the guide line
- **LEFT / RIGHT:** Executes corrective turns based on sensor alignment
- **REV_TRN:** Reverses and turns after detecting a collision
- **ALL_STOP:** Stops motion until reactivated

A central dispatcher routine evaluates the current state and calls
the appropriate state handler, allowing for clean and organized control
logic.

## Programming & Implementation
- Implemented the full control system in HCS12 assembly language
- Wrote modular subroutines for:
  - Reading multiple sensors using the ADC and a hardware multiplexer
  - Processing sensor values against calibrated thresholds
  - Controlling motor direction and enable signals
  - Updating LCD output for debugging and status display
- Used timer overflow interrupts to support timing-based behaviors
- Structured the program to separate initialization, main loop,
  state handling, and utility routines

The code was designed to be readable, well-commented, and structured
to support debugging and incremental testing.

## Hardware & Inputs
- **Microcontroller:** HCS12
- **Sensors:** Guide line sensors and bumper switches
- **Actuators:** DC motors
- **Display:** LCD for battery voltage and current state

## Files
- `main.asm` – Assembly source code implementing the robot control logic
- `projectcoe538.pdf` – Project description and requirements

## What I Learned
- Designing and implementing state machines for embedded systems
- Programming sensor acquisition and decision logic in assembly language
- Debugging embedded software using LCD output and structured states
- Coordinating sensors and motor control through software for autonomous behavior

