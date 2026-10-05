import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";
export default defineConfig({
  plugins: [react()],
  server: {
    proxy: {
      "/auth": "http://localhost:8001",
      "/appointments": "http://localhost:8002",
      "/records": "http://localhost:8003",
    },
  },
});
