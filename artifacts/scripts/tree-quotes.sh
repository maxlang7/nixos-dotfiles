#!/bin/bash

# Seed the random number generator (if needed)
RANDOM=$$$(date +%s)

quotes=(
  "The only way to do great work is to love what you do. - Steve Jobs"
  "Strive not to be a success, but rather to be of value. - Albert Einstein"
  "Two things are infinite: the universe and human stupidity; and I'm not sure about the universe. - Albert Einstein"
  "Be the change that you wish to see in the world. - Mahatma Gandhi"
  "The only thing necessary for the triumph of evil is for good men to do nothing. - Edmund Burke"
  "I am at home among the trees - J.R.R Tolkien"
)

while true; do
  # Get a random index
  index=$((RANDOM % ${#quotes[@]}))

  # Get the quote at that index
  quote="${quotes[$index]}"

  # Execute the cbonsai command in the background and store the PID
  cbonsai -l -t 0.005 -m "$quote" &
  pid=$!

  # Wait for a short time (e.g., 2 seconds)
  sleep 2

  # Kill the cbonsai process
  kill $pid

  # Wait for 3 seconds (total delay including the bonsai animation time)
  sleep 3
done
