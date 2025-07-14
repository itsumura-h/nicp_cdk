# Async/Await in Nim: A Demonstration of Metaprogramming Flexibility

Hello everyone, thank you for coming to the last talk of the day. I know you're all eager to get home. My name is Dominik Pihata, I've been a core contributor to Nim for many years, and I wrote the first book about Nim called "Nim in Action". Currently, I work at Facebook during the day, and then I work on Nim whenever I have time at night.

So, without further ado, let's talk about Nim's async/await.

## Introduction to Nim

Many of you here may not need to hear this, and some of you may have already heard about Nim. But for those of you who are unfamiliar with Nim, or for those of you who are watching at home, I'd like to give a few words of introduction.

What is Nim? Well, Nim is a programming language, of course, but it has some very special properties.

*   **Efficient and Portable:** It can compile to C, C++, Objective-C, and even JavaScript. This gives it C-like speed and access to C's extensive libraries.
*   **Easy to Learn:** Nim focuses on building a small language core, implementing more features using its excellent macro system. This makes it easy for anyone to pick up.
*   **Modern:** It includes many features you'd expect from a modern language, such as generics, iterators, closures, and a great module system.
*   **Production Ready:** Last year, we hit our 1.0 release, and Nim now guarantees backward compatibility and is ready for production use. The great thing about the 1.0 release is that it shipped with two very cool features: procedural macros and async/await. And I'm going to touch on both of those in this talk.

So, enough with the preamble, let's get into the meat of it. We'll start with some basics.

## The Problem with I/O

What is the problem with I/O? I/O operations, such as reading data from a hard drive or receiving information over a network, can be very slow. When you perform synchronous I/O, your application becomes blocked, meaning it's not doing any useful work while the I/O operation is in progress.

Asynchronous I/O, on the other hand, solves this problem by providing a mechanism to repeatedly check whether the I/O operation has completed. But there's no easy way to do this. How do you manage thousands of I/O operations with many actions that should execute when each operation completes?

The most basic solution is to use callbacks. But as many of you know, callbacks can be extremely difficult to manage. Here's an example of callbacks in Nim. The main reason is that callbacks don't compose well. Ideally, we want to write I/O code just like we write non-I/O code.

```nim
proc onGotSecoundaryData(data: string) =
  echo "Got: ", data

proc onGotFirstData(data: string) =
  socket.recv(100, onData=onGotSecoundaryData)

proc getData(socket: AsyncSocket) =
  socket.recv(100, onData=onGotFirstData)
```

To explain this code, it's basically three functions. `getData` at the bottom reads 100 bytes of data from a socket, takes a callback called `onGotFirstData`, which reads another 100 bytes, takes another callback, and then finally that callback prints the result from the receive call.

Callbacks are the worst. I think you'll all agree with me on that.

## A Better Solution: Async/Await

I think one of the best solutions is what we call async/await. Here's another example showing just that. We have a `getData` procedure that takes a socket and an async socket. The `async` pragma there indicates that it's an asynchronous procedure. We immediately see that the first 100 bytes read from the socket are discarded, and only the second 100 bytes are used to print it. The code is much easier to understand, and the `await` call provides a useful hint as to where I/O is being performed.

```nim
proc getData(socket: AsyncSocket): {.async.} =
  discard await socket.recv(100)
  let secoundData = await socket.recv(100)
  echo "Got: ", secoundData
```

Now, you may have seen this in other languages like C# or Rust, but what's special about this is that it's implemented entirely using macros in Nim. The compiler has no support for this whatsoever. And I'm going to talk more about this in a bit.

## Building Blocks of Nim's Async

So, first, let's talk about how all the components of Nim's async fit together. There aren't actually that many; there are four components.

1.  Future
2.  Asynchronous procedures
3.  `selectors` module
4.  Asynchronous dispatcher

Let's look at these in a bit more detail.

### Future

`Future` is a simple object that acts as a container. If you run the code at the top, you'll see that it's a simple generic type definition that takes a generic type `T`. It has four fields.
*   `value`: stores the value that will be stored in the future.
*   `callback`: you can set a procedure that will be called when the future completes.
*   `finished`: a field to keep track of whether the future has completed.
*   `exception`: for when an error occurs during the future's computation.

```nim
type Future[T] = ref object
  value: T
  callback: proc()
  finished: bool
  exception: Exception
```

### Asynchronous Procedures

```nim
proc findPageSize(client: AsyncHttpClient, url: Uri):Future[int] {.async.} =
  let data = await client.getContent(url)
  return data.len
```

Here's another example of an asynchronous procedure called `findPageSize`. It takes two arguments: `AsyncHttpClient` and `url`, and it returns a `Future[int]`. And then again, the `async` pragma is there to indicate that it's an asynchronous procedure. In the body, we use the HTTP client to send an HTTP GET to a URL, and then we return the length of the data that we receive.

Now, the problem here is that Nim has no idea how asynchronous procedures work, so how would we represent this without the `async` pragma?

```nim
proc findPageSize(client: AsyncHttpClient, url: Uri):Future[int] =
  result = newFuture[int]()
  let dataFut = client.getContent(url)
  dataFut.callback = proc() =
    result.complete(dataFut.read().len)
```

One possible way is to transform it to use callbacks. It would look like this. The function is very similar, but the `async` pragma is gone. We set `result` to a newly allocated `Future`, and then we call the `getContent` procedure again. That returns a future. We assign that to a new variable, and then we assign a new procedure to its callback field, and in that callback, we complete the result's future with the length of the data future. There are a lot of futures here, so I hope you're following along.

