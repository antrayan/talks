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

Plan: Maven picks the JARs → class loaders pick the classes → how to build plugins and stay sane.

One metaphor for the whole talk: an apartment building. Maven is the doorman, class loaders are the floors, classes are the tenants.
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

<!--
One classpath = the input of one loader (App). Plugin loaders get their own JAR lists, and Maven knows nothing about them. That's Part 3.
-->

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
The doorman lets in one tenant per surname. Not the youngest, not the best — whoever stands <b>closest to the door</b>.
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
Maven followed its rules perfectly. lib-C just didn't get the version it was compiled against.

Both enforcer rules only look at versions of the same artifact. They don't see "different names, same classes" — that's the next slide. For that case, use `banDuplicateClasses` from extra-enforcer-rules.
-->

---

###### Part 1 · Maven

# Maven's monologue

<v-clicks>

- "I read `pom.xml` and compare **names**: `groupId:artifactId`"
- "Same name, two versions? I keep **one** — by my rules"
- "Different names? Two libraries. **Both** go in"
- "Same classes inside? <span class="accent">Not my problem.</span>"

</v-clicks>

<div v-click class="mt-8 text-xl">
→ My output: a <b>flat list of JARs</b>. <span class="muted">Class loader, your turn.</span>
</div>

<div v-click class="aside">
The doorman checks surnames, not faces. Ivanov and Petrov both get in — even if Petrov is Ivanov in a wig.
</div>

<!--
"Different names, same classes" examples:
- `javax.servlet:servlet-api` vs `jakarta.servlet-api` 4.x. The second is the old API under new coordinates, still `javax.servlet` inside.
- `commons-logging` vs `jcl-over-slf4j`. Both contain `org.apache.commons.logging`.
- A fat JAR with a copy of Guava inside, packages not renamed (shading without relocation). Maven sees one Guava, the JVM sees two.

What happens next: the App loader walks the classpath in order. For each class, the first JAR that has it wins. That's decided per class, so you can end up with a mix of two versions of one API.

The JAR order comes from the pom: direct dependencies first, in declaration order, then transitive ones. Check it with `mvn dependency:build-classpath`.
-->

---

###### Part 2 · ClassLoader

# What happens to the JARs next?

<div class="flow mt-10">
  <div class="card"><div class="card-title mono">pom.xml</div><div class="card-sub">what you asked for</div></div>
  <div class="arrow">→</div>
  <div class="card"><div class="card-title">classpath</div><div class="card-sub">Maven's output · loader's input</div></div>
  <div class="arrow">→</div>
  <div class="card hot"><div class="card-title">ClassLoader</div><div class="card-sub">reads bytes</div></div>
  <div class="arrow">→</div>
  <div class="card"><div class="card-title mono">Class&lt;?&gt;</div><div class="card-sub">floor plan · Metaspace</div></div>
  <div class="arrow">→</div>
  <div class="card"><div class="card-title mono">new Foo()</div><div class="card-sub">objects · Heap</div></div>
</div>

<v-clicks>

<div class="grid grid-cols-3 gap-8 mt-14">
  <div><div class="accent mono text-sm mb-1">Class</div>A floor plan. <b>One per class loader</b></div>
  <div><div class="accent mono text-sm mb-1">Object</div>A flat built from it. Build as many as you like</div>
  <div><div class="accent mono text-sm mb-1">Loader</div>Delivers the plan. Doesn't build anything</div>
</div>

</v-clicks>

<!--
Inside one classpath: the first JAR that has the class wins, per class. Parent-first is a different thing — it's between loaders (floors), coming up next.
-->

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

<div class="muted text-sm mb-1">Any <b>one</b> of these loads and initializes <code>Foo</code></div>

```java
new Foo();                         // instance
Foo.helper();                      // static call
Class.forName("com.example.Foo");  // reflection
```

<div v-click>
<div class="muted text-sm mb-1 mt-6">These do <b>not</b> initialize <code>Foo</code></div>

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
Nobody turns on the lights in an empty flat. First real visitor — and they go on. Walking past the door doesn't count.
</div>

<!--
Reading a non-constant static field also triggers loading, same as `Foo.helper()`.

The constant gotcha: if `COUNT` is a compile-time constant (a `static final` primitive or `String` with a constant value), javac copies the value into the caller. `Foo` is not loaded at all.

Bonus: change `COUNT`, recompile only `Foo`, and the caller keeps the old value. Fun at deploy time.
-->

