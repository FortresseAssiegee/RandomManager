import { computed, reactive, ref, shallowRef } from "vue";
import {
  BrowserProvider,
  Contract,
  Interface,
  JsonRpcProvider,
  ZeroAddress,
  decodeBytes32String,
  encodeBytes32String,
  getAddress,
  isAddress,
  keccak256,
  toUtf8Bytes,
} from "ethers";
import { ElMessage, ElNotification } from "element-plus";
import {
  DEFAULT_MANAGER_ADDRESS,
  DEFAULT_RPC_URL,
  EXPLORER_URL,
  MANAGER_ABI,
  PROJECT_ABI,
  SEPOLIA_CHAIN_HEX,
  SEPOLIA_CHAIN_ID,
} from "../config/contracts";

export const p2Generator = Object.freeze({
  x0: "11559732032986387107991004021392285783925812861821192530917403151452391805634",
  x1: "10857046999023057135944570762232829481370756359578518086990519993285655852781",
  y0: "4082367875863433681332203403145435568316851327593401208105741076214120093531",
  y1: "8495653923123431417604973247489272438418190587263600148770280649306958101930",
});

export const statusLabels = ["不存在", "等待签名", "随机数已生成", "已消费"];
export const statusTypes = ["info", "warning", "success", "info"];

function normalizeAddress(value) {
  return getAddress(String(value || "").trim().toLowerCase());
}

const managerInterface = new Interface(MANAGER_ABI);
const projectInterface = new Interface(PROJECT_ABI);
const managerAddress = ref(normalizeAddress(localStorage.getItem("randora.manager") || DEFAULT_MANAGER_ADDRESS));
const rpcUrl = ref(localStorage.getItem("randora.rpc") || DEFAULT_RPC_URL);
const storedProjectAddress = localStorage.getItem("randora.project") || "";
const projectAddress = ref(storedProjectAddress ? normalizeAddress(storedProjectAddress) : "");
const account = ref("");
const chainId = ref(null);
const browserProvider = shallowRef(null);
const signer = shallowRef(null);
const readProvider = shallowRef(null);
const initialized = ref(false);

const managerMeta = reactive({ online: false, implementation: "", verifier: "", projectCount: 0 });
const projectMeta = reactive({
  valid: false,
  owner: "",
  manager: "",
  verifier: "",
  projectId: "",
  requestCount: "0",
  paused: false,
});
const requestResult = reactive({
  loaded: false,
  id: "",
  requester: "",
  seed: "",
  blockNumber: "",
  randomness: "",
  status: 0,
  message: "",
});
const activities = ref([]);
const loading = reactive({
  manager: false,
  project: false,
  create: false,
  predict: false,
  lookup: false,
  request: false,
  query: false,
  fulfill: false,
  consume: false,
  pause: false,
  key: false,
  events: false,
});

const walletReady = computed(() => Boolean(account.value));
const onSepolia = computed(() => chainId.value === SEPOLIA_CHAIN_ID);
const shortAccount = computed(() => shortAddress(account.value));
const projectName = computed(() => decodeProjectId(projectMeta.projectId) || "未绑定项目");
const isProjectOwner = computed(
  () => account.value && projectMeta.owner && account.value.toLowerCase() === projectMeta.owner.toLowerCase(),
);

function getReadProvider() {
  if (!readProvider.value) {
    readProvider.value = new JsonRpcProvider(rpcUrl.value, SEPOLIA_CHAIN_ID, { staticNetwork: true });
  }
  return readProvider.value;
}

function managerContract(runner = getReadProvider()) {
  return new Contract(normalizeAddress(managerAddress.value), MANAGER_ABI, runner);
}

function projectContract(runner = getReadProvider()) {
  if (!isAddress(projectAddress.value)) throw new Error("请先绑定有效的项目代理地址");
  return new Contract(normalizeAddress(projectAddress.value), PROJECT_ABI, runner);
}

