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

# Meet the cast

<div class="grid grid-cols-3 gap-4 mt-6 text-sm">

<div v-click class="card">
  <div class="tag mb-2">Maven · the doorman</div>
  <div>"I decide which vans get into the building. One per name."</div>
</div>

<div v-click class="card">
  <div class="tag mb-2">JAR · a moving van</div>
  <div>"I'm full of classes. The doorman reads my label, never looks inside."</div>
</div>

<div v-click class="card hot">
  <div class="tag hot mb-2">ClassLoader · a floor</div>
  <div>"I move tenants in. But first I always ask upstairs."</div>
</div>

<div v-click class="card">
  <div class="tag mb-2">Class · a tenant</div>
  <div>"My ID is my name <b>plus</b> my floor. I never move out."</div>
</div>

<div v-click class="card">
  <div class="tag mb-2">Object · a tenant's kid</div>
  <div>"<code>new Foo()</code> — and Foo has one more kid."</div>
</div>

<div v-click class="card cool">
  <div class="tag mb-2" style="color:var(--noir-alt);border-color:var(--noir-alt)">You · the architect</div>
  <div>"I'm digging basements for plugins. What could go wrong?"</div>
</div>

</div>

<div v-click class="aside">
Lost at any point? Ask two questions: <b>which van?</b> and <b>which floor?</b>
</div>

<!--
The whole talk is one building. Introduce the cast once and keep coming back to it.

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

- Libraries bring their own libraries
- Same library, **two versions**
- Only **one** van gets in

<div v-click class="mt-8 text-2xl font-600">Which one?</div>

</div>
</div>

<!--
Let the room guess. Most say "the newest". Wrong — next slide.
-->

---

###### Part 1 · Maven

# The doorman's rules

<v-clicks>

1. **Closest to the door wins** — fewest hops from your `pom.xml`. *Not* the newest
2. **A tie?** First in the queue — whoever was declared first
3. **The landlord's list** — `dependencyManagement` / BOM forces the version
4. **"Not this one"** — `exclusions` turn a van away

</v-clicks>

<div v-click class="mt-8 text-lg">
→ Here <span class="accent font-600">2.15</span> wins. Two hops beat three, even though lib-C wanted 2.17
</div>

<div v-click class="aside">
"Young, old, shiny — I don't care. <b>Closest to the door</b> gets in." — the doorman
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

<div class="mt-6 text-xl">Green build. <span class="accent">Red production.</span></div>

```bash
mvn dependency:tree -Dverbose  # who won, who lost
mvn dependency:build-classpath # the final queue
```

</div>
<div v-click>

<div class="card">
  <div class="card-title">Call the inspector: <code>maven-enforcer-plugin</code></div>
  <div class="card-sub mb-4">Shut it down at build time, not in production</div>
  <div class="mono text-sm accent">requireUpperBoundDeps</div>
  <div class="text-sm muted mb-3">Fails if someone got an <b>older</b> version than they asked for</div>
  <div class="mono text-sm accent">dependencyConvergence</div>
  <div class="text-sm muted">Stricter: fails on <b>any</b> version mismatch</div>
</div>

</div>
</div>

<div v-click class="aside">
Doorman: <b>"Two jacksons at the door. Inspector — your call."</b>
</div>

<!--
Maven followed its rules perfectly. lib-C just didn't get the version it was compiled against.

`-Dverbose` needs maven-dependency-plugin 3.2.0+. It was removed in 3.0 and came back later.

Both enforcer rules compare versions of the same artifact only. "Different names, same classes" is invisible to them — that's the next slide. For that case, use `banDuplicateClasses` from extra-enforcer-rules.
-->

---

###### Part 1 · Maven

# This week's interview: Maven

<div class="flex flex-col gap-4 mt-4 text-base">
  <div v-click><span class="accent font-600">Q:</span> So you decide which JARs get in?<br><b>Maven:</b> I read labels — <code>groupId:artifactId</code>. That's all I read.</div>
  <div v-click><span class="accent font-600">Q:</span> Two vans with the same label?<br><b>Maven:</b> One gets in. Closest to the door.</div>
  <div v-click><span class="accent font-600">Q:</span> Even if the other one is newer?<br><b>Maven:</b> I don't do ages.</div>
  <div v-click><span class="accent font-600">Q:</span> Different labels, but the same classes inside?<br><b>Maven:</b> Both get in. I don't open vans. Not my job.</div>
