#!/bin/sh

OUT_DIR="out"
LOG_DIR="logs/storage"

rm -rf "$LOG_DIR"/*
dirOutputs=$(ls "$OUT_DIR" | grep '^[^.]*\.sol$')
while IFS= read -r contractDir; do
  innerdirOutputs=$(ls "$OUT_DIR/$contractDir")

  while IFS= read -r jsonFile; do
    fileIn="$OUT_DIR/$contractDir/$jsonFile"
    fileOut="$LOG_DIR/$contractDir:${jsonFile%.json}.log"
    node .husky/storage-logger.js "$fileIn" "$fileOut" &
  done <<< "$innerdirOutputs"
done <<< "$dirOutputs"

# Wait for all background jobs to finish
wait