export function toBytes32(value) {
  const text = String(value || "").trim();
  if (/^0x[0-9a-fA-F]{64}$/.test(text)) return text;
  if (!text) throw new Error("请输入内容");
  if (toUtf8Bytes(text).length <= 31) return encodeBytes32String(text);
  return keccak256(toUtf8Bytes(text));
}

export function decodeProjectId(value) {
  if (!value) return "";
  try {
    return decodeBytes32String(value);
  } catch {
    return `${value.slice(0, 10)}…${value.slice(-6)}`;
  }
}

export function shortAddress(value, head = 6, tail = 4) {
  if (!value) return "—";
  return `${value.slice(0, head)}…${value.slice(-tail)}`;
}

export function formatNumber(value) {
  if (value === "" || value === null || value === undefined) return "—";
  try {
    return BigInt(value).toLocaleString("en-US");
  } catch {
    return value;
  }
}

export const explorerAddress = (address) => `${EXPLORER_URL}/address/${address}`;
export const explorerTx = (hash) => `${EXPLORER_URL}/tx/${hash}`;

export async function copyText(value) {
  if (!value) return;
  await navigator.clipboard.writeText(value);
  ElMessage.success("已复制");
}

function reportError(error, title) {
  console.error(error);
  const raw = error?.shortMessage || error?.reason || error?.info?.error?.message || error?.message || title;
  ElNotification({
    title,
    message: String(raw).replace("execution reverted: ", "").slice(0, 180),
    type: "error",
    duration: 6000,
  });
}

function publicKeyFrom(form) {
  const values = [form.x0, form.x1, form.y0, form.y1];
  if (values.some((value) => !/^\d+$/.test(String(value).trim()))) {
    throw new Error("BLS 公钥坐标必须是十进制整数");
  }
  return { x: [BigInt(form.x0), BigInt(form.x1)], y: [BigInt(form.y0), BigInt(form.y1)] };
}

function mergeActivities(items) {
  const seen = new Set();
  activities.value = [...items, ...activities.value]
    .filter((item) => {
      if (seen.has(item.key)) return false;
      seen.add(item.key);
      return true;
    })
    .slice(0, 16);
}

async function switchToSepolia() {
  if (!window.ethereum) throw new Error("未检测到浏览器钱包，请先安装 MetaMask");
  try {
    await window.ethereum.request({ method: "wallet_switchEthereumChain", params: [{ chainId: SEPOLIA_CHAIN_HEX }] });
  } catch (error) {
    if (error.code !== 4902) throw error;
    await window.ethereum.request({
      method: "wallet_addEthereumChain",
      params: [{
        chainId: SEPOLIA_CHAIN_HEX,
        chainName: "Sepolia",
        nativeCurrency: { name: "Sepolia ETH", symbol: "ETH", decimals: 18 },
        rpcUrls: [rpcUrl.value],
        blockExplorerUrls: [EXPLORER_URL],
      }],
    });
  }
}

async function connectWallet() {
  try {
    if (!window.ethereum) throw new Error("未检测到浏览器钱包，请先安装 MetaMask");
    browserProvider.value = new BrowserProvider(window.ethereum, "any");
    const accounts = await browserProvider.value.send("eth_requestAccounts", []);
    account.value = accounts[0] ? normalizeAddress(accounts[0]) : "";
    chainId.value = Number((await browserProvider.value.getNetwork()).chainId);
    if (!onSepolia.value) await switchToSepolia();
    browserProvider.value = new BrowserProvider(window.ethereum, "any");
    signer.value = await browserProvider.value.getSigner();
    chainId.value = Number((await browserProvider.value.getNetwork()).chainId);
    ElMessage.success("钱包已连接");
    await Promise.allSettled([loadManagerMeta(), projectAddress.value ? loadProject() : null]);
  } catch (error) {
    reportError(error, "连接钱包失败");
    throw error;
  }
}

async function requireSigner() {
  if (!account.value || !signer.value) await connectWallet();
  if (!onSepolia.value) {
    await switchToSepolia();
    browserProvider.value = new BrowserProvider(window.ethereum, "any");
    signer.value = await browserProvider.value.getSigner();
    chainId.value = SEPOLIA_CHAIN_ID;
  }
  return signer.value;
}

