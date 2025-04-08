export function collapse(
  strings: TemplateStringsArray,
  ...args: (string | number)[]
): string {
  return strings
    .map((str, i) => (i < args.length ? str + args[i] : str))
    .join("")
    .replace(/(^\s+|\s+$)/gm, "")
    .replace(/\n/g, " ");
}
