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
Open with a question: "Who has seen `ClassCastException: Foo cannot be cast to Foo`?" Usually half the room raises a hand. The other half hasn't read their logs yet.

Plan: Maven picks the JARs → class loaders pick the classes → plugins, and how to stay sane.
-->

---

###### Before we start

# Meet the ministry

<div class="grid grid-cols-3 gap-4 mt-6 text-sm">

<div v-click class="card">
  <div class="tag mb-2">Maven · HR</div>
  <div>"I approve which CV folders we accept. One per name."</div>
</div>

<div v-click class="card">
  <div class="tag mb-2">JAR · a CV folder</div>
  <div>"Full of CVs — that's classes. HR reads my label, never the CVs."</div>
</div>

<div v-click class="card hot">
  <div class="tag hot mb-2">ClassLoader · a department</div>
  <div>"I hire people. But first I always check with upstairs."</div>
</div>

<div v-click class="card">
  <div class="tag mb-2">Class · an employee</div>
  <div>"My ID is my name <b>plus</b> the department that hired me."</div>
</div>

<div v-click class="card">
  <div class="tag mb-2">Object · a stamped document</div>
  <div>"<code>new Foo()</code> — Foo stamps one more paper."</div>
</div>

<div v-click class="card cool">
  <div class="tag mb-2" style="color:var(--noir-alt);border-color:var(--noir-alt)">Plugin · a contractor crew</div>
  <div>"Called in on the fly. Own tools. Needs your sockets."</div>
</div>

</div>

<div v-click class="aside">
Lost at any point? Ask two questions: <b>which folder?</b> and <b>which department?</b>
</div>

<!--
The whole talk is one ministry. Introduce the cast once and keep coming back to it.

"Upstairs" always means "the parent loader".
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

- Libraries recommend their own libraries
- Two candidates: **jackson 2.15 and 2.17**
- Only **one** gets the job

<div v-click class="mt-8 text-2xl font-600">Who gets hired?</div>

</div>
</div>

<!--
Let the room guess. Most say "the newest". Wrong — next slide.
-->

---

###### Part 1 · Maven

# HR's rules

<v-clicks>

1. **Fewest handshakes wins** — closest to your `pom.xml`. *Not* the youngest
2. **A tie?** Whoever applied first — declared first
3. **The staffing plan** — `dependencyManagement` / BOM fixes the version from above
4. **The blacklist** — `exclusions` reject a candidate

</v-clicks>

<div v-click class="mt-8 text-lg">
→ Here <span class="accent font-600">2.15</span> gets the job. Two handshakes beat three, even though lib-C wanted 2.17
</div>

<div v-click class="aside">
"Young, experienced, brilliant — irrelevant. <b>Who recommended you?</b>" — HR
</div>

<!--
A direct dependency is the shortest possible chain (depth 1). That's why "just declare it directly" is the most common fix. It's rule 1 in action, not a separate rule.
-->

---

###### Part 1 · Maven

# Where it backfires

<div class="grid grid-cols-2 gap-10">
<div>

- lib-C was built for 2.17, got 2.15
- It calls a method 2.15 doesn't have
- → `NoSuchMethodError` **at runtime**

<div class="mt-6 text-xl">Green build. <span class="accent">Red production.</span></div>

```bash
mvn dependency:tree -Dverbose  # who got hired, who didn't
mvn dependency:build-classpath # the approved list
```

</div>
<div v-click>

<div class="card">
  <div class="card-title">Call the auditor: <code>maven-enforcer-plugin</code></div>
  <div class="card-sub mb-4">Catch it at build time, not in production</div>
  <div class="mono text-sm accent">requireUpperBoundDeps</div>
  <div class="text-sm muted mb-3">Fails if someone got an <b>older</b> version than they asked for</div>
  <div class="mono text-sm accent">dependencyConvergence</div>
  <div class="text-sm muted">Stricter: fails on <b>any</b> version mismatch</div>
</div>

</div>
</div>

<div v-click class="aside">
HR: <b>"Two jacksons applied. Auditor — your call."</b>
</div>

<!--
Maven followed its rules perfectly. lib-C just didn't get the version it was compiled against.

`-Dverbose` needs maven-dependency-plugin 3.2.0+. It was removed in 3.0 and came back later.

Both enforcer rules compare versions of the same artifact only. "Different names, same classes" is invisible to them — that's the next slide. For that case, use `banDuplicateClasses` from extra-enforcer-rules.
-->

