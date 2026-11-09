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

# Welcome to the base

<div class="grid grid-cols-3 gap-4 mt-4 text-sm">

<div v-click class="card">
  <div class="tag mb-2">Maven · the checkpoint</div>
  <div>"I read the label on each van. One van per label gets through."</div>
</div>

<div v-click class="card">
  <div class="tag mb-2">JAR · a van</div>
  <div>"I carry job descriptions — <code>.class</code> files. The checkpoint never opens me."</div>
</div>

<div v-click class="card hot">
  <div class="tag hot mb-2">ClassLoader · a unit</div>
  <div>"I put positions on my staff list. But first I report up the chain."</div>
</div>

<div v-click class="card">
  <div class="tag mb-2">Class · a position</div>
  <div>"Driver, company A." My ID is my title <b>plus</b> my unit.</div>
</div>

<div v-click class="card">
  <div class="tag mb-2">Object · a soldier</div>
  <div>"<code>new Driver()</code> — one more soldier in that position."</div>
</div>

<div v-click class="card cool">
  <div class="tag mb-2" style="color:var(--noir-alt);border-color:var(--noir-alt)">Plugin · a contractor</div>
  <div>"Called in on the fly. Own gear. Needs your fuel and radio."</div>
</div>

</div>

<div v-click class="aside">
Lost at any point? Ask two questions: <b>which van?</b> and <b>which unit?</b>
</div>

<!--
The whole talk is one military base. Introduce the cast once and keep coming back to it.

"Up the chain" always means "the parent loader".

One position, many soldiers: that's one class, many objects.
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

- Libraries bring their own libraries
- Two vans labelled **jackson**: 2.15 and 2.17
- Only **one** gets through the checkpoint

<div v-click class="mt-8 text-2xl font-600">Which one?</div>

</div>
</div>

<!--
Let the room guess. Most say "the newest". Wrong — next slide.
-->

---

###### Part 1 · Maven

# The checkpoint's rules

<v-clicks>

1. **Closest to the gate wins** — fewest hops from your `pom.xml`. *Not* the newest
2. **A tie?** First in the queue — declared first
3. **Orders from above** — `dependencyManagement` / BOM fixes the version
4. **"Turn it back"** — `exclusions` send a van away

</v-clicks>

<div v-click class="mt-8 text-lg">
→ Here <span class="accent font-600">2.15</span> gets through. Two hops beat three, even though lib-C wanted 2.17
</div>

<div v-click class="aside">
"New, old, freshly painted — I don't care. <b>Closest to the gate</b> gets through." — the guard
</div>

<!--
A direct dependency is the closest van possible (depth 1). That's why "just declare it directly" is the most common fix. It's rule 1 in action, not a separate rule.
-->

---

###### Part 1 · Maven

# Where it backfires

<div class="grid grid-cols-2 gap-10">
<div>

- lib-C was built for 2.17, got 2.15
- It calls a method 2.15 doesn't have
- → `NoSuchMethodError` **at runtime**

<div class="mt-5 text-xl">Green build. <span class="accent">Red production.</span></div>

```bash
# who got in, who didn't
mvn dependency:tree -Dverbose
# the column of vans
mvn dependency:build-classpath
```

</div>
<div v-click>

<div class="card">
  <div class="card-title">Call the inspector from HQ: <code>maven-enforcer-plugin</code></div>
  <div class="card-sub mb-4">Catch it at build time, not in production</div>
  <div class="mono text-sm accent">requireUpperBoundDeps</div>
  <div class="text-sm muted mb-3">Fails if someone got an <b>older</b> version than they asked for</div>
  <div class="mono text-sm accent">dependencyConvergence</div>
  <div class="text-sm muted">Stricter: fails on <b>any</b> version mismatch</div>
</div>

</div>
</div>

<div v-click class="aside">
The guard: <b>"Two jacksons at the gate. Inspector — your call."</b>
</div>

<style>
.slidev-code { --slidev-code-font-size: 13px; }
h1 { margin-bottom: 1rem; }
</style>

<!--
Maven followed its rules perfectly. lib-C just didn't get the version it was compiled against.

`-Dverbose` needs maven-dependency-plugin 3.2.0+. It was removed in 3.0 and came back later.

Both enforcer rules compare versions of the same artifact only. "Different names, same classes" is invisible to them — that's the next slide. For that case, use `banDuplicateClasses` from extra-enforcer-rules.
-->

---

###### Part 1 · Maven

# This week's interview: the guard

<div class="flex flex-col gap-3 mt-2 text-base">
  <div v-click><span class="accent font-600">Q:</span> So you decide which JARs get in?<br><b>Guard:</b> I read the label on the van — <code>groupId:artifactId</code>. That's all I read.</div>
  <div v-click><span class="accent font-600">Q:</span> Two vans with the same label?<br><b>Guard:</b> One gets through. Closest to the gate.</div>
  <div v-click><span class="accent font-600">Q:</span> Even if the other one is newer?<br><b>Guard:</b> I don't do ages.</div>
  <div v-click><span class="accent font-600">Q:</span> Different labels, but the same cargo inside?<br><b>Guard:</b> Both get through. I don't open vans. Not my job.</div>
