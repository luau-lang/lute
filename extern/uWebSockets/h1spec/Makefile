compliance:
	deno run --allow-net test_subjects/deno_test_subject.ts &
	sleep 1
	~/.deno/bin/deno run --allow-net http_test.ts localhost 8000 || true
	kill $$(lsof -t -i:8000)
	bun run test_subjects/bun_test_subject.ts &
	sleep 1
	~/.deno/bin/deno run --allow-net http_test.ts localhost 8000 || true
	kill $$(lsof -t -i:8000)
	node test_subjects/nodejs_test_subject.js &
	sleep 1
	~/.deno/bin/deno run --allow-net http_test.ts localhost 8000 || true
	kill $$(lsof -t -i:8000)