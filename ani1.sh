#!/bin/bash

echo "Monitoring PT1000 Temperature Sensor..."
echo "Press Ctrl+C to exit"

# Path to the analog input device
AI_DIR="/sys/bus/iio/devices/ai_1_1"
VALUE_FILE="$AI_DIR/in_voltage0_raw"

# Check if the value file exists
if [ ! -f "$VALUE_FILE" ]; then
  echo "Error: Value file $VALUE_FILE not found"
  exit 1
fi

echo "Using value file: $VALUE_FILE"

# Constants for PT1000
R0=1000.0       # Resistance at 0°C (ohms)
ALPHA=0.00385   # Temperature coefficient (/°C)

# Circuit parameters - adjust these based on your specific setup
VREF=10.0       # Reference voltage (V)
R_PULLUP=1000.0 # Pull-up resistor value (ohms)

# Voltage scale factor
SCALE=0.00244   # Example scale for 0-10V with 12-bit resolution

# Monitor the PT1000 sensor
while true; do
  if [ -f "$VALUE_FILE" ]; then
    # Read raw ADC value
    RAW_VALUE=$(cat $VALUE_FILE)

    # Use awk for all calculations
    RESULT=$(awk -v raw="$RAW_VALUE" -v scale="$SCALE" -v r_pullup="$R_PULLUP" \
             -v vref="$VREF" -v r0="$R0" -v alpha="$ALPHA" '
      BEGIN {
        # Convert to voltage
        voltage = raw * scale;

        # Convert voltage to resistance (voltage divider formula)
        resistance = r_pullup * voltage / (vref - voltage);

        # Convert resistance to temperature using PT1000 formula
        temp = (resistance - r0) / (r0 * alpha);

        # Print results with proper formatting
        printf "%.3f %.3f %.2f", voltage, resistance, temp;
      }
    ')

    # Parse the results
    VOLTAGE=$(echo $RESULT | cut -d' ' -f1)
    RESISTANCE=$(echo $RESULT | cut -d' ' -f2)
    TEMP=$(echo $RESULT | cut -d' ' -f3)

    echo "PT1000: $TEMP °C (Resistance: $RESISTANCE Ω, Voltage: $VOLTAGE V, Raw: $RAW_VALUE)"
  else
    echo "Error: Cannot read analog input"
  fi

  # Small delay
  sleep 1
done