---
title: One Class, Two Classes
info: How the JVM loads code and why Foo can't be cast to Foo
theme: ./themes/noir
colorSchema: dark
layout: cover
transition: fade
magicMoveDuration: 700
---

###### JVM · ClassLoaders · Plugins

# One Class,<br><span class="accent">Two Classes</span>

How the JVM loads code — and why `Foo` can't be cast to `Foo`

<div class="mt-12 flex gap-3">
  <span class="tag">Maven</span>
  <span class="tag">ClassLoader</span>
  <span class="tag hot">Plugin isolation</span>
</div>

<!--
Start with a question: "Who has seen `ClassCastException: Foo cannot be cast to Foo`?" Usually half the room raises a hand. The other half hasn't read their logs yet.

Plan: how the JVM loads code → why two identical classes can be different → how to build plugins and stay sane.
-->

---

###### Part 1 · Maven

# A familiar picture

<div class="grid grid-cols-[1.1fr_1fr] gap-12 items-center">

```text {3,6}
my-app
├── lib-A
│   └── jackson 2.15      depth 2
└── lib-B
    └── lib-C
        └── jackson 2.17  depth 3
```

<div>

- Libraries bring their own dependencies
- Same library, **different versions**
- Only **one** gets on the classpath

<div v-click class="mt-8 text-2xl font-600">Which one?</div>

</div>
</div>

---

###### Part 1 · Maven

# How Maven picks a version

<v-clicks>

1. **Nearest wins** — closest to the root, *not* the newest
2. **Same depth?** First declared wins
3. **Direct dependency** wins — it's depth 1
4. **`dependencyManagement` / BOM** — version forced from above
5. **`exclusions`** — cut a branch by hand

</v-clicks>

<div v-click class="mt-8 text-lg">
→ In our example <span class="accent font-600">2.15</span> wins, even though lib-C wants 2.17
</div>

<div v-click class="aside">
A doorman lets in one person per surname. Not the youngest, not the best — whoever stands <b>closest to the door</b>.
</div>

<!--
Rule 3 is not a separate rule. A direct dependency sits at depth 1, so "nearest wins" already covers it.
-->

---

###### Part 1 · Maven

# Where it backfires

<div class="grid grid-cols-2 gap-10">
<div>

- lib-C built for 2.17, got 2.15 → `NoSuchMethodError` **at runtime**
- Same packages, new coordinates → Maven ships **both**
- Shaded **without relocation** → same clash

<div class="mt-6 text-xl">Green build. <span class="accent">Red production.</span></div>

```bash
mvn dependency:tree -Dverbose  # who won
mvn dependency:build-classpath # order
```

</div>
<div v-click>

<div class="card">
  <div class="card-title">Safety net: <code>maven-enforcer-plugin</code></div>
  <div class="card-sub mb-4">Make the <b>build</b> fail, not production</div>
  <div class="mono text-sm accent">requireUpperBoundDeps</div>
  <div class="text-sm muted mb-3">Fails if Maven picked a version <b>lower</b> than someone needs</div>
  <div class="mono text-sm accent">dependencyConvergence</div>
  <div class="text-sm muted">Stricter: fails on <b>any</b> version mismatch in the tree</div>
</div>

</div>
</div>

<div v-click class="aside">
The doorman calls the manager: <b>"two Ivanovs — you decide."</b>
</div>

<!--
Examples of "same packages, new coordinates": `javax.servlet:servlet-api` vs `jakarta.servlet-api` 4.x, and `commons-logging` vs `jcl-over-slf4j`.

`jakarta.servlet-api` 4.x is the old API under new coordinates. Inside it's still `javax.servlet`. Maven sees two different artifacts and keeps both. Whichever is first on the classpath wins.

Same for `commons-logging` and `jcl-over-slf4j`. Both contain `org.apache.commons.logging`.

Shading is fine when packages are relocated (`org.foo` → `shaded.org.foo`). A fat JAR without relocation is just a second copy in a fake moustache.

Neither enforcer rule catches the different-coordinates case. For that, use `banDuplicateClasses` from extra-enforcer-rules.
-->

---

###### Part 2 · ClassLoader

# What happens to the JARs next?