</div>

<div v-click class="mt-5 text-xl">
→ My output: a <b>column of vans</b> — the classpath. <span class="muted">Units, your turn.</span>
</div>

<div v-click class="aside">
Van "Potatoes", same cargo as van "Vegetables"? Different labels — drive through.
</div>

<style>
h1 { margin-bottom: 1rem; }
</style>

<!--
Real "same cargo, different label":
- `javax.servlet:servlet-api` vs `jakarta.servlet:jakarta.servlet-api` 4.x. New label, still `javax.servlet` inside.
- `commons-logging` vs `jcl-over-slf4j`. Both contain `org.apache.commons.logging`.
- A fat JAR with Guava copied inside, packages not renamed. Maven sees one Guava, the JVM sees two.

The column order: Maven 3 reads the tree like a book — lib-A, everything under lib-A, then lib-B. So a dependency of lib-A can stand before your own lib-B. Maven 4 orders by depth: all direct dependencies first. Upgrading Maven can change which duplicate class wins. Check with `mvn dependency:build-classpath`.
-->

---

###### Part 2 · ClassLoader

# The chain of command

<div class="flex flex-col gap-2 mt-2 mb-6">
  <div v-click="2" class="card py-2">
    <div class="flex justify-between"><span class="card-title">Bootstrap</span><span class="tag">General Staff</span></div>
    <div class="text-sm muted mt-1">"<code>String</code>, <code>Object</code>, <code>List</code> — strategic matters. <code>Foo</code>? Not our package."</div>
  </div>
  <div v-click="2" class="text-center faint mono text-xs">▲ "is Foo yours?"</div>
  <div v-click="1" class="card py-2">
    <div class="flex justify-between"><span class="card-title">Platform</span><span class="tag">base command</span></div>
    <div class="text-sm muted mt-1">"<code>java.sql</code>, <code>java.net.http</code> — ours. But first I report to General Staff. <code>Foo</code>? Not our package either."</div>
  </div>
  <div v-click="1" class="text-center faint mono text-xs">▲ "is Foo yours?"</div>
  <div class="card hot py-2">
    <div class="flex justify-between"><span class="card-title">App</span><span class="tag hot">your company · you are here</span></div>
    <div class="text-sm muted mt-1">"I always report up first. Not their package? I handle it locally: <code>Foo</code>'s job description, from the first van that has it."</div>
  </div>
</div>

<div v-click="3" class="aside">
The rule: <b>report up first</b>. Up the chain says "not our package" — handle it locally.
</div>

<!--
"Is Foo yours?" always travels up. Higher = more basic, more trusted.

"Not our package" is the real mechanism, not a joke: since JDK 9 the built-in loaders keep a map "package → module → loader". They don't keep a list of classes, only places to look. A class is found on demand: the name becomes a path (`com/acme/Foo.class`), and the vans are checked one by one.

Most core modules, `java.xml` and `java.logging` included, belong to General Staff. Base command gets the extras like `java.sql` and `java.compiler`.

Ten vans with `com.acme.Foo`? The first one wins, the other nine are never opened, and nobody warns you. It's decided per class, so `Foo` can come from van 1 and `Bar` from van 2. Catch it at build time with `banDuplicateClasses`.
-->

---

###### Part 2 · ClassLoader

# Who hired the General Staff?

<div class="mt-6">

```java
String.class.getClassLoader()   // → null
```

</div>

<div class="flex flex-col gap-2 mt-6 text-lg muted">
  <div v-click>To load <code>ClassLoader</code>, you need a <code>ClassLoader</code>.</div>
  <div v-click>So Bootstrap isn't Java at all — it's C++ inside the JVM.</div>
  <div v-click>No Java object → nothing to return → <code>null</code>.</div>
</div>

<div v-click class="mt-auto mono text-sm accent">
Nobody hired the General Staff. It came with the state.
</div>

<style>
.slidev-code { --slidev-code-font-size: 26px; --slidev-code-padding: 28px 36px; }
</style>

<!--
Ask the room first: "What does this print?" Someone always says "Bootstrap ClassLoader", and the JVM says `null`.

`ClassLoader` is itself a class, so somebody has to load it before any Java loader exists. That somebody is native code in HotSpot, and there's no Java object for it, so `null` is the only honest answer.

That's also why `null` as a parent in the JDK means "ask Bootstrap", and why Platform's `getParent()` comes back empty on the next slides.
-->

---

###### Part 2 · ClassLoader

# Different code, different rules

