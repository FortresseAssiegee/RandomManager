import { ref } from "vue";
import { Contract, JsonRpcProvider, decodeBytes32String, getAddress } from "ethers";
import { useRandomManager } from "./useRandomManager";
import { useReliableProjectHistory } from "./useReliableProjectHistory";

const PROJECT_ABI = [
  "function requestId() view returns (uint256)",
  "function paused() view returns (bool)",
  "function getRequest(uint256) view returns (address requester, bytes32 userSeed, uint256 blockNumber, uint256 randomness, uint8 status)",
  "function getRequestMessage(uint256) view returns (bytes32)",
];
const FALLBACK_RPC = "https://sepolia.drpc.org";

const projects = ref([]);
const loading = ref(false);
const loaded = ref(false);
const error = ref("");

function normalizeAddress(value) {
  return getAddress(String(value || "").trim().toLowerCase());
}

function decodeSeed(value) {
  try {
    return decodeBytes32String(value) || value;
  } catch {
    return value;
  }
}

async function hydrateWithRpc(rpcUrl, baseProjects) {
  const provider = new JsonRpcProvider(rpcUrl, 11155111, { staticNetwork: true });
  try {
    const hydrated = [];
    for (const project of baseProjects) {
      const contract = new Contract(normalizeAddress(project.proxy), PROJECT_ABI, provider);
      const [requestCountValue, paused] = await Promise.all([contract.requestId(), contract.paused()]);
      const requestCount = Number(requestCountValue);
      const requests = [];
      for (let id = requestCount; id >= 1; id--) {
        const [request, message] = await Promise.all([contract.getRequest(id), contract.getRequestMessage(id)]);
        requests.push({
          id,
          requester: request.requester,
          userSeed: request.userSeed,
          userSeedText: decodeSeed(request.userSeed),
          blockNumber: request.blockNumber.toString(),
          randomness: request.randomness.toString(),
          status: Number(request.status),
          message,
        });
      }
      hydrated.push({ ...project, paused, requestCount, requests });
    }
    return hydrated;
  } finally {
    provider.destroy?.();
  }
}

function resetDirectory() {
  projects.value = [];
  loaded.value = false;
  error.value = "";
}

async function loadDirectory(force = false) {
  if (loading.value || (loaded.value && !force)) return;
  const store = useRandomManager();
  const history = useReliableProjectHistory();
  loading.value = true;
  error.value = "";
  try {
    await history.loadHistory();
    if (history.error.value) throw new Error(history.error.value);
    const candidates = [...new Set([store.rpcUrl.value, FALLBACK_RPC])];
    let lastError;
    for (const rpcUrl of candidates) {
      try {
        projects.value = await hydrateWithRpc(rpcUrl, history.projects.value);
        loaded.value = true;
        return;
      } catch (reason) {
        lastError = reason;
      }
    }
    throw lastError || new Error("无法读取项目请求历史");
  } catch (reason) {
    error.value = reason?.shortMessage || reason?.message || "读取项目请求历史失败";
  } finally {
    loading.value = false;
  }
}

export function useProjectRequestDirectory() {
  return { projects, loading, loaded, error, resetDirectory, loadDirectory };
}
