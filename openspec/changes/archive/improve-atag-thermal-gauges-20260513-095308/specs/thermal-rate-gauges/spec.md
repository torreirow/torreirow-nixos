## ADDED Requirements

### Requirement: Heating Rate gauge shows only positive heating values
The Heating Rate gauge SHALL display only positive temperature change rates when the room is actively heating. When the room is cooling or stable (rate ≤ 0), the gauge SHALL display 0°C/h.

#### Scenario: Room is actively heating
- **WHEN** the room temperature derivative is positive (e.g., +0.6°C/h)
- **THEN** the Heating Rate gauge displays the positive value (0.6°C/h)

#### Scenario: Room is cooling
- **WHEN** the room temperature derivative is negative (e.g., -0.5°C/h)
- **THEN** the Heating Rate gauge displays 0°C/h (not heating)

#### Scenario: Room is stable
- **WHEN** the room temperature derivative is near zero (e.g., +0.05°C/h)
- **THEN** the Heating Rate gauge displays the value as-is (0.05°C/h)

### Requirement: Cooling Rate gauge shows only cooling magnitude
The Cooling Rate gauge SHALL display the absolute magnitude of temperature loss only when the room is cooling. When the room is heating or stable (rate ≥ 0), the gauge SHALL display 0°C/h.

#### Scenario: Room is actively cooling
- **WHEN** the room temperature derivative is negative (e.g., -0.6°C/h)
- **THEN** the Cooling Rate gauge displays the absolute magnitude (0.6°C/h)

#### Scenario: Room is heating
- **WHEN** the room temperature derivative is positive (e.g., +0.5°C/h)
- **THEN** the Cooling Rate gauge displays 0°C/h (not cooling)

#### Scenario: Room is stable
- **WHEN** the room temperature derivative is near zero (e.g., -0.05°C/h)
- **THEN** the Cooling Rate gauge displays the absolute value (0.05°C/h)

### Requirement: Heating Rate uses efficiency-based thresholds
The Heating Rate gauge SHALL use color thresholds that reflect thermal efficiency best practices, not just speed of heating.

#### Scenario: Stable temperature maintenance
- **WHEN** heating rate is between 0-0.2°C/h
- **THEN** gauge displays GRAY or GREEN (stable state, minimal heating needed)

#### Scenario: Healthy heating operation
- **WHEN** heating rate is between 0.2-0.8°C/h
- **THEN** gauge displays GREEN (optimal efficiency range)

#### Scenario: Active heating
- **WHEN** heating rate is between 0.8-1.2°C/h
- **THEN** gauge displays YELLOW (active but acceptable)

#### Scenario: Aggressive inefficient heating
- **WHEN** heating rate exceeds 1.2°C/h
- **THEN** gauge displays RED (inefficient, excessive cycling)

### Requirement: Cooling Rate uses heat loss thresholds
The Cooling Rate gauge SHALL use color thresholds that indicate the magnitude of heat loss, with more lenient thresholds than heating due to natural thermal characteristics.

#### Scenario: Minimal heat loss
- **WHEN** cooling rate is between 0-0.4°C/h
- **THEN** gauge displays GREEN (minimal heat loss, good insulation)

#### Scenario: Normal heat dissipation
- **WHEN** cooling rate is between 0.4-0.8°C/h
- **THEN** gauge displays YELLOW (normal heat loss rate)

#### Scenario: Fast heat loss
- **WHEN** cooling rate exceeds 0.8°C/h
- **THEN** gauge displays RED (rapid heat loss, check insulation or extreme weather)

### Requirement: Prometheus queries separate heating from cooling
The gauge queries SHALL use PromQL functions to mathematically separate positive (heating) from negative (cooling) temperature derivatives.

#### Scenario: Heating Rate query extracts only positive values
- **WHEN** the Heating Rate panel executes its Prometheus query
- **THEN** the query uses `max(deriv(...), 0)` or equivalent to show only positive rates

#### Scenario: Cooling Rate query extracts only negative values
- **WHEN** the Cooling Rate panel executes its Prometheus query
- **THEN** the query uses `abs(min(deriv(...), 0))` or equivalent to show only cooling magnitude
