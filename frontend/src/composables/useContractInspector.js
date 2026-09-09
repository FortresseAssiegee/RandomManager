import { reactive, ref } from "vue";
import { Contract, JsonRpcProvider, getAddress } from "ethers";
import { ElNotification } from "element-plus";
import { p2Generator, useRandomManager } from "./useRandomManager";

const MANAGER_INSPECT_ABI = [
  "function implementation() view returns (address)",
  "function verifier() view returns (address)",
  "function projectProxy(bytes32) view returns (address)",
  "function getProjectProxy(bytes32) view returns (address)",
  "function isProjectProxy(address) view returns (bool)",
];

const PROJECT_INSPECT_ABI = [
  "function manager() view returns (address)",
  "function owner() view returns (address)",
  "function projectId() view returns (bytes32)",
  "function verifier() view returns (address)",
  "function requestId() view returns (uint256)",
  "function paused() view returns (bool)",
  "function getRequest(uint256) view returns (address requester, bytes32 userSeed, uint256 blockNumber, uint256 randomness, uint8 status)",
  "function getRequestMessage(uint256) view returns (bytes32)",
  "function getRandomness(uint256) view returns (uint256)",
  "function requestRandomness(bytes32) returns (uint256)",
  "function consumeRandomness(uint256) returns (uint256)",
];

const VERIFIER_INSPECT_ABI = [
  "function hashToG1(bytes32 message) view returns (tuple(uint256 x, uint256 y))",
  "function verify(bytes32 message, tuple(uint256 x, uint256 y) signature, tuple(uint256[2] x, uint256[2] y) publicKey) view returns (bool)",
];

const managerRows = ref([]);
const projectRows = ref([]);
const requestRows = ref([]);
const verifierRows = ref([]);
const signature = reactive({ x: "", y: "", available: false, demoValid: false, message: "" });
const loading = ref(false);
const error = ref("");
const updatedAt = ref("");
let provider;
let providerUrl = "";

function normalizedAddress(value) {
  return getAddress(String(value || "").trim().toLowerCase());
}

function getProvider(rpcUrl) {
  if (!provider || providerUrl !== rpcUrl) {
    provider?.destroy?.();
    providerUrl = rpcUrl;
    provider = new JsonRpcProvider(rpcUrl);
  }
  return provider;
}

function serialize(value) {
  if (typeof value === "bigint") return value.toString();
  if (Array.isArray(value)) return value.map(serialize);
  if (value && typeof value === "object") {
    const named = {};
    for (const key of Object.keys(value)) {
      if (!/^\d+$/.test(key)) named[key] = serialize(value[key]);
    }
    if (Object.keys(named).length) return named;
    return Array.from(value).map(serialize);
  }
  return value;
}

function display(value) {
  const serialized = serialize(value);
  return typeof serialized === "object" ? JSON.stringify(serialized, null, 2) : String(serialized);
}

function errorText(reason) {
  return String(reason?.shortMessage || reason?.reason || reason?.message || reason || "读取失败")
    .replace("execution reverted: ", "")
    .slice(0, 240);
}

async function collect(definitions) {
  return Promise.all(definitions.map(async ([name, description, call]) => {
    try {
      const value = await call();
      return { name, description, value: display(value), ok: true };
    } catch (reason) {
      return { name, description, value: errorText(reason), ok: false };
    }
  }));
}

function g2PublicKey() {
  return {
    x: [BigInt(p2Generator.x0), BigInt(p2Generator.x1)],
    y: [BigInt(p2Generator.y0), BigInt(p2Generator.y1)],
  };
}