</div>

<div v-click class="mt-6 text-xl">
→ My output: a <b>queue of vans</b> — the classpath. <span class="muted">ClassLoader, your turn.</span>
</div>

<div v-click class="aside">
A van labelled "Petrov", full of Ivanovs? Different label — come on in.
</div>

<!--
Real "Petrovs full of Ivanovs":
- `javax.servlet:servlet-api` vs `jakarta.servlet:jakarta.servlet-api` 4.x. New label, still `javax.servlet` inside.
- `commons-logging` vs `jcl-over-slf4j`. Both contain `org.apache.commons.logging`.
- A fat JAR with Guava copied inside, packages not renamed. Maven sees one Guava, the JVM sees two.

The queue order: Maven 3 reads the tree like a book — lib-A, everything under lib-A, then lib-B. So a dependency of lib-A can stand before your own lib-B. Maven 4 queues by depth: all direct dependencies first. Upgrading Maven can change which duplicate class wins. Check with `mvn dependency:build-classpath`.
-->

---

###### Part 2 · ClassLoader

# What happens to the vans next?

<div class="flow mt-10">
  <div class="card"><div class="card-title mono">pom.xml</div><div class="card-sub">the wish list</div></div>
  <div class="arrow">→</div>
  <div class="card"><div class="card-title">classpath</div><div class="card-sub">vans in a queue</div></div>
  <div class="arrow">→</div>
  <div class="card hot"><div class="card-title">ClassLoader</div><div class="card-sub">moves tenants in</div></div>
  <div class="arrow">→</div>
  <div class="card"><div class="card-title mono">Class&lt;?&gt;</div><div class="card-sub">a tenant · Metaspace</div></div>
  <div class="arrow">→</div>
  <div class="card"><div class="card-title mono">new Foo()</div><div class="card-sub">his kids · Heap</div></div>
</div>

<div v-click class="mt-14 text-xl">
One tenant per name <b>per floor</b>. Kids — as many as you like.
</div>

<div v-click class="aside">
The floor only moves tenants in. Kids are made with <code>new</code>.
</div>

<!--
Inside one classpath, the first van that has the class wins. That's decided per class.
-->

---

###### Part 2 · ClassLoader

# A day in the life of `Foo`

<div class="grid grid-cols-3 gap-6 mt-8">

<div v-click class="card">
  <div class="tag hot mb-3">01 · Loading</div>
  <div class="text-sm">"The floor found me in a van, read my bytes and called <span class="accent mono">defineClass()</span>. I've moved in."</div>
</div>

<div v-click class="card">
  <div class="tag hot mb-3">02 · Linking</div>
  <div class="text-sm leading-6">
    "Security checks my papers <span class="muted">(verify)</span>.<br>
    I get empty shelves for my <code>static</code> fields <span class="muted">(prepare)</span>.<br>
    My contacts get real addresses — usually later <span class="muted">(resolve)</span>."
  </div>
</div>

<div v-click class="card">
  <div class="tag hot mb-3">03 · Initialization</div>
  <div class="text-sm">"I unpack: my <code>static { }</code> runs. <b>Once</b>, thread-safe. If it throws — I'm broken forever."</div>
</div>

</div>

<div v-click class="aside">
Broken forever: 1st call — <code>ExceptionInInitializerError</code>. Every call after — <code>NoClassDefFoundError</code>. Same bug, new disguise.
</div>

<!--
Empty shelves = default values: 0, null, false. Real values arrive in step 3.

The second error says "Could not initialize class Foo". People go hunting for a missing JAR, but the real cause is in the very first stack trace.
-->

---

###### Part 2 · ClassLoader

# The JVM is lazy

<div class="grid grid-cols-[1.35fr_1fr] gap-8">
<div>

<div class="muted text-sm mb-1">"I wake <code>Foo</code> up only for <b>real</b> work:"</div>

```java
new Foo();                         // an instance
Foo.helper();                      // a static call
Class.forName("com.example.Foo");  // reflection
```

<div v-click>
<div class="muted text-sm mb-1 mt-6">"For these, I don't even get up:"</div>

