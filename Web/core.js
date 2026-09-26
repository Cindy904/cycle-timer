export const LIMITS = Object.freeze({ groups: 8, steps: 24, segments: 48, seconds: 86400 });

const uid = () => globalThis.crypto?.randomUUID?.() ?? `id-${Date.now()}-${Math.random().toString(36).slice(2)}`;
const validCount = value => Number.isInteger(value) && value >= 1 && value <= 99;
const validDuration = value => Number.isInteger(value) && value >= 1 && value <= 86399;
const validInterval = value => Number.isInteger(value) && value >= 0 && value <= 86399;
const validName = value => typeof value === 'string' && value.trim().length >= 1 && value.trim().length <= 30;

export function makeStep(index = 1, kind = 'focus') {
  return { id: uid(), kind, name: kind === 'focus' ? `步骤 ${index}` : '休息', durationSeconds: kind === 'focus' ? 0 : 15,
    repetitions: 1, repetitionIntervalSeconds: 0 };
}

export function makeGroup(index = 1, steps = []) {
  return { id: uid(), name: `第 ${index} 组`, repetitions: 1, loopIntervalSeconds: 0, steps };
}

export function makeProject(title = '', groups = [makeGroup()]) {
  const now = new Date().toISOString();
  return { id: uid(), title, repetitions: 1, loopIntervalSeconds: 0, groups, createdAt: now, updatedAt: now, isArchived: false };
}

export function makeQuickSingle(seconds, repeats, restSeconds = 0) {
  const step = makeStep(1);
  Object.assign(step, { name: '计时', durationSeconds: seconds, repetitions: repeats, repetitionIntervalSeconds: restSeconds });
  return makeProject('单步骤重复', [makeGroup(1, [step])]);
}

export function makeQuickMulti(steps, cycles, restSeconds = 0) {
  const project = makeProject('多步骤循环', [makeGroup(1, steps)]);
  project.groups[0].repetitions = cycles;
  project.groups[0].loopIntervalSeconds = restSeconds;
  return project;
}

export function compilePlan(project) {
  if (!validName(project.title)) throw new Error('请填写 1–30 个字符的项目名称');
  if (!Array.isArray(project.groups) || project.groups.length < 1 || project.groups.length > LIMITS.groups)
    throw new Error('每个项目需要 1–8 个循环组');
  if (!validCount(project.repetitions) || !validInterval(project.loopIntervalSeconds))
    throw new Error('整套循环次数或间隔无效');
  const configuredSteps = project.groups.reduce((sum, group) => sum + (group.steps?.length ?? 0), 0);
  if (configuredSteps > LIMITS.steps) throw new Error('最多添加 24 个配置步骤');
  if (!project.groups.some(group => group.steps?.some(step => step.kind === 'focus')))
    throw new Error('至少需要一个计时步骤');
  for (const [groupIndex, group] of project.groups.entries()) {
    if (!validName(group.name)) throw new Error('循环组名称需为 1–30 个字符');
    if (!Array.isArray(group.steps) || !group.steps.length) throw new Error(`第 ${groupIndex + 1} 组至少需要一个步骤`);
    if (!validCount(group.repetitions) || !validInterval(group.loopIntervalSeconds))
      throw new Error('本组循环次数或间隔无效');
    for (const step of group.steps) {
      if (!validName(step.name)) throw new Error('步骤名称需为 1–30 个字符');
      if (!validDuration(step.durationSeconds)) throw new Error('每段时长需为 1 秒至 23 小时 59 分 59 秒');
      if (!validCount(step.repetitions) || !validInterval(step.repetitionIntervalSeconds))
        throw new Error('步骤重复次数或间隔无效');
      if (step.kind !== 'focus' && step.kind !== 'interval') throw new Error('步骤类型无效');
      if (step.kind === 'interval' && (step.repetitions !== 1 || step.repetitionIntervalSeconds !== 0))
        throw new Error('间隔步骤不能重复');
    }
  }

  const segments = [];
  let offset = 0;
  function append(title, kind, source, seconds, projectRepeat, groupName, groupRepeat, stepRepeat = 1, stepRepeatTotal = 1) {
    if (segments.length >= LIMITS.segments) throw new Error('展开后最多 48 个执行段，请减少重复次数');
    if (offset + seconds > LIMITS.seconds) throw new Error('计划总时长不能超过 24 小时');
    segments.push({ title, kind, source, durationSeconds: seconds, startsAtSeconds: offset,
      endsAtSeconds: offset + seconds, projectRepeat, groupName, groupRepeat, stepRepeat, stepRepeatTotal });
    offset += seconds;
  }
  for (let p = 1; p <= project.repetitions; p++) {
    for (const group of project.groups) {
      for (let g = 1; g <= group.repetitions; g++) {
        for (const step of group.steps) {
          if (step.kind === 'interval') {
            append(step.name, 'interval', 'explicit', step.durationSeconds, p, group.name, g);
          } else {
            for (let s = 1; s <= step.repetitions; s++) {
              append(step.name, 'focus', 'step', step.durationSeconds, p, group.name, g, s, step.repetitions);
              if (s < step.repetitions && step.repetitionIntervalSeconds > 0)
                append('步骤间隔', 'interval', 'stepInterval', step.repetitionIntervalSeconds, p, group.name, g);
            }
          }
        }
        if (g < group.repetitions && group.loopIntervalSeconds > 0)
          append('组间隔', 'interval', 'groupInterval', group.loopIntervalSeconds, p, group.name, g);
      }
    }
    if (p < project.repetitions && project.loopIntervalSeconds > 0)
      append('整套间隔', 'interval', 'projectInterval', project.loopIntervalSeconds, p, '', 1);
  }
  return { segments, totalSeconds: offset, focusCount: segments.filter(segment => segment.kind === 'focus').length };
}