---

###### Part 1 · Maven

# This week's interview: HR

<div class="flex flex-col gap-4 mt-4 text-base">
  <div v-click><span class="accent font-600">Q:</span> So you decide which JARs get in?<br><b>HR:</b> I read folder labels — <code>groupId:artifactId</code>. That's all I read.</div>
  <div v-click><span class="accent font-600">Q:</span> Two folders with the same label?<br><b>HR:</b> One gets approved. Fewest handshakes.</div>
  <div v-click><span class="accent font-600">Q:</span> Even if the other one is newer?<br><b>HR:</b> I don't do ages.</div>
  <div v-click><span class="accent font-600">Q:</span> Different labels, but the same people inside?<br><b>HR:</b> Both approved. I don't read CVs. Not my job.</div>
</div>

<div v-click class="mt-6 text-xl">
→ My output: an <b>approved list of folders</b> — the classpath. <span class="muted">Departments, your turn.</span>
</div>

<div v-click class="aside">
A folder labelled "Petrov", full of Ivanovs? Different label — approved.
</div>

<!--
Real "Petrovs full of Ivanovs":
- `javax.servlet:servlet-api` vs `jakarta.servlet:jakarta.servlet-api` 4.x. New label, still `javax.servlet` inside.
- `commons-logging` vs `jcl-over-slf4j`. Both contain `org.apache.commons.logging`.
- A fat JAR with Guava copied inside, packages not renamed. Maven sees one Guava, the JVM sees two.

The list order: Maven 3 reads the tree like a book — lib-A, everything under lib-A, then lib-B. So a dependency of lib-A can stand before your own lib-B. Maven 4 orders by depth: all direct dependencies first. Upgrading Maven can change which duplicate class wins. Check with `mvn dependency:build-classpath`.
-->

---

###### Part 2 · ClassLoader

# Three floors, one rule

<div class="flex flex-col gap-2 mt-2 mb-6">
  <div v-click="2" class="card py-2">
    <div class="flex justify-between"><span class="card-title">Bootstrap</span><span class="tag">top floor · the minister</span></div>
    <div class="text-sm muted mt-1">"<code>String</code>, <code>Object</code>, <code>List</code> — matters of state. <code>Foo</code>? Not my package."</div>
  </div>
  <div v-click="2" class="text-center faint mono text-xs">▲ "is Foo yours?"</div>
  <div v-click="1" class="card py-2">
    <div class="flex justify-between"><span class="card-title">Platform</span><span class="tag">deputy ministers</span></div>
    <div class="text-sm muted mt-1">"<code>java.sql</code>, <code>java.net.http</code> — mine. But first I check with the minister. <code>Foo</code>? Not my package either."</div>
  </div>
  <div v-click="1" class="text-center faint mono text-xs">▲ "is Foo yours?"</div>
  <div class="card hot py-2">
    <div class="flex justify-between"><span class="card-title">App</span><span class="tag hot">your department · you are here</span></div>
    <div class="text-sm muted mt-1">"I always check upstairs first. Not their package? Then I hire <code>Foo</code> myself — from the first folder that has his CV."</div>
  </div>
</div>

<div v-click="3" class="aside">
The rule: <b>escalate first</b>. Upstairs says "not my package" — handle it yourself.
</div>

<!--
"Is Foo yours?" always travels up. Higher floor = more basic, more trusted.

"Not my package" is the real mechanism, not a joke: since JDK 9 the built-in loaders keep a map "package → module → loader". They don't keep a list of classes, only places to look. A class is found on demand: the name becomes a path (`com/acme/Foo.class`), and the folders are checked one by one.

Most core modules, `java.xml` and `java.logging` included, sit with the minister. Deputies get the extras like `java.sql` and `java.compiler`.

Ten folders with `com.acme.Foo`? The first one wins, the other nine are never opened, and nobody warns you. It's decided per class, so `Foo` can come from folder 1 and `Bar` from folder 2. Catch it at build time with `banDuplicateClasses`.
-->

---

###### Part 2 · ClassLoader

# The rule as code: parent-first

<div class="grid grid-cols-[auto_1fr] gap-10 items-center">

```java {all|2|4|6|all}
protected Class<?> loadClass(String name) {
    Class<?> c = findLoadedClass(name);          // 1. already on staff?
    if (c == null) {
        try { c = getParent().loadClass(name); } // 2. escalate
        catch (ClassNotFoundException e) {
            c = findClass(name);                 // 3. hire myself
        }
    }
    return c;
}
```