<div class="flow mt-10">
  <div class="card"><div class="card-title mono">pom.xml</div><div class="card-sub">what you asked for</div></div>
  <div class="arrow">→</div>
  <div class="card"><div class="card-title">classpath</div><div class="card-sub">flat list of JARs</div></div>
  <div class="arrow">→</div>
  <div class="card hot"><div class="card-title">ClassLoader</div><div class="card-sub">reads bytes</div></div>
  <div class="arrow">→</div>
  <div class="card"><div class="card-title mono">Class&lt;?&gt;</div><div class="card-sub">blueprint · Metaspace</div></div>
  <div class="arrow">→</div>
  <div class="card"><div class="card-title mono">new Foo()</div><div class="card-sub">objects · Heap</div></div>
</div>

<v-clicks>

<div class="grid grid-cols-3 gap-8 mt-14">
  <div><div class="accent mono text-sm mb-1">Class</div>A blueprint. <b>One per class loader</b></div>
  <div><div class="accent mono text-sm mb-1">Object</div>A house built from it. Build as many as you like</div>
  <div><div class="accent mono text-sm mb-1">Loader</div>Delivers the blueprint. Doesn't build anything</div>
</div>

</v-clicks>

---

###### Part 2 · ClassLoader

# Class lifecycle

<div class="grid grid-cols-3 gap-6 mt-8">

<div v-click class="card">
  <div class="tag hot mb-3">01 · Loading</div>
  <div class="mono text-sm muted leading-7">
    Foo<br>→ com/example/Foo.class<br>→ bytes<br>→ <span class="accent">defineClass()</span>
  </div>
</div>

<div v-click class="card">
  <div class="tag hot mb-3">02 · Linking</div>
  <div class="text-sm leading-7">
    <b>Verify</b> <span class="muted">— bytecode is valid and doesn't lie</span><br>
    <b>Prepare</b> <span class="muted">— space for <code>static</code> fields, set to zero</span><br>
    <b>Resolve</b> <span class="muted">— names → real addresses, often lazily</span>
  </div>
</div>

<div v-click class="card">
  <div class="tag hot mb-3">03 · Initialization</div>
  <div class="text-sm leading-7">
    <code>static { ... }</code><br>
    <span class="muted">Runs <b>once</b>, thread-safe</span>
  </div>
</div>

</div>

---

###### Part 2 · ClassLoader

# Everything is lazy

<div class="grid grid-cols-[1.35fr_1fr] gap-8">
<div>

<div class="muted text-sm mb-1">Loads <b>and</b> initializes — one is enough</div>

```java
new Foo();                         // instance
Foo.helper();                      // static call
Class.forName("com.example.Foo");  // reflection
```

<div v-click>
<div class="muted text-sm mb-1 mt-6">Just mentioning the type — not enough</div>

```java
Foo f = null;            // nothing happens
Class<?> c = Foo.class;  // loaded, no static {}
int n = Foo.COUNT;       // inlined, Foo not loaded
```

</div>
</div>
<div v-click>

<div class="card hot">
  <div class="card-title">Consequence</div>
  <div class="text-sm mt-2"><code>NoClassDefFoundError</code> can hit <b>an hour after startup</b> — in a code path nobody visited. Not even QA.</div>
</div>

```bash
java -Xlog:class+load=info -jar app.jar
```

<div class="text-sm muted">What got loaded, when, and <b>from where</b></div>

</div>
</div>

<div class="aside">
The concierge opens the door for a key <b>or</b> a code <b>or</b> a phone call — one is enough. Walking past the building isn't.
</div>

<!--
Reading a non-constant static field also triggers loading, same as `Foo.helper()`.

The constant gotcha: if `COUNT` is a compile-time constant (a `static final` primitive or `String` with a constant value), javac copies the value into the caller. `Foo` is not loaded at all.

Bonus: change `COUNT`, recompile only `Foo`, and the caller keeps the old value. Fun at deploy time.
-->

---

###### Part 2 · ClassLoader

# Class loader hierarchy

<div class="grid grid-cols-[1.3fr_1fr] gap-12 items-center mt-4">

<div class="flex flex-col gap-2">
  <div class="card">
    <div class="flex justify-between"><span class="card-title">Bootstrap</span><span class="tag">built into the JVM</span></div>
    <div class="card-sub mono mt-1">String · List · Map</div>
  </div>
  <div class="text-center faint mono text-xs">▲ parent</div>
  <div class="card">
    <div class="flex justify-between"><span class="card-title">Platform</span><span class="tag">extra JDK</span></div>
    <div class="card-sub mono mt-1">java.sql · java.compiler · java.net.http</div>
  </div>
  <div class="text-center faint mono text-xs">▲ parent</div>
  <div class="card hot">
    <div class="flex justify-between"><span class="card-title">App</span><span class="tag hot">you are here</span></div>
    <div class="card-sub mono mt-1">your code + every JAR Maven added</div>
  </div>
