# Host Overlays

`linux/install/sync --host <name>` passes `linux/hosts/<name>.yaml` to dotpkg as
an overlay over the initialized per-user manifest. The repository's
`linux/packages.yaml` is used as the initial seed for that manifest. Overlays
are committed descriptions of a machine's differences; they replace the old
mutable window-manager selection file.

For example:

```yaml
profiles:
  desktop:
    packages:
      extras:
        host-only-tool: []
```

An overlay can also add package metadata under the same manifest categories.
Desktop selections are stored locally after the first interactive sync. Packages
inherit the manifest's root `source: aur`. Add `source: repo` to an individual
package only when it must bypass the default resolver.