export function clock(seconds) {
  const safe = Math.max(0, Math.floor(seconds));
  const h = Math.floor(safe / 3600), m = Math.floor((safe % 3600) / 60), s = safe % 60;
  return h ? `${h}:${String(m).padStart(2, '0')}:${String(s).padStart(2, '0')}` :
    `${String(m).padStart(2, '0')}:${String(s).padStart(2, '0')}`;
}

export function readable(seconds) {
  const safe = Math.max(0, Math.floor(seconds));
  if (safe >= 3600) return `${Math.floor(safe / 3600)} 小时 ${Math.floor(safe % 3600 / 60)} 分钟`;
  if (safe >= 60) return `${Math.floor(safe / 60)} 分 ${safe % 60} 秒`;
  return `${safe} 秒`;
}

export function progress(session, plan, now = Date.now()) {
  const elapsed = Math.min(plan.totalSeconds, session.elapsedBeforeRun +
    (session.status === 'running' ? Math.max(0, (now - session.runStartedAt) / 1000) : 0));
  const index = plan.segments.findIndex(segment => elapsed < segment.endsAtSeconds);
  const segment = index >= 0 ? plan.segments[index] : null;
  const completedFocusCount = plan.segments.filter(item => item.kind === 'focus' && item.endsAtSeconds <= elapsed).length;
  const completedProjectLoops = Array.from({ length: session.project.repetitions }, (_, i) => i + 1).filter(loop => {
    const items = plan.segments.filter(item => item.projectRepeat === loop && item.source !== 'projectInterval');
    return items.length && items.at(-1).endsAtSeconds <= elapsed;
  }).length;
  let focusSeconds = 0, intervalSeconds = 0;
  for (const item of plan.segments) {
    const amount = Math.max(0, Math.min(elapsed, item.endsAtSeconds) - item.startsAtSeconds);
    if (item.kind === 'focus') focusSeconds += amount; else intervalSeconds += amount;
  }
  return { elapsed, index, segment, remainingSegmentSeconds: segment ? Math.max(0, Math.ceil(segment.endsAtSeconds - elapsed)) : 0,
    remainingTotalSeconds: Math.max(0, Math.ceil(plan.totalSeconds - elapsed)), completedFocusCount,
    completedProjectLoops, focusSeconds: Math.floor(focusSeconds), intervalSeconds: Math.floor(intervalSeconds) };
}

export function makeRecord(session, plan, state, status, now = Date.now()) {
  return { id: session.id, project: session.project, startedAt: new Date(session.startedAt).toISOString(),
    endedAt: new Date(now).toISOString(), status, completedFocusCount: state.completedFocusCount,
    plannedFocusCount: plan.focusCount, completedProjectLoops: state.completedProjectLoops,
    plannedProjectLoops: session.project.repetitions, focusSeconds: state.focusSeconds,
    intervalSeconds: state.intervalSeconds };
}
