# FreshTrack 🌱

FreshTrack is a smart pantry tracker that helps users manage their food inventory and reduce food waste.

## Features

- User registration and login
- Add, edit and delete food items
- Track food quantities and units
- Track expiry dates
- Expiring-soon and expired food alerts
- Low-stock tracking
- FreshTrack Impact calculation
- Pantry health overview
- Responsive Flutter interface

## Tech Stack

- Flutter / Dart
- Python Flask
- SQLite
- REST API
- Render

## Architecture

Flutter frontend → Flask REST API → SQLite database

## Deployment

The Flask backend is deployed using Render.

The Flutter application communicates with the deployed backend through its REST API.