<div class="flex flex-col gap-2 mt-2 mb-6">
  <div v-click class="card py-2">
    <div class="flex justify-between"><span class="card-title">Bootstrap</span><span class="tag">General Staff</span></div>
    <div class="text-sm muted mt-1">"I load the JDK image (<code>lib/modules</code>). Fully trusted, bytecode not even verified, never unloaded."</div>
  </div>
  <div v-click class="card py-2">
    <div class="flex justify-between"><span class="card-title">Platform</span><span class="tag">base command</span></div>
    <div class="text-sm muted mt-1">"Formerly Extension. <code>java.sql</code>, <code>java.net.http</code> — Java SE, but no core privileges needed. Least privilege: the smaller the General Staff, the safer."</div>
  </div>
  <div v-click class="card hot py-2">
    <div class="flex justify-between"><span class="card-title">App</span><span class="tag hot">your company · you are here</span></div>
    <div class="text-sm muted mt-1">"Your classpath. Jars from who-knows-where. Full verification."</div>
  </div>
</div>

<div v-click class="mt-auto text-center mono text-sm muted">
One pile = verify <code>String</code> on every start (slow) or trust your jar blindly (dangerous).
</div>

<!--
Same chain as before, but now the question is why there are three units at all. The answer: different code deserves different trust.

General Staff gets a free pass. Boot classes skip the verifier by default, and they live until the JVM dies. Base command was split off in JDK 9 so non-core modules don't run with General Staff privileges.

Strictly speaking, `lib/modules` holds every JDK module, including `java.sql`. Bootstrap owns `java.base` and most of the core, and Platform reads its own modules from the same file.

Your company gets checked every time, because nobody knows where that jar has been.
-->

---

###### Part 2 · ClassLoader

# The rule as code: parent-first

<div class="grid grid-cols-[auto_1fr] gap-10 items-center">

```java {all|2|4|6|all}
protected Class<?> loadClass(String name) {
    Class<?> c = findLoadedClass(name);          // 1. already on staff?
    if (c == null) {
        try { c = getParent().loadClass(name); } // 2. report up
        catch (ClassNotFoundException e) {
            c = findClass(name);                 // 3. handle it locally
        }
    }
    return c;
}
```

<div>

- **The default** — every `URLClassLoader` works like this
- That's why there's exactly **one** `String`
- Up the chain always wins → **its version** always wins

</div>
</div>

<!--
This is App's monologue, as code.

Simplified. Since JDK 9 the built-in loaders first check which module owns the package and go straight to that module's loader.

Platform's `getParent()` returns `null`. Bootstrap is native code, not a Java object, so "report to General Staff" is a native call.
-->

---

###### Part 2 · ClassLoader

# The army is lazy

<div class="grid grid-cols-[1.35fr_1fr] gap-8">
<div>

<div class="muted text-sm mb-1">"A position is created only for <b>real</b> work:"</div>

```java
new Foo();                         // a soldier
Foo.helper();                      // a static call
Class.forName("com.example.Foo");  // reflection
```

<div v-click>
<div class="muted text-sm mb-1 mt-4">"Not worth the paperwork:"</div>

