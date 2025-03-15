const server = Bun.serve({
  port: 8000,
  async fetch(req) {
    // Read the request body as text
    const body = await req.text();

    // Echo the body back in the response
    return new Response(body, {
      headers: { "Content-Type": "text/plain" },
    });
  },
});

console.log("HTTP webserver running. Access it at: http://localhost:8000/");
