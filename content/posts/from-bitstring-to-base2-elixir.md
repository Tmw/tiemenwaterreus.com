---
title: From BitString to Base2 with Elixir
date: 2020-07-03T00:30:03+02:00
draft: false
description: Printing the binary representation of a BitString using Elixir.
tags: BitString, Elixir, Binary, Base2
icon: 🧶
---


If you ever worked with the BitString type in Elixir you're probably familiar with the `<<104, 101, 108, 108, 111>>`-like notation. This is basically a compact notation of printing each byte as their decimal notation. Converting them to a string of ones and zeroes is as easy as combining a BitString generator with some functions from the Enum module, and voila:


```elixir
defmodule Bits do
  def as_string(binary) do
    for(<<x::size(1) <- binary>>, do: "#{x}")
    |> Enum.chunk_every(8)
    |> Enum.join(" ")
  end
end
```

Calling the function defined above like:

```elixir
Bits.as_string("Hello, world!")
"01001000 01100101 01101100 01101100 01101111 00101100 00100000 01110111 01101111 01110010 01101100 01100100 00100001"
```

Where every 8 bits are separated with a space for readability, we can clearly see the patterns of the ASCII table, where: 

```text
H = 0100 1000
e = 0110 0101
l = 0110 1100
etc.
```

🙌