async function refresh(requestIdInput = "") {
  const store = useRandomManager();
  loading.value = true;
  error.value = "";
  signature.available = false;
  signature.demoValid = false;
  signature.x = "";
  signature.y = "";
  signature.message = "";

  try {
    const rpc = store.rpcUrl.value;
    const readProvider = getProvider(rpc);
    const manager = new Contract(normalizedAddress(store.managerAddress.value), MANAGER_INSPECT_ABI, readProvider);
    const projectId = store.projectMeta.projectId;
    const proxy = store.projectAddress.value;

    const managerDefinitions = [
      ["implementation()", "RandomProject 逻辑合约", () => manager.implementation()],
      ["verifier()", "BLS 验证器合约", () => manager.verifier()],
    ];
    if (projectId) {
      managerDefinitions.push(
        ["projectProxy(projectId)", "项目 ID 映射的代理", () => manager.projectProxy(projectId)],
        ["getProjectProxy(projectId)", "存在性检查后的代理", () => manager.getProjectProxy(projectId)],
      );
    }
    if (proxy) managerDefinitions.push(["isProjectProxy(proxy)", "是否由当前工厂创建", () => manager.isProjectProxy(normalizedAddress(proxy))]);
    managerRows.value = await collect(managerDefinitions);

    if (!proxy) {
      projectRows.value = [];
      requestRows.value = [];
      verifierRows.value = [];
      updatedAt.value = new Date().toLocaleTimeString("zh-CN", { hour12: false });
      return;
    }

    const project = new Contract(normalizedAddress(proxy), PROJECT_INSPECT_ABI, readProvider);
    projectRows.value = await collect([
      ["manager()", "所属 RandomManager", () => project.manager()],
      ["owner()", "项目所有者", () => project.owner()],
      ["projectId()", "原始 bytes32 项目 ID", () => project.projectId()],
      ["verifier()", "项目使用的验证器", () => project.verifier()],
      ["requestId()", "最新请求编号", () => project.requestId()],
      ["paused()", "暂停状态", () => project.paused()],
    ]);

    const chosenId = String(requestIdInput || store.requestResult.id || store.projectMeta.requestCount || "").trim();
    if (!/^\d+$/.test(chosenId) || BigInt(chosenId) === 0n) {
      requestRows.value = [];
      verifierRows.value = [];
      updatedAt.value = new Date().toLocaleTimeString("zh-CN", { hour12: false });
      return;
    }

    let message = "";
    requestRows.value = await collect([
      ["getRequest(id)", "请求结构体全部字段", () => project.getRequest(chosenId)],
      ["getRequestMessage(id)", "链下服务必须签名的 bytes32", async () => {
        message = await project.getRequestMessage(chosenId);
        return message;
      }],
      ["getRandomness(id)", "仅 Fulfilled 状态可读取", () => project.getRandomness(chosenId)],
      ["consumeRandomness.staticCall(id)", "消费交易预期返回值，不发送交易", () => project.consumeRandomness.staticCall(chosenId, { from: normalizedAddress(store.projectMeta.owner) })],
    ]);

    if (!message) {
      try { message = await project.getRequestMessage(chosenId); } catch {}
    }
    if (!message) {
      verifierRows.value = [];
      updatedAt.value = new Date().toLocaleTimeString("zh-CN", { hour12: false });
      return;
    }

    const verifierAddress = normalizedAddress(store.projectMeta.verifier);
    const verifier = new Contract(verifierAddress, VERIFIER_INSPECT_ABI, readProvider);
    const verifierResult = await collect([
      ["hashToG1(message)", "消息映射到 BN254 G1 的坐标", async () => {
        const point = await verifier.hashToG1(message);
        signature.x = point.x.toString();
        signature.y = point.y.toString();
        signature.message = message;
        signature.available = true;
        return { x: signature.x, y: signature.y };
      }],
    ]);

    if (signature.available) {
      const verifyRows = await collect([
        ["verify(message, G1, P2)", "按演示公钥 P2 验证候选签名", async () => {
          const valid = await verifier.verify(
            message,
            { x: BigInt(signature.x), y: BigInt(signature.y) },
            g2PublicKey(),
          );
          signature.demoValid = valid;
          return valid;
        }],
      ]);
      verifierRows.value = [...verifierResult, ...verifyRows];
    } else {
      verifierRows.value = verifierResult;
    }
    updatedAt.value = new Date().toLocaleTimeString("zh-CN", { hour12: false });
  } catch (reason) {
    error.value = errorText(reason);
  } finally {
    loading.value = false;
  }
}

async function submitDemoSignature(requestId) {
  const store = useRandomManager();
  if (!signature.available) throw new Error("请先读取演示签名坐标");
  try {
    await store.fulfillRandomness(requestId, { x: signature.x, y: signature.y });
    await refresh(requestId);
  } catch (reason) {
    ElNotification({
      title: "演示签名提交失败",
      message: "如果项目公钥不是默认 P2，这组坐标不会通过验证，必须由对应 BLS 私钥服务签名。",
      type: "warning",
      duration: 7000,
    });
    throw reason;
  }
}

const singleton = {
  managerRows,
  projectRows,
  requestRows,
  verifierRows,
  signature,
  loading,
  error,
  updatedAt,
  refresh,
  submitDemoSignature,
};

export function useContractInspector() {
  return singleton;
}