<div>

- **The default** — every `URLClassLoader` works like this
- That's why there's exactly **one** `String`
- Upstairs always wins → **its version** always wins

</div>
</div>

<!--
This is App's monologue, as code.

Simplified. Since JDK 9 the built-in loaders first check which module owns the package and go straight to that module's loader.

Platform's `getParent()` returns `null`. Bootstrap is native code, not a Java object, so "ask the minister" is a native call.
-->

---

###### Part 2 · ClassLoader

# Officials are lazy

<div class="grid grid-cols-[1.35fr_1fr] gap-8">
<div>

<div class="muted text-sm mb-1">"I hire <code>Foo</code> only for <b>real</b> work:"</div>

```java
new Foo();                         // an instance
Foo.helper();                      // a static call
Class.forName("com.example.Foo");  // reflection
```

<div v-click>
<div class="muted text-sm mb-1 mt-6">"Not worth the paperwork:"</div>

```java
Foo f = null;            // just a name, Foo not hired
Class<?> c = Foo.class;  // hired, onboarding not done
int n = Foo.COUNT;       // constant copied, Foo not hired
```

</div>
</div>
<div v-click>

<div class="card hot">
  <div class="card-title">So what?</div>
  <div class="text-sm mt-2"><code>NoClassDefFoundError</code> can show up <b>an hour after startup</b> — in a code path nobody visited. Not even QA.</div>
</div>

```bash
java -Xlog:class+load=info -jar app.jar
```

<div class="text-sm muted">Who was hired, when, and <b>from which folder</b></div>

</div>
</div>

<div v-click class="aside">
Onboarding (<code>static {}</code>) happens once. Fail it — fired for good: <code>ExceptionInInitializerError</code> first, <code>NoClassDefFoundError</code> forever after.
</div>

<!--
The full lifecycle: loading (bytes → `defineClass()`), linking (verify the papers, give static fields default values, resolve names to addresses), initialization (`static {}`, once, thread-safe).

Reading a non-constant static field also triggers hiring, same as `Foo.helper()`.

The constant gotcha: a compile-time constant (`static final` primitive or `String`) is copied into the caller by javac. `Foo` is not loaded at all. Change `COUNT`, recompile only `Foo` — the caller keeps the old value. Fun at deploy time.

The second error says "Could not initialize class Foo". People go hunting for a missing JAR, but the real cause is in the very first stack trace.
-->

---

###### Sharpen your pencil

# Whose package is it?

<div class="grid grid-cols-[1fr_auto] gap-x-12 gap-y-4 mt-8 text-lg items-center">
  <div class="mono">java.lang.String</div>
  <div v-click class="accent">Bootstrap</div>
  <div class="mono">java.sql.Connection</div>
  <div v-click class="accent">Platform</div>
  <div class="mono">javax.xml.parsers.DocumentBuilder</div>
  <div v-click class="accent">Bootstrap (not Platform!)</div>
  <div class="mono">com.fasterxml.jackson.databind.ObjectMapper</div>
  <div v-click class="accent">App</div>
  <div class="mono">com.acme.Foo <span class="muted text-sm">· in 3 folders</span></div>
  <div v-click class="accent">App · first folder wins</div>
</div>

<div v-click class="aside">
<code>javax</code> doesn't mean "minor". The <code>java.xml</code> module is a matter of state.
</div>

<!--
Ask the room before each click. Wrong answers are the fun part.

`javax.xml.parsers` lives in the `java.xml` module, which belongs to Bootstrap. The prefix tells you nothing — the module decides. This sets up the `javax.*` trap in Part 3.
-->

---

###### Part 2 · ClassLoader

# Can I write my own `java.lang.String`?

<div v-click>
<div class="muted text-sm mb-1">Attempt 1: put my <code>String.class</code> into app.jar</div>

```java
String s = "hi";   // the JDK's String. Mine is never even opened
```

</div>

<div v-click>
<div class="muted text-sm mb-1 mt-4">Attempt 2: my own loader, don't escalate</div>

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
Forms with the state seal are printed by the ministry only. Anyone else — forgery.
</div>

<style>
.slidev-code { --slidev-code-font-size: 12.5px; }
</style>

<!--
Why the same name: the goal is to *replace* the system `String`. A class called `com.anton.String` is legal and boring — just a different class.