---

###### Part 2 · ClassLoader

# Class loader hierarchy

<div class="flex flex-col gap-2 mt-2">
  <div v-click="2" class="card py-2">
    <div class="flex justify-between"><span class="card-title">Bootstrap</span><span class="tag">built into the JVM</span></div>
    <div class="text-sm muted mt-1">"I'm native code — C++, written by the JVM folks. I own <code>java.base</code>: <code>String</code>, <code>Object</code>, <code>List</code>. Don't have it? Not my problem."</div>
  </div>
  <div v-click="2" class="text-center faint mono text-xs">▲ asks first</div>
  <div v-click="1" class="card py-2">
    <div class="flex justify-between"><span class="card-title">Platform</span><span class="tag">extra JDK</span></div>
    <div class="text-sm muted mt-1">"I keep the extra JDK modules: <code>java.sql</code>, <code>java.compiler</code>, <code>java.net.http</code>. Anything else — I check with Bootstrap first."</div>
  </div>
  <div v-click="1" class="text-center faint mono text-xs">▲ asks first</div>
  <div class="card hot py-2">
    <div class="flex justify-between"><span class="card-title">App</span><span class="tag hot">you are here</span></div>
    <div class="text-sm muted mt-1">"Maven handed me a list of JARs. Someone asks for a class — I ask upstairs first. They shrug? I search my JARs, top to bottom. First match wins."</div>
  </div>
</div>

<div v-click="3" class="aside">
Top floor — the owner. Middle — the management company. Ground floor — you, with Maven's shopping list.
</div>

<!--
The question "do you have `Foo`?" goes bottom-up: App → Platform → Bootstrap. Nobody hands work downstairs. If upstairs has nothing, the lower floor looks for itself.

Each loader has a parent — the floor above. Higher = more basic, more trusted.

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

- **The default** — every `URLClassLoader` works like this
- Only **one** `java.lang.String` — nobody can swap it
- Parent always wins → **its version** always wins

</div>
</div>

<div class="aside">
The ground floor always asks upstairs first. It handles things itself only if upstairs shrugs.
</div>

<!--
This is what App said in its monologue, as code.

This code is simplified. Since JDK 9 the built-in loaders delegate by module first: they check which module owns the package and go straight to that module's loader.

Also, Platform's `getParent()` returns `null`. Bootstrap is native code, not a Java object. So "ask the top floor" is a native call, not `getParent().loadClass()`.
-->

---

###### Part 2 · ClassLoader

# Can I write my own `java.lang.String`?

<div v-click>
<div class="muted text-sm mb-1">Attempt 1: put my <code>String.class</code> in app.jar</div>

```java
String s = "hi";   // JDK's String. Mine is never even read
```

</div>

<div v-click>
<div class="muted text-sm mb-1 mt-4">Attempt 2: my own loader, skip the parent</div>

```java
defineClass("java.lang.String", bytes, 0, bytes.length);
// SecurityException: Prohibited package name: java.lang
```

</div>

<div v-click>
<div class="muted text-sm mb-1 mt-4">Attempt 3: the official back door</div>

```bash
java --patch-module java.base=my-string.jar -jar app.jar   # works. You're a JDK developer now
```

</div>

<div v-click class="aside">
You can't swap the building's foundation from your flat. Only the developer can — with a permit and a hard hat.
</div>

<style>
.slidev-code { --slidev-code-font-size: 12.5px; }
</style>

<!--
Attempt 1: the App loader sees the package `java.lang`, knows it belongs to the `java.base` module, and goes straight to Bootstrap (module-first delegation, JDK 9+). Bootstrap returns its own `String`. Your file is never even opened. Parent-first in action.

Attempt 2: `ClassLoader.preDefineClass` forbids `java.*` packages for everyone except Bootstrap and Platform. So `java.*` on the plugin shared list later isn't a choice — it's the law.

Attempt 3: `--patch-module` (formerly `-Xbootclasspath/p`, removed in JDK 9) replaces classes of `java.base` itself. Used for JDK development and exotic debugging.

Takeaway: many loaders out of the box, but everyone asks upstairs, so everyone sees the same JDK. Your own loaders add floors, not a new foundation.
-->

---
layout: statement
---

###### The key insight

# Class = <span class="muted">name</span> + <span class="accent">loader</span>

<v-clicks>

