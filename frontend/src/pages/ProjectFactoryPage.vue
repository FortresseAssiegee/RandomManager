<script setup>
import { useRandomManager } from "../composables/useRandomManager";
import UnifiedProjectRequestDirectory from "../components/UnifiedProjectRequestDirectory.vue";

const store = useRandomManager();
const directoryInstanceKey = Date.now();
</script>

<template>
  <main class="route-page">
    <section class="page-banner factory-banner">
      <div>
        <span class="page-index">01</span>
        <span class="section-kicker">PROJECT FACTORY</span>
        <h1>项目工厂</h1>
        <p>集中管理当前项目、链上历史以及每个项目产生的随机请求。</p>
      </div>
      <div class="banner-fact">
        <small>FACTORY CONTRACT</small>
        <strong>RandomManager</strong>
        <code>{{ store.managerAddress.value }}</code>
      </div>
    </section>
    <section class="route-content factory-directory-content">
      <UnifiedProjectRequestDirectory :key="directoryInstanceKey" />
    </section>
  </main>
</template>
