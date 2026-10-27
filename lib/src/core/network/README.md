# Network Boundary

`LuliVerifySessionTransport` is the injection boundary. The native HTTP adapter
exchanges one-use server grants and owns memory-only tokens, abortable requests,
multipart upload and cleanup. It refuses redirects and browser Origin headers.
No UI imports, merchant secrets, sensitive logging or automatic request retries.