<div class="mt-10 text-lg muted leading-9">
The loader that called <code>defineClass()</code> <b>owns</b> the class for life<br>
Same bytes, two loaders → <b>two different classes</b><br>
<code>instanceof</code>, casts, <code>==</code> on <code>Class</code> — all check the loader
</div>

</v-clicks>

<!--
"Owns for life": a class can't move to another loader. It is unloaded only together with its loader, when nothing references either of them.

Analogy: class = name + loader is like tenant = surname + flat. Ivanov from flat 1 is not Ivanov from flat 42, even if they look the same.
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

<!--
Ivanov from flat 1 and Ivanov from flat 42. Same surname, different people — the second half of the message says which flats.
-->

---

###### Part 3 · Plugins

# The task: plug into a big host

<div class="grid grid-cols-2 gap-6 mt-8 mb-8">
  <div class="card"><div class="card-title">Host</div><div class="card-sub mono">jackson 2.16 · mysql 8.0</div></div>
  <div class="card cool"><div class="card-title">Plugin</div><div class="card-sub mono">jackson 2.17 · mysql 8.4</div></div>
</div>

<v-clicks>

- The host loads the plugin JAR **at runtime**
- Maven can't help: it never saw the plugin

</v-clicks>

<div v-click class="mt-10 text-xl">
<span class="accent">Goal:</span> the plugin runs on <b>its own</b> libraries
</div>

<div v-click class="aside">
A new tenant arrives with his own furniture. The building says: <b>"flats come furnished — use ours."</b>
</div>

<!--
The host is a big system with its own libraries. We don't control them, and we don't want every plugin author to match our versions.

Five steps from here: attempt, attempt, error, fix, error + fix.
-->

---

###### Part 3 · Step 1

# Attempt 1: just a URLClassLoader

```java
var loader = new URLClassLoader(pluginJars, hostLoader);
var cls = loader.loadClass("com.acme.MyPlugin");
Plugin p = (Plugin) cls.getDeclaredConstructor().newInstance();
p.run();   // plugin calls a jackson 2.17 method
```

<div class="mono text-sm mt-2" style="color:#ff6b6b">java.lang.NoSuchMethodError: com.fasterxml.jackson…</div>

<div v-click class="flow mt-6">
  <div class="card"><div class="card-sub">plugin loader</div><div class="card-title">asks parent first</div></div>
  <div class="arrow">→</div>
  <div class="card hot"><div class="card-sub">host loader</div><div class="card-title">has jackson 2.16</div></div>
  <div class="arrow">→</div>
  <div class="card"><div class="card-sub">plugin code</div><div class="card-title">wanted 2.17</div></div>
</div>

<div v-click class="mt-8 text-xl">
Default delegation = <span class="accent">the host always wins</span>
</div>

<!--
This is the parent-first default from Part 2. The URLClassLoader asks the host first. The host has jackson 2.16, so the plugin never sees its own 2.17. The jackson inside the plugin JAR is dead weight.
-->

---

###### Part 3 · Step 2

# Attempt 2: child-first

````md magic-move {lines: false}
```java
class PluginClassLoader extends URLClassLoader {
    @Override
    protected Class<?> loadClass(String name, boolean resolve) {
        // 1. cache
        // 2. own JARs first
        // 3. not found → parent
    }
}
```

```java
class PluginClassLoader extends URLClassLoader {
    @Override
    protected Class<?> loadClass(String name, boolean resolve) throws ClassNotFoundException {
        Class<?> c = findLoadedClass(name);                // 1. cache
        if (c == null) {
            try { c = findClass(name); }                   // 2. own JARs first
            catch (ClassNotFoundException e) { c = getParent().loadClass(name); }
        }
        if (resolve) resolveClass(c);
        return c;
    }
}
```
````

<style>
.slidev-code { --slidev-code-font-size: 12.5px; }
h1 { margin-bottom: 1rem; }
</style>

<!--
Flip the order: look at home first, ask the parent only if not found. Now the plugin gets its own jackson 2.17.

Real code wraps the body in `synchronized (getClassLoadingLock(name))`. Skipped here to fit the slide.

Isolation achieved! But…
-->

---
layout: statement
---

# Isolation achieved! <span class="accent">But…</span>

---

###### Part 3 · Step 3

# Error: Plugin ≠ Plugin

```java
var loader = new PluginClassLoader(pluginJars, hostLoader);
var cls = loader.loadClass("com.acme.MyPlugin");
Plugin p = (Plugin) cls.getDeclaredConstructor().newInstance();  // boom
```