Attempt 1: App sees the package `java.lang`, knows it belongs to `java.base`, and goes straight to Bootstrap. `-Xlog:class+load` shows `java.lang.String source: shared objects file` — your file is never opened.

Attempt 2: `ClassLoader.preDefineClass` forbids `java.*` for every loader except Bootstrap and Platform. So `java.*` on the plugin shared list later isn't a choice — it's the law. Also, the name passed to `defineClass` must match the name inside the bytes.

Attempt 3: `--patch-module` (formerly `-Xbootclasspath/p`, removed in JDK 9) replaces classes inside `java.base`. For JDK development and exotic debugging.
-->

---
layout: statement
---

###### The one thing to remember

# Class = <span class="muted">name</span> + <span class="accent">loader</span>

<v-clicks>

<div class="mt-10 text-lg muted leading-9">
The department that called <code>defineClass()</code> <b>owns</b> the employee for life<br>
Same CV, two departments → <b>two different employees</b><br>
<code>instanceof</code>, casts, <code>==</code> on <code>Class</code> — all check the stamp
</div>

<div class="mt-8 text-xl">Ivanov from the ministry ≠ Ivanov from the contractor crew</div>

</v-clicks>

<!--
"Owns for life": a class can't move to another loader. It's unloaded only together with its loader, when nothing references either of them.

The package is part of the name: `com.a.Foo` and `com.b.Foo` are different classes anyway. Where the JAR lies on disk doesn't matter — only which loader defined the class.
-->

---

###### Part 2 · ClassLoader

# The most absurd error in Java

<div class="card mono text-base leading-8 mt-8">
  <div style="color:#ff6b6b">java.lang.ClassCastException:</div>
  <div class="pl-4">class <b>com.example.Foo</b> cannot be cast to class <b>com.example.Foo</b></div>
  <div v-click class="pl-4 muted">
    (com.example.Foo is in unnamed module of loader <span class="alt font-600">com.example.PluginClassLoader @6d06d69c</span>;<br>
    &nbsp;com.example.Foo is in unnamed module of loader <span class="accent font-600">'app'</span>)
  </div>
</div>

<div v-click class="mt-10 text-xl">
Same signature — <b>Ivanov</b>. Different stamp — <span class="accent">the contractor's</span>. Rejected.<br>
<span class="muted">The JVM even says whose stamp. We just never read past the first line.</span>
</div>

<!--
The message names the document's department first, then the department of the type you cast to. Here: a document stamped by the contractor's `Foo`, cast to the ministry's `Foo`.
-->

---

###### Part 3 · Plugins

# The task: call in a crew

<div class="grid grid-cols-2 gap-6 mt-8 mb-8">
  <div class="card"><div class="card-title">The ministry · host</div><div class="card-sub mono">jackson 2.16 · mysql 8.0</div></div>
  <div class="card cool"><div class="card-title">A contractor crew · plugin</div><div class="card-sub mono">jackson 2.17 · mysql 8.4</div></div>
</div>

<v-clicks>

- The ministry calls crews **at runtime**. Each gets its own office — a new loader
- HR never saw them — **Maven can't help**

</v-clicks>

<div v-click class="mt-10 text-xl">
<span class="accent">Goal:</span> <b>their own tools</b>, <b>our sockets</b>
</div>

<div v-click class="aside">
The ministry's habit: <b>"Leave your tools at the door. State-issued only — everything must be uniform."</b>
</div>

<!--
The crew's loader has the host's App loader as its parent. So "upstairs" for the crew is the ministry.

The host is big and has its own libraries. We don't want every plugin author to match our versions.

Tools = libraries the plugin uses inside. Sockets = types both sides touch. Hold on to that split — it's the whole of Part 3.
-->

---

###### Part 3 · Step 1

# Try 1: state-issued tools only

```java
var loader = new URLClassLoader(pluginJars, hostLoader);
var cls = loader.loadClass("com.acme.MyPlugin");
Plugin p = (Plugin) cls.getDeclaredConstructor().newInstance();
p.run();   // the plugin calls a jackson 2.17 method
```

<div class="mono text-sm mt-2" style="color:#ff6b6b">java.lang.NoSuchMethodError: com.fasterxml.jackson…</div>

<div v-click class="flow mt-6">
  <div class="card"><div class="card-sub">crew</div><div class="card-title">"need a jackson wrench"</div></div>
  <div class="arrow">→</div>
  <div class="card hot"><div class="card-sub">ministry</div><div class="card-title">"state-issued: 2.16"</div></div>
  <div class="arrow">→</div>
  <div class="card"><div class="card-sub">crew's code</div><div class="card-title">built for 2.17</div></div>
