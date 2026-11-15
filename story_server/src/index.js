import { PORT, createServer } from './server.js';

if (!process.env.ANTHROPIC_API_KEY && !process.env.ANTHROPIC_AUTH_TOKEN) {
  console.warn('Warning: ANTHROPIC_API_KEY is not set; generation calls will fail.');
}
createServer().listen(PORT, () => console.log(`story server listening on :${PORT}`));
