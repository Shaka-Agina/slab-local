# Music Player Frontend

This is the frontend for the Raspberry Pi Music Player, built with React and Mantine UI.

## Setup

1. Install Node.js and npm if you haven't already.
2. Install dependencies:
   ```
   npm install
   ```
3. Build the production version:
   ```
   npm run build
   ```

## Development

To run the development server:
```
npm start
```

This will start the React development server on port 3000. The API requests will be proxied to the Flask backend on port 5000.

## Production

For production, build the app and the Flask server will serve the static files:
```
npm run build
```

Then start the Flask server as usual. 