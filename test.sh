#!/bin/bash

echo "Monitoring gpiochip2 (Digital Input 1) for button press..."
echo "Press Ctrl+C to exit"

previous_state=$(sudo gpioget gpiochip2 0)
echo "Initial state: $previous_state"

while true; do
  current_state=$(sudo gpioget gpiochip2 0)

  if [ "$current_state" != "$previous_state" ]; then
    if [ "$current_state" -eq "1" ]; then
      echo "Button PRESSED (state: $current_state)"
    else
      echo "Button RELEASED (state: $current_state)"
    fi
    previous_state=$current_state
  fi

  # Small delay to reduce CPU usage
  sleep 0.1
done