</div>

<div v-click class="mt-8 text-xl">
Parent-first: <span class="accent">state-issued always wins</span>. The crew's toolbox is never opened.
</div>

<!--
Exactly the default from Part 2: a URLClassLoader asks upstairs first. The cast works here — `Plugin` comes from the ministry on both sides. But the plugin's jackson 2.17 is dead weight in the JAR.
-->

---

###### Part 3 · Step 2

# Try 2: own tools first

````md magic-move {lines: false}
```java
class PluginClassLoader extends URLClassLoader {
    @Override
    protected Class<?> loadClass(String name, boolean resolve) {
        // 1. already have it?
        // 2. own toolbox first
        // 3. not found → ask the ministry
    }
}
```

```java
class PluginClassLoader extends URLClassLoader {
    @Override
    protected Class<?> loadClass(String name, boolean resolve) throws ClassNotFoundException {
        Class<?> c = findLoadedClass(name);                // 1. already have it?
        if (c == null) {
            try { c = findClass(name); }                   // 2. own toolbox first
            catch (ClassNotFoundException e) { c = getParent().loadClass(name); }
        }
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
Flip the order: own JARs first, upstairs only if not found. The plugin now gets its own jackson 2.17.

Real code wraps the body in `synchronized (getClassLoadingLock(name))` and ends with `if (resolve) resolveClass(c);`. Skipped to fit.
-->

---

###### Fireside chat

# Parent-first vs Child-first

<div class="muted text-sm -mt-2 mb-3">Tonight's talk: who decides which tools are used?</div>

<div class="flex flex-col gap-3 text-sm">
  <div v-click class="card hot py-2 mr-32"><b>Parent-first:</b> I escalate. Always. That's why the country has exactly one <code>String</code>.</div>
  <div v-click class="card cool py-2 ml-32"><b>Child-first:</b> And that's why every crew works with rusty state-issued wrenches. I use my own toolbox.</div>
  <div v-click class="card hot py-2 mr-32"><b>Parent-first:</b> In that toolbox you'll also find your own socket. Enjoy your <code>ClassCastException</code>.</div>
  <div v-click class="card cool py-2 ml-32"><b>Child-first:</b> …fine. Sockets from you. Tools are mine.</div>
  <div v-click class="card hot py-2 mr-32"><b>Parent-first:</b> So we're cooperating now?</div>
  <div v-click class="card cool py-2 ml-32"><b>Child-first:</b> Don't put it in the minutes.</div>
</div>

<!--
This chat is a spoiler for the next slides. Child-first gives isolation, but breaks whatever crosses the border. The fix is a mix of the two.
-->

---

###### Part 3 · Step 3

# Error: the crew brought its own socket

```java
var loader = new PluginClassLoader(pluginJars, hostLoader);
Plugin p = (Plugin) loader.loadClass("com.acme.MyPlugin")
        .getDeclaredConstructor().newInstance();   // boom
```

<div class="mono text-sm mt-2" style="color:#ff6b6b">ClassCastException: class com.acme.MyPlugin cannot be cast to class com.example.plugin.api.Plugin</div>

<div v-click class="mt-5 text-lg">
— But <code>MyPlugin</code> implements <code>Plugin</code>! I wrote it myself!<br>
— It does. <span class="accent">A different <code>Plugin</code>.</span>
</div>

<div v-click class="grid grid-cols-2 gap-6 mt-6 text-sm">
  <div class="card cool"><span class="alt font-600">Tools</span> <span class="muted">· own first</span><br>Used <b>inside</b> the crew: jackson 2.17, mysql 8.4. The ministry doesn't care.</div>
  <div class="card hot"><span class="accent font-600">Sockets</span> <span class="muted">· from the ministry</span><br>What <b>both sides</b> plug into: the <code>Plugin</code> interface, a <code>Logger</code>. Must be one standard.</div>
</div>

<!--
This is the real message. The JVM names the object's class (`MyPlugin`), not the interface. The end of the message names the loaders: `MyPlugin` is in `PluginClassLoader`, `Plugin` is in `'app'`.

Why: the plugin is a fat JAR with the API classes inside. Child-first found the crew's own copy of `Plugin` first — its own socket. The ministry's plug doesn't fit it.

The usual setup: `Plugin` lives in a thin `plugin-api` JAR. The host has it. The plugin depends on it with `<scope>provided</scope>`, so it's not packed. The shared list on the next slide is the safety net for when someone packs it anyway.
-->

---

###### Part 3 · Step 4

# Fix: sockets come from the ministry

````md magic-move {lines: false}
```java
class PluginClassLoader extends URLClassLoader {
    @Override
    protected Class<?> loadClass(String name, boolean resolve) throws ClassNotFoundException {
        Class<?> c = findLoadedClass(name);                // 1. already have it?
        if (c == null) {
            try { c = findClass(name); }                   // 2. own toolbox first
            catch (ClassNotFoundException e) { c = getParent().loadClass(name); }
        }
        return c;
    }
}
```

```java
class PluginClassLoader extends URLClassLoader {
    static final List<String> SOCKETS =
        List.of("java.", "com.example.plugin.api.", "org.slf4j.");

