import { makeQuickSingle, makeQuickMulti, makeStep, compilePlan, progress } from './core.js';
function equal(actual, expected, message) {
  if (actual !== expected) throw new Error(`${message}: got ${actual}, expected ${expected}`);
}
const single = compilePlan(makeQuickSingle(45, 8, 15));
equal(single.totalSeconds, 465, 'single duration');
equal(single.focusCount, 8, 'single focus count');
equal(single.segments.length, 15, 'single interval count');
const a = makeStep(1), b = makeStep(2);
a.durationSeconds = 40; b.durationSeconds = 20;
const multi = compilePlan(makeQuickMulti([a,b], 5));
equal(multi.totalSeconds, 300, 'multi duration');
equal(multi.focusCount, 10, 'multi focus count');
const session = { project: makeQuickSingle(45,8,15), status:'running', elapsedBeforeRun:0, runStartedAt:1000 };
const state = progress(session, single, 47000);
equal(state.completedFocusCount, 1, 'elapsed focus count');
equal(state.remainingSegmentSeconds, 14, 'interval remaining');
let rejected = false;
try { compilePlan(makeQuickSingle(0,1)); } catch { rejected = true; }
equal(rejected, true, 'invalid duration');
print('Core tests passed');
