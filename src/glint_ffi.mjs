export function exit(code) {
  import("node:process")
    .then((process) => process.exit(code))
    .catch((error) => {});
  return undefined;
}