async function loadManagerMeta() {
  if (!isAddress(managerAddress.value)) return;
  loading.manager = true;
  try {
    const contract = managerContract();
    const [implementation, verifier] = await Promise.all([contract.implementation(), contract.verifier()]);
    Object.assign(managerMeta, { implementation, verifier, online: true });
    await loadManagerEvents();
  } catch (error) {
    managerMeta.online = false;
    console.warn(error);
  } finally {
    loading.manager = false;
  }
}

async function loadManagerEvents() {
  try {
    const latest = await getReadProvider().getBlockNumber();
    const contract = managerContract();
    const events = await contract.queryFilter(contract.filters.ProjectCreated(), Math.max(0, latest - 9999), latest);
    managerMeta.projectCount = events.length;
    mergeActivities(events.slice(-10).reverse().map((event) => ({
      key: `${event.transactionHash}-${event.index}`,
      type: "project",
      title: "项目代理已创建",
      detail: `${decodeProjectId(event.args.projectId)} · ${shortAddress(event.args.proxy)}`,
      hash: event.transactionHash,
      block: event.blockNumber,
    })));
  } catch (error) {
    console.warn(error);
  }
}

async function predictProject(form) {
  loading.predict = true;
  try {
    if (!isAddress(form.owner)) throw new Error("请输入有效的项目所有者地址");
    const projectId = toBytes32(form.projectName);
    const userSalt = toBytes32(form.salt);
    const contract = managerContract();
    const [address, salt] = await Promise.all([
      contract.predictProjectAddress(projectId, form.owner, userSalt),
      contract.makeSalt(projectId, form.owner, userSalt),
    ]);
    return { address, salt };
  } catch (error) {
    reportError(error, "地址预测失败");
    throw error;
  } finally {
    loading.predict = false;
  }
}

async function createProject(form) {
  loading.create = true;
  try {
    const walletSigner = await requireSigner();
    if (!isAddress(form.owner)) throw new Error("请输入有效的项目所有者地址");
    const projectId = toBytes32(form.projectName);
    const userSalt = toBytes32(form.salt);
    const contract = managerContract(walletSigner);
    const predicted = await contract.predictProjectAddress(projectId, form.owner, userSalt);
    const tx = await contract.createProject(projectId, form.owner, userSalt, publicKeyFrom(form));
    ElMessage.info("交易已提交，正在等待链上确认");
    const receipt = await tx.wait();
    let proxy = predicted;
    for (const log of receipt.logs) {
      try {
        const parsed = managerInterface.parseLog(log);
        if (parsed?.name === "ProjectCreated") proxy = parsed.args.proxy;
      } catch {}
    }
    mergeActivities([{ key: tx.hash, type: "project", title: "项目创建成功", detail: `${form.projectName} · ${shortAddress(proxy)}`, hash: tx.hash, block: receipt.blockNumber }]);
    await bindProject(proxy);
    await loadManagerMeta();
    ElNotification({ title: "项目已创建", message: `代理地址 ${shortAddress(proxy, 10, 8)}`, type: "success" });
    return proxy;
  } catch (error) {
    reportError(error, "创建项目失败");
    throw error;
  } finally {
    loading.create = false;
  }
}

async function lookupProject(name) {
  loading.lookup = true;
  try {
    const result = await managerContract().projectProxy(toBytes32(name));
    if (result === ZeroAddress) throw new Error("该 Project ID 尚未创建");
    return result;
  } catch (error) {
    reportError(error, "查询项目失败");
    throw error;
  } finally {
    loading.lookup = false;
  }
}

async function bindProject(address) {
  loading.project = true;
  try {
    if (!isAddress(String(address).trim().toLowerCase())) throw new Error("请输入有效的项目代理地址");
    projectAddress.value = normalizeAddress(address);
    localStorage.setItem("randora.project", projectAddress.value);
    await loadProject();
    ElMessage.success("项目已载入");
  } catch (error) {
    projectMeta.valid = false;
    reportError(error, "载入项目失败");
    throw error;
  } finally {
    loading.project = false;
  }
}

