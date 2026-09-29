<script>
  import { onMount } from 'svelte';

  const NOTICE_KINDS = new Set(['inform', 'success', 'warning', 'error']);
  const STACK_POSITIONS = new Set(['top-right', 'top-left', 'bottom-right', 'bottom-left']);
  const PROMPT_POSITIONS = new Set(['bottom-center', 'center-right', 'center-left']);
  const LEAVE_TIME = 360;

  const kindMeta = {
    inform: { title: "Ship's notice", sigil: '◆' },
    success: { title: 'Ledger marked', sigil: '✓' },
    warning: { title: 'Mind the tide', sigil: '!' },
    error: { title: 'Action failed', sigil: '×' }
  };

  let settings = {
    maxVisible: 4,
    position: 'top-right',
    promptPosition: 'bottom-center'
  };

  let notices = [];
  let progress = null;
  let prompt = null;
  let active = false;
  let nextNoticeId = 1;
  let nextProgressId = 1;
  let progressExitTimer;
  let uiSynced = false;

  const expiryTimers = new Map();
  const leaveTimers = new Map();

  $: active = notices.length > 0 || progress !== null || prompt !== null;
  $: setDocumentActive(active);

  function setDocumentActive(state) {
    document.body.classList.toggle('seam-active', state);
  }

  function cleanLine(value) {
    return String(value ?? '').replace(/[\r\n\t]+/g, ' ').replace(/\s{2,}/g, ' ').trim();
  }

  function clamp(value, minimum, maximum, fallback) {
    const number = Number(value);
    if (!Number.isFinite(number)) return fallback;
    return Math.min(maximum, Math.max(minimum, number));
  }

  function nui(name, data = {}) {
    const resource = typeof window.GetParentResourceName === 'function'
      ? window.GetParentResourceName()
      : null;

    if (!resource) return Promise.resolve();

    return fetch(`https://${resource}/${name}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(data)
    }).catch(() => undefined);
  }

  function clearTimer(map, id) {
    const timer = map.get(id);
    if (timer !== undefined) window.clearTimeout(timer);
    map.delete(id);
  }

  function removeNotice(id) {
    clearTimer(expiryTimers, id);
    clearTimer(leaveTimers, id);
    notices = notices.filter((notice) => notice.id !== id);
  }

  function dismissNotice(id) {
    const notice = notices.find((entry) => entry.id === id);
    if (!notice || notice.leaving) return;

    clearTimer(expiryTimers, id);
    notices = notices.map((entry) => entry.id === id ? { ...entry, leaving: true } : entry);
    leaveTimers.set(id, window.setTimeout(() => removeNotice(id), LEAVE_TIME));
  }

  function enforceNoticeLimit() {
    const visible = notices.filter((notice) => !notice.leaving);
    while (visible.length > settings.maxVisible) {
      const oldest = visible.shift();
      if (oldest) dismissNotice(oldest.id);
    }
  }

  function addNotice(data) {
    const message = cleanLine(data.message);
    if (!message) return;

    const requestedKind = cleanLine(data.kind).toLowerCase();
    const kind = NOTICE_KINDS.has(requestedKind) ? requestedKind : 'inform';
    const notice = {
      id: nextNoticeId++,
      kind,
      title: cleanLine(data.title) || kindMeta[kind].title,
      message,
      duration: clamp(data.duration, 800, 30000, 4000),
      leaving: false
    };

    notices = [...notices, notice];
    expiryTimers.set(notice.id, window.setTimeout(() => dismissNotice(notice.id), notice.duration));
    enforceNoticeLimit();
  }

  function clearNotices() {
    for (const notice of notices) dismissNotice(notice.id);
  }

  function updateSetup(data) {
    const position = STACK_POSITIONS.has(data.position) ? data.position : 'top-right';
    const promptPosition = PROMPT_POSITIONS.has(data.prompt) ? data.prompt : 'bottom-center';

    settings = {
      maxVisible: Math.round(clamp(data.maxVisible, 1, 8, 4)),
      position,
      promptPosition
    };

    if (data.accent) document.documentElement.style.setProperty('--inform', String(data.accent));
    if (prompt) prompt = { ...prompt, position: promptPosition };
    enforceNoticeLimit();
    uiSynced = true;
  }

  function updateProgress(data) {
    if (progressExitTimer !== undefined) {
      window.clearTimeout(progressExitTimer);
      progressExitTimer = undefined;
    }

    if (data.visible === false) {
      if (!progress) return;

      progress = {
        ...progress,
        leaving: true,
        completed: data.completed !== false
      };

      progressExitTimer = window.setTimeout(() => {
        progress = null;
        progressExitTimer = undefined;
      }, 260);
      return;
    }

    progress = {
      id: nextProgressId++,
      label: cleanLine(data.label) || 'Working',
      duration: clamp(data.duration, 100, 3600000, 1000),
      canCancel: data.canCancel !== false,
      leaving: false,
      completed: false
    };
  }

  function updatePrompt(data) {
    if (data.visible === false) {
      prompt = null;
      return;
    }

    const text = cleanLine(data.text);

    // Never render a key by itself. This is the guard that removes the stray
    // permanent "E" caused by callers sending an empty prompt.
    if (!text) {
      prompt = null;
      return;
    }

    prompt = {
      text,
      key: (cleanLine(data.key) || 'E').slice(0, 12),
      position: settings.promptPosition
    };
  }

  function handleMessage(event) {
    const payload = event.data || {};
    const data = payload.data || {};

    switch (payload.action) {
      case 'setup':
        updateSetup(data);
        break;
      case 'notify':
        addNotice(data);
        break;
      case 'clear':
        clearNotices();
        break;
      case 'progress':
        updateProgress(data);
        break;
      case 'prompt':
        updatePrompt(data);
        break;
    }
  }

  function resetUi() {
    for (const timer of expiryTimers.values()) window.clearTimeout(timer);
    for (const timer of leaveTimers.values()) window.clearTimeout(timer);
    expiryTimers.clear();
    leaveTimers.clear();

    if (progressExitTimer !== undefined) window.clearTimeout(progressExitTimer);

    notices = [];
    progress = null;
    prompt = null;
  }

  onMount(() => {
    document.documentElement.dataset.seamUi = 'ready';
    window.addEventListener('message', handleMessage);

    let attempts = 0;
    const requestSync = () => {
      if (uiSynced || attempts >= 4) return;
      attempts += 1;
      nui('ready');
    };

    requestSync();
    const readyRetry = window.setInterval(() => {
      if (uiSynced || attempts >= 4) {
        window.clearInterval(readyRetry);
        return;
      }
      requestSync();
    }, 750);

    return () => {
      window.clearInterval(readyRetry);
      window.removeEventListener('message', handleMessage);
      resetUi();
      document.body.classList.remove('seam-active');
      delete document.documentElement.dataset.seamUi;
    };
  });
</script>

{#if active}
  <main class="ui-layer" aria-label="SeaM interface">
    {#if notices.length}
      <section class="notice-stack {settings.position}" aria-live="polite" aria-label="Notifications">
        {#each notices as notice (notice.id)}
          <article class="notice {notice.kind}" class:leaving={notice.leaving}>
            <span class="notice-sigil" aria-hidden="true">{kindMeta[notice.kind].sigil}</span>
            <div class="notice-copy">
              <div class="notice-heading">
                <strong>{notice.title}</strong>
                <i></i>
              </div>
              <p>{notice.message}</p>
            </div>
            <span class="notice-timer" style:animation-duration={`${notice.duration}ms`}></span>
          </article>
        {/each}
      </section>
    {/if}

    {#if progress}
      <section
        class="progress-card"
        class:leaving={progress.leaving}
        class:completed={progress.completed}
        aria-label={progress.label}
      >
        <header>
          <div>
            <span class="eyebrow">Task under way</span>
            <strong>{progress.label}</strong>
          </div>
          {#if progress.canCancel}
            <span class="cancel"><kbd>X</kbd> Break off</span>
          {/if}
        </header>
        <div class="progress-track">
          {#key progress.id}
            <span class="progress-fill" style:animation-duration={`${progress.duration}ms`}></span>
          {/key}
        </div>
      </section>
    {/if}

    {#if prompt}
      <section class="interaction-prompt {prompt.position}" aria-label={`${prompt.key}: ${prompt.text}`}>
        <kbd>{prompt.key}</kbd>
        <span class="prompt-rule"><i></i></span>
        <strong>{prompt.text}</strong>
      </section>
    {/if}
  </main>
{/if}
