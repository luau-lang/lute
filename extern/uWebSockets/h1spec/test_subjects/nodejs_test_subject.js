const http = require('http');

// Create an HTTP server
const server = http.createServer(async (req, res) => {
    let body = '';

    // Read the request body
    req.on('data', chunk => {
        body += chunk.toString(); // Convert Buffer to string
    });

    req.on('end', () => {
        // Set the response headers
        res.writeHead(200, { "Content-Type": "text/plain", "Content-Length": body.length });
        // Send the body back as the response
        res.end(body);
    });

    // Handle errors
    req.on('error', (err) => {
        console.error(err);
        res.writeHead(500);
        res.end('Server error');
    });
});

// Start the server and listen on port 8000
const PORT = 8000;
server.listen(PORT, () => {
    console.log(`HTTP webserver running. Access it at: http://localhost:${PORT}/`);
});