async function loadProject() {
  if (!isAddress(projectAddress.value)) return;
  const contract = projectContract();
  const [owner, manager, verifier, projectId, count, paused, valid] = await Promise.all([
    contract.owner(), contract.manager(), contract.verifier(), contract.projectId(), contract.requestId(), contract.paused(), managerContract().isProjectProxy(projectAddress.value),
  ]);
  Object.assign(projectMeta, { valid, owner, manager, verifier, projectId, requestCount: count.toString(), paused });
  await loadProjectEvents();
}

async function loadProjectEvents() {
  loading.events = true;
  try {
    const latest = await getReadProvider().getBlockNumber();
    const contract = projectContract();
    const events = await contract.queryFilter("*", Math.max(0, latest - 9999), latest);
    const titles = { RandomnessRequested: "随机数请求已发起", RandomnessFulfilled: "BLS 验证通过", RandomnessConsumed: "随机数已消费" };
    mergeActivities(events.filter((event) => titles[event.fragment?.name]).slice(-12).reverse().map((event) => ({
      key: `${event.transactionHash}-${event.index}`,
      type: event.fragment.name === "RandomnessRequested" ? "request" : event.fragment.name === "RandomnessFulfilled" ? "fulfilled" : "consumed",
      title: titles[event.fragment.name],
      detail: `Request #${event.args.requestId.toString()}`,
      hash: event.transactionHash,
      block: event.blockNumber,
    })));
  } catch (error) {
    console.warn(error);
  } finally {
    loading.events = false;
  }
}

async function requestRandomness(seedValue) {
  loading.request = true;
  try {
    const contract = projectContract(await requireSigner());
    const tx = await contract.requestRandomness(toBytes32(seedValue));
    ElMessage.info("随机数请求已提交");
    const receipt = await tx.wait();
    let id = (BigInt(projectMeta.requestCount) + 1n).toString();
    for (const log of receipt.logs) {
      try {
        const parsed = projectInterface.parseLog(log);
        if (parsed?.name === "RandomnessRequested") id = parsed.args.requestId.toString();
      } catch {}
    }
    mergeActivities([{ key: tx.hash, type: "request", title: "随机数请求已发起", detail: `Request #${id}`, hash: tx.hash, block: receipt.blockNumber }]);
    await Promise.all([loadProject(), queryRequest(id)]);
    ElNotification({ title: `Request #${id}`, message: "请求已进入等待 BLS 签名状态", type: "success" });
    return id;
  } catch (error) {
    reportError(error, "发起随机数请求失败");
    throw error;
  } finally {
    loading.request = false;
  }
}

async function queryRequest(id) {
  loading.query = true;
  try {
    if (!/^\d+$/.test(String(id))) throw new Error("Request ID 必须是整数");
    const contract = projectContract();
    const [result, message] = await Promise.all([contract.getRequest(id), contract.getRequestMessage(id)]);
    Object.assign(requestResult, {
      loaded: true,
      id: String(id),
      requester: result.requester,
      seed: result.userSeed,
      blockNumber: result.blockNumber.toString(),
      randomness: result.randomness.toString(),
      status: Number(result.status),
      message,
    });
    return requestResult;
  } catch (error) {
    requestResult.loaded = false;
    reportError(error, "查询请求失败");
    throw error;
  } finally {
    loading.query = false;
  }
}

async function fulfillRandomness(id, signature) {
  loading.fulfill = true;
  try {
    if (!/^\d+$/.test(signature.x) || !/^\d+$/.test(signature.y)) throw new Error("BLS 签名坐标必须是十进制整数");
    const tx = await projectContract(await requireSigner()).fulfillRandomness(id, { x: BigInt(signature.x), y: BigInt(signature.y) });
    ElMessage.info("签名已提交，正在执行链上验证");
    const receipt = await tx.wait();
    mergeActivities([{ key: tx.hash, type: "fulfilled", title: "BLS 验证通过", detail: `Request #${id}`, hash: tx.hash, block: receipt.blockNumber }]);
    await queryRequest(id);
    ElMessage.success("随机数已写入链上");
  } catch (error) {
    reportError(error, "提交 BLS 签名失败");
    throw error;
  } finally {
    loading.fulfill = false;
  }
}