This isn't ideal. The problem is that it's not scalable. As soon as you add control flow to a synchronous procedure, you're going to have problems. The transformation becomes very difficult.

And I should preface this by saying that Andreas told me that it is, apparently, possible to achieve this, but I've looked, and I haven't found a programming language that does this. Even JavaScript, when you transpile JavaScript code with `await` to ECMAScript 5 using Babel, still uses iterators.

This leads us to our second transformation attempt: using iterators. Here, we have very similar code again, but we're just using an iterator. Nim has a `closure` pragma that basically turns iterators into something that can be allocated on the heap. This makes the transformation much easier, because all we have to do is change each `await` statement to a `yield`. The rest of it is fairly similar to the previous code, but you'll see that it's not that hard to transform more complex examples. And the scalability problem is solved.

```nim
proc findPageSize(client: AsyncHttpClient, url: Uri):Future[int] {.closure.} =
  result = newFuture[int]()
  let dataFut = client.getContent(url)
  yield dataFut
  result.complete(dataFut.read().len)
```

## Metaprogramming in Nim

Next, we'll move on to metaprogramming in Nim. I'm going to show you how we achieve this transformation.

```nim
proc testAsync(): Future[int] {.async.} =
  return await getMagicInt()

macro async(body: untyped): untyped =
  echo treeRepr(body)
```

So, we have this simple procedure here. I think we need to simplify it a little bit for this example. When you start developing macros in Nim, you usually start with something like this. An `async` macro that takes an `untyped` type for the `body` parameter. This is a magical type that refers to multiple code statements, and it returns `untyped` because we're transforming a procedure code statement into another code statement. And in its body, we're just printing the tree representation of the abstract syntax tree (AST).

And then it looks like this. We have a link at the bottom if you want to try it out on the Nim playground. You can run it in your browser. Basically, you get this beautiful tree structure with each component of the procedure: the name `testAsync`, the parameters (in this case, just a return value), and the body, which contains the `await` and `return` statements.

Going back to our example, how would you develop a macro that transforms a synchronous procedure into its equivalent iterator? Well, it would look something like this. I couldn't show you something that works generically for all asynchronous procedures, so I've obviously taken some liberties here. It wouldn't fit on the slide.

```nim
proc testAsync(): Future[int] {.async.} =
  return await getMagicInt()

macro async(body: untyped): untyped =
  let name = body[0]
  let returnType = body[3][0]
  let awaitedFunc = body[6][0][0][1]
  result = quote:
    iterator `name`(): `returnType` =
      yield `awaitedFunc`
  echo result.toStrLit
```

So, here, we're hardcoding the locations in the AST for each node that we're transforming. We're getting the first child node of the body and assigning it to the `name` variable, which is the name of the procedure. Then we're getting the return type. And then the awaited function, we're getting that from the body, assuming there's only one. And obviously, this is going to break very quickly.

And then we're using this beautiful feature of Nim where you basically quote what you want the macro to output. And then we're using backticks to embed the AST nodes that we need. And that becomes our result. And then we're echoing the result of the macro, the AST node that we're returning, in the form of Nim code. Again, you can try this out using the link at the bottom there. And if you run this code, it will print that to your console. This is the result of the macro.

```nim
iterator testAsync(): Future[int] =
  yield getMagicInt()
```

And that's it for metaprogramming. I hope that gives you a little bit of an idea of how this works and maybe spurs you to look into it further.

## Other Components

Let's quickly go over some of the other components.

### `selectors` Module

The `selectors` module, which is in the standard library, implements a readiness-based I/O API. It basically wraps `epoll`, `kqueue`, and so on, and provides a great API. It's very portable because it has no dependencies, it's high-performance, and it basically supports everything.

### Asynchronous Dispatcher

And then there's also an asynchronous dispatcher built on top of `selectors`, which implements a proactor API. So, instead of asking the system, "Hey, I want to read from a socket, is it ready to read?", you would say, "Hey, I want to read 100 bytes of data from a socket," and then it will notify you when it's ready. And that's actually how I/O completion ports work on Windows. So this module also implements I/O completion ports on Windows and provides a layer on top of the `selectors` module to provide a proactor API.

## Current State and Future of Nim's Async

So, briefly, the current state of Nim's async. It's used in production. The Nim forum runs on it. And there's also this HTTP server that gets pretty good numbers on the TechEmpower benchmarks. It's neck and neck with Rust. It's called `httpbeast`, so if you're interested, go check it out.

And then the future of async: we might borrow some ideas from Rust and use zero-cost abstractions using polling futures. Better integration with Nim's parallelism (there's currently no way to use `spawn` and `await spawn`), and better stack traces as well.

The best way to learn is to pick up my book. That's it. There are a few other links there.

## Q&A

**Question:** Why not use green threads?

**Answer:** That's a good question. I think in a systems programming language like Nim, it would have been much more complicated. I guess when you have green threads, you would also assume that you need a runtime to use them, but this allows you to opt out of using a runtime if you don't really need one. So that's the main reason.

**Question:** Or do you use callbacks? If you have callbacks, I don't know, you can call them any number of times. Do you have to keep that code?

**Answer:** I'm not entirely sure what you mean. The current mechanism in Nim allows each future to basically emulate callbacks. Since we're returning futures from all our synchronous procedures, we can say, "Hey, assign a callback to this future and call it when it's ready." And that's how it works. Every time you read from a socket, you get a new future, and you repeatedly assign callbacks to it. Does that make sense?

Alright, that's it for me. Thank you very much for a great talk. When you exit the room, please look around and make sure you haven't left anything behind... [End of talk] 