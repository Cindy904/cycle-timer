import { LIMITS, makeStep, makeGroup, makeProject, makeQuickSingle, makeQuickMulti,
  compilePlan, clock, readable, progress, makeRecord } from './core.js';

const root = document.getElementById('app');
const audio = document.getElementById('completion-sound');
const STORE_KEY = 'cycle-timer-web-v1';
const defaults = () => ({ projects: [], records: [], active: null, settings: { sound: true }, version: 1 });
let data;
try {
  data = { ...defaults(), ...JSON.parse(localStorage.getItem(STORE_KEY) || '{}') };
  if (!Array.isArray(data.projects) || !Array.isArray(data.records)) throw Error('bad data');
} catch { data = defaults(); }
let route = { name: 'home' };
let stack = [];
let toastTimer;
let swipeOpen = false;
let swipeGesture = null;
let lastStarSession = null;
let observedSessionId = null;
let observedSegmentIndex = null;
let soundContext = null;
let soundBuffer = null;
let soundLoadPromise = null;
let scheduledFinishSource = null;
let scheduledFinishSessionId = null;
let renderedTimerSessionId = null;
let renderedTimerStatus = null;
let renderedTimerSegmentIndex = null;
const quickInitial = kind => ({ name: 'quick', kind, singleSeconds: 0, singleRepeats: 1,
  steps: [makeStep(1), makeStep(2)], cycles: 1, hasRest: kind === 'single', restSeconds: 0 });

