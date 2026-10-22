import type { Step } from "../deletionCore";

/**
 * Custom teardown steps for the `room` deletion kind. `deletionPlans.planFor`
 * merges them with the generic cascade/setNull steps; a step lists the rule keys
 * it handles itself in `claims` so no generic step also runs for them.
 */
export const roomSteps: Step[] = [];