```java
Foo f = null;            // just a word
Class<?> c = Foo.class;  // created, not approved
int n = Foo.COUNT;       // copied, no position
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

<div class="text-sm muted">Which positions were created, when, and <b>from which van</b></div>

</div>
</div>

<div v-click class="aside">
Approval (<code>static {}</code>) happens once. Fails? Nobody can ever be assigned: <code>ExceptionInInitializerError</code> first, <code>NoClassDefFoundError</code> forever after.
</div>

<style>
.slidev-code { --slidev-code-font-size: 12.5px; }
h1 { margin-bottom: 1rem; }
</style>

<!--
The full lifecycle: loading (job description from the van → `defineClass()`), linking (HQ checks the papers, the position gets its shared locker with default values, names become real addresses), initialization (`static {}`, once, thread-safe).

Static fields belong to the position, not to a soldier: one shared locker for every driver.

Reading a non-constant static field also creates the position, same as `Foo.helper()`.

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
  <div class="mono">com.acme.Foo <span class="muted text-sm">· in 3 vans</span></div>
  <div v-click class="accent">App · first van wins</div>
</div>

<div v-click class="aside">
<code>javax</code> doesn't mean "minor". The <code>java.xml</code> module is a strategic matter.
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
<div class="muted text-sm mb-1 mt-3">Attempt 2: my own loader, skip the chain of command</div>

```java
defineClass("java.lang.String", bytes, 0, bytes.length);
// SecurityException: Prohibited package name: java.lang
```

</div>

<div v-click>
<div class="muted text-sm mb-1 mt-3">Attempt 3: the official back door</div>

```bash
java --patch-module java.base=my-string.jar -jar app.jar   # works. Welcome to the General Staff
```

</div>

<div v-click class="aside">
Only the General Staff issues national insignia. A unit making its own — court-martial.
</div>

<style>
.slidev-code { --slidev-code-font-size: 12.5px; }
h1 { margin-bottom: 1rem; }
</style>

<!--
Why the same name: the goal is to *replace* the system `String`. A class called `com.anton.String` is legal and boring — just a different position.

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
The unit that called <code>defineClass()</code> <b>owns</b> the position for life<br>
Same job description, two units → <b>two different positions</b><br>
<code>instanceof</code>, casts, <code>==</code> on <code>Class</code> — all check whose staff list
</div>

<div class="mt-8 text-xl">"Driver" on our staff list ≠ "Driver" on the contractor's</div>

</v-clicks>

<!--
"Owns for life": a class can't move to another loader. It's unloaded only together with its loader, when nothing references either of them.

The package is part of the name: `com.a.Foo` and `com.b.Foo` are different positions anyway. Where the JAR lies on disk doesn't matter — only which loader defined the class.
-->

---

###### Part 2 · ClassLoader

# The most absurd error in Java

<div class="card mono text-base leading-8 mt-6">
  <div style="color:#ff6b6b">java.lang.ClassCastException:</div>
  <div class="pl-4">class <b>com.example.Foo</b> cannot be cast to class <b>com.example.Foo</b></div>
  <div v-click class="pl-4 muted text-sm leading-7">
    (com.example.Foo is in unnamed module of loader <span class="alt font-600">com.example.PluginClassLoader @6d06d69c</span>;<br>
    &nbsp;com.example.Foo is in unnamed module of loader <span class="accent font-600">'app'</span>)
  </div>
</div>

<div v-click class="mt-8 text-xl">
Is he a <code>Foo</code>? Yes. On <b>our</b> staff list? No — <span class="accent">the contractor's</span>. Rejected.<br>
<span class="muted">The JVM even says whose list. We just never read past the first line.</span>
</div>

<!--
The message names the object's loader first, then the loader of the type you cast to. Here: a soldier on the contractor's `Foo` position, cast to our `Foo`.
-->

---

###### Part 3 · Plugins

# The task: call in contractors

<div class="grid grid-cols-2 gap-6 mt-6 mb-6">
  <div class="card"><div class="card-title">The base · host</div><div class="card-sub mono">jackson 2.16 · mysql 8.0</div></div>
  <div class="card cool"><div class="card-title">Contractors · plugin</div><div class="card-sub mono">jackson 2.17 · mysql 8.4</div></div>
</div>

<v-clicks>

- The base calls contractors **at runtime**. Each gets its own staff list — a new loader
- The checkpoint never saw their vans — **Maven can't help**

</v-clicks>

<div v-click class="mt-8 text-xl">
<span class="accent">Goal:</span> <b>their own gear</b>, <b>our fuel and radio</b>
</div>

<div v-click class="aside">
The base's habit: <b>"Hand in your gear. Standard issue only — everything must be uniform."</b>
</div>

<!--
The contractor's loader has the host's App loader as its parent. So "up the chain" for the contractor is the base.

The host is big and has its own libraries. We don't want every plugin author to match our versions.

Gear = libraries the plugin uses inside. Fuel and radio = types both sides touch. Hold on to that split — it's the whole of Part 3.
-->

---

###### Part 3 · Step 1

# Try 1: standard issue only

```java
var loader = new URLClassLoader(pluginJars, hostLoader);
var cls = loader.loadClass("com.acme.MyPlugin");
Plugin p = (Plugin) cls.getDeclaredConstructor().newInstance();
p.run();   // the plugin calls a jackson 2.17 method
```

<div class="mono text-sm mt-2" style="color:#ff6b6b">java.lang.NoSuchMethodError: com.fasterxml.jackson…</div>

<div v-click class="flow mt-5">
  <div class="card"><div class="card-sub">contractor</div><div class="card-title">"jackson, size 2.17"</div></div>
  <div class="arrow">→</div>
  <div class="card hot"><div class="card-sub">the base</div><div class="card-title">"standard issue: 2.16"</div></div>
  <div class="arrow">→</div>
  <div class="card"><div class="card-sub">contractor's code</div><div class="card-title">doesn't fit</div></div>
</div>

<div v-click class="mt-6 text-xl">
Parent-first: <span class="accent">standard issue always wins</span>. The contractor's own crates are never opened.
</div>

<style>
.slidev-code { --slidev-code-font-size: 13px; }
h1 { margin-bottom: 1rem; }
</style>

<!--
Exactly the default from Part 2: a URLClassLoader reports up first. The cast works here — `Plugin` comes from the base on both sides. But the plugin's jackson 2.17 is dead weight in the JAR.
-->

---

###### Part 3 · Step 2

# Try 2: own gear first

````md magic-move {lines: false}
```java
class PluginClassLoader extends URLClassLoader {
    @Override
    protected Class<?> loadClass(String name, boolean resolve) {
        // 1. already on staff?
        // 2. own gear first
        // 3. not found → ask the base
    }
}
```

```java
class PluginClassLoader extends URLClassLoader {
    @Override
    protected Class<?> loadClass(String name, boolean resolve) throws ClassNotFoundException {
        Class<?> c = findLoadedClass(name);                // 1. already on staff?
        if (c == null) {
            try { c = findClass(name); }                   // 2. own gear first
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
Flip the order: own JARs first, up the chain only if not found. The plugin now gets its own jackson 2.17.

Real code wraps the body in `synchronized (getClassLoadingLock(name))` and ends with `if (resolve) resolveClass(c);`. Skipped to fit.
-->

---

###### Fireside chat

# Parent-first vs Child-first

<div class="muted text-sm -mt-2 mb-3">Tonight's talk: whose gear does the contractor use?</div>

<div class="flex flex-col gap-3 text-sm">
  <div v-click class="card hot py-2 mr-32"><b>Parent-first:</b> I report up. Always. That's why the whole army has exactly one <code>String</code>.</div>
  <div v-click class="card cool py-2 ml-32"><b>Child-first:</b> And that's why contractors march in boots two sizes too small. I bring my own gear.</div>
  <div v-click class="card hot py-2 mr-32"><b>Parent-first:</b> In your gear you'll also find your own radio. Enjoy your <code>ClassCastException</code>.</div>
  <div v-click class="card cool py-2 ml-32"><b>Child-first:</b> …fine. Fuel and radio from you. Gear is mine.</div>
  <div v-click class="card hot py-2 mr-32"><b>Parent-first:</b> So we're allies now?</div>
  <div v-click class="card cool py-2 ml-32"><b>Child-first:</b> Don't put it in the report.</div>
</div>

<!--
This chat is a spoiler for the next slides. Child-first gives isolation, but breaks whatever crosses the border. The fix is a mix of the two.
-->

---

###### Part 3 · Step 3

# Error: the contractor brought its own radio

```java
var loader = new PluginClassLoader(pluginJars, hostLoader);
Plugin p = (Plugin) loader.loadClass("com.acme.MyPlugin")
        .getDeclaredConstructor().newInstance();   // boom
```

<div class="mono text-xs mt-1" style="color:#ff6b6b">ClassCastException: class com.acme.MyPlugin cannot be cast to class com.example.plugin.api.Plugin</div>

<div v-click class="mt-4 text-base">
— But <code>MyPlugin</code> implements <code>Plugin</code>! I wrote it myself!<br>
— It does. <span class="accent">A different <code>Plugin</code>.</span>
</div>

<div v-click class="grid grid-cols-2 gap-6 mt-4 text-sm">
  <div class="card cool py-3"><span class="alt font-600">Gear</span> <span class="muted">· own first</span><br>Used <b>inside</b> the contractor: jackson 2.17, mysql 8.4. The base doesn't care.</div>
  <div class="card hot py-3"><span class="accent font-600">Fuel & radio</span> <span class="muted">· from the base</span><br>What <b>both sides</b> plug into: the <code>Plugin</code> interface, a <code>Logger</code>. One standard, or nothing works.</div>
</div>

<style>
.slidev-code { --slidev-code-font-size: 12.5px; }
h1 { font-size: 2rem !important; margin-bottom: 0.8rem; }
</style>

<!--
This is the real message. The JVM names the object's class (`MyPlugin`), not the interface. The end of the message names the loaders: `MyPlugin` is in `PluginClassLoader`, `Plugin` is in `'app'`.

Why: the plugin is a fat JAR with the API classes inside. Child-first found the contractor's own copy of `Plugin` first — its own radio, on its own frequency. The base can't talk to it.

The usual setup: `Plugin` lives in a thin `plugin-api` JAR. The host has it. The plugin depends on it with `<scope>provided</scope>`, so it's not packed. The shared list on the next slide is the safety net for when someone packs it anyway.
-->

---

###### Part 3 · Step 4

# Fix: fuel and radio come from the base

````md magic-move {lines: false}
```java
class PluginClassLoader extends URLClassLoader {
    @Override
    protected Class<?> loadClass(String name, boolean resolve) throws ClassNotFoundException {
        Class<?> c = findLoadedClass(name);                // 1. already on staff?
        if (c == null) {
            try { c = findClass(name); }                   // 2. own gear first
            catch (ClassNotFoundException e) { c = getParent().loadClass(name); }
        }
        return c;
    }
}
```

```java
class PluginClassLoader extends URLClassLoader {
    static final List<String> SHARED =
        List.of("java.", "com.example.plugin.api.", "org.slf4j.");

    @Override
    protected Class<?> loadClass(String name, boolean resolve) throws ClassNotFoundException {
        if (isShared(name)) return getParent().loadClass(name);   // 0. fuel & radio → the base
        Class<?> c = findLoadedClass(name);                       // 1. already on staff?
        if (c == null) {
            try { c = findClass(name); }                          // 2. own gear first
            catch (ClassNotFoundException e) { c = getParent().loadClass(name); }
        }
        return c;
    }
    boolean isShared(String n) { return SHARED.stream().anyMatch(n::startsWith); }
}
```
````

<style>
.slidev-code { --slidev-code-font-size: 12px; }
h1 { font-size: 2rem !important; margin-bottom: 0.8rem; }
</style>

<!--
Same loader plus one list. Names from the list always come from the base. Everything else stays child-first.

Now `Plugin` comes from the base on both sides, so the cast works.

In code we keep the real-world name: the shared list, a.k.a. parent-first packages.
-->

---

###### Part 3 · Detour

# What must be standard?

<div class="grid grid-cols-2 gap-6 mt-4">
  <div class="card hot">
    <div class="tag hot mb-3">standard · from the base</div>
    <div class="mono text-sm leading-7">java.*<br>javax.{crypto,net,xml}.*<br>com.example.plugin.api.*<br>org.slf4j.*<br><span class="muted">&lt;metrics library&gt;</span></div>
  </div>
  <div class="card cool">
    <div class="tag mb-3" style="color:var(--noir-alt);border-color:var(--noir-alt)">own gear · own first</div>
    <div class="mono text-sm leading-7">everything else</div>
  </div>
</div>

<div v-click class="grid grid-cols-2 gap-6 mt-6 text-base">
  <div><span class="accent">Less standard</span> → stronger isolation</div>
  <div><span class="alt">More standard</span> → fewer duplicates, fewer border problems</div>
</div>

<div v-click class="aside">
"A jerrycan is fuel too, right?" No. <code>javax.inject</code> is just their own gear.
</div>

<!--
A deliberate trade-off, not a default.

Why all of `javax.*` is a trap: a shared name goes only to the base, with no fallback. `javax.inject`, `javax.servlet` and `javax.annotation` are normal libraries from Maven. The plugin ships one, the host doesn't, and you get `ClassNotFoundException`.

Careful with `javax.xml.*` too: `javax.xml.bind` (JAXB) left the JDK in 11. If plugins bring their own JAXB, keep it child-first.
-->

---

###### Part 3 · Detour

# SPI: the register

<div class="grid grid-cols-3 gap-4 mt-4">

<div v-click class="card">
  <div class="tag hot mb-3">01 · The position</div>
  <div class="mono text-sm">java.sql.Driver</div>
  <div class="text-sm muted mt-2">"A position defined by General Staff. Never met MySQL."</div>
</div>

<div v-click class="card">
  <div class="tag hot mb-3">02 · An application</div>
  <div class="mono text-sm">META-INF/services/<br>java.sql.Driver</div>
  <div class="text-sm muted mt-2">A note in the MySQL van: "Candidate for <code>Driver</code>: <code>com.mysql.cj.jdbc.Driver</code>."</div>
</div>

<div v-click class="card">
  <div class="tag hot mb-3">03 · The lookup</div>
  <div class="mono text-sm">ServiceLoader<br>.load(Driver.class)</div>
  <div class="text-sm muted mt-2">"I read the notes from the unit the <b>thread</b> serves in. Default: the base."</div>
</div>

</div>

<div class="mt-4 text-[0.95rem]">

<v-clicks>

- The contractor's notes are invisible from the base → pass the loader: `ServiceLoader.load(X.class, pluginLoader)`
- Many-seat positions (JDBC `Driver`): five candidates is fine — next slide
- One-seat positions (SLF4J binding): two candidates → coin toss → **the base fills it, plugins don't apply**

</v-clicks>

</div>

<!--
SPI = Service Provider Interface. Someone defines an interface, any JAR can ship an implementation, and the caller never names it in code. JDBC drivers, logging bindings, Jackson modules, JAXB.

Yes, the JDBC interface is literally called `Driver` — a position on the staff list.

"The unit the thread serves in" is the thread context class loader (TCCL): `Thread.currentThread().getContextClassLoader()`. By default it's App — the host. From a unit you see its notes and the notes of every unit up the chain. Never the ones below.
-->

---

###### Part 3 · Detour

# Five candidates, one job

<div class="muted text-sm -mt-2 mb-4">
<code>getConnection("jdbc:postgresql://db/app")</code> — roll call at the quartermaster's
</div>

<div class="flex flex-col gap-2 text-sm">
  <div v-click class="card py-2 mr-32"><b>Quartermaster:</b> "<code>jdbc:postgresql</code> — who drives this truck?"</div>
  <div v-click class="card py-2 ml-32"><b>MySQL:</b> <span class="muted">…not my licence.</span> <span class="faint mono text-xs">→ null</span></div>
  <div v-click class="card py-2 ml-32"><b>H2:</b> <span class="muted">…not my licence.</span> <span class="faint mono text-xs">→ null</span></div>
  <div v-click class="card hot py-2 ml-32"><b>Postgres:</b> "Me." <span class="accent mono text-xs">→ Connection</span></div>
</div>

<div v-click class="mt-6 text-base">
Everyone gets <b>registered</b>. The job goes to <span class="accent">the first one who says "me"</span>, asked in registration order.
</div>

<div v-click class="aside">
Two drivers both say "me" to <code>jdbc:mysql</code>? First registered wins — i.e. <b>classpath order</b>. A quiet lottery.
</div>

<!--
`DriverManager` loads every driver it finds via `ServiceLoader` once, and each one registers itself. On `getConnection` it walks the list in registration order and calls `driver.connect(url, props)`. A driver that doesn't recognise the URL prefix returns `null` — "not my licence, next". First non-null wins.

So five drivers is fine: each has its own specialty (URL prefix). Trouble only starts when two claim the same prefix — e.g. `mysql-connector-j` and an old MariaDB 2.x connector, both accepting `jdbc:mysql:`.

`ServiceLoader` itself decides nothing — it hands back all candidates. Picking is the caller's job: ask each (JDBC), take the first with a warning (SLF4J), sort by priority, configure explicitly (`driverClassName` in Hikari, `-Dslf4j.provider`), or fail on more than one.

Peek at the order: `DriverManager.drivers().forEach(d -> System.out.println(d.getClass().getName()));`
-->

---

###### Part 3 · Step 5

# Error: No suitable driver

```java
// inside the plugin
var conn = DriverManager.getConnection("jdbc:mysql://db/app", user, pass);
```

<div class="mono text-sm mt-2" style="color:#ff6b6b">SQLException: No suitable driver found for jdbc:mysql://db/app</div>

<div v-click class="card mt-6 text-sm">
  <div class="card-title mb-2"><code>DriverManager</code> · the quartermaster since 1997 (JDK 1.1)</div>
  <div>"I read the register once, from the base's office. The base's mysql <code>Driver</code>? It's not the <code>Driver</code> your contractor sees, so you can't have it. Your own <code>Driver</code>? Not in my ledger."</div>
</div>

<div v-click class="mt-6 text-lg">
He checks everywhere <span class="accent">except where the driver is</span>.
</div>

<!--
Two reasons it fails:
1. `DriverManager` scans `META-INF/services/java.sql.Driver` once, on first use, through the TCCL. That's the host's loader, so the plugin's driver is never found.
2. The host's mysql 8.0 driver is registered. But `getConnection` checks that the caller's loader sees the same driver class. The contractor has its own copy of `com.mysql.cj.jdbc.Driver` (child-first — two "Driver" positions again), so the host driver is skipped.
-->

---

###### Part 3 · Step 5

# Plot twist: try again

```java
DriverManager.getConnection(url);   // 1st call: SQLException: No suitable driver
DriverManager.getConnection(url);   // 2nd call: works?!
```

<div class="text-[0.95rem]">

<v-clicks>

- **Call 1:** the quartermaster checks the base's driver — "does the contractor see this exact `Driver`?"
- To find out, he makes the contractor load **its own** `Driver`. Its `static {}` runs and registers it
- But he's working off yesterday's ledger → fail. **Call 2:** the new driver is in the ledger → works

</v-clicks>

</div>

<div v-click>

```java
// the fix: register it yourself, on start
Class.forName("com.mysql.cj.jdbc.Driver", true, pluginLoader);
```

</div>

<div v-click class="aside">
Monitoring says: <b>"flaky database"</b>. Reality: class loaders.
</div>

<style>
.slidev-code { --slidev-code-font-size: 12.5px; }
h1 { margin-bottom: 1rem; }
</style>

<!--
Reproduced on JDK 21 with a fake driver.

The check (`isDriverAllowed`) calls `Class.forName(name, true, callerLoader)` — `true` means "initialize", so the plugin driver's `static {}` runs and registers it. `getConnection` loops over a snapshot of the registered drivers (a `CopyOnWriteArrayList`), so the new driver only shows up on the next call.

This needs a host driver with the same class name. Without one, nothing triggers the load, and every retry fails too.

Other fix: skip `DriverManager` and create the driver's `DataSource` directly. Switching the TCCL helps only if `DriverManager` hasn't scanned yet — in a running host it usually has.
-->

---

###### Part 3 · Plugins

# Safety rules for contractors

<div class="grid grid-cols-[1.3fr_1fr] gap-8">
<div class="text-[0.95rem]">

<v-clicks>

1. **Shared list** — fuel & radio: API, logging, `java.*`
2. **Thin API** — few plugs on the border
3. **Explicit loader** for `ServiceLoader`, `Class.forName`, JDBC
4. **Move the thread** into the contractor's unit (TCCL), back in `finally`
5. **When contractors leave:** deregister drivers, stop threads, clear ThreadLocals, `close()` the loader
6. **Test it** — two contractors, two versions of one library

</v-clicks>

</div>
<div class="flex flex-col gap-4">

<div v-click class="card">
  <div class="card-title text-sm accent">Loader leak</div>
  <div class="text-sm mt-2 muted">The contractor left, but its truck is still hooked to the base's fuel line — a static field, a ThreadLocal, a thread. The hangar can't be freed.</div>
</div>

<div v-click class="card">
  <div class="card-title mono text-sm accent">LinkageError: loader constraint violation</div>
  <div class="text-sm mt-2 muted">Two units agreed on one radio standard. Each brought its own radio.</div>
</div>

</div>
</div>

<style>
h1 { margin-bottom: 1rem; }
</style>

<!--
The rules follow the story: steps 3–4 gave us the shared list and the thin API, step 5 gave us explicit loaders and driver cleanup.

Rule 4: Jackson modules, JAXB and many SPIs use `Thread.currentThread().getContextClassLoader()`. Set it to the plugin loader before calling plugin code and restore it in `finally`.

Rule 5: `deregisterDriver` checks that the caller sees the same driver class — call it from plugin code, from host code you get a `SecurityException`. A `URLClassLoader` keeps its JARs open; forget `close()`, and on Windows you can't even delete the old plugin JAR.

Bonus trap — generic type erasure: `List<Foo>` is just `List` at runtime, so a `Foo` from the wrong loader slips through and explodes later, on `get()`.
-->

---

###### Alternatives

# Can we skip the custom loader?

<div class="flex justify-between text-xs mono faint mb-1">
  <span>← cheaper</span><span>more isolated →</span>
</div>

<div class="text-sm">
<div v-click class="grid grid-cols-[9rem_12rem_1fr] gap-4 py-2 border-b border-[var(--noir-border)]">
  <b>Shading</b><span class="accent">new call signs</span><span class="muted">Packages renamed at build time. Misses class names in config files and strings built at runtime</span>
</div>
<div v-click class="grid grid-cols-[9rem_12rem_1fr] gap-4 py-2 border-b border-[var(--noir-border)]">
  <b>JPMS</b><span class="accent">restricted zones</span><span class="muted">Strong walls, but one version per module. Several versions only via <code>ModuleLayer</code> — a custom loader in disguise</span>
</div>
<div v-click class="grid grid-cols-[9rem_12rem_1fr] gap-4 py-2 border-b border-[var(--noir-border)]">
  <b>Custom loader</b><span class="accent">your own contractor units</span><span class="muted">Full control, plugins at runtime — and every trap is yours</span>
</div>
<div v-click class="grid grid-cols-[9rem_12rem_1fr] gap-4 py-2 border-b border-[var(--noir-border)]">
  <b>OSGi</b><span class="accent">full military bureaucracy</span><span class="muted">Every unit signs a contract with versions. Powerful, battle-tested, heavy</span>
</div>
<div v-click class="grid grid-cols-[9rem_12rem_1fr] gap-4 py-2">
  <b>Separate process</b><span class="accent">a separate base</span><span class="muted">Total isolation — but every question goes by courier: network, serialization, memory</span>
</div>
</div>

<div v-click class="aside">
Tomcat, Jenkins, Elasticsearch, IntelliJ plugins — custom loaders. Eclipse — OSGi. gRPC — shades Netty.
</div>

<style>
h1 { margin-bottom: 1rem; }
</style>

<!--
Shading in one sentence: renaming `com.google.common` to `myapp.shaded.com.google.common` changes the full class names. They become different positions, and the conflict is gone without any loaders.
-->

---

###### Summary

# What to take home

<v-clicks>

1. The checkpoint (Maven) lets **JARs** through by label — closest wins
2. A unit (class loader) creates **positions** (classes) — first van wins
3. The army is **lazy** → errors show up late
4. **Class = name + loader** — always check whose staff list
5. Parent-first is the **default** — report up, the chain of command wins
6. Plugins: **own gear** (child-first), **shared fuel & radio**, explicit loader for SPI

</v-clicks>

---
layout: statement
---

# Questions?

<div class="mono text-lg muted mt-8">
<span class="line-through decoration-[var(--noir-accent)] decoration-2">Foo cannot be cast to Foo</span>
</div>

<div class="mt-3 muted">now you know whose staff list it's on</div>

<!--
Questions people usually ask:

Q: Why doesn't Maven just pick the newest version?
A: Newest isn't always safe either — 3.0 can break code built for 2.x. Maven picks predictably; the enforcer tells you when it hurts.

Q: Why not make everything child-first?
A: Then the contractor's `Plugin` ≠ the base's. Whatever crosses the border must be one class.

Q: Then why not share everything?
A: That's parent-first again. The plugin gets the host's versions — back to Try 1.

Q: Can I unload one class?
A: No. Only the whole loader, once nothing points to it, its classes or their objects.

Q: Does a loader keep a list of its classes?
A: No, only a list of places to look. Classes are found on demand, by turning the name into a path.
-->