</div>

<div>

- Each loader has a **parent** — the floor above
- Higher = more basic, more trusted
- Your classes live on the ground floor

</div>
</div>

<div v-click class="aside">
Top floor — the owner. Middle — the management company. Ground floor — you, next to the bins.
</div>

<!--
Most core modules, `java.xml` included, live on the top floor (Bootstrap). Platform gets the "extra" ones like `java.sql` and `java.compiler`.
-->

---

###### Part 2 · ClassLoader

# Delegation: parent-first

<div class="grid grid-cols-[auto_1fr] gap-10 items-center">

```java {all|2|4|6|all}
protected Class<?> loadClass(String name) {
    Class<?> c = findLoadedClass(name);          // 1. cache
    if (c == null) {
        try { c = getParent().loadClass(name); } // 2. parent
        catch (ClassNotFoundException e) {
            c = findClass(name);                 // 3. myself
        }
    }
    return c;
}
```

<div>

- Only **one** `java.lang.String` — nobody can swap it
- One loader → **one version** of each class

</div>
</div>

<div class="aside">
The intern asks the boss first. He answers himself only if the boss has no idea.
</div>

<!--
This code is simplified. Since JDK 9 the built-in loaders delegate by module first: they check which module owns the package and go straight to that module's loader.

Also, Platform's `getParent()` returns `null`. Bootstrap is native code, not a Java object. So "ask the top floor" is a native call, not `getParent().loadClass()`.
-->

---
layout: statement
---

###### The key insight

# Class = <span class="muted">name</span> + <span class="accent">loader</span>

<v-clicks>

<div class="mt-10 text-lg muted leading-9">
Whoever called <code>defineClass()</code> is the <b>defining loader</b> — forever<br>
Same bytes, two loaders → <b>two different classes</b><br>
<code>instanceof</code>, casts, <code>==</code> on <code>Class</code> — all check the loader
</div>

</v-clicks>

<!--
Analogy: twins with different passports. Same face, but border control won't let one travel on the other's passport.
-->

---

###### Part 2 · ClassLoader

# The most absurd error in Java

<div class="card mono text-base leading-8 mt-8">
  <div style="color:#ff6b6b">java.lang.ClassCastException:</div>
  <div class="pl-4">class <b>com.example.Foo</b> cannot be cast to class <b>com.example.Foo</b></div>
  <div v-click class="pl-4 muted">
    (com.example.Foo is in unnamed module of loader <span class="accent font-600">'app'</span>;<br>
    &nbsp;com.example.Foo is in unnamed module of loader <span class="alt font-600">com.example.PluginLoader @6d06d69c</span>)
  </div>
</div>

<div v-click class="mt-10 text-xl">
The JVM is being honest: these are <span class="accent">different classes</span>.<br>
<span class="muted">We just never read past the first line.</span>
</div>

---

###### Part 3 · Plugins

# The task: a plugin system

<div class="grid grid-cols-3 gap-4 mt-8 mb-8">
  <div class="card"><div class="card-title">Host</div><div class="card-sub mono">jackson 2.16</div></div>
  <div class="card cool"><div class="card-title">Plugin A</div><div class="card-sub mono">jackson 2.15</div></div>
  <div class="card hot"><div class="card-title">Plugin B</div><div class="card-sub mono">jackson 2.17</div></div>
</div>

<v-clicks>

- The app loads third-party JARs **at runtime**
- Maven can't help: it picks **one** version

</v-clicks>

<div v-click class="mt-10 text-xl">
<span class="accent">Goal:</span> each plugin gets its own versions of its dependencies
</div>

---

###### Part 3 · Plugins

# Solution: a child-first loader

````md magic-move {lines: false}
```java
class PluginClassLoader extends URLClassLoader {
    @Override
    protected Class<?> loadClass(String name, boolean resolve) {
        // 1. cache
        // 2. shared package → parent
        // 3. otherwise → own JARs first, then parent
    }
}
```

```java
class PluginClassLoader extends URLClassLoader {
    @Override
    protected Class<?> loadClass(String name, boolean resolve) throws ClassNotFoundException {
        synchronized (getClassLoadingLock(name)) {
            Class<?> c = findLoadedClass(name);                // 1. cache
            if (c == null && isShared(name))
                c = getParent().loadClass(name);               // 2. shared → parent
            if (c == null) {
                try { c = findClass(name); }                   // 3. own JARs first
                catch (ClassNotFoundException e) { c = getParent().loadClass(name); }
            }
            if (resolve) resolveClass(c);
            return c;
        }
    }
}
```
````