    @Override
    protected Class<?> loadClass(String name, boolean resolve) throws ClassNotFoundException {
        if (isSocket(name)) return getParent().loadClass(name);   // 0. sockets → ministry
        Class<?> c = findLoadedClass(name);                       // 1. already have it?
        if (c == null) {
            try { c = findClass(name); }                          // 2. own toolbox first
            catch (ClassNotFoundException e) { c = getParent().loadClass(name); }
        }
        return c;
    }
    boolean isSocket(String n) { return SOCKETS.stream().anyMatch(n::startsWith); }
}
```
````

<style>
.slidev-code { --slidev-code-font-size: 12px; }
h1 { margin-bottom: 1rem; }
</style>

<!--
Same loader plus one list. Names from the list always come from upstairs. Everything else stays child-first.

Now `Plugin` comes from the ministry on both sides, so the cast works.

In real projects this list is usually called "shared" or "parent-first packages".
-->

---

###### Part 3 · Detour

# What counts as a socket?

<div class="grid grid-cols-2 gap-6 mt-6">
  <div class="card hot">
    <div class="tag hot mb-3">sockets · from the ministry</div>
    <div class="mono text-sm leading-7">java.*<br>javax.{crypto,net,xml}.*<br>com.example.plugin.api.*<br>org.slf4j.*<br><span class="muted">&lt;metrics library&gt;</span></div>
  </div>
  <div class="card cool">
    <div class="tag mb-3" style="color:var(--noir-alt);border-color:var(--noir-alt)">tools · own first</div>
    <div class="mono text-sm leading-7">everything else</div>
  </div>
</div>

<div v-click class="grid grid-cols-2 gap-6 mt-8 text-base">
  <div><span class="accent">Fewer sockets</span> → stronger isolation</div>
  <div><span class="alt">More sockets</span> → fewer duplicates, fewer border problems</div>
</div>

<div v-click class="aside">
"An extension cord is a socket too, right?" No. <code>javax.inject</code> is just a tool.
</div>

<!--
A deliberate trade-off, not a default.

Why all of `javax.*` is a trap: a socket name goes only upstairs, with no fallback. `javax.inject`, `javax.servlet` and `javax.annotation` are normal libraries from Maven. The plugin ships one, the host doesn't, and you get `ClassNotFoundException`.

Careful with `javax.xml.*` too: `javax.xml.bind` (JAXB) left the JDK in 11. If plugins bring their own JAXB, keep it child-first.
-->

---

###### Part 3 · Detour

# SPI: the license registry

<div class="grid grid-cols-3 gap-4 mt-6">

<div v-click class="card">
  <div class="tag hot mb-3">01 · The license type</div>
  <div class="mono text-sm">java.sql.Driver</div>
  <div class="text-sm muted mt-2">"I'm an interface in the JDK. Never met MySQL."</div>
</div>

<div v-click class="card">
  <div class="tag hot mb-3">02 · A license</div>
  <div class="mono text-sm">META-INF/services/<br>java.sql.Driver</div>
  <div class="text-sm muted mt-2">A note inside the MySQL JAR: "Licensed <code>Driver</code>: <code>com.mysql.cj.jdbc.Driver</code>."</div>
</div>

<div v-click class="card">
  <div class="tag hot mb-3">03 · The lookup</div>
  <div class="mono text-sm">ServiceLoader<br>.load(Driver.class)</div>
  <div class="text-sm muted mt-2">"I check the registry from the office the <b>thread</b> sits in. Default: the ministry."</div>
</div>

</div>

<v-clicks>

- The crew's licenses are invisible from the ministry → pass the loader: `ServiceLoader.load(X.class, pluginLoader)`
- Some SPIs hate two providers (hello, SLF4J bindings) → **ministry only**

</v-clicks>

<!--
SPI = Service Provider Interface. Someone defines an interface, any JAR can ship an implementation, and the caller never names it in code. JDBC drivers, logging bindings, Jackson modules, JAXB.

"The office the thread sits in" is the thread context class loader (TCCL): `Thread.currentThread().getContextClassLoader()`. By default it's App — the host. From an office you see its licenses and the licenses of every floor above it. Never the ones below.
-->

---

###### Part 3 · Step 5

# Error: No suitable driver

```java
// inside the plugin
var conn = DriverManager.getConnection("jdbc:mysql://db/app", user, pass);
```

<div class="mono text-sm mt-2" style="color:#ff6b6b">SQLException: No suitable driver found for jdbc:mysql://db/app</div>

<div v-click class="card mt-8 text-sm">
  <div class="card-title mb-2"><code>DriverManager</code> · the archivist since 1997 (JDK 1.1)</div>
  <div>"I checked the registry once, from the ministry's office. The ministry's mysql driver? It's not the <code>Driver</code> your crew sees, so you can't have it. Your own driver? Not in my records."</div>
</div>

<div v-click class="mt-6 text-lg">
He checks everywhere <span class="accent">except where the driver is</span>.
</div>

<!--
Two reasons it fails:
1. `DriverManager` scans `META-INF/services/java.sql.Driver` once, on first use, through the TCCL. That's the host's loader, so the plugin's driver is never found.
2. The host's mysql 8.0 driver is registered. But `getConnection` checks that the caller's loader sees the same driver class. The crew has its own copy of `com.mysql.cj.jdbc.Driver` (child-first — two Ivanovs again), so the host driver is skipped.
-->

---

###### Part 3 · Step 5

# Plot twist: try again

```java
DriverManager.getConnection(url);   // 1st call: SQLException: No suitable driver
DriverManager.getConnection(url);   // 2nd call: works?!
```

<v-clicks>

- **Call 1:** the archivist checks the ministry's driver — "does the crew see this exact class?"
- To find out, he makes the crew load **its own** driver. Its `static {}` runs and registers it
- But he's reading yesterday's printout → fail. **Call 2:** the new driver is on the list → works

</v-clicks>

<div v-click>

```java
Class.forName("com.mysql.cj.jdbc.Driver", true, pluginLoader);  // the fix: register it yourself, on start
```

</div>

<div v-click class="aside">
Monitoring says: <b>"flaky database"</b>. Reality: class loaders.
</div>

<style>
.slidev-code { --slidev-code-font-size: 12.5px; }
</style>

<!--
Reproduced on JDK 21 with a fake driver.

The check (`isDriverAllowed`) calls `Class.forName(name, true, callerLoader)` — `true` means "initialize", so the plugin driver's `static {}` runs and registers it. `getConnection` loops over a snapshot of the registered drivers (a `CopyOnWriteArrayList`), so the new driver only shows up on the next call.

This needs a host driver with the same class name. Without one, nothing triggers the load, and every retry fails too.

Other fix: skip `DriverManager` and create the driver's `DataSource` directly. Switching the TCCL helps only if `DriverManager` hasn't scanned yet — in a running host it usually has.
-->

---

###### Part 3 · Plugins

# Safety rules for crews

<div class="grid grid-cols-[1.3fr_1fr] gap-8">
<div>

<v-clicks>

1. **Sockets list** — API, logging, `java.*`
2. **Thin API** — few sockets on the wall
3. **Explicit loader** for `ServiceLoader`, `Class.forName`, JDBC
4. **Move the thread** into the crew's office (TCCL), back in `finally`
5. **When the crew leaves:** deregister drivers, stop threads, clear ThreadLocals, `close()` the loader
6. **Test it** — two crews, two versions of one tool

</v-clicks>

</div>
<div class="flex flex-col gap-4">

<div v-click class="card">
  <div class="card-title text-sm accent">Loader leak</div>
  <div class="text-sm mt-2 muted">The crew left, but its drill is still plugged into the ministry's wall — a static field, a ThreadLocal, a thread. The office can't be cleared.</div>
</div>

<div v-click class="card">
  <div class="card-title mono text-sm accent">LinkageError: loader constraint violation</div>
  <div class="text-sm mt-2 muted">Two offices promised to use one form. Each printed its own.</div>
</div>

</div>
</div>

<!--
The rules follow the story: step 3–4 gave us the sockets list and the thin API, step 5 gave us explicit loaders and driver cleanup.

Rule 4: Jackson modules, JAXB and many SPIs use `Thread.currentThread().getContextClassLoader()`. Set it to the plugin loader before calling plugin code and restore it in `finally`.

Rule 5: `deregisterDriver` checks that the caller sees the same driver class — call it from plugin code, from host code you get a `SecurityException`. A `URLClassLoader` keeps its JARs open; forget `close()`, and on Windows you can't even delete the old plugin JAR.

Bonus trap — generic type erasure: `List<Foo>` is just `List` at runtime, so a wrong-loader `Foo` slips through and explodes later, on `get()`.
-->

---

###### Alternatives

# Can we skip the custom loader?

<div class="flex justify-between text-xs mono faint mt-4 mb-1">
  <span>← cheaper</span><span>more isolated →</span>
</div>

<div class="text-[0.95rem]">
<div v-click class="grid grid-cols-[10rem_14rem_1fr] gap-4 py-3 border-b border-[var(--noir-border)]">
  <b>Shading</b><span class="accent">a new passport</span><span class="muted">Packages renamed at build time. Misses class names in config files and strings built at runtime</span>
</div>
<div v-click class="grid grid-cols-[10rem_14rem_1fr] gap-4 py-3 border-b border-[var(--noir-border)]">
  <b>JPMS</b><span class="accent">locked offices</span><span class="muted">Strong walls, but one version per module. Several versions only via <code>ModuleLayer</code> — a custom loader in disguise</span>
</div>
<div v-click class="grid grid-cols-[10rem_14rem_1fr] gap-4 py-3 border-b border-[var(--noir-border)]">
  <b>Custom loader</b><span class="accent">your own crew offices</span><span class="muted">Full control, plugins at runtime — and every trap is yours</span>
</div>
<div v-click class="grid grid-cols-[10rem_14rem_1fr] gap-4 py-3 border-b border-[var(--noir-border)]">
  <b>OSGi</b><span class="accent">bureaucracy squared</span><span class="muted">Every crew signs a contract with versions. Powerful, battle-tested, heavy</span>
</div>
<div v-click class="grid grid-cols-[10rem_14rem_1fr] gap-4 py-3">
  <b>Separate process</b><span class="accent">another building</span><span class="muted">Total isolation — but every question goes by mail: network, serialization, memory</span>
</div>
</div>

<div v-click class="aside">
Tomcat, Jenkins, Elasticsearch, IntelliJ plugins — custom loaders. Eclipse — OSGi. gRPC — shades Netty.
</div>

<!--
Shading in one sentence: renaming `com.google.common` to `myapp.shaded.com.google.common` changes the full class names. They become different people, and the conflict is gone without any loaders.
-->

---

###### Summary

# What to take home

<v-clicks>

1. HR (Maven) approves **JARs** by name — fewest handshakes wins
2. A department (class loader) hires **classes** — first folder wins
3. Hiring is **lazy** → errors show up late
4. **Class = name + loader** — always check the stamp
5. Parent-first is the **default** — escalate, upstairs wins
6. Plugins: **own tools** (child-first), **shared sockets**, explicit loader for SPI

</v-clicks>

---
layout: statement
---

# Questions?

<div class="mono text-lg muted mt-8">
<span class="line-through decoration-[var(--noir-accent)] decoration-2">Foo cannot be cast to Foo</span>
</div>

<div class="mt-3 muted">now you know whose stamp it is</div>

<!--
Questions people usually ask:

Q: Why doesn't Maven just pick the newest version?
A: Newest isn't always safe either — 3.0 can break code built for 2.x. Maven picks predictably; the enforcer tells you when it hurts.

Q: Why not make everything child-first?
A: Then the crew's `Plugin` ≠ the ministry's. Whatever crosses the border must be one class.

Q: Then why not share everything?
A: That's parent-first again. The plugin gets the host's versions — back to Try 1.

Q: Can I unload one class?
A: No. Only the whole loader, once nothing points to it, its classes or their objects.

Q: Does a loader keep a list of its classes?
A: No, only a list of places to look. Classes are found on demand, by turning the name into a path.
-->
