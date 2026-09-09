import { ref } from "vue";
import { Contract, JsonRpcProvider, getAddress } from "ethers";
import { decodeProjectId, useRandomManager } from "./useRandomManager";

const MANAGER_DEPLOYMENT_BLOCK = Number(import.meta.env.VITE_MANAGER_DEPLOYMENT_BLOCK || 11355617);
const HISTORY_FALLBACK_RPC = "https://sepolia.drpc.org";
const EVENT_ABI = ["event ProjectCreated(bytes32 indexed projectId, address indexed owner, address indexed proxy, bytes32 salt)"];

const projects = ref([]);
const loading = ref(false);
const loaded = ref(false);
const error = ref("");
const source = ref("");

function normalizeAddress(value) {
  return getAddress(String(value || "").trim().toLowerCase());
}

async function readAllEvents(rpcUrl, managerAddress) {
  const provider = new JsonRpcProvider(rpcUrl, 11155111, { staticNetwork: true });
  try {
    const manager = new Contract(normalizeAddress(managerAddress), EVENT_ABI, provider);
    const latest = await provider.getBlockNumber();
    const events = [];
    const chunkSize = 9_999;
    for (let from = MANAGER_DEPLOYMENT_BLOCK; from <= latest; from += chunkSize + 1) {
      const to = Math.min(latest, from + chunkSize);
      events.push(...await manager.queryFilter(manager.filters.ProjectCreated(), from, to));
    }
    return events;
  } finally {
    provider.destroy?.();
  }
}

async function loadHistory() {
  const store = useRandomManager();
  loading.value = true;
  error.value = "";
  loaded.value = false;
  const candidates = [...new Set([store.rpcUrl.value, HISTORY_FALLBACK_RPC])];
  let lastError;
  try {
    let events;
    for (const rpcUrl of candidates) {
      try {
        events = await readAllEvents(rpcUrl, store.managerAddress.value);
        source.value = rpcUrl === store.rpcUrl.value ? "当前 RPC" : "历史日志备用 RPC";
        break;
      } catch (reason) {
        lastError = reason;
      }
    }
    if (!events) throw lastError || new Error("没有可用的历史日志 RPC");
    projects.value = events.slice().reverse().map((event) => ({
      projectId: event.args.projectId,
      name: decodeProjectId(event.args.projectId),
      owner: event.args.owner,
      proxy: event.args.proxy,
      salt: event.args.salt,
      transactionHash: event.transactionHash,
      blockNumber: event.blockNumber,
    }));
    loaded.value = true;
  } catch (reason) {
    error.value = reason?.shortMessage || reason?.message || "读取项目历史失败";
  } finally {
    loading.value = false;
  }
}

export function useReliableProjectHistory() {
  return { projects, loading, loaded, error, source, loadHistory };
}