async function consumeRandomness(id) {
  loading.consume = true;
  try {
    const tx = await projectContract(await requireSigner()).consumeRandomness(id);
    const receipt = await tx.wait();
    mergeActivities([{ key: tx.hash, type: "consumed", title: "随机数已消费", detail: `Request #${id}`, hash: tx.hash, block: receipt.blockNumber }]);
    await queryRequest(id);
    ElMessage.success("随机数消费成功");
  } catch (error) {
    reportError(error, "消费随机数失败");
    throw error;
  } finally {
    loading.consume = false;
  }
}

async function togglePause() {
  loading.pause = true;
  try {
    const contract = projectContract(await requireSigner());
    const tx = projectMeta.paused ? await contract.unpause() : await contract.pause();
    await tx.wait();
    await loadProject();
    ElMessage.success(projectMeta.paused ? "项目已暂停" : "项目已恢复");
  } catch (error) {
    reportError(error, "更新项目状态失败");
    throw error;
  } finally {
    loading.pause = false;
  }
}

async function updatePublicKey(form) {
  loading.key = true;
  try {
    const tx = await projectContract(await requireSigner()).setPublicKey(publicKeyFrom(form));
    await tx.wait();
    ElMessage.success("BLS 公钥已更新");
  } catch (error) {
    reportError(error, "更新公钥失败");
    throw error;
  } finally {
    loading.key = false;
  }
}

async function saveConfiguration(manager, rpc) {
  if (!isAddress(String(manager).trim().toLowerCase())) throw new Error("管理合约地址无效");
  if (!/^https?:\/\//.test(rpc)) throw new Error("RPC 地址格式无效");
  managerAddress.value = normalizeAddress(manager);
  rpcUrl.value = rpc.trim();
  localStorage.setItem("randora.manager", managerAddress.value);
  localStorage.setItem("randora.rpc", rpcUrl.value);
  readProvider.value?.destroy?.();
  readProvider.value = null;
  await loadManagerMeta();
  ElMessage.success("网络配置已保存");
}

function handleAccountsChanged(accounts) {
  account.value = accounts[0] ? normalizeAddress(accounts[0]) : "";
  signer.value = null;
  if (account.value && browserProvider.value) browserProvider.value.getSigner().then((value) => (signer.value = value));
}

function handleChainChanged(value) {
  chainId.value = Number.parseInt(value, 16);
  browserProvider.value = null;
  signer.value = null;
}

async function initialize() {
  if (initialized.value) return;
  initialized.value = true;
  if (window.ethereum) {
    window.ethereum.on?.("accountsChanged", handleAccountsChanged);
    window.ethereum.on?.("chainChanged", handleChainChanged);
    try {
      const provider = new BrowserProvider(window.ethereum, "any");
      const accounts = await provider.send("eth_accounts", []);
      if (accounts.length) {
        browserProvider.value = provider;
        account.value = normalizeAddress(accounts[0]);
        signer.value = await provider.getSigner();
        chainId.value = Number((await provider.getNetwork()).chainId);
      }
    } catch {}
  }
  await loadManagerMeta();
  if (projectAddress.value) {
    try { await loadProject(); } catch { projectMeta.valid = false; }
  }
}

export function useRandomManager() {
  return {
    managerAddress, rpcUrl, projectAddress, account, chainId,
    walletReady, onSepolia, shortAccount, projectName, isProjectOwner,
    managerMeta, projectMeta, requestResult, activities, loading,
    initialize, connectWallet, loadManagerMeta, loadManagerEvents,
    predictProject, createProject, lookupProject, bindProject, loadProject, loadProjectEvents,
    requestRandomness, queryRequest, fulfillRandomness, consumeRandomness,
    togglePause, updatePublicKey, saveConfiguration,
  };
}