<style>
.slidev-code { --slidev-code-font-size: 12.5px; }
h1 { margin-bottom: 1rem; }
</style>

<!--
Each plugin gets its own loader with its own JARs. Look at home first, then ask the parent.

Shared packages skip the "home first" step. In two slides you'll see why that's not optional.

Isolation achieved! But…
-->

---
layout: statement
---

# Isolation achieved! <span class="accent">But…</span>

---

###### Part 3 · Plugins

# …and then everything explodes

```java
Plugin p = (Plugin) pluginClass.getDeclaredConstructor().newInstance();
```

<div class="mono text-sm mt-2" style="color:#ff6b6b">ClassCastException: Plugin cannot be cast to Plugin</div>

<div v-click class="flow mt-8">
  <div class="card flex-1"><div class="card-sub">host loader</div><div class="card-title mono">Plugin</div></div>
  <div class="arrow text-2xl accent">≠</div>
  <div class="card cool flex-1"><div class="card-sub">plugin loader</div><div class="card-title mono">Plugin</div></div>
</div>

<div v-click class="mt-8">

**Takeaway:** shared contracts load <span class="accent">parent-first</span> <span class="muted">— the host↔plugin API and anything that crosses the boundary</span>

</div>

<!--
The twins again: the host has its own `Plugin`, and the plugin loader made a second one from the plugin JAR. Same face, different passport.

Parent-first means: the host↔plugin API, logging, metrics, anything both sides touch. And `java.*`, because the JVM won't let you define those anyway ("Prohibited package name").
-->

---

###### Part 3 · Plugins

# The boundary: a whitelist

<div class="grid grid-cols-2 gap-6 mt-6">
  <div class="card hot">
    <div class="tag hot mb-3">parent-first</div>
    <div class="mono text-sm leading-7">java.*<br>javax.{crypto,net,xml}.*<br>com.example.plugin.api.*<br>org.slf4j.*<br><span class="muted">&lt;metrics library&gt;</span></div>
  </div>
  <div class="card cool">
    <div class="tag mb-3" style="color:var(--noir-alt);border-color:var(--noir-alt)">child-first</div>
    <div class="mono text-sm leading-7">everything else</div>
  </div>
</div>

<div v-click class="grid grid-cols-2 gap-6 mt-8 text-base">
  <div><span class="accent">Less shared</span> → stronger isolation</div>
  <div><span class="alt">More shared</span> → fewer duplicates, fewer border problems</div>
</div>

<div v-click class="aside">
<code>javax.*</code> looks like a JDK passport. Half are fake — hello, <code>javax.inject</code>.
</div>

<!--
This is a deliberate trade-off, not a default setting.

Why `javax.*` as a whole is a trap: in our loader, a shared name goes only to the parent, with no fallback. `javax.inject`, `javax.servlet` and `javax.annotation` are normal libraries. The plugin ships one, the host doesn't, and you get `ClassNotFoundException`.

Careful with `javax.xml.*` too: `javax.xml.bind` (JAXB) and `javax.xml.ws` left the JDK in 11. If plugins bring their own JAXB, keep those child-first.
-->

---

###### Part 3 · Plugins

# ServiceLoader and `META-INF/services`

```java
ServiceLoader.load(Plugin.class, pluginClassLoader);
```

<v-clicks>

- Pass the loader **explicitly** — or you get the thread's context loader
- Classes and resources are **separate**: the interface comes from the parent, `META-INF/services/*` files from both levels
- Some SPIs hate two providers (hello, logger bindings) → **parent only**

</v-clicks>

---

###### Part 3 · Plugins

# Subtle traps

<div class="grid grid-cols-2 gap-5 mt-4">

<div v-click class="card">
  <div class="card-title mono text-sm accent">NoClassDefFoundError</div>
  <div class="text-sm mt-2 muted">The class was there at compile time. At runtime it's <b>missing</b> — or its <code>static {}</code> blew up</div>
</div>

<div v-click class="card">
  <div class="card-title mono text-sm accent">LinkageError: loader constraint violation</div>
  <div class="text-sm mt-2 muted">Two loaders promised to see the same type. Each brought its own</div>
</div>

<div v-click class="card">
  <div class="card-title text-sm accent">Generic type erasure</div>
  <div class="text-sm mt-2 muted">Can <b>hide</b> a conflict: no type in bytecode → no check. Until someone calls <code>get()</code></div>
</div>

