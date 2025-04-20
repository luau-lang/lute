local net = require("@lute/net")

local server = net.serve({
	port = 8080,
	handler = function(req)
		local headers = ""
		for key, value in req.headers do
			headers ..= `\n  {key}: {value}`
		end

		return {
			status = 200,
			headers = {
				["Content-Type"] = "text/html",
				["X-Powered-By"] = "Lute",
			},
			-- stylua: ignore
			body = [[
                <html>
                    <head>
                        <title>Lute Server Example</title>
                        <style>
                            body { font-family: system-ui; margin: 40px; line-height: 1.6; }
                            pre { background: #eee; padding: 10px; border-radius: 5px; }
                        </style>
                    </head>
                    <body>
                        <h1>Hello from Lute Server!</h1>
                        <p>This is a simple example of the Lute HTTP server.</p>
                        <h2>Request Details:</h2>
                        <pre>Method: ]] .. req.method .. [[, Path: ]] .. req.path .. [[, Headers:]] .. headers ..[[</pre>
                    </body>
                </html>
            ]],
		}
	end,
})

print(`Server listening on http://{server.hostname}:{server.port}`)
