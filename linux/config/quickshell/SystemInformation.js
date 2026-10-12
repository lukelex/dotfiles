function bytes(value) {
  if (!Number.isFinite(value) || value < 0)
    return "Unavailable";
  const units = ["B", "KiB", "MiB", "GiB", "TiB"];
  let index = 0;
  while (value >= 1024 && index < units.length - 1) {
    value /= 1024;
    index++;
  }
  return value.toFixed(index ? 1 : 0) + " " + units[index];
}

function normalize(data) {
  if (!Array.isArray(data) || !data.some(entry => entry && entry.result))
    throw new Error("No system information returned");
  const result = type => data.find(entry => entry && entry.type === type)?.result;
  const object = type => result(type) || {};
  const list = type => Array.isArray(result(type)) ? result(type) : [];
  const row = (icon, label, value) => ({ icon, label, value: value || "Unavailable", usage: -1 });
  const metric = (icon, label, used, total) => ({
    icon, label,
    value: Number.isFinite(used) && Number.isFinite(total) && total > 0
      ? bytes(used) + " / " + bytes(total) + " · " + Math.round(used / total * 100) + "%"
      : total === 0 ? "None" : "Unavailable",
    usage: Number.isFinite(used) && Number.isFinite(total) && total > 0
      ? Math.max(0, Math.min(1, used / total)) : -1
  });
  const title = object("Title"), host = object("Host"), os = object("OS");
  const cpu = object("CPU"), kernel = object("Kernel"), wm = object("WM");
  const memory = object("Memory"), packages = object("Packages");
  const hardware = [row("cpu", "Processor", cpu.cpu)];
  if (cpu.cores)
    hardware.push(row("cpu", "Cores / threads", cpu.cores.physical + " cores · " + cpu.cores.logical + " threads"));
  for (const gpu of list("GPU"))
    hardware.push(row("monitor", "Graphics", [gpu.name, gpu.type, gpu.driver].filter(Boolean).join(" · ")));
  hardware.push(metric("memory-stick", "Memory", memory.used, memory.total));
  const swap = result("Swap");
  const swaps = Array.isArray(swap) ? swap : swap ? [swap] : [];
  hardware.push(metric("memory-stick", "Swap", swaps.length ? swaps.reduce((n, s) => n + s.used, 0) : undefined,
    swaps.length ? swaps.reduce((n, s) => n + s.total, 0) : Array.isArray(swap) ? 0 : undefined));

  // Btrfs subvolumes report the same underlying capacity. Show it only once.
  const disks = new Map();
  for (const disk of list("Disk")) {
    const key = disk.mountFrom && disk.filesystem === "btrfs"
      ? disk.mountFrom + ":" + disk.filesystem : disk.mountpoint;
    if (disks.has(key)) {
      disks.get(key).label += ", " + disk.mountpoint;
      continue;
    }
    const entry = metric("hard-drive", disk.mountpoint || "Storage", disk.bytes?.used, disk.bytes?.total);
    entry.value += disk.filesystem ? " · " + disk.filesystem : "";
    disks.set(key, entry);
  }
  const minutes = Math.floor(object("Uptime").uptime / 60000);
  const uptime = Number.isFinite(minutes)
    ? (minutes >= 1440 ? Math.floor(minutes / 1440) + "d " : "") + Math.floor(minutes % 1440 / 60) + "h " + minutes % 60 + "m" : "";
  const session = [
    row("box", "Operating system", os.prettyName || os.name),
    row("cpu", "Kernel", [kernel.name, kernel.release, kernel.architecture].filter(Boolean).join(" · ")),
    row("monitor", "Desktop / session", [object("DE").prettyName, wm.prettyName, wm.version, wm.protocolName].filter(Boolean).join(" · ")),
    row("box", "Login shell", title.userShell),
    row("box", "Packages", Number.isFinite(packages.all) ? String(packages.all) : ""),
    row("clock", "Uptime", uptime)
  ];
  return {
    hostname: title.hostName || "This computer",
    model: [host.vendor, host.version || host.family || host.name].filter(Boolean).join(" · "),
    os: os.prettyName || os.name || "",
    groups: [
      { title: "Hardware", icon: "cpu", rows: hardware },
      { title: "Storage", icon: "hard-drive", rows: Array.from(disks.values()) },
      { title: "Desktop & session", icon: "box", rows: session }
    ].filter(group => group.rows.length)
  };
}
