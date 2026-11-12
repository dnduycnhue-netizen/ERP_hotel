#!/usr/bin/env python3
"""Chay pgTAP (supabase/tests/*_test.sql) tren project Supabase dang lien ket,
moi file trong MOT transaction roi ROLLBACK — khong de lai du lieu.

Vi sao: du an khong dung Docker va khong co project test (xem docs/11-TESTING.md
va memory 'no-test-project'), nen `supabase test db` cuc bo khong dung duoc.

Cach dung (tu thu muc goc repo):
  python3 scripts/pgtap-rehearse.py                       # tat ca suite
  python3 scripts/pgtap-rehearse.py finance_invoices_test.sql  # chon suite
  python3 scripts/pgtap-rehearse.py --migration supabase/migrations/<file>.sql <suite>
      # ghep migration CHUA push vao dau transaction de thu truoc khi db push

Yeu cau: `node_modules/.bin/supabase` da `supabase link` toi ERP_hotel. Lenh co
--yes vi no ghi (roi rollback) len database that: CHI chay khi ban chu dich.
Ket qua: in tung suite + tong; chi tiet o file JSON trong thu muc tam (in ra).

Gioi han: moi test phai ket thuc bang `rollback;`. Test dung `reset role`/`set local
role` van chay duoc (bang ket qua tam cap quyen cho PUBLIC). Test can DB TRONG
(bootstrap_initial_org_test) se do tren DB da co du lieu — day la dac tinh cua test.
"""
import argparse, glob, json, os, re, subprocess, sys, tempfile, time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FNS = ("ok|is|isnt|throws_ok|lives_ok|cmp_ok|is_empty|isnt_empty|matches|doesnt_match|like|unlike|pass|fail|performs_ok|"
       "results_eq|results_ne|set_eq|bag_eq|row_eq|throws_like|throws_matching|throws_imatching|isa_ok|has_table|hasnt_table|"
       "has_column|hasnt_column|has_function|hasnt_function|has_view|has_index|has_trigger|has_policy|has_schema|has_role|"
       "col_not_null|col_is_pk|col_type_is|col_has_default|function_returns|function_privs_are|table_privs_are|schema_privs_are|"
       "policies_are|columns_are|tables_are|functions_are|is_definer|isnt_definer|is_strict|volatility_is|trigger_is|"
       "can|is_indexed|todo|skip|alike|ialike")
PRE = ("create temp table tap_out(id serial, l text);\n"
       "grant all on tap_out to public;\n"
       "grant usage on sequence tap_out_id_seq to public;\n")


def build(test_path, migration_path, out_path):
    t = open(test_path, encoding="utf8").read()
    t = re.sub(r"(?m)^select (%s)\(" % FNS, r"insert into tap_out(l) select \1(", t)
    begin = re.search(r"(?mi)^\s*begin\s*;", t)
    if not begin:
        raise ValueError("test khong co 'begin;'")
    mig = open(migration_path, encoding="utf8").read() if migration_path else ""
    t = t[:begin.end()] + "\n" + mig + "\n" + PRE + t[begin.end():]
    end = re.search(r"(select (\* from )?finish\(\);\s*)?rollback;\s*$", t)
    if not end:
        raise ValueError("test phai ket thuc bang 'rollback;'")
    t = t[:end.start()] + "\nreset role;\nselect id, l from tap_out order by id;\nrollback;\n"
    open(out_path, "w", encoding="utf8").write(t)


def run_one(path, migration, workdir):
    name = os.path.basename(path)
    plan = re.search(r"select plan\((\d+)\)", open(path, encoding="utf8").read())
    plan = int(plan.group(1)) if plan else None
    out = os.path.join(workdir, "run_" + name)
    try:
        build(path, migration, out)
    except ValueError as e:
        return dict(test=name, plan=plan, ok=0, notok=0, error="BUILD: %s" % e)
    t0 = time.time()
    p = subprocess.run([os.path.join(ROOT, "node_modules/.bin/supabase"), "db", "query", "--remote", "--yes",
                        "-f", out, "-o", "json"], capture_output=True, text=True, timeout=900, cwd=ROOT)
    txt = p.stdout + p.stderr
    open(os.path.join(workdir, "out_" + name + ".json"), "w", encoding="utf8").write(txt)
    oks = re.findall(r'"l": "(ok \d+[^"]*)"', txt)
    noks = re.findall(r'"l": "(not ok \d+[^"]*)"', txt)
    m = re.search(r'"message":"([^"]*)"', txt)
    err = m.group(1).replace("\\n", " ")[:300] if m else None
    return dict(test=name, plan=plan, ok=len(oks), notok=len(noks), error=err, secs=round(time.time() - t0),
                notok_list=[n.split("\\n")[0] for n in noks][:12])


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("suites", nargs="*", help="ten file test (mac dinh: tat ca)")
    ap.add_argument("--migration", help="migration chua push de ghep vao dau transaction")
    a = ap.parse_args()
    files = sorted(glob.glob(os.path.join(ROOT, "supabase/tests/*_test.sql")))
    if a.suites:
        files = [f for f in files if os.path.basename(f) in a.suites]
    workdir = tempfile.mkdtemp(prefix="pgtap-rehearse-")
    results = []
    for f in files:
        r = run_one(f, a.migration, workdir)
        results.append(r)
        good = r.get("ok") == r.get("plan") and not r.get("notok") and not r.get("error")
        print(("PASS " if good else "FAIL ") + f"{r['test']:50s} plan={r.get('plan')} ok={r.get('ok')} notok={r.get('notok')}"
              + (f"  ERR={r['error'][:100]}" if r.get("error") else ""), flush=True)
        for n in r.get("notok_list") or []:
            print("      " + n[:160])
    bad = [r for r in results if not (r.get("ok") == r.get("plan") and not r.get("notok") and not r.get("error"))]
    print(f"\n{len(results) - len(bad)}/{len(results)} suite dat | ca ok {sum(r.get('ok') or 0 for r in results)}"
          f"/{sum(r.get('plan') or 0 for r in results)} | chi tiet: {workdir}")
    json.dump(results, open(os.path.join(workdir, "summary.json"), "w"), ensure_ascii=False, indent=1)
    sys.exit(1 if bad else 0)


if __name__ == "__main__":
    main()
