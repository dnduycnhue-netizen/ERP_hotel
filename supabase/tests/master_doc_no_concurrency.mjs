// Uses committed fixtures and leaves audit entries. Prefer an isolated project.
// SUPABASE_TEST_REF=<ref> T010_ALLOW_COMMITTED_TEST_FIXTURES=1 node supabase/tests/master_doc_no_concurrency.mjs
import { execFile } from "node:child_process";
import { randomUUID } from "node:crypto";
import { promisify } from "node:util";
import { fileURLToPath } from "node:url";

const execFileAsync = promisify(execFile);
const project = process.env.SUPABASE_TEST_REF;
if (
  !project ||
  !/^[a-z0-9]{20}$/.test(project) ||
  process.env.T010_ALLOW_COMMITTED_TEST_FIXTURES !== "1"
) {
  throw new Error(
    "Specify SUPABASE_TEST_REF and explicitly allow committed test fixtures.",
  );
}

const cli = fileURLToPath(
  new URL("../../node_modules/.bin/supabase", import.meta.url),
);
const orgId = randomUUID();
const entityId = randomUUID();
const code = `T010${orgId.replaceAll("-", "").slice(0, 12).toUpperCase()}`;
const type = "T010TEST";
const date = "2026-01-01";

async function query(sql) {
  const { stdout } = await execFileAsync(
    cli,
    ["db", "query", `--remote=${project}`, "--yes", sql],
    { timeout: 180_000, maxBuffer: 1024 * 1024 },
  );
  return JSON.parse(stdout).rows;
}

let fixtureMayExist = false;
let failure;
try {
  fixtureMayExist = true;
  await query(`
    begin;
    insert into public.organizations (id, name) values ('${orgId}', 'T-010 concurrency test');
    insert into public.legal_entities (id, org_id, code, name)
      values ('${entityId}', '${orgId}', '${code}', 'T-010 concurrency test');
    commit;
  `);
  const calls = await Promise.allSettled(
    Array.from({ length: 50 }, () =>
      query(`
        with started as materialized (select clock_timestamp() as at),
        pause as materialized (select pg_sleep(10) from started)
        select public.next_doc_no('${entityId}', '${type}', '${date}') as number,
          started.at as started_at, clock_timestamp() as ended_at
        from started cross join pause;
      `),
    ),
  );
  const errors = calls.filter((result) => result.status === "rejected");
  if (errors.length) {
    throw new AggregateError(
      errors.map((result) => result.reason),
      `${errors.length} of 50 calls failed`,
    );
  }
  const rows = calls.flatMap((result) => result.value);
  const actual = rows.map((row) => row.number).sort();
  const expected = Array.from(
    { length: 50 },
    (_, i) => `${type}-${code}-2601-${String(i + 1).padStart(4, "0")}`,
  ).sort();
  if (JSON.stringify(actual) !== JSON.stringify(expected)) {
    throw new Error(
      "Document numbers are not exactly the expected unique range 1–50.",
    );
  }
  const latestStart = Math.max(
    ...rows.map((row) => Date.parse(row.started_at)),
  );
  const earliestEnd = Math.min(...rows.map((row) => Date.parse(row.ended_at)));
  if (!(latestStart < earliestEnd)) {
    throw new Error(
      "All 50 database calls did not overlap; the concurrency requirement was not verified.",
    );
  }
  const count = await query(`select last_no from public.doc_sequences
    where legal_entity_id = '${entityId}' and doc_type = '${type}' and year = 2026`);
  if (Number(count[0]?.last_no) !== 50) {
    throw new Error("Stored sequence counter is not 50.");
  }
  console.log(
    "PASS: 50 overlapping database calls produced exactly numbers 1–50.",
  );
} catch (error) {
  failure = error;
} finally {
  if (fixtureMayExist) {
    try {
      await query(`
        begin;
        delete from public.doc_sequences where legal_entity_id = '${entityId}' and doc_type = '${type}' and year = 2026;
        delete from public.legal_entities where id = '${entityId}' and org_id = '${orgId}';
        delete from public.organizations where id = '${orgId}';
        commit;
      `);
      const remaining = await query(`select
        (select count(*) from public.organizations where id = '${orgId}') as organizations,
        (select count(*) from public.legal_entities where id = '${entityId}') as entities,
        (select count(*) from public.doc_sequences where legal_entity_id = '${entityId}') as sequences`);
      if (Object.values(remaining[0]).some((value) => Number(value) !== 0)) {
        throw new Error("Fixture cleanup verification failed.");
      }
      console.log("Fixture rows removed; immutable audit entries remain.");
    } catch (error) {
      console.error(
        `Cleanup failed for organization ${orgId} and entity ${entityId}:`,
        error,
      );
      failure = failure
        ? new AggregateError([failure, error], "Test and cleanup failed")
        : error;
    }
  }
}
if (failure) {
  console.error(failure);
  process.exitCode = 1;
}
