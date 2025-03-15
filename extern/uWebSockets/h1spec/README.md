# h1spec
Quick and easy HTTP/1.1 server spec. compliance check that finishes in less than a second.

## Compliances as of 28th Oct 2024
| Deno     | Node.js     | Bun     | uWS | mrhttp
|--------------|--------------|--------------|---------|-------|
| 31/33 | 32/33 | 32/33 | 33/33 | 17/33 |


### How to run
To run all tests against Deno, Nodejs and Bun, just hit `make` (runs on Linux and macOS).

For a specific server, run `deno run --allow-net http_test.ts localhost 8000` if the server is listening at localhost:8000. The server must echo back whatever HTTP body it gets, for all HTTP methods.

### Example output
```
✅ Missing Host header: Response Status Code 400, Expected ranges: [[400,499]]
✅ Overflowing negative Content-Length header: Response Status Code 400, Expected ranges: [[400,499]]
✅ Non-numeric Content-Length header: Response Status Code 400, Expected ranges: [[400,499]]
✅ Header containing invalid control character: Response Status Code 400, Expected ranges: [[400,499]]
✅ Invalid prefix of request: Response Status Code 400, Expected ranges: [[400,499],[500,599]]
✅ Valid POST request with body: Response Status Code 200, Expected ranges: [[200,299],[404,404]]
✅ Conflicting Transfer-Encoding and Content-Length in varying case: Response Status Code 400, Expected ranges: [[400,499],[200,299]]
✅ Request without HTTP version: Response Status Code 400, Expected ranges: [[400,599]]
✅ Request with Expect header: Response Status Code 100, Expected ranges: [[100,100],[200,299]]
✅ Valid GET request: Response Status Code 200, Expected ranges: [[200,299]]
✅ Valid GET request with edge cases: Response Status Code 200, Expected ranges: [[200,299]]
✅ Invalid header characters: Response Status Code 400, Expected ranges: [[400,499]]
❌ Multiple Host headers: Response Status Code 200, Expected ranges: [[400,499]]
✅ Negative Content-Length header: Response Status Code 400, Expected ranges: [[400,499]]
✅ Empty header value: Response Status Code 200, Expected ranges: [[200,299]]
✅ Invalid HTTP version: Response Status Code 400, Expected ranges: [[400,499],[500,599]]
✅ Invalid line ending: Response Status Code 400, Expected ranges: [[400,499]]
✅ Chunked Transfer-Encoding: Response Status Code 200, Expected ranges: [[200,299]]
✅ Fragmented HTTP version: Server waited successfully
✅ Fragmented field name: Server waited successfully
✅ Fragmented method: Server waited successfully
✅ Fragmented URL 1: Server waited successfully
✅ Fragmented URL 2: Server waited successfully
✅ Fragmented URL 3: Server waited successfully
✅ Fragmented request line: Server waited successfully
✅ Fragmented request line newline 1: Server waited successfully
✅ Fragmented request line newline 2: Server waited successfully
✅ Fragmented field value 1: Server waited successfully
✅ Fragmented field value 2: Server waited successfully
✅ Fragmented field value 3: Server waited successfully
✅ Fragmented field value 4: Server waited successfully
✅ Fragmented request: Server waited successfully
✅ Fragmented request termination: Server waited successfully

32 out of 33 tests passed.
```
