/**
 * Deploys `firestore.rules` to the live project.
 *
 * `firebase deploy --only firestore:rules` is the normal path and stays the
 * documented one. It is unusable from a service-account-only environment,
 * because before deploying it calls `serviceusage.services.get` to check the
 * Firestore API is enabled — a permission the Admin SDK service account does
 * not carry, so the deploy dies on a 403 about an API that is already on.
 *
 * This talks to the same API the CLI ultimately uses (firebaserules), in the
 * same two steps: create an immutable ruleset from the file, then point the
 * `cloud.firestore` release at it. Nothing else about the project is touched,
 * and the source deployed is byte-for-byte the file in the repo.
 *
 *   GOOGLE_APPLICATION_CREDENTIALS=secrets/<key>.json \
 *     node tool/deploy_firestore_rules.js
 *
 * Pass --project to override the project id.
 */

const fs = require("fs");
const path = require("path");
const { GoogleAuth } = require("google-auth-library");

const RULES = path.join(__dirname, "..", "firestore.rules");

function projectId() {
  const flag = process.argv.indexOf("--project");
  if (flag !== -1 && process.argv[flag + 1]) return process.argv[flag + 1];
  const key = process.env.GOOGLE_APPLICATION_CREDENTIALS;
  if (key) return JSON.parse(fs.readFileSync(key, "utf8")).project_id;
  throw new Error("No project id. Pass --project or set GOOGLE_APPLICATION_CREDENTIALS.");
}

async function main() {
  const project = projectId();
  const source = fs.readFileSync(RULES, "utf8");

  const auth = new GoogleAuth({
    scopes: ["https://www.googleapis.com/auth/cloud-platform"],
  });
  const client = await auth.getClient();
  const base = `https://firebaserules.googleapis.com/v1/projects/${project}`;

  const ruleset = await client.request({
    url: `${base}/rulesets`,
    method: "POST",
    data: { source: { files: [{ name: "firestore.rules", content: source }] } },
  });
  const name = ruleset.data.name;
  console.log(`Created ruleset ${name}`);

  // The release name is fixed: `cloud.firestore` is the one Firestore reads.
  // PATCH so an existing release is repointed rather than duplicated.
  const release = `projects/${project}/releases/cloud.firestore`;
  await client.request({
    url: `https://firebaserules.googleapis.com/v1/${release}`,
    method: "PATCH",
    data: { release: { name: release, rulesetName: name } },
  });
  console.log(`Released ${name} as ${release}`);
}

main().catch((error) => {
  const detail = error?.response?.data ?? error?.message ?? error;
  console.error("Deploy failed:", JSON.stringify(detail, null, 2));
  process.exit(1);
});