<div v-click class="card">
  <div class="card-title text-sm accent">Loader leak</div>
  <div class="text-sm mt-2 muted">One live plugin object, static ref, ThreadLocal or thread — and the <b>whole loader</b> stays in memory</div>
</div>

</div>

---

###### Part 3 · Plugins

# Design rules

<v-clicks>

1. **Thin API module** — few classes on the boundary
2. **Explicit whitelist** of parent-first packages
3. **Explicit loader** in `ServiceLoader` and `Class.forName`
4. **Switch TCCL** into the plugin, restore in `finally`
5. **Don't pass child-first classes** across the boundary
6. **Clean up on unload** — threads, ThreadLocals, caches
7. **`close()` the `URLClassLoader`** — frees JAR files
8. **Test isolation** — two plugins, two versions

</v-clicks>

<!--
TCCL = thread context class loader. Jackson modules, JAXB and many SPIs look up classes via `Thread.currentThread().getContextClassLoader()`. Set it to the plugin loader before the call and restore it in `finally`. Otherwise the plugin's code goes looking for its classes in the host's flat.

`close()`: a `URLClassLoader` keeps its JAR files open. Forget it, and on Windows you can't even delete the old plugin JAR.
-->

---

###### Alternatives

# Can we do without a custom loader?

<div class="mt-14">
  <div class="flex justify-between text-xs mono faint mb-3">
    <span>← cheaper</span><span>more isolated →</span>
  </div>
  <div style="height:2px;background:linear-gradient(90deg,var(--noir-faint),var(--noir-accent))"></div>
  <div class="grid grid-cols-5 gap-4 mt-6 text-center">
    <div v-click><div class="card-title">Shading</div><div class="card-sub">build</div></div>
    <div v-click><div class="card-title">JPMS</div><div class="card-sub">modules</div></div>
    <div v-click><div class="card-title accent">Custom loader</div><div class="card-sub">runtime, by hand</div></div>
    <div v-click><div class="card-title">OSGi</div><div class="card-sub">runtime, framework</div></div>
    <div v-click><div class="card-title">Separate process</div><div class="card-sub">infrastructure</div></div>
  </div>
</div>

<div class="aside">
The further right — the fewer conflicts, and the bigger the bill in complexity.
</div>

---

###### Alternatives

# One line each

<div class="mt-2 text-[0.95rem]">
<div v-click class="grid grid-cols-[10rem_14rem_1fr] gap-4 py-3 border-b border-[var(--noir-border)]">
  <b>Shading</b><span class="accent">rename one twin</span><span class="muted">Packages renamed at build time. Breaks on reflection and class names in strings</span>
</div>
<div v-click class="grid grid-cols-[10rem_14rem_1fr] gap-4 py-3 border-b border-[var(--noir-border)]">
  <b>JPMS</b><span class="accent">apartments with locks</span><span class="muted">Strong walls, one version per module. Several versions only via <code>ModuleLayer</code> — a custom loader in disguise</span>
</div>
<div v-click class="grid grid-cols-[10rem_14rem_1fr] gap-4 py-3 border-b border-[var(--noir-border)]">
  <b>Custom loader</b><span class="accent">your own building manager</span><span class="muted">Full control, plugins at runtime — and every trap is yours</span>
</div>
<div v-click class="grid grid-cols-[10rem_14rem_1fr] gap-4 py-3 border-b border-[var(--noir-border)]">
  <b>OSGi</b><span class="accent">bureaucratic housing office</span><span class="muted">Every tenant signs a contract with versions. Powerful, battle-tested, heavy</span>
</div>
<div v-click class="grid grid-cols-[10rem_14rem_1fr] gap-4 py-3">
  <b>Separate process</b><span class="accent">separate houses</span><span class="muted">Total isolation — but borrowing sugar means crossing the street: network, serialization, memory</span>
</div>
</div>

<div v-click class="aside">
Tomcat, Jenkins, Elasticsearch, IntelliJ plugins — custom loaders. Eclipse — OSGi. gRPC — shades Netty.
</div>

---

###### Summary

# What to take home

<v-clicks>

1. Maven picks **one** version — nearest, not newest
2. A loader delivers the **blueprint**; objects come later
3. Everything is **lazy** → errors show up late
4. **Class = name + class loader**
5. Isolation = child-first + **carefully chosen** shared contracts

</v-clicks>

---
layout: statement
---

# Questions?

<div class="mono text-lg muted mt-8">
<span class="line-through decoration-[var(--noir-accent)] decoration-2">Foo cannot be cast to Foo</span>
</div>

<div class="mt-3 muted">now you know why</div>
