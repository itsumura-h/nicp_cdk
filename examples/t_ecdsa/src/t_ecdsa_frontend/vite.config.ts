import { defineConfig } from 'vite';
import preact from '@preact/preset-vite';
import EnvironmentPlugin, {
  type EnvVarDefaults,
} from "vite-plugin-environment";
import { fileURLToPath, URL } from "url";
import { config } from "dotenv";

config({ path: `${process.cwd()}/../../.env` });

const envVarsToInclude = [
  // put the ENV vars you want to expose here
  "DFX_VERSION",
  "DFX_NETWORK",
  "CANISTER_ID_INTERNET_IDENTITY",
  "CANISTER_ID_T_ECDSA_FRONTEND",
  "CANISTER_ID_T_ECDSA_BACKEND",
  "CANISTER_ID",
  "CANISTER_CANDID_PATH",
  // "WALLETCONNECT_PROJECT_ID",
];
const esbuildEnvs = Object.fromEntries(
  envVarsToInclude.map(key => [
    `process.env.${key}`,
    JSON.stringify(process.env[key]),
  ])
);
const viteEnvMap: EnvVarDefaults = Object.fromEntries(
  envVarsToInclude.map(entry => [entry, undefined])
);

// https://vitejs.dev/config/
export default defineConfig({
	build: {
    emptyOutDir: true,
  },
  optimizeDeps: {
    esbuildOptions: {
      define: {
        global: "globalThis",
        ...esbuildEnvs,
      },
    },
  },
  server: {
    proxy: {
      "/api": {
        target: "http://127.0.0.1:4943",
        changeOrigin: true,
      },
    },
  },
	plugins: [
		preact({
			prerender: {
				enabled: true,
				renderTarget: '#app',
			},
		}),
		EnvironmentPlugin(viteEnvMap),
	],
	resolve: {
		alias: [
			{
				find: "declarations",
				replacement: fileURLToPath(new URL("../declarations", import.meta.url)),
			},
		],
		dedupe: ["@dfinity/agent"],
	},
});