```java
Foo f = null;            // just a label, Foo not loaded
Class<?> c = Foo.class;  // loaded, static {} not run
int n = Foo.COUNT;       // constant copied, Foo not loaded
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

<div class="text-sm muted">Who moved in, when, and <b>from which van</b></div>

</div>
</div>

<div class="aside">
Nobody wakes a tenant until someone really knocks. Walking past the door doesn't count.
</div>

<!--
Reading a non-constant static field also wakes `Foo` up, same as `Foo.helper()`.

The constant gotcha: if `COUNT` is a compile-time constant (a `static final` primitive or `String`), javac copies the value into the caller. `Foo` is not loaded at all.

Bonus: change `COUNT`, recompile only `Foo` — the caller keeps the old value. Fun at deploy time.
-->

---

###### Part 2 · ClassLoader

# Three floors, one rule

<div class="flex flex-col gap-2 mt-2 mb-6">
  <div v-click="2" class="card py-2">
    <div class="flex justify-between"><span class="card-title">Bootstrap</span><span class="tag">penthouse · the owner</span></div>
    <div class="text-sm muted mt-1">"<code>String</code>, <code>Object</code>, <code>List</code> — mine. <code>Foo</code>? Never heard of him."</div>
  </div>
  <div v-click="2" class="text-center faint mono text-xs">▲ "got Foo?"</div>
  <div v-click="1" class="card py-2">
    <div class="flex justify-between"><span class="card-title">Platform</span><span class="tag">middle floor · management</span></div>
    <div class="text-sm muted mt-1">"<code>java.sql</code>, <code>java.net.http</code> — mine. But first I ask the owner. <code>Foo</code>? Nope."</div>
  </div>
  <div v-click="1" class="text-center faint mono text-xs">▲ "got Foo?"</div>
  <div class="card hot py-2">
    <div class="flex justify-between"><span class="card-title">App</span><span class="tag hot">ground floor · you are here</span></div>
    <div class="text-sm muted mt-1">"I always ask upstairs first. Nobody has <code>Foo</code>? Then I check the vans myself, in queue order. First van with a <code>Foo</code> wins."</div>
  </div>
</div>

<div v-click="3" class="aside">
The rule: <b>ask upstairs first</b>. Do it yourself only when upstairs shrugs.
</div>

<!--
"Got Foo?" always travels up. Higher floor = more basic, more trusted.

Most core modules, `java.xml` and `java.logging` included, live in the penthouse. Management gets the extras like `java.sql` and `java.compiler`.

Ten vans with `com.acme.Foo`? The first one wins, the other nine are never opened, and nobody warns you. It's decided per class, so `Foo` can come from van 1 and `Bar` from van 2. Catch it at build time with `banDuplicateClasses`.
-->

---

###### Part 2 · ClassLoader

# The rule as code: parent-first

<div class="grid grid-cols-[auto_1fr] gap-10 items-center">

```java {all|2|4|6|all}
protected Class<?> loadClass(String name) {
    Class<?> c = findLoadedClass(name);          // 1. already living here?
    if (c == null) {
        try { c = getParent().loadClass(name); } // 2. ask upstairs
        catch (ClassNotFoundException e) {
            c = findClass(name);                 // 3. check my own vans
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

Also, Platform's `getParent()` returns `null`. Bootstrap is native code, not a Java object, so "ask the penthouse" is a native call.
-->

---

###### Sharpen your pencil

# Who loads it?

<div class="grid grid-cols-[1fr_auto] gap-x-12 gap-y-4 mt-8 text-lg items-center">
  <div class="mono">java.lang.String</div>
  <div v-click class="accent">Bootstrap</div>
  <div class="mono">java.sql.Connection</div>
  <div v-click class="accent">Platform</div>
  <div class="mono">javax.xml.parsers.DocumentBuilder</div>
  <div v-click class="accent">Bootstrap · gotcha!</div>
  <div class="mono">com.fasterxml.jackson.databind.ObjectMapper</div>
  <div v-click class="accent">App</div>
  <div class="mono">com.acme.Foo <span class="muted text-sm">· in 3 vans</span></div>
  <div v-click class="accent">App · first van wins</div>
</div>

<div v-click class="aside">
<code>javax</code> doesn't mean "extra". The <code>java.xml</code> module lives in the penthouse.
</div>

<!--
Ask the room before each click. Wrong answers are the fun part.

The last one is the trap from the previous slide: three copies, one is read, no warning.
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
<div class="muted text-sm mb-1 mt-4">Attempt 2: my own loader, skip upstairs</div>

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
You can't swap the foundation from the ground floor. Only the developer can — with a permit and a hard hat.
</div>

<style>
.slidev-code { --slidev-code-font-size: 12.5px; }
</style>

<!--
Attempt 1: App sees the package `java.lang`, knows it belongs to `java.base`, and goes straight to Bootstrap. `-Xlog:class+load` shows `java.lang.String source: shared objects file` — your file is never opened.

Attempt 2: `ClassLoader.preDefineClass` forbids `java.*` for every loader except Bootstrap and Platform. So `java.*` on the plugin shared list later isn't a choice — it's the law.

Attempt 3: `--patch-module` (formerly `-Xbootclasspath/p`, removed in JDK 9) replaces classes inside `java.base`. For JDK development and exotic debugging.

Takeaway: you can add floors, but everyone stands on the same foundation.
-->

---
layout: statement
---

###### The one thing to remember

# Class = <span class="muted">name</span> + <span class="accent">loader</span>

<v-clicks>

<div class="mt-10 text-lg muted leading-9">
The floor that called <code>defineClass()</code> <b>owns</b> the tenant for life<br>
Same bytes, two floors → <b>two different tenants</b><br>
<code>instanceof</code>, casts, <code>==</code> on <code>Class</code> — all check the floor
</div>

<div class="mt-8 text-xl">Ivanov from the ground floor ≠ Ivanov from the basement</div>

</v-clicks>

<!--
"Owns for life": a class can't move to another loader. It's unloaded only together with its loader, when nothing references either of them.
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
The JVM isn't crazy. It even tells you <span class="accent">which floors</span>.<br>
<span class="muted">We just never read past the first line.</span>
</div>

<!--
The message names the object's floor first, then the floor of the type you cast to. Here: a kid of the basement `Foo`, cast to the ground-floor `Foo`.
-->

---

###### Part 3 · Plugins

# Plugins move into the basement

<div class="grid grid-cols-2 gap-6 mt-8 mb-8">
  <div class="card"><div class="card-title">Host · ground floor</div><div class="card-sub mono">jackson 2.16 · mysql 8.0</div></div>
  <div class="card cool"><div class="card-title">Plugin · basement</div><div class="card-sub mono">jackson 2.17 · mysql 8.4</div></div>
</div>

<v-clicks>

- The host loads plugin JARs **at runtime**, each into its own basement — a new loader
- The doorman never saw these vans — **Maven can't help**

</v-clicks>

<div v-click class="mt-10 text-xl">
<span class="accent">Goal:</span> the plugin uses <b>its own</b> libraries
</div>

<div v-click class="aside">
New tenant, own furniture. The building: <b>"We're furnished. Use ours."</b>
</div>

<!--
Why a basement: the plugin loader's parent is the host's App loader. So "upstairs" for the plugin is the host.

The host is big and has its own libraries. We don't want every plugin author to match our versions.

Five steps from here: try, try, error, fix, error (with a plot twist).
-->

---

###### Part 3 · Step 1

# Try 1: just a URLClassLoader

```java
var loader = new URLClassLoader(pluginJars, hostLoader);
var cls = loader.loadClass("com.acme.MyPlugin");
Plugin p = (Plugin) cls.getDeclaredConstructor().newInstance();
p.run();   // the plugin calls a jackson 2.17 method
```

<div class="mono text-sm mt-2" style="color:#ff6b6b">java.lang.NoSuchMethodError: com.fasterxml.jackson…</div>

<div v-click class="flow mt-6">
  <div class="card"><div class="card-sub">basement</div><div class="card-title">"got jackson?"</div></div>
  <div class="arrow">→</div>
  <div class="card hot"><div class="card-sub">ground floor</div><div class="card-title">"sure, 2.16"</div></div>
  <div class="arrow">→</div>
  <div class="card"><div class="card-sub">plugin code</div><div class="card-title">wanted 2.17</div></div>
</div>

<div v-click class="mt-8 text-xl">
Parent-first: <span class="accent">upstairs always wins</span>. The plugin's own van is never opened.
</div>

<!--
Exactly the default from Part 2. The cast works here: `Plugin` comes from upstairs on both sides. But the plugin's jackson 2.17 is dead weight in the JAR.
-->

---

###### Part 3 · Step 2

# Try 2: child-first

````md magic-move {lines: false}
```java
class PluginClassLoader extends URLClassLoader {
    @Override
    protected Class<?> loadClass(String name, boolean resolve) {
        // 1. already living here?
        // 2. check my own vans first
        // 3. not found → ask upstairs
    }
}
```

```java
class PluginClassLoader extends URLClassLoader {
    @Override
    protected Class<?> loadClass(String name, boolean resolve) throws ClassNotFoundException {
        Class<?> c = findLoadedClass(name);                // 1. already living here?
        if (c == null) {
            try { c = findClass(name); }                   // 2. check my own vans first
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
Flip the order: own vans first, upstairs only if not found. The plugin now gets its own jackson 2.17.

Real code wraps the body in `synchronized (getClassLoadingLock(name))` and ends with `if (resolve) resolveClass(c);`. Skipped to fit.
-->

---

###### Fireside chat

# Parent-first vs Child-first

<div class="muted text-sm -mt-2 mb-3">Tonight's talk: who's in charge of the furniture?</div>

<div class="flex flex-col gap-3 text-sm">
  <div v-click class="card hot py-2 mr-32"><b>Parent-first:</b> I ask upstairs. Always. That's why the world has exactly one <code>String</code>.</div>
  <div v-click class="card cool py-2 ml-32"><b>Child-first:</b> And that's why nobody ever gets new furniture. I check my own vans first.</div>
  <div v-click class="card hot py-2 mr-32"><b>Parent-first:</b> Then you'll find your own copy of <code>Plugin</code> in there. Enjoy your <code>ClassCastException</code>.</div>
  <div v-click class="card cool py-2 ml-32"><b>Child-first:</b> …fine. Shared stuff I'll take from upstairs. Everything else is mine.</div>
  <div v-click class="card hot py-2 mr-32"><b>Parent-first:</b> So we're working together now?</div>
  <div v-click class="card cool py-2 ml-32"><b>Child-first:</b> Don't tell anyone.</div>
</div>

<!--
This chat is a spoiler for the next slides. Child-first gives isolation, but breaks whatever crosses the border. The fix is a mix of the two.
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

<div class="mono text-sm mt-2" style="color:#ff6b6b">ClassCastException: class com.acme.MyPlugin cannot be cast to class com.example.plugin.api.Plugin</div>

<div v-click class="mt-6 text-lg">
— But <code>MyPlugin</code> implements <code>Plugin</code>! I wrote it myself!<br>
— It does. <span class="accent">A different <code>Plugin</code>.</span>
</div>

<div v-click class="flow mt-6">
  <div class="card flex-1"><div class="card-sub">ground floor</div><div class="card-title mono">Plugin</div></div>
  <div class="arrow text-2xl accent">≠</div>
  <div class="card cool flex-1"><div class="card-sub">basement · copy from plugin.jar</div><div class="card-title mono">Plugin</div></div>
</div>

<div v-click class="text-sm muted mt-3">The fat plugin JAR brought its own <code>Plugin</code>. Child-first moved it in. Two Ivanovs again.</div>

<!--
This is the real message. The JVM names the object's class (`MyPlugin`), not the interface. The end of the message names the floors: `MyPlugin` is in loader `PluginClassLoader`, `Plugin` is in loader `'app'`.

Why: the plugin is a fat JAR with the API classes inside. Child-first finds that copy first.

The usual setup: `Plugin` lives in a thin `plugin-api` JAR. The host has it. The plugin depends on it with `<scope>provided</scope>`, so it's not packed. Child-first finds nothing at home and asks upstairs. The shared list (two slides on) is the safety net for when someone packs it anyway.
-->

---

###### Part 3 · Step 3

# Own furniture vs shared

<div class="grid grid-cols-2 gap-6 mt-8">
  <div class="card cool">
    <div class="tag mb-3" style="color:var(--noir-alt);border-color:var(--noir-alt)">own · child-first</div>
    <div class="text-sm">What the plugin uses <b>inside</b>: jackson 2.17, mysql 8.4.<br><span class="muted">The host doesn't care which version.</span></div>
  </div>
  <div class="card hot">
    <div class="tag hot mb-3">shared · from upstairs</div>
    <div class="text-sm">What <b>both sides</b> touch: the <code>Plugin</code> interface, a <code>Logger</code> the host passes in.<br><span class="muted">Must be one class, or nothing fits.</span></div>
  </div>
</div>

<div v-click class="mt-10 text-xl">
Shared = <span class="accent">only what crosses the border</span>. Not "everything we both have".
</div>

<div v-click class="aside">
Like an intercom: the host and the plugin can only talk through <b>the same</b> one.
</div>

<!--
Shared means the host↔plugin API, logging, metrics — anything both sides touch. Plus `java.*`, because the JVM won't let you define those anyway (remember the `String` slide).
-->

---

###### Part 3 · Step 4

# Fix: shared packages go upstairs

````md magic-move {lines: false}
```java
class PluginClassLoader extends URLClassLoader {
    @Override
    protected Class<?> loadClass(String name, boolean resolve) throws ClassNotFoundException {
        Class<?> c = findLoadedClass(name);                // 1. already living here?
        if (c == null) {
            try { c = findClass(name); }                   // 2. check my own vans first
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
        if (isShared(name)) return getParent().loadClass(name);   // 0. shared → upstairs
        Class<?> c = findLoadedClass(name);                       // 1. already living here?
        if (c == null) {
            try { c = findClass(name); }                          // 2. check my own vans first
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
h1 { margin-bottom: 1rem; }
</style>

<!--
Same loader plus one list. Names from `SHARED` always come from upstairs. Everything else stays child-first.

Now `Plugin` comes from the ground floor on both sides, so the cast works.

The list here is short on purpose. The next slide has the full menu.
-->

---

###### Part 3 · Detour

# Which packages to share?

<div class="grid grid-cols-2 gap-6 mt-6">
  <div class="card hot">
    <div class="tag hot mb-3">upstairs only</div>
    <div class="mono text-sm leading-7">java.*<br>javax.{crypto,net,xml}.*<br>com.example.plugin.api.*<br>org.slf4j.*<br><span class="muted">&lt;metrics library&gt;</span></div>
  </div>
  <div class="card cool">
    <div class="tag mb-3" style="color:var(--noir-alt);border-color:var(--noir-alt)">own vans first</div>
    <div class="mono text-sm leading-7">everything else</div>
  </div>
</div>

<div v-click class="grid grid-cols-2 gap-6 mt-8 text-base">
  <div><span class="accent">Share less</span> → stronger isolation</div>
  <div><span class="alt">Share more</span> → fewer duplicates, fewer border problems</div>
</div>

<div v-click class="aside">
<code>javax.*</code> sounds like building staff. Half of them are just tenants — hello, <code>javax.inject</code>.
</div>

<!--
A deliberate trade-off, not a default.

Why all of `javax.*` is a trap: a shared name goes only upstairs, with no fallback. `javax.inject`, `javax.servlet` and `javax.annotation` are normal libraries. The plugin ships one, the host doesn't, and you get `ClassNotFoundException`.

Careful with `javax.xml.*` too: `javax.xml.bind` (JAXB) left the JDK in 11. If plugins bring their own JAXB, keep it child-first.
-->

---

###### Part 3 · Detour

# SPI: the lobby notice board

<div class="grid grid-cols-3 gap-4 mt-6">

<div v-click class="card">
  <div class="tag hot mb-3">01 · The heading</div>
  <div class="mono text-sm">java.sql.Driver</div>
  <div class="text-sm muted mt-2">"I'm an interface in the JDK. Never met MySQL."</div>
</div>

<div v-click class="card">
  <div class="tag hot mb-3">02 · A card on the board</div>
  <div class="mono text-sm">META-INF/services/<br>java.sql.Driver</div>
  <div class="text-sm muted mt-2">A note inside the MySQL JAR: "Need a <code>Driver</code>? Call <code>com.mysql.cj.jdbc.Driver</code>."</div>
</div>

<div v-click class="card">
  <div class="tag hot mb-3">03 · Reading the board</div>
  <div class="mono text-sm">ServiceLoader<br>.load(Driver.class)</div>
  <div class="text-sm muted mt-2">"I look from the floor the <b>thread</b> is standing on. Default: the ground floor."</div>
</div>

</div>

<v-clicks>

- Basement cards are invisible from the ground floor → pass the loader: `ServiceLoader.load(X.class, pluginLoader)`
- Some SPIs hate two providers (hello, SLF4J bindings) → **upstairs only**

</v-clicks>

<!--
SPI = Service Provider Interface. Someone defines an interface, any JAR can ship an implementation, and the caller never names it in code. JDBC drivers, logging bindings, Jackson modules, JAXB.

"The floor the thread stands on" is the thread context class loader (TCCL): `Thread.currentThread().getContextClassLoader()`. By default it's App — the host. From a floor you see its cards and the cards of every floor above it. Never the ones below.
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
  <div class="card-title mb-2"><code>DriverManager</code> · the concierge since JDK 1.1</div>
  <div>"I read the notice board once, from the ground floor. The host's mysql driver? It's not the <code>Driver</code> your basement sees, so you can't have it. Your own driver? Never heard of it."</div>
</div>

<div v-click class="mt-6 text-lg">
It looks everywhere <span class="accent">except where the driver is</span>.
</div>

<!--
Two reasons it fails:
1. `DriverManager` scans `META-INF/services/java.sql.Driver` once, on first use, through the TCCL. That's the host's loader, so the plugin's driver is never found.
2. The host's mysql 8.0 driver is registered. But `getConnection` checks that the caller's loader sees the same driver class. The basement has its own copy of `com.mysql.cj.jdbc.Driver` (child-first — two Ivanovs again), so the host driver is skipped.
-->

---

###### Part 3 · Step 5

# Plot twist: try again

```java
DriverManager.getConnection(url);   // 1st call: SQLException: No suitable driver
DriverManager.getConnection(url);   // 2nd call: works?!
```

<v-clicks>

- While checking the host's driver, the concierge asks the basement: `Class.forName(name, true, pluginLoader)`
- That loads the plugin's own driver — and its `static {}` registers it
- Too late for this call. **Just in time for the next one**

</v-clicks>

<div v-click class="aside">
Monitoring says: <b>"flaky database"</b>. Reality: class loaders.
</div>

<!--
Reproduced on JDK 21 with a fake driver.

The check (`isDriverAllowed`) calls `Class.forName` with `initialize = true`. `getConnection` loops over a snapshot of the registered drivers (a `CopyOnWriteArrayList`), so the freshly registered plugin driver only shows up on the next call.

This needs a host driver of the same class name. Without one, nothing triggers the load, and every retry fails too.
-->

---

###### Part 3 · Step 5

# Fix: introduce the driver yourself

```java
// on start: load the driver through the plugin loader
Class.forName("com.mysql.cj.jdbc.Driver", true, pluginLoader);  // its static {} registers it

// on unload, from plugin code
DriverManager.deregisterDriver(pluginDriver);                    // or the basement is never demolished
```

<div v-click class="mt-6 text-lg">
Or skip the concierge: create the driver's <code>DataSource</code> directly.
</div>

<div v-click class="aside">
The concierge never leaves, never forgets. Take your driver back before you move out.
</div>

<style>
.slidev-code { --slidev-code-font-size: 12.5px; }
</style>

<!--
`deregisterDriver` checks that the caller sees the same driver class. Call it from plugin code — from host code you get a `SecurityException`.

Switching the TCCL helps only if `DriverManager` hasn't scanned yet, and in a running host it usually has.
-->

---

###### Part 3 · Plugins

# Most wanted

<div class="grid grid-cols-2 gap-5 mt-4">

<div v-click class="card">
  <div class="card-title mono text-sm accent">NoClassDefFoundError</div>
  <div class="text-sm mt-2 muted">"I was there at compile time. At runtime I'm gone — or my <code>static {}</code> blew up earlier."</div>
</div>

<div v-click class="card">
  <div class="card-title mono text-sm accent">LinkageError: loader constraint violation</div>
  <div class="text-sm mt-2 muted">"Two floors promised to share one type. Each brought its own."</div>
</div>

<div v-click class="card">
  <div class="card-title text-sm accent">Generic type erasure</div>
  <div class="text-sm mt-2 muted">"<code>List&lt;Foo&gt;</code>? At runtime I'm just <code>List</code>. I'll explode later — on <code>get()</code>."</div>
</div>

<div v-click class="card">
  <div class="card-title text-sm accent">Loader leak</div>
  <div class="text-sm mt-2 muted">"Someone upstairs still holds a key — a static field, a ThreadLocal, a running thread. The basement can't be demolished."</div>
</div>

</div>

---

###### There are no dumb questions

# Q & A, before you ask

<div class="flex flex-col gap-4 mt-4 text-sm">

<div v-click>
<b class="accent">Q: Why doesn't Maven just pick the newest version?</b><br>
<span class="muted">Newest isn't always safe either — 3.0 can break code built for 2.x. Maven picks <b>predictably</b>. The inspector tells you when it hurts.</span>
</div>

<div v-click>
<b class="accent">Q: Why not make everything child-first?</b><br>
<span class="muted">Then the basement's <code>Plugin</code> ≠ the ground floor's. Whatever crosses the border must be one class.</span>
</div>

<div v-click>
<b class="accent">Q: Then why not share everything?</b><br>
<span class="muted">That's just parent-first again. The plugin gets the host's versions — back to Try 1.</span>
</div>

<div v-click>
<b class="accent">Q: Can I evict just one tenant?</b><br>
<span class="muted">No. Only demolish the whole basement — once nothing points to the loader, its classes or their objects.</span>
</div>

</div>

---

###### Part 3 · Plugins

# House rules for plugins

<v-clicks>

1. **Shared list** of upstairs-only packages — API, logging, `java.*`
2. **Thin API module** — few classes cross the border
3. **Explicit loader** for `ServiceLoader`, `Class.forName`, JDBC
4. **Walk the thread down** to the basement (TCCL) — and back up in `finally`
5. **Don't hand basement-only classes** to the host
6. **On unload:** deregister drivers, stop threads, clear ThreadLocals
7. **`close()` the loader** — return the van keys (open JAR files)
8. **Test isolation** — two plugins, two versions of one library

</v-clicks>

<!--
The rules follow the story: steps 3–4 gave us the shared list and the thin API, step 5 gave us explicit loaders and driver cleanup.

Rule 4: Jackson modules, JAXB and many SPIs use `Thread.currentThread().getContextClassLoader()`. Set it to the plugin loader before calling plugin code and restore it in `finally`. Otherwise the plugin looks for its classes on the host's floor.

Rule 7: a `URLClassLoader` keeps its JARs open. Forget `close()`, and on Windows you can't even delete the old plugin JAR.
-->

---

###### Alternatives

# Can we skip the custom loader?

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
The further right — the fewer conflicts, and the bigger the bill.
</div>

---

###### Alternatives

# One line each

<div class="mt-2 text-[0.95rem]">
<div v-click class="grid grid-cols-[10rem_14rem_1fr] gap-4 py-3 border-b border-[var(--noir-border)]">
  <b>Shading</b><span class="accent">rename one Ivanov</span><span class="muted">Packages renamed at build time. Misses class names in config files and strings built at runtime</span>
</div>
<div v-click class="grid grid-cols-[10rem_14rem_1fr] gap-4 py-3 border-b border-[var(--noir-border)]">
  <b>JPMS</b><span class="accent">doors with locks</span><span class="muted">Strong walls, but one version per module. Several versions only via <code>ModuleLayer</code> — a custom loader in disguise</span>
</div>
<div v-click class="grid grid-cols-[10rem_14rem_1fr] gap-4 py-3 border-b border-[var(--noir-border)]">
  <b>Custom loader</b><span class="accent">dig your own basement</span><span class="muted">Full control, plugins at runtime — and every trap is yours</span>
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

###### Bullet points

# What to take home

<v-clicks>

1. The doorman (Maven) picks **vans** (JARs) by name — closest wins
2. A floor (class loader) picks **tenants** (classes) — first van wins
3. The JVM is **lazy** → errors show up late
4. **Class = name + loader** — Ivanov ≠ Ivanov
5. Parent-first is the **default** — upstairs always wins
6. Plugins: a child-first basement + a **shared list** + an explicit loader for SPI

</v-clicks>

---
layout: statement
---

# Questions?

<div class="mono text-lg muted mt-8">
<span class="line-through decoration-[var(--noir-accent)] decoration-2">Foo cannot be cast to Foo</span>
</div>

<div class="mt-3 muted">now you know which floors</div>