function persist() {
  try { localStorage.setItem(STORE_KEY, JSON.stringify(data)); }
  catch { notice('本地空间不足，请导出数据备份'); }
}
function clone(value) { return JSON.parse(JSON.stringify(value)); }
function esc(value) { return String(value ?? '').replace(/[&<>"']/g, char => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[char])); }
function notice(message) {
  document.querySelector('.toast')?.remove();
  const el = document.createElement('div'); el.className = 'toast'; el.textContent = message; document.body.append(el);
  clearTimeout(toastTimer); toastTimer = setTimeout(() => el.remove(), 3200);
}
function navigate(next, push = true) {
  if (push) stack.push(route);
  route = next; render(); window.scrollTo(0, 0);
}
function back() {
  if (route.name === 'timer') { navigate({ name: 'home' }, false); stack = []; return; }
  route = stack.pop() || { name: 'home' }; render(); window.scrollTo(0, 0);
}
function planOf(project) { try { return { plan: compilePlan(project) }; } catch (error) { return { error: error.message }; } }
function projectAt(index) { return data.projects[Number(index)]; }
function savedProject(project) { return data.projects.some(item => item.id === project.id); }
function icon(name, className = '') {
  const shapes = {
    back: '<path d="m15 3-9 9 9 9"/>',
    repeat: '<path d="M4 9V7a3 3 0 0 1 3-3h12m-4-3 4 3-4 3M20 15v2a3 3 0 0 1-3 3H5m4-3-4 3 4 3"/>',
    layers: '<path d="m12 2 9 5-9 5-9-5 9-5Z"/><path d="m3 11 9 5 9-5M3 15l9 5 9-5"/>',
    layersFilled: '<path d="m12 2 9 5-9 5-9-5 9-5Zm-9 9 9 5 9-5v3l-9 5-9-5v-3Zm0 6 9 5 9-5v2l-9 5-9-5v-2Z" fill="currentColor" stroke="none"/>',
    timer: '<path d="M12 5V2m-2 0h4M5.4 8.1A8 8 0 1 0 12 5"/><path d="M12 8v5l-3-3"/>',
    bars: '<path d="M3 21h18"/><rect x="4" y="10" width="3" height="9" rx=".7" fill="currentColor" stroke="none"/><rect x="9" y="4" width="3" height="15" rx=".7" fill="currentColor" stroke="none"/><rect x="14" y="7" width="3" height="12" rx=".7" fill="currentColor" stroke="none"/><rect x="19" y="13" width="3" height="6" rx=".7" fill="currentColor" stroke="none"/>',
    history: '<path d="M4 4v5h5"/><path d="M4.8 9a8 8 0 1 1-.6 5"/><path d="M12 7v5l3 2"/>',
    settings: '<path d="M10 2h4l.7 2.4 2 .9 2.2-1.1 2.8 2.8-1.1 2.2.9 2L24 12v4l-2.5.7-.9 2 1.1 2.2-2.8 2.8-2.2-1.1-2 .9L14 26h-4l-.7-2.5-2-.9-2.2 1.1-2.8-2.8 1.1-2.2-.9-2L0 16v-4l2.5-.7.9-2-1.1-2.2 2.8-2.8 2.2 1.1 2-.9L10 2Z" transform="translate(3 2) scale(.75)"/><circle cx="12" cy="12" r="3"/>',
    settingsFilled: '<path d="M10 2h4l.7 2.4 2 .9 2.2-1.1 2.8 2.8-1.1 2.2.9 2L24 12v4l-2.5.7-.9 2 1.1 2.2-2.8 2.8-2.2-1.1-2 .9L14 26h-4l-.7-2.5-2-.9-2.2 1.1-2.8-2.8 1.1-2.2-.9-2L0 16v-4l2.5-.7.9-2-1.1-2.2 2.8-2.8 2.2 1.1 2-.9L10 2Z" transform="translate(3 2) scale(.75)" fill="currentColor" stroke="none"/><circle cx="12" cy="12" r="2.5" fill="white" stroke="none"/>',
    play: '<path d="m7 4 13 8-13 8V4Z" fill="currentColor" stroke="none"/>',
    pause: '<path d="M7 4h3v16H7zM14 4h3v16h-3z" fill="currentColor" stroke="none"/>',
    arrow: '<path d="M5 19 19 5M8 5h11v11"/>',
    turnRight: '<path d="M5 4v7a6 6 0 0 0 6 6h8m-4-4 4 4-4 4"/>',
    clockFace: '<circle cx="12" cy="12" r="9"/><path d="M12 6v6l4 2"/>',
    more: '<circle cx="12" cy="12" r="9"/><circle cx="8" cy="12" r=".7" fill="currentColor"/><circle cx="12" cy="12" r=".7" fill="currentColor"/><circle cx="16" cy="12" r=".7" fill="currentColor"/>',
    ellipsis: '<circle cx="5" cy="12" r="1.5" fill="currentColor" stroke="none"/><circle cx="12" cy="12" r="1.5" fill="currentColor" stroke="none"/><circle cx="19" cy="12" r="1.5" fill="currentColor" stroke="none"/>',
    details: '<rect x="3" y="4" width="18" height="16" rx="2"/><path d="M8 9h3m-3 4h3m-3 4h3m3-8h4m-4 4h4m-4 4h4"/>',
    pencil: '<path d="m4 20 4-.8L19.4 7.8a2 2 0 0 0-2.8-2.8L5.2 16.4 4 20Zm11-12 2.8 2.8"/>',
    copy: '<rect x="8" y="8" width="12" height="12" rx="2"/><path d="M16 8V5a2 2 0 0 0-2-2H5a2 2 0 0 0-2 2v9a2 2 0 0 0 2 2h3"/>',
    up: '<path d="M12 20V4m-6 6 6-6 6 6"/>',
    down: '<path d="M12 4v16m-6-6 6 6 6-6"/>',
    archive: '<rect x="3" y="4" width="18" height="4" rx="1"/><path d="M5 8v12h14V8m-10 5h6"/>',
    trash: '<path d="M4 6h16m-13 0 1 15h8l1-15M9 6V4h6v2m-5 4v7m4-7v7"/>',
    check: '<path d="m5 12 5 5L20 7"/>',
    clock: '<path d="M12 6v6H7"/>',
    digital: '<path d="M8 3 6 21M18 3l-2 18M3 9h18M2 15h18"/>'
  };
  return `<svg class="svg-icon ${className}" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">${shapes[name] || ''}</svg>`;
}
function navBar(title, right = '') {
  return `<div class="top-row"><button class="back" data-action="back" aria-label="返回">${icon('back')}</button><div class="center-title">${esc(title)}</div>${right || '<span class="top-spacer"></span>'}</div>`;
}
function tabbar(tab) {
  return `<nav class="tabbar" aria-label="主导航">
    <button data-action="tab-home" class="${tab === 'home' ? 'active' : ''}"><span class="tab-icon">${icon('layersFilled')}</span>项目</button>
    <button data-action="tab-history" class="${tab === 'history' ? 'active' : ''}"><span class="tab-icon">${icon('bars')}</span>记录</button>
    <button data-action="tab-settings" class="${tab === 'settings' ? 'active' : ''}"><span class="tab-icon">${icon('settingsFilled')}</span>设置</button>
  </nav>`;
}
function mainButton(text, action, disabled = false, teal = false) {
  const label = text.startsWith('▶ ') ? `${icon('play')}<span>${esc(text.slice(2))}</span>` :
    text.startsWith('Ⅱ ') ? `${icon('pause')}<span>${esc(text.slice(2))}</span>` : esc(text);
  return `<button class="main-button ${teal ? 'teal' : ''}" data-action="${action}" ${disabled ? 'disabled' : ''}>${label}</button>`;
}
function bottomButton(text, action, disabled = false) {
  return `<div class="bottom-action">${mainButton(text, action, disabled)}</div>`;
}
function countField(label, path, value, suffix = '次') {
  return `<div class="count-row"><span>${esc(label)}</span><span class="count-control"><input type="text" inputmode="numeric" pattern="[0-9]*" data-bind="${esc(path)}" data-number="count" value="${esc(value)}" aria-label="${esc(label)}"><span>${suffix}</span></span></div>`;
}
function toggleField(label, path, checked) {
  return `<label class="toggle-row"><span>${esc(label)}</span><input class="switch" type="checkbox" data-bind="${esc(path)}" ${checked ? 'checked' : ''}></label>`;
}
function durationField(label, path, seconds) {
  const parts = [Math.floor(seconds / 3600), Math.floor(seconds % 3600 / 60), seconds % 60];
  const units = ['小时', '分钟', '秒'];
  return `<div class="duration-field"><label>${esc(label)}</label><div class="duration-grid">${parts.map((value, i) => {
    const limit = i === 0 ? 23 : 59;
    return `<div class="duration-col" data-duration="${esc(path)}" data-part="${i}">
      <div class="duration-selection"><b>${units[i]}</b></div>
      <div class="duration-wheel" data-duration="${esc(path)}" data-part="${i}" data-value="${value}" role="listbox" tabindex="0" aria-label="${esc(label)}${units[i]}">
        <div class="duration-spacer" aria-hidden="true"></div>
        ${Array.from({length:limit+1}, (_, number) => `<button type="button" tabindex="-1" role="option" aria-selected="${number === value}" class="duration-wheel-item ${number === value ? 'is-selected' : ''}" data-action="wheel-pick" data-value="${number}">${number}</button>`).join('')}
        <div class="duration-spacer" aria-hidden="true"></div>
      </div>
      <input class="duration-editor" type="text" inputmode="numeric" pattern="[0-9]*" data-bind="${esc(path)}" data-part="${i}" data-number="duration" value="${value}" aria-label="手动输入${esc(label)}${units[i]}">
    </div>`;
  }).join('')}</div></div>`;
}
function stepFields(step, path, index, editing = false) {
  const kind = step.kind;
  const steps = getPath(path.slice(0, path.lastIndexOf('.')));
  const position = Number(path.slice(path.lastIndexOf('.') + 1));
  const total = editing ? route.draft.groups.reduce((n, group) => n + group.steps.length, 0) : steps.length;
  const menuOpen = route.stepMenuPath === path;
  const stepOption = (operation, label, symbol, disabled = false) =>
    `<button class="menu-item ${operation === 'delete' ? 'destructive' : ''}" data-action="step-option" data-path="${path}" data-operation="${operation}" ${disabled ? 'disabled' : ''}><span>${label}</span>${icon(symbol)}</button>`;
  return `<div class="step-card card ${menuOpen ? 'menu-open' : ''}">
    <div class="step-head"><input class="name-input" type="text" maxlength="30" data-bind="${path}.name" value="${esc(step.name)}" placeholder="步骤名称" aria-label="步骤名称">
      <button class="step-more" data-action="step-menu" data-path="${path}" aria-label="步骤操作" aria-expanded="${menuOpen}">${icon('more')}</button></div>
    ${menuOpen ? `<div class="menu-popover step-popover" role="menu">
      ${stepOption('copy', '复制步骤', 'copy', total >= (editing ? LIMITS.steps : 8))}
      ${stepOption('up', '上移', 'up', position === 0)}
      ${stepOption('down', '下移', 'down', position === steps.length - 1)}
      ${stepOption('delete', '删除', 'trash', steps.length <= 1)}
    </div>` : ''}
    <div class="segmented"><button data-action="step-kind" data-path="${path}" data-kind="focus" class="${kind === 'focus' ? 'selected' : ''}">计时</button><button data-action="step-kind" data-path="${path}" data-kind="interval" class="${kind === 'interval' ? 'selected' : ''}">间隔</button></div>
    ${durationField('持续时间', `${path}.durationSeconds`, step.durationSeconds)}
    ${kind === 'focus' ? `${countField('重复', `${path}.repetitions`, step.repetitions)}
      ${step.repetitions > 1 ? `<div style="margin-top:20px">${toggleField('每次计时之间休息', `${path}.restOn`, step.repetitionIntervalSeconds > 0)}</div>
        ${step.repetitionIntervalSeconds > 0 ? durationField('休息时长', `${path}.repetitionIntervalSeconds`, step.repetitionIntervalSeconds) : ''}` : ''}` : ''}
  </div>`;
}

function homePage() {
  const visible = data.projects.filter(project => !project.isArchived).sort((a,b) => (b.updatedAt || '').localeCompare(a.updatedAt || ''));
  return `<main class="page home-page"><button class="home-more" data-action="home-menu" aria-label="更多选项" aria-expanded="${!!route.homeMenuOpen}">${icon('ellipsis')}</button>
    ${route.homeMenuOpen ? `<div class="menu-popover home-popover"><button class="menu-item" data-action="show-archive"><span>查看归档</span>${icon('archive')}</button></div>` : ''}
    <h1 class="page-title">循环计时</h1>
    <div class="cards-two"><button class="template" data-action="quick-single"><span class="symbol">${icon('repeat')}</span><strong>单步骤重复</strong><small>45秒 × 8次</small></button>
      <button class="template sky" data-action="quick-multi"><span class="symbol">${icon('layersFilled')}</span><strong>多步骤循环</strong><small>（40秒+20秒）×5组</small></button></div>
    ${data.active ? `<div class="active-swipe"><button class="swipe-remove" data-action="discard-active" aria-label="移除当前计时">${icon('trash')}<span>移除</span></button>
      <div class="card active-card swipe-front ${swipeOpen ? 'open' : ''}"><div class="row"><span class="active-icon">${icon('timer')}</span><div style="flex:1"><div class="hint">${data.active.status === 'completed' || data.active.status === 'endedEarly' ? '查看本次结果' : '正在进行'}</div><strong>${esc(data.active.project.title)}</strong></div><button class="resume-button" data-action="open-active" aria-label="返回当前计时">${icon('arrow')}</button></div></div></div>` : ''}
    <h2 class="section-heading">我的项目 <button data-action="new-project">＋ 新建</button></h2>
    ${visible.length ? visible.map(project => {
      const index = data.projects.indexOf(project);
      return `<div class="card project-card ${route.menuIndex === index ? 'menu-open' : ''}" style="margin-bottom:15px"><div class="row"><h2>${esc(project.title)}</h2><button class="project-more" data-action="project-menu" data-index="${index}" aria-label="项目操作" aria-expanded="${route.menuIndex === index}">${icon('ellipsis')}</button></div>
        ${route.menuIndex === index ? `<div class="menu-popover project-popover">
          <button class="menu-item" data-action="view-project" data-index="${index}"><span>查看详情</span>${icon('details')}</button>
          <button class="menu-item" data-action="edit-project" data-index="${index}"><span>编辑</span>${icon('pencil')}</button>
          <button class="menu-item" data-action="copy-project" data-index="${index}"><span>复制</span>${icon('copy')}</button>
          <button class="menu-item" data-action="archive-project" data-index="${index}"><span>归档</span>${icon('archive')}</button>
        </div>` : ''}
        <div class="card-actions"><button class="small-button" data-action="edit-project" data-index="${index}">${icon('pencil')} 编辑</button><button class="small-button primary" data-action="start-project" data-index="${index}">${icon('play')} 开始</button></div></div>`;
    }).join('') : `<div class="card empty"><strong>还没有项目</strong><span class="muted">点击「新建」，创建自己的计时项目。</span></div>`}
    </main>${tabbar('home')}`;
}

function quickPage() {
  const single = route.kind === 'single';
  const project = single ? makeQuickSingle(route.singleSeconds, route.singleRepeats, route.hasRest ? route.restSeconds : 0) :
    makeQuickMulti(route.steps, route.cycles, route.hasRest ? route.restSeconds : 0);
  const { plan } = planOf(project);
  return `<main class="page no-tab">${navBar(single ? '单步骤重复' : '多步骤循环')}
    ${single ? `<div class="card" style="margin-top:26px">${durationField('单次时长', 'route.singleSeconds', route.singleSeconds)}${countField('重复', 'route.singleRepeats', route.singleRepeats)}</div>
      <div class="card" style="margin-top:18px">${toggleField('每次计时之间间隔', 'route.hasRest', route.hasRest)}${route.hasRest ? durationField('间隔时长', 'route.restSeconds', route.restSeconds) : ''}</div>` :
      `<div class="section-heading" style="font-size:18px">步骤配置 <span class="hint">${route.steps.length} / 8</span></div>
      ${route.steps.map((step,i) => stepFields(step, `route.steps.${i}`, i)).join('')}
      <button class="dashed" data-action="add-quick-step" ${route.steps.length >= 8 ? 'disabled' : ''}>＋ 添加步骤</button>
      <div class="card" style="margin-top:20px">${countField('整套循环', 'route.cycles', route.cycles, '遍')}
        ${route.cycles > 1 ? `<div style="margin-top:20px">${toggleField('循环之间间隔', 'route.hasRest', route.hasRest)}</div>${route.hasRest ? durationField('间隔时长', 'route.restSeconds', route.restSeconds) : ''}` : ''}</div>`}
    <div class="total-row"><span>预计总时长</span><span>${plan ? clock(plan.totalSeconds) : '—'}</span></div>
    </main>${bottomButton('▶ 开始计时','start-quick',!plan || !!data.active)}`;
}

function editorPage() {
  const project = route.draft, stepCount = project.groups.reduce((n,g) => n + g.steps.length,0);
  const { plan } = planOf({ ...project, title: project.title.trim() || '预览' });
  return `<main class="page no-tab">${navBar(route.isNew ? '新建项目' : '编辑项目', '<button class="plain-action" data-action="save-project">保存</button>')}
    <div class="card" style="margin-top:24px"><label class="field-label">项目名称</label><input class="title-input" type="text" maxlength="30" data-bind="route.draft.title" value="${esc(project.title)}" placeholder="例如：晨间拉伸"></div>
    <h2 class="section-heading" style="font-size:18px">步骤配置 <span class="hint">${stepCount} / ${LIMITS.steps}</span></h2>
    ${stepCount === 0 ? '<div class="dashed" style="height:124px;margin:0" aria-label="暂无步骤"></div>' : ''}
    ${project.groups.map((group, gi) => group.steps.length === 0 && project.groups.length === 1 ? '' : `<div class="card editor-group" style="margin-top:16px">
      ${project.groups.length > 1 ? `<input class="name-input" type="text" maxlength="30" data-bind="route.draft.groups.${gi}.name" value="${esc(group.name)}" aria-label="循环组名称">
        ${countField('本组循环', `route.draft.groups.${gi}.repetitions`, group.repetitions)}
        ${group.repetitions > 1 ? durationField('组循环之间', `route.draft.groups.${gi}.loopIntervalSeconds`, group.loopIntervalSeconds) : ''}` : ''}
      ${group.steps.map((step,si) => stepFields(step, `route.draft.groups.${gi}.steps.${si}`, `${gi}-${si}`, true)).join('')}
      ${project.groups.length > 1 ? `<button class="small-button danger" data-action="remove-group" data-index="${gi}" style="margin-top:15px">删除本组</button>` : ''}
    </div>`).join('')}
    <button class="dashed" data-action="add-editor-step" ${stepCount >= LIMITS.steps ? 'disabled' : ''}>＋ 添加步骤</button>
    ${stepCount > 0 ? `<button class="add-group-link" data-action="add-group" ${project.groups.length >= LIMITS.groups ? 'disabled' : ''}>添加循环组</button>` : ''}
    <div class="card summary-card">${countField('整套循环', 'route.draft.repetitions', project.repetitions, '遍')}
      ${project.repetitions > 1 ? `<div style="margin-top:20px">${toggleField('循环之间休息', 'route.draft.projectRestOn', project.loopIntervalSeconds > 0)}</div>${project.loopIntervalSeconds > 0 ? durationField('休息时长','route.draft.loopIntervalSeconds',project.loopIntervalSeconds) : ''}` : ''}</div>
    <div class="card editor-total"><span>预计总时长</span><strong>${plan ? clock(plan.totalSeconds) : '00:00'}</strong></div>
    </main>`;
}

function historyPage() {
  const completed = data.records.filter(record => record.status === 'completed').length;
  const focusSeconds = data.records.reduce((sum,record) => sum + (record.focusSeconds || 0),0);
  return `<main class="page"><h1 class="page-title">历史记录</h1>
    <div class="stats"><div class="card stat"><span class="stat-icon">${icon('layers')}</span><strong>${completed}</strong><small class="muted">完成项目数</small></div>
      <div class="card stat"><span class="stat-icon" style="color:var(--teal)">${icon('timer')}</span><strong>${readable(focusSeconds)}</strong><small class="muted">有效计时</small></div></div>
    <div style="margin-top:25px">${data.records.length ? data.records.map(record => `<div class="card" style="margin-bottom:14px"><div class="history-item">
      <span class="check ${record.status === 'completed' ? '' : 'early'}">${icon(record.status === 'completed' ? 'check' : 'clock')}</span><div><strong>${esc(record.project.title)}</strong>
      <small>${new Date(record.startedAt).toLocaleString('zh-CN')}</small><small>计时段 ${record.completedFocusCount}/${record.plannedFocusCount} · 完成次数 ${record.completedProjectLoops}/${record.plannedProjectLoops}</small></div>
      <span class="time">${clock(record.focusSeconds)}</span></div></div>`).join('') : `<div class="card muted">完成一次计时后，记录会出现在这里。</div>`}</div>
    </main>${tabbar('history')}`;
}
function settingsPage() {
  return `<main class="page"><h1 class="page-title">设置</h1>
    <section class="setting-section"><div class="hint">提醒</div><div class="card">
      ${toggleField('提示声音', 'data.settings.sound', data.settings.sound)}
      <button class="sound-preview" data-action="test-sound" ${data.settings.sound ? '' : 'disabled'}>试听提示音</button>
      <hr class="divider"><div class="warning">网页在锁屏或切到后台后无法保证准时响铃。请在需要提醒的长时间计时中使用原生版。</div>
    </div></section>
    <section class="setting-section"><div class="hint">数据备份</div><div class="card stack"><span class="muted" style="font-size:14px">项目和记录只存在当前浏览器中，不会自动同步到其他设备。</span>
      <div class="row"><button class="small-button" data-action="export-data">导出备份</button><button class="small-button" data-action="import-data">导入备份</button></div>
      <input id="import-file" class="hidden" type="file" accept="application/json,.json"></div></section>
    <section class="setting-section"><div class="hint">关于</div><div class="card"><div class="data-row"><span>应用</span><span>循环计时</span></div><div class="data-row"><span>版本</span><span>网页版 1.0</span></div></div></section>
    </main>${tabbar('settings')}`;
}
function detailPage() {
  const project = data.projects.find(item => item.id === route.id);
  if (!project) { route = { name: 'home' }; return homePage(); }
  const { plan } = planOf(project);
  const history = data.records.filter(record => record.project.id === project.id);
  const completed = history.reduce((sum,record) => sum + (record.completedProjectLoops || 0),0);
  const effective = history.reduce((sum,record) => sum + (record.focusSeconds || 0),0);
  return `<main class="page no-tab">${navBar(project.title, '<button class="plain-action" data-action="back">完成</button>')}
    <section class="detail-section"><small>当前方案</small><div class="card">
      <div class="data-row"><span>循环组</span><span>${project.groups.length}</span></div>
      <div class="data-row"><span>整套重复</span><span>${project.repetitions}次</span></div>
      ${plan ? `<div class="data-row"><span>总时长</span><span>${readable(plan.totalSeconds)}</span></div><div class="data-row"><span>计时段</span><span>${plan.focusCount}个</span></div>
      <button class="plain-action" style="padding:15px 0;text-align:left" data-action="flow">查看完整执行顺序</button>` : ''}</div></section>
    <section class="detail-section"><small>历史投入</small><div class="card"><div class="data-row"><span>完成次数</span><span>${completed}</span></div><div class="data-row"><span>有效计时</span><span>${readable(effective)}</span></div></div></section>
    <section class="detail-section"><small>最近记录</small><div class="card">${history.length ? history.slice(0,20).map(record => `<div class="data-row"><span>${new Date(record.startedAt).toLocaleString('zh-CN')}</span><span>${record.completedFocusCount}/${record.plannedFocusCount}</span></div>`).join('') : '<span class="muted">还没有记录</span>'}</div></section>
    </main>`;
}
function flowPage() {
  const project = data.projects.find(item => item.id === route.id);
  if (!project) { route = { name: 'home' }; return homePage(); }
  const { plan } = planOf(project);
  return `<main class="page no-tab flow-page"><div class="top-row"><span class="top-spacer"></span><div class="center-title">完整执行顺序</div><button class="plain-action" data-action="back">完成</button></div>
    <div class="flow-list">${plan ? plan.segments.map((segment,i) => `<div class="flow-step">
      <span class="flow-number ${segment.kind === 'interval' ? 'interval' : ''}">${i+1}</span>
      <span class="flow-copy"><strong>${esc(segment.title)}</strong><small>第 ${segment.projectRepeat} 套 · ${esc(segment.groupName)} · 第 ${segment.groupRepeat} 遍</small></span>
      <span class="flow-time">${clock(segment.durationSeconds)}</span></div>`).join('') : '配置需要检查'}</div></main>`;
}
function clockView(state) {
  const fraction = Math.max(0,Math.min(1,state.remainingSegmentSeconds / Math.max(1,state.segment.durationSeconds)));
  const ticks = Array.from({length:60},(_,i) => {
    const angle = i * 6 * Math.PI / 180;
    const r1 = i % 5 === 0 ? 84 : 88, r2 = 93;
    return `<line x1="${100+Math.sin(angle)*r1}" y1="${100-Math.cos(angle)*r1}" x2="${100+Math.sin(angle)*r2}" y2="${100-Math.cos(angle)*r2}" stroke="${i%5===0?'#2d392e':'#e9dfcc'}" stroke-width="${i%5===0?2:1}" stroke-linecap="round"/>`;
  }).join('');
  return `<div class="clock-wrap"><svg viewBox="0 0 200 200" role="img" aria-label="倒计时 ${clock(state.remainingSegmentSeconds)}">
    <circle cx="100" cy="100" r="96" fill="white" stroke="#e9dfcc" stroke-width="7"/>
    <circle class="clock-progress" cx="100" cy="100" r="96" fill="none" stroke="#7e9f61" stroke-width="7" stroke-linecap="round" stroke-dasharray="${fraction*603.19} 603.19" transform="rotate(-90 100 100)"/>
    ${ticks}<line class="clock-hand" x1="100" y1="100" x2="100" y2="45" stroke="#2d392e" stroke-width="3" stroke-linecap="round" transform="rotate(${-360*(1-fraction)} 100 100)"/>
    <circle cx="100" cy="100" r="5" fill="#7e9f61"/></svg></div>`;
}
function timerPage() {
  if (!data.active) { route = { name: 'home' }; return homePage(); }
  const session = data.active;
  if (session.status === 'preparing') {
    const remain = Math.max(1,Math.ceil((session.prepareUntil - Date.now()) / 1000));
    return `<main class="page timer-page preparing"><div class="timer-top"><button class="back" data-action="cancel-prepare" aria-label="返回">${icon('back')}</button></div>
      <div class="timer-center"><h2>准备开始</h2><div class="timer-digits">${remain}</div><p class="muted">计时将在 3 秒后开始</p></div></main>`;
  }
  const { plan, error } = planOf(session.project);
  if (!plan) return `<main class="page timer-page">${navBar('计时错误')}<p>${esc(error)}</p></main>`;
  const state = progress(session,plan);
  if (session.status === 'completed' || session.status === 'endedEarly') {
    const endedEarly = session.status === 'endedEarly';
    return `<main class="page timer-page result-page ${endedEarly ? 'ended-result' : ''}"><div class="result-spacer"></div>
      <div class="result-hero"><img src="./assets/${endedEarly ? 'ended' : 'complete'}.png" alt="${endedEarly ? '提前结束时安静思考' : '庆祝任务达成'}的人物插画"></div>
      <h1 class="result-heading">${endedEarly ? '本次已结束' : '任务达成！'}</h1>
      <p class="result-project">${esc(session.project.title)}</p>
      <div class="card result-body"><div class="data-row"><span>完成计时段</span><span>${state.completedFocusCount} / ${plan.focusCount}</span></div>
      <div class="data-row"><span>完成次数</span><span>${state.completedProjectLoops} / ${session.project.repetitions}</span></div>
      <div class="data-row"><span>有效计时</span><span>${readable(state.focusSeconds)}</span></div>
      <div class="data-row"><span>间隔时间</span><span>${readable(state.intervalSeconds)}</span></div></div>
      <div class="result-spacer"></div>
      <div class="timer-bottom">${mainButton('再来一次','restart',false,true)}<button class="bottom-link" data-action="close-result">返回项目</button></div></main>`;
  }
  const segment = state.segment, rest = segment?.kind === 'interval';
  const showTitle = savedProject(session.project);
  const next = plan.segments[state.index+1];
  return `<main class="page timer-page running-page"><div class="timer-top"><button class="back" data-action="timer-home" aria-label="返回首页，计时继续">${icon('back')}</button>
    ${showTitle ? `<span class="pill">${esc(session.project.title)}</span>` : '<span></span>'}
    ${!rest ? `<button class="icon-button" data-action="display-mode" aria-label="切换时钟显示">${session.displayMode === 'digital' ? icon('clockFace') : icon('digital')}</button>` : '<span style="width:44px"></span>'}</div>
    <div class="running-content"><div class="running-spacer"></div>
      <div class="running-visual">${rest ? '<img class="timer-figure" src="./assets/rest.png" alt="放松打坐的人物插画">' : session.displayMode === 'digital' ? `<div class="timer-digits visual-digits">${clock(state.remainingSegmentSeconds)}</div>` : clockView(state)}</div>
      <div class="running-spacer"></div><div class="running-status">
      <span class="timer-status ${rest ? 'rest' : ''}">${session.status === 'paused' ? '已暂停' : rest ? '休息中' : '计时中'}</span>
      ${!rest && segment.title !== '计时' ? `<div class="timer-label">${esc(segment.title)}</div>` : ''}
      ${rest || session.displayMode !== 'digital' ? `<div class="timer-digits">${clock(state.remainingSegmentSeconds)}</div>` : ''}</div><div class="running-spacer"></div></div>
    <div class="timer-bottom"><div class="progress-track"><div class="progress-fill" style="width:${100*state.elapsed/Math.max(1,plan.totalSeconds)}%"></div></div>
      <div class="progress-caption"><span>已完成 ${state.completedFocusCount}/${plan.focusCount} 个计时段</span><span>总剩余 ${clock(state.remainingTotalSeconds)}</span></div>
      ${next ? `<div class="next-card"><span class="next-label">${icon('turnRight')}<span>下一步：${esc(next.kind === 'interval' ? '休息' : next.title)}</span></span><span>${clock(next.durationSeconds)}</span></div>` : ''}
      ${mainButton(session.status === 'paused' ? '▶ 继续' : 'Ⅱ 暂停',session.status === 'paused' ? 'resume' : 'pause',false,rest)}
      <button class="bottom-link" data-action="end-early">结束本次计时</button></div></main>`;
}
function archivePage() {
  const archived = data.projects.filter(project => project.isArchived);
  return `<main class="page no-tab">${navBar('归档项目')}<div style="margin-top:24px">${archived.length ? archived.map(project => `<div class="card row" style="margin-bottom:12px"><strong>${esc(project.title)}</strong><button class="small-button" data-action="restore-project" data-index="${data.projects.indexOf(project)}">恢复</button></div>`).join('') : '<div class="card muted">暂无归档项目</div>'}</div></main>`;
}
function render() {
  const page = { home: homePage, history: historyPage, settings: settingsPage, quick: quickPage,
    editor: editorPage, detail: detailPage, flow: flowPage, timer: timerPage, archive: archivePage }[route.name] || homePage;
  root.innerHTML = `<div class="app-shell">${page()}</div>`;
  renderedTimerSessionId = route.name === 'timer' ? data.active?.id ?? null : null;
  renderedTimerStatus = route.name === 'timer' ? data.active?.status ?? null : null;
  if (renderedTimerSessionId && ['running', 'paused'].includes(renderedTimerStatus)) {
    const { plan } = planOf(data.active.project);
    renderedTimerSegmentIndex = plan ? progress(data.active, plan).index : null;
  } else renderedTimerSegmentIndex = null;
  root.querySelectorAll?.('.duration-wheel').forEach(wheel => {
    wheel.scrollTop = Number(wheel.dataset.value) * 42;
  });
}

function updateTimerDisplay(state, plan) {
  const page = root.querySelector?.('.running-page');
  if (!page) return;
  const remaining = clock(state.remainingSegmentSeconds);
  page.querySelectorAll('.timer-digits').forEach(element => {
    if (element.textContent !== remaining) element.textContent = remaining;
  });
  const circle = page.querySelector('.clock-progress');
  const hand = page.querySelector('.clock-hand');
  if (circle && hand) {
    const fraction = Math.max(0, Math.min(1, state.remainingSegmentSeconds / Math.max(1, state.segment.durationSeconds)));
    circle.setAttribute('stroke-dasharray', `${fraction * 603.19} 603.19`);
    hand.setAttribute('transform', `rotate(${-360 * (1 - fraction)} 100 100)`);
    page.querySelector('.clock-wrap svg')?.setAttribute('aria-label', `倒计时 ${remaining}`);
  }
  const fill = page.querySelector('.progress-fill');
  if (fill) fill.style.width = `${100 * state.elapsed / Math.max(1, plan.totalSeconds)}%`;
  const completed = page.querySelector('.progress-caption span:first-child');
  const remainingTotal = page.querySelector('.progress-caption span:last-child');
  if (completed) completed.textContent = `已完成 ${state.completedFocusCount}/${plan.focusCount} 个计时段`;
  if (remainingTotal) remainingTotal.textContent = `总剩余 ${clock(state.remainingTotalSeconds)}`;
}

function getPath(path) {
  return path.split('.').reduce((object,key) => object?.[key], { route, data });
}
function setPath(path,value) {
  const keys = path.split('.');
  const property = keys.pop();
  const object = keys.reduce((current,key) => current?.[key], { route, data });
  if (!object) return;
  if (property === 'restOn') object.repetitionIntervalSeconds = value ? 15 : 0;
  else if (property === 'projectRestOn') object.loopIntervalSeconds = value ? 15 : 0;
  else object[property] = value;
}
function setDurationPart(path, part, entered) {
  const value = getPath(path);
  const max = part === 0 ? 23 : 59;
  const number = Math.min(max,Math.max(0,Number.parseInt(entered,10) || 0));
  const h = Math.floor(value / 3600), m = Math.floor(value % 3600 / 60), s = value % 60;
  setPath(path, part === 0 ? number*3600 + m*60 + s : part === 1 ? h*3600 + number*60 + s : h*3600 + m*60 + number);
}
function updateDurationSummary() {
  if (route.name === 'quick') {
    const project = route.kind === 'single' ? makeQuickSingle(route.singleSeconds, route.singleRepeats, route.hasRest ? route.restSeconds : 0) :
      makeQuickMulti(route.steps, route.cycles, route.hasRest ? route.restSeconds : 0);
    const { plan } = planOf(project);
    const total = root.querySelector?.('.total-row span:last-child');
    if (total) total.textContent = plan ? clock(plan.totalSeconds) : '—';
    const start = root.querySelector?.('[data-action="start-quick"]');
    if (start) start.disabled = !plan || !!data.active;
  } else if (route.name === 'editor') {
    const { plan } = planOf({ ...route.draft, title: route.draft.title.trim() || '预览' });
    const total = root.querySelector?.('.editor-total strong');
    if (total) total.textContent = plan ? clock(plan.totalSeconds) : '00:00';
  }
}
let durationSummaryFrame = 0;
function scheduleDurationSummary() {
  if (durationSummaryFrame) return;
  if (typeof requestAnimationFrame !== 'function') return updateDurationSummary();
  durationSummaryFrame = requestAnimationFrame(() => {
    durationSummaryFrame = 0;
    updateDurationSummary();
  });
}
function syncWheel(wheel) {
  const next = Math.max(0, Math.min(Number(wheel.dataset.part) === 0 ? 23 : 59, Math.round(wheel.scrollTop / 42)));
  const previous = Number(wheel.dataset.value);
  if (next === previous) return;
  const oldItem = wheel.querySelector?.(`.duration-wheel-item[data-value="${previous}"]`);
  const newItem = wheel.querySelector?.(`.duration-wheel-item[data-value="${next}"]`);
  oldItem?.classList.remove('is-selected'); oldItem?.setAttribute('aria-selected', 'false');
  newItem?.classList.add('is-selected'); newItem?.setAttribute('aria-selected', 'true');
  wheel.dataset.value = String(next);
  const editor = wheel.parentElement?.querySelector('.duration-editor');
  if (editor && document.activeElement !== editor) editor.value = String(next);
  setDurationPart(wheel.dataset.duration, Number(wheel.dataset.part), next);
  scheduleDurationSummary();
}
function begin(project) {
  const { error } = planOf(project);
  if (error) return notice(error);
  if (data.active) return notice('请先结束当前计时');
  cancelScheduledFinish();
  swipeOpen = false;
  data.active = { id: project.id + ':' + Date.now(), project: clone(project), status: 'preparing',
    prepareUntil: Date.now() + 3000, startedAt: Date.now(), elapsedBeforeRun: 0, runStartedAt: 0, displayMode: 'clock' };
  observedSessionId = data.active.id;
  observedSegmentIndex = 0;
  prepareSound();
  persist(); stack = []; navigate({ name: 'timer' }, false);
}
function finish(status) {
  const session = data.active;
  if (!session || !['running','paused'].includes(session.status)) return;
  const { plan } = planOf(session.project); if (!plan) return;
  const state = progress(session,plan);
  const finishCueScheduled = scheduledFinishSessionId === session.id && soundContext?.state === 'running';
  if (status === 'completed' && document.visibilityState === 'visible' && !finishCueScheduled) playCue();
  if (status !== 'completed') cancelScheduledFinish();
  else { scheduledFinishSource = null; scheduledFinishSessionId = null; }
  session.elapsedBeforeRun = status === 'completed' ? plan.totalSeconds : state.elapsed;
  session.status = status;
  const finalState = progress(session,plan);
  if (!data.records.some(record => record.id === session.id)) data.records.unshift(makeRecord(session,plan,finalState,status));
  persist(); render();
  if (status === 'completed' && document.visibilityState === 'visible') {
    if (navigator.vibrate) navigator.vibrate([90,60,120]);
    launchStars(session.id);
  }
}
function prepareSound() {
  if (!data.settings.sound) return;
  try {
    if (navigator.audioSession) navigator.audioSession.type = 'playback';
  } catch {}
  const AudioContextClass = window.AudioContext || window.webkitAudioContext;
  if (!AudioContextClass) return;
  try {
    if (!soundContext) soundContext = new AudioContextClass();
    if (!soundBuffer && !soundLoadPromise) {
      soundLoadPromise = fetch('./assets/complete.wav')
        .then(response => {
          if (!response.ok && response.ok !== undefined) throw Error('提示音文件加载失败');
          return response.arrayBuffer();
        })
        .then(bytes => soundContext.decodeAudioData(bytes))
        .then(buffer => { soundBuffer = buffer; })
        .catch(() => { soundLoadPromise = null; });
    }
    if (soundContext.state !== 'running') soundContext.resume().catch(() => {});
  } catch {}
}
function playCue() {
  if (!data.settings.sound) return Promise.resolve(false);
  if (soundContext?.state === 'running' && soundBuffer) {
    try {
      const source = soundContext.createBufferSource();
      source.buffer = soundBuffer;
      source.connect(soundContext.destination);
      source.start();
      return Promise.resolve(true);
    } catch {}
  }
  try {
    audio.muted = false;
    audio.currentTime = 0;
    return Promise.resolve(audio.play()).then(() => true, () => false);
  } catch { return Promise.resolve(false); }
}
function scheduleFinishCue(session, plan, state) {
  if (!data.settings.sound || document.visibilityState !== 'visible' ||
      scheduledFinishSessionId === session.id || !soundBuffer || soundContext?.state !== 'running') return;
  const remaining = plan.totalSeconds - state.elapsed;
  if (remaining <= 0 || remaining > 2) return;
  try {
    const source = soundContext.createBufferSource();
    source.buffer = soundBuffer;
    source.connect(soundContext.destination);
    source.start(soundContext.currentTime + remaining);
    scheduledFinishSource = source;
    scheduledFinishSessionId = session.id;
  } catch {}
}
function cancelScheduledFinish() {
  try { scheduledFinishSource?.stop(); } catch {}
  scheduledFinishSource = null;
  scheduledFinishSessionId = null;
}
function launchStars(sessionId) {
  if (lastStarSession === sessionId) return;
  lastStarSession = sessionId;
  const field = document.createElement('div'); field.className = 'stars';
  const colors = ['#7e9f61','#159d99','#f6bf65','#f28f95','#8c7be0','#5dbce0','#efaa4e'];
  for (let i = 0; i < 72; i++) {
    const angle = Math.random() * Math.PI * 2;
    const distance = 90 + Math.random() * Math.max(innerWidth,innerHeight) * .8;
    const item = document.createElement('span'); item.className = 'star'; item.textContent = Math.random() < .75 ? '★' : '✦';
    item.style.setProperty('--x',`${Math.cos(angle)*distance}px`);
    item.style.setProperty('--y',`${Math.sin(angle)*distance}px`);
    item.style.setProperty('--color',colors[Math.floor(Math.random()*colors.length)]);
    item.style.setProperty('--size',`${11+Math.random()*17}px`);
    item.style.setProperty('--delay',`${Math.random()*.48}s`);
    item.style.setProperty('--duration',`${1.8+Math.random()*1.5}s`);
    item.style.setProperty('--rotate',`${Math.random()*560-280}deg`);
    field.append(item);
  }
  document.body.append(field);
  setTimeout(() => field.remove(), 4100);
}
function tick() {
  const session = data.active;
  if (!session) return;
  if (session.status === 'preparing' && Date.now() >= session.prepareUntil) {
    session.status = 'running'; session.runStartedAt = session.prepareUntil; session.startedAt = session.prepareUntil; persist();
  }
  if (session.status === 'preparing') {
    if (route.name === 'timer') {
      const digits = root.querySelector?.('.preparing .timer-digits');
      if (digits) digits.textContent = String(Math.max(1, Math.ceil((session.prepareUntil - Date.now()) / 1000)));
    }
    return;
  }
  if (session.status === 'running') {
    const { plan } = planOf(session.project);
    if (plan) {
      const state = progress(session,plan);
      if (state.elapsed >= plan.totalSeconds) { finish('completed'); return; }
      scheduleFinishCue(session,plan,state);
      if (observedSessionId !== session.id || observedSegmentIndex === null) {
        observedSessionId = session.id;
        observedSegmentIndex = state.index;
      } else if (state.index > observedSegmentIndex) {
        observedSegmentIndex = state.index;
        const boundary = plan.segments[state.index - 1].endsAtSeconds;
        if (document.visibilityState === 'visible' && state.elapsed - boundary < 1.5) playCue();
      }
      if (route.name === 'timer') {
        if (renderedTimerSessionId !== session.id || renderedTimerStatus !== 'running' || renderedTimerSegmentIndex !== state.index) render();
        else updateTimerDisplay(state, plan);
      }
    }
  }
}
function exportData() {
  const copy = { version: 1, projects: data.projects, records: data.records, exportedAt: new Date().toISOString() };
  const blob = new Blob([JSON.stringify(copy,null,2)],{type:'application/json'});
  const url = URL.createObjectURL(blob), a = document.createElement('a');
  a.href = url; a.download = `循环计时备份-${new Date().toISOString().slice(0,10)}.json`; a.click();
  setTimeout(() => URL.revokeObjectURL(url),1000);
}
async function importData(file) {
  try {
    const incoming = JSON.parse(await file.text());
    if (!Array.isArray(incoming.projects) || !Array.isArray(incoming.records)) throw Error('文件格式不正确');
    for (const project of incoming.projects) compilePlan(project);
    if (!confirm(`将导入 ${incoming.projects.length} 个项目和 ${incoming.records.length} 条记录，替换当前浏览器的数据。继续吗？`)) return;
    data.projects = incoming.projects; data.records = incoming.records; data.active = null; persist(); render(); notice('导入完成');
  } catch (error) { notice(`导入失败：${error.message}`); }
}

root.addEventListener('click', event => {
  const button = event.target.closest('[data-action]');
  if (!button || button.disabled) {
    if (route.stepMenuPath && !button) {
      route.stepMenuPath = null;
      render();
    }
    if (route.name === 'home' && (route.homeMenuOpen || route.menuIndex != null)) {
      route.homeMenuOpen = false;
      route.menuIndex = null;
      render();
    }
    return;
  }
  const action = button.dataset.action, index = Number(button.dataset.index);
  if (route.stepMenuPath && action !== 'step-menu' && action !== 'step-option') route.stepMenuPath = null;
  if (action === 'wheel-pick') {
    const wheel = button.closest('.duration-wheel');
    const chosen = Number(button.dataset.value);
    if (chosen === Number(wheel.dataset.value)) {
      const editor = wheel.parentElement.querySelector('.duration-editor');
      wheel.parentElement.classList.add('editing');
      editor.focus(); editor.select();
    } else wheel.scrollTo({ top: chosen * 42, behavior: 'smooth' });
    return;
  }
  if (action === 'tab-home') return navigate({ name:'home' },false);
  if (action === 'tab-history') return navigate({ name:'history' },false);
  if (action === 'tab-settings') return navigate({ name:'settings' },false);
  if (action === 'back') return back();
  if (action === 'quick-single' || action === 'quick-multi') return navigate(quickInitial(action === 'quick-single' ? 'single' : 'multiple'));
  if (action === 'new-project') return navigate({name:'editor',isNew:true,draft:makeProject('',[makeGroup(1,[])])});
  if (action === 'home-menu') { route.homeMenuOpen = !route.homeMenuOpen; route.menuIndex = null; return render(); }
  if (action === 'show-archive') { route.homeMenuOpen = false; return navigate({name:'archive'}); }
  if (action === 'project-menu') { route.menuIndex = route.menuIndex === index ? null : index; route.homeMenuOpen = false; return render(); }
  if (action === 'view-project') { route.menuIndex = null; return navigate({name:'detail',id:projectAt(index).id}); }
  if (action === 'edit-project') { route.menuIndex = null; return navigate({name:'editor',isNew:false,draft:clone(projectAt(index))}); }
  if (action === 'copy-project') {
    const original = projectAt(index), copy = clone(original);
    copy.id = makeProject().id; copy.title = `${original.title} 副本`; copy.isArchived = false;
    copy.createdAt = copy.updatedAt = new Date().toISOString(); data.projects.push(copy); route.menuIndex = null; persist(); return render();
  }
  if (action === 'archive-project' || action === 'restore-project') {
    projectAt(index).isArchived = action === 'archive-project'; projectAt(index).updatedAt = new Date().toISOString(); route.menuIndex = null; persist(); return render();
  }
  if (action === 'start-project') return begin(projectAt(index));
  if (action === 'open-active') return navigate({name:'timer'},false);
  if (action === 'discard-active') { cancelScheduledFinish(); data.active = null; swipeOpen = false; persist(); return render(); }
  if (action === 'add-quick-step') {
    if (route.steps.length >= 8) return notice('最多 8 个步骤');
    route.steps.push(makeStep(route.steps.length+1)); return render();
  }
  if (action === 'add-editor-step') {
    const count = route.draft.groups.reduce((n,g) => n+g.steps.length,0);
    if (count >= LIMITS.steps) return notice('最多 24 个步骤');
    route.draft.groups.at(-1).steps.push(makeStep(count+1)); return render();
  }
  if (action === 'step-menu') {
    route.stepMenuPath = route.stepMenuPath === button.dataset.path ? null : button.dataset.path;
    return render();
  }
  if (action === 'step-option') {
    const path = button.dataset.path;
    const dot = path.lastIndexOf('.');
    const steps = getPath(path.slice(0, dot));
    const position = Number(path.slice(dot + 1));
    const step = steps?.[position];
    const operation = button.dataset.operation;
    route.stepMenuPath = null;
    if (!step) return render();
    if (operation === 'copy') {
      const count = route.name === 'editor' ? route.draft.groups.reduce((n, group) => n + group.steps.length, 0) : steps.length;
      if (count >= (route.name === 'editor' ? LIMITS.steps : 8)) return notice('已达到步骤上限');
      const copy = clone(step); copy.id = makeStep(1).id;
      steps.splice(position + 1, 0, copy);
    } else if (operation === 'up' && position > 0) {
      [steps[position - 1], steps[position]] = [steps[position], steps[position - 1]];
    } else if (operation === 'down' && position < steps.length - 1) {
      [steps[position], steps[position + 1]] = [steps[position + 1], steps[position]];
    } else if (operation === 'delete' && steps.length > 1) {
      steps.splice(position, 1);
    }
    return render();
  }
  if (action === 'add-group') {
    if (route.draft.groups.length >= LIMITS.groups) return notice('最多 8 个循环组');
    route.draft.groups.push(makeGroup(route.draft.groups.length+1,[])); return render();
  }
  if (action === 'remove-group') { route.draft.groups.splice(index,1); return render(); }
  if (action === 'step-kind') {
    const path = button.dataset.path, step = getPath(path); step.kind = button.dataset.kind;
    if (step.kind === 'interval') { step.repetitions = 1; step.repetitionIntervalSeconds = 0; }
    return render();
  }
  if (action === 'save-project') {
    const project = route.draft; try { compilePlan(project); } catch(error) { return notice(error.message); }
    project.updatedAt = new Date().toISOString();
    const found = data.projects.findIndex(item => item.id === project.id);
    if (found >= 0) data.projects[found] = clone(project); else data.projects.push(clone(project));
    persist(); stack = []; return navigate({name:'home'},false);
  }
  if (action === 'start-quick') {
    const project = route.kind === 'single' ? makeQuickSingle(route.singleSeconds,route.singleRepeats,route.hasRest ? route.restSeconds : 0) :
      makeQuickMulti(route.steps,route.cycles,route.hasRest ? route.restSeconds : 0);
    return begin(project);
  }
  if (action === 'cancel-prepare') { data.active = null; persist(); return navigate({name:'home'},false); }
  if (action === 'timer-home') return navigate({name:'home'},false);
  if (action === 'display-mode') { data.active.displayMode = data.active.displayMode === 'clock' ? 'digital' : 'clock'; persist(); return render(); }
  if (action === 'pause') {
    cancelScheduledFinish();
    const plan = compilePlan(data.active.project); data.active.elapsedBeforeRun = progress(data.active,plan).elapsed;
    data.active.status = 'paused'; persist(); return render();
  }
  if (action === 'resume') { prepareSound(); data.active.runStartedAt = Date.now(); data.active.status = 'running'; persist(); return render(); }
  if (action === 'end-early') { if (confirm('结束本次计时并保存已完成的进度？')) finish('endedEarly'); return; }
  if (action === 'restart') { const project = clone(data.active.project); data.active = null; persist(); return begin(project); }
  if (action === 'close-result') { cancelScheduledFinish(); data.active = null; persist(); return navigate({name:'home'},false); }
  if (action === 'flow') return navigate({name:'flow',id:route.id});
  if (action === 'test-sound') {
    prepareSound();
    return playCue().then(played => notice(played ? '提示音已触发，请确认是否听到' : '浏览器未能播放提示音，请检查手机音量并重试'));
  }
  if (action === 'export-data') return exportData();
  if (action === 'import-data') return document.getElementById('import-file')?.click();
});

root.addEventListener('input', event => {
  const field = event.target.closest('[data-bind]'); if (!field || field.type === 'checkbox') return;
  const path = field.dataset.bind;
  if (field.dataset.number === 'count') {
    const parsed = Number.parseInt(field.value,10); if (Number.isFinite(parsed)) setPath(path,parsed);
  } else if (field.dataset.number === 'duration') {
    setDurationPart(path,Number(field.dataset.part),field.value);
    scheduleDurationSummary();
  }
  else setPath(path,field.value);
});
root.addEventListener('change', event => {
  const field = event.target;
  if (field.id === 'import-file' && field.files?.[0]) return importData(field.files[0]);
  if (!field.matches('[data-bind]')) return;
  const path = field.dataset.bind;
  if (field.type === 'checkbox') setPath(path,field.checked);
  else if (field.dataset.number === 'count') setPath(path,Math.min(99,Math.max(1,Number.parseInt(field.value,10) || 1)));
  else if (field.dataset.number === 'duration') setDurationPart(path,Number(field.dataset.part),field.value);
  else setPath(path,field.value);
  if (path === 'data.settings.sound') {
    if (field.checked) prepareSound(); else cancelScheduledFinish();
  }
  if (path.startsWith('data.')) persist();
  if (field.type === 'checkbox' || field.dataset.number) setTimeout(render,0);
});

root.addEventListener('scroll', event => {
  if (event.target.matches?.('.duration-wheel')) syncWheel(event.target);
}, true);
root.addEventListener('pointerdown', event => {
  const front = event.target.closest?.('.swipe-front');
  if (!front) return;
  swipeGesture = { front, pointerId: event.pointerId, x: event.clientX, y: event.clientY,
    initial: swipeOpen ? -98 : 0, dragging: false };
});
root.addEventListener('pointermove', event => {
  const gesture = swipeGesture;
  if (!gesture || event.pointerId !== gesture.pointerId) return;
  const dx = event.clientX - gesture.x, dy = event.clientY - gesture.y;
  if (!gesture.dragging && Math.abs(dx) > 10 && Math.abs(dx) > Math.abs(dy)) gesture.dragging = true;
  if (!gesture.dragging) return;
  event.preventDefault?.();
  gesture.front.style.transition = 'none';
  gesture.front.style.transform = `translateX(${Math.max(-98,Math.min(0,gesture.initial + dx))}px)`;
});
root.addEventListener('pointerup', event => {
  const gesture = swipeGesture;
  if (!gesture || event.pointerId !== gesture.pointerId) return;
  swipeGesture = null;
  if (gesture.dragging) swipeOpen = gesture.initial + event.clientX - gesture.x < -50;
  gesture.front.style.transition = '';
  gesture.front.style.transform = '';
  gesture.front.classList.toggle('open', swipeOpen);
});
root.addEventListener('pointercancel', () => {
  if (!swipeGesture) return;
  swipeGesture.front.style.transition = '';
  swipeGesture.front.style.transform = '';
  swipeGesture = null;
});
root.addEventListener('focusout', event => {
  if (event.target.matches?.('.duration-editor')) event.target.closest('.duration-col')?.classList.remove('editing');
});
document.addEventListener('visibilitychange',() => {
  if (document.visibilityState === 'visible') {
    if (data.active?.status === 'running') prepareSound();
    tick();
  } else cancelScheduledFinish();
});
if ('serviceWorker' in navigator && location.protocol !== 'file:') navigator.serviceWorker.register('./sw.js').catch(() => {});
setInterval(tick,100);
render();
tick();