<div class="mono text-sm mt-2" style="color:#ff6b6b">ClassCastException: Plugin cannot be cast to Plugin</div>

<div v-click class="flow mt-8">
  <div class="card flex-1"><div class="card-sub">host loader</div><div class="card-title mono">Plugin</div></div>
  <div class="arrow text-2xl accent">≠</div>
  <div class="card cool flex-1"><div class="card-sub">plugin loader</div><div class="card-title mono">Plugin</div></div>
</div>

<div v-click class="mt-8">

**Fix:** shared contracts load <span class="accent">parent-first</span> <span class="muted">— the host↔plugin API and anything that crosses the boundary</span>

</div>

<!--
Why: the plugin is built as a fat JAR, and the plugin API classes are inside it. Child-first finds its own copy of `Plugin` first.

Two Ivanovs in different flats: the host has its own `Plugin`, and the plugin loader made a second one from the plugin JAR. Same surname, different people.

Parent-first means: the host↔plugin API, logging, metrics, anything both sides touch. And `java.*`, because the JVM won't let you define those anyway — remember the `String` slide.
-->

---

###### Part 3 · Step 4

# Fix: shared packages go to the parent

````md magic-move {lines: false}
```java
class PluginClassLoader extends URLClassLoader {
    @Override
    protected Class<?> loadClass(String name, boolean resolve) throws ClassNotFoundException {
        Class<?> c = findLoadedClass(name);                // 1. cache
        if (c == null) {
            try { c = findClass(name); }                   // 2. own JARs first
            catch (ClassNotFoundException e) { c = getParent().loadClass(name); }
        }
        if (resolve) resolveClass(c);
        return c;
    }
}
```

```java
class PluginClassLoader extends URLClassLoader {
    static final List<String> SHARED = List.of("java.", "javax.crypto.", "com.example.plugin.api.", "org.slf4j.");

    @Override
    protected Class<?> loadClass(String name, boolean resolve) throws ClassNotFoundException {
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
    boolean isShared(String n) { return SHARED.stream().anyMatch(n::startsWith); }
}
```
````

<style>
.slidev-code { --slidev-code-font-size: 12px; }
h1 { margin-bottom: 1rem; }
</style>

<!--
Same loader, plus one list. Names from `SHARED` always come from the host. Everything else is still child-first.

Now `Plugin` comes from the host on both sides, so the cast works. Next slide: how to choose that list.
-->

---

###### Part 3 · Detour

# Which packages to share?

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
<code>javax.*</code> sounds like building staff. Half of them are just tenants — hello, <code>javax.inject</code>.
</div>

<!--
This is a deliberate trade-off, not a default setting.

Why `javax.*` as a whole is a trap: in our loader, a shared name goes only to the parent, with no fallback. `javax.inject`, `javax.servlet` and `javax.annotation` are normal libraries. The plugin ships one, the host doesn't, and you get `ClassNotFoundException`.

Careful with `javax.xml.*` too: `javax.xml.bind` (JAXB) and `javax.xml.ws` left the JDK in 11. If plugins bring their own JAXB, keep those child-first.
-->

---

###### Part 3 · Detour

# What is SPI?

<div class="grid grid-cols-3 gap-4 mt-6">

<div v-click class="card">
  <div class="tag hot mb-3">01 · Interface</div>
  <div class="mono text-sm">java.sql.Driver</div>
  <div class="text-sm muted mt-2">Lives in the JDK. Knows nothing about MySQL</div>
</div>

<div v-click class="card">
  <div class="tag hot mb-3">02 · Registration</div>
  <div class="mono text-sm">META-INF/services/<br>java.sql.Driver</div>
  <div class="text-sm muted mt-2">A text file in the MySQL JAR: <code>com.mysql.cj.jdbc.Driver</code></div>
</div>

<div v-click class="card">
  <div class="tag hot mb-3">03 · Lookup</div>
  <div class="mono text-sm">ServiceLoader<br>.load(Driver.class)</div>
  <div class="text-sm muted mt-2">Reads those files through a loader — by default the <b>thread context</b> one</div>
</div>

</div>

<v-clicks>

- Pass the loader **explicitly**: `ServiceLoader.load(X.class, pluginLoader)`
- Some SPIs hate two providers (hello, logger bindings) → **parent only**

</v-clicks>

<div v-click class="aside">
The lobby board: the JDK writes the heading "Driver", every JAR pins its own number under it.
</div>

<!--
SPI = Service Provider Interface. Someone (the JDK, a framework) defines an interface. Any JAR can ship an implementation, and the caller never names it in code. Examples: JDBC drivers, logging bindings, Jackson modules (`findAndRegisterModules()`), JAXB.

Thread context class loader (TCCL): every thread carries one. By default it's the App loader, i.e. the host. So without an explicit loader, `ServiceLoader` reads the host's lobby board, not the plugin's.

Classes and resources are separate: the interface can come from the parent, while `META-INF/services/*` files are found in both the parent and the plugin JARs.
-->

---

###### Part 3 · Step 5

# Error: No suitable driver

```java
// inside the plugin
var conn = DriverManager.getConnection("jdbc:mysql://db/app", user, pass);
```

<div class="mono text-sm mt-2" style="color:#ff6b6b">SQLException: No suitable driver found for jdbc:mysql://db/app</div>

<div v-click class="flow mt-6">
  <div class="card"><div class="card-sub">DriverManager</div><div class="card-title">scans drivers once</div></div>
  <div class="arrow">→</div>
  <div class="card"><div class="card-sub">through the TCCL</div><div class="card-title">= host loader</div></div>
  <div class="arrow">→</div>
  <div class="card hot"><div class="card-sub">plugin's mysql 8.4</div><div class="card-title">never seen</div></div>
</div>

<div v-click>

```java
// fix, on start: load the driver through the plugin loader
Class.forName("com.mysql.cj.jdbc.Driver", true, pluginLoader);  // static {} registers it
// on unload, from plugin code
DriverManager.deregisterDriver(pluginDriver);                    // or the loader leaks
```

</div>

<style>
.slidev-code { --slidev-code-font-size: 12.5px; }
</style>

<!--
Two reasons it fails:
1. `DriverManager` scans `META-INF/services/java.sql.Driver` once, on first use, through the TCCL. That's the host's loader, so the plugin's driver is never found.
2. The host's own mysql 8.0 driver is registered. But `getConnection` checks whether the caller's loader sees the same driver class. The plugin loader loads its own copy of `com.mysql.cj.jdbc.Driver` (child-first — two Ivanovs again), so the host driver is skipped.

Fix: load the driver through the plugin loader. Its `static {}` calls `DriverManager.registerDriver`. Or skip `DriverManager` and create the driver's `DataSource` directly.

Switching the TCCL helps only if `DriverManager` hasn't scanned yet, and in a running host it usually has.

On unload: call `deregisterDriver` from plugin code. `DriverManager` is a JDK class that lives forever. If it holds the plugin's driver, the whole plugin loader leaks.
-->

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

1. **Shared list** of parent-first packages — API, logging, `java.*`
2. **Thin API module** — few classes on the boundary
3. **Explicit loader** for `ServiceLoader`, `Class.forName`, JDBC
4. **Switch TCCL** into the plugin, restore in `finally`
5. **Don't pass child-first classes** across the boundary
6. **On unload:** deregister drivers, stop threads, clear ThreadLocals
7. **`close()` the `URLClassLoader`** — frees JAR files
8. **Test isolation** — two plugins, two versions

</v-clicks>

<!--
The rules follow the story: steps 3–4 gave us the shared list and the thin API, step 5 gave us explicit loaders and driver cleanup.

TCCL = thread context class loader. Jackson modules, JAXB and many SPIs look up classes via `Thread.currentThread().getContextClassLoader()`. Set it to the plugin loader before the call and restore it in `finally`. Otherwise the plugin's code goes looking for its classes on the host's floor.

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
  <b>Shading</b><span class="accent">rename one Ivanov</span><span class="muted">Packages renamed at build time. Breaks on reflection and class names in strings</span>
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

1. Maven picks **JARs** by name — nearest wins
2. The class loader picks **classes** — first match wins
3. Everything is **lazy** → errors show up late
4. **Class = name + class loader**
5. Parent-first is the **default** — the host always wins
6. Plugins: child-first + a **shared list** + explicit loader for SPI

</v-clicks>

---
layout: statement
---

# Questions?

<div class="mono text-lg muted mt-8">
<span class="line-through decoration-[var(--noir-accent)] decoration-2">Foo cannot be cast to Foo</span>
</div>

<div class="mt-3 muted">now you know why</div>
