---
title: Huffman coding from scratch with Elixir
date: 2020-09-03T14:00:10+02:00
draft: false
description: Implement a basic Huffman compression algorithm using Elixir.
tags: Huffman, compression, encoding, lossless, elixir
icon: 🗜️
---
Huffman coding is a pretty straight-forward lossless compression algorithm first described in 1992 by David Huffman. It utilizes a binary tree as its base and it's quite an easy to grasp algorithm. In this post we walk through implementing a Huffman coder and decoder from scratch using Elixir ⚗️

## How does Huffman work?
In this example we assume the data we are compressing is a piece of text, as text lends itself very well for compression due to repetition of characters.

The algorithm in its core works by building a binary tree based on the frequency of the individual characters. Placing characters with a higher frequency closer to the root of the tree than characters with a lower one.

The Huffman code can be derived by walking the tree until we find the character. Every time we pick the left-child, we write down a `0` and for every right-child a `1`. Repeat the process for each character in the text, and voila!

Decoding the text is as simple as starting at the root of the tree and traverse down the left-child for every `0` you encounter and pick the right-child for every `1`. Once you hit a character, write it down and start over with the remainder of the bits.


For an excellent explanation on the Huffman Coding algorithm, give this [explainer video by Tom Scott](https://www.youtube.com/watch?v=JsTptu56GM8) a watch!

## Let's get to work: Setting up the project
Ok! Let's begin by generating a new Mix project using `mix new huffman`. `cd huffman` into the project root and open up the `lib/huffman.ex` file. This file contains our `Huffman` module. Replace the contents of the file with a single function declaration `encode/1` like so:

```elixir
defmodule Huffman do
  def encode(text \\ "cheesecake") do
  end
end
```

This function accepts the text we like to compress and defaults to "cheesecake" because, why not 🤷


## Frequency analysis
The first step in Huffman coding is a simple frequency analysis. For each character in the given text, count how many times it is used in the text. This is a rather crucial part of the encoding algorithm as this determines where the characters are placed in the binary tree.

For example; when encoding the word "cheesecake" we can already see that certain characters appear more than others. `e` is used four times whereas the `c` appears only twice. 

Let's write some code that does the frequency analysis for us. Update our `encode/1` function to match the following:

```elixir
def encode(text \\ "cheesecake") do
  frequencies =
    text
    |> String.graphemes()
    |> Enum.reduce(%{}, fn char, map ->
      Map.update(map, char, 1, fn val -> val + 1 end)
    end)
end
```

This code above splits the input string into graphemes (individual characters) and stores the count per character in a map using [Map.update/4](https://hexdocs.pm/elixir/Map.html#update/4).

Popping into an `iex` shell and running `Huffman.encode` now gives us the following output:
```elixir
%{
  "a" => 1,
  "c" => 2,
  "e" => 4,
  "h" => 1,
  "k" => 1,
  "s" => 1
}
```

## Sorting the characters
Since order is important when building our tree, we need to sort the list of characters by their frequency. Luckily Elixir's Enum module comes to the rescue. Add the following code to our `Huffman.encode/1` function:

```elixir
queue = 
  frequencies
  |> Enum.sort_by(fn {_char, frequency} -> 
    frequency 
  end)
```
By passing the map with frequencies to [`Enum.sort_by/2`](https://hexdocs.pm/elixir/Enum.html#sort_by/3), we sort the map using its values (the frequencies). This outputs:

```elixir
[
  {"a", 1}, 
  {"h", 1}, 
  {"k", 1}, 
  {"s", 1}, 
  {"c", 2}, 
  {"e", 4}
]
```

## Building the tree
Before we can neatly build a tree, we need to determine which kinds of nodes we have. We have a `Leaf` node which holds a single character and a `Node` which contains a left- and a right child. Each child on its own can be another `Node` or a `Leaf`.

Let's define two structs to model these types of nodes at the top or our module:

```elixir
defmodule Node do
  defstruct [:left, :right]
end

defmodule Leaf do
  defstruct [:value]
end
```

_Note:_ Make sure you define the two structs within our current `Huffman` module to avoid naming clashes with the built-in [`Node`](https://hexdocs.pm/elixir/Node.html).

The next step is to iterate over our list of sorted characters and convert them to `Leaf` nodes. Extend our `Huffman.encode/1` function like this:

```diff
  queue =
    frequencies
    |> Enum.sort_by(fn {_node, frequency} -> frequency end)
+   |> Enum.map(fn {value, frequency} -> 
+        {
+          %Leaf{value: value}, 
+          frequency
+        }
+   end)
```

Now that we have an ordered set of `Leaf` nodes, we can build up the rest of the binary tree. Define a new function to do exactly this:

```elixir
defp build([{root, _freq}]), do: root

defp build(queue) do
  [{node_a, freq_a} | queue] = queue
  [{node_b, freq_b} | queue] = queue

  new_node = %Node{
    left: node_a,
    right: node_b
  }

  total = freq_a + freq_b

  queue = [{new_node, total}] ++ queue

  queue
  |> Enum.sort_by(fn {_node, frequency} -> frequency end)
  |> build()
end
```

Since this is a recursive function we need an exit condition, otherwise we are looping forever. In our case we are done building the tree when there is only a single root-node in the queue. The second clause is a bit more beefy, let's break it down:

- First thing we do is pop two nodes of the queue by pattern matching the tuple `{node, frequency}` as the head of the list, and matching the _rest_ of the list again as `queue`. Doing this twice gives us two nodes and their frequencies we can work with. 

- The next step is combining these two nodes in a parent `Node` and tallying up the frequencies so we can prepend it to the queue.

- The next step is sorting the queue again to make sure the items with the lowest frequency are at the head of the queue.

- The last step is to call `build/1` again so this process starts all over again.

Calling our `build/1` function at the end of our `Huffman.encode/1` function passing the queue of items results in: 

```elixir
%Huffman.Node{  
  left: %Huffman.Leaf{value: "e"},
  right: %Huffman.Node{
    left: %Huffman.Leaf{value: "c"},    
    right: %Huffman.Node{
      left: %Huffman.Node{
        left: %Huffman.Leaf{value: "k"},
        right: %Huffman.Leaf{value: "s"}
      },
      right: %Huffman.Node{
        left: %Huffman.Leaf{value: "a"},
        right: %Huffman.Leaf{value: "h"}
      }
    }
  }
}
```

The output above shows a tree structure where the character `e` is placed more towards the root of the tree and the character `a` is placed more towards the bottom. Each node in our tree is either a `Leaf` with the actual character or another `Node`. Drawn out this looks like:

{{< figure src="/resources/huffman/tree.png" caption="Our Huffman tree" width="500" >}}

## Encoding the text
Now that we have the Huffman tree all setup and ready to go, let's focus on encoding the text using Huffman coding. The process of doing so is quite simple:

Look up each character of the text in our binary tree and keep track of each step while traversing down the tree. Each time we traverse down the left-child, write down a `0` and each time we traverse down the right-child write down a `1`. Once we find the character in the tree, the path we wrote down is our Huffman code.

### An example

So for example, in our tree above, the letter C has the code `10` since at the first node we  take the right branch and then the left branch and voila. Similarly for the character `s` the code is `1101` since for the first two nodes, we take the right branch, then the left and lastly the right one again.

{{< figure src="/resources/huffman/tree_with_example.png" caption="Encoding process of S an C" width="500">}}

### Code

First things first, we should be able to look up a character in the binary tree and keep track of its path while doing so.
```elixir
defp find(tree, character, path \\ <<>>)

defp find(%Leaf{value: value}, character, path) do
  case value do
    ^character -> path
    _ -> nil
  end
end

defp find(%Node{left: left, right: right}, character, path) do
  find(left, character, <<path::bitstring, 0::size(1)>>) ||
    find(right, character, <<path::bitstring, 1::size(1)>>)
end
```

In the code example above we defined a function with two different clauses and a function header. The function header is just so that we can define a default value for the path which we set to an empty binary.

The first clause executes when passed in a `Leaf` node. The only thing we need to do is compare its value to the character we are looking for. When they match, return the path, else return `nil`.

The second clause matches on `Node`s and calls `find/3` with each child of the node, passing in an updated path. So when recursing on the left-child, we update the `path` with a `0`. The `||` (or) operator makes sure that either of the two paths is returned.

Now that we can look up a single character in our binary tree, let's iterate over all the characters in the text and replace them with their Huffman code. Add the following function to our `Huffman` module:

```elixir
defp convert(text, tree) do
  text
  |> String.graphemes()
  |> Enum.reduce(<<>>, fn character, binary ->
    code = find(tree, character)

    <<binary::bitstring, code::bitstring>>
  end)
end
```

This function simply breaks the text into graphemes and iterates over each grapheme by calling `Enum.reduce/3`. Starting off with a empty binary, we can simply append to it for each character we find.

Now wire it all up and call our `convert/2` function at the bottom of our `Huffman.encode/1` function passing the original text and the tree. 

The `encode/1` function now looks like:

```elixir
def encode(text \\ "cheesecake") do
  frequencies =
    text
    |> String.graphemes()
    |> Enum.reduce(%{}, fn char, map ->
      Map.update(map, char, 1, fn val -> val + 1 end)
    end)

  queue =
    frequencies
    |> Enum.sort_by(fn {_node, frequency} -> frequency end)
    |> Enum.map(fn {value, frequency} -> {%Leaf{value: value}, frequency} end)

  tree = build(queue)
  {tree, convert(text, tree)}
end
```

As you can see it returns a tuple containing the tree and the encoded text. It returns the tree because we need this in the next step to decode the text to its original form again.

Calling `Huffman.encode` now results in the following:

```elixir
{
  %Huffman.Node{
   left: %Huffman.Leaf{value: "e"},
   right: %Huffman.Node{
     left: %Huffman.Leaf{value: "c"},
     right: %Huffman.Node{
       left: %Huffman.Node{
         left: %Huffman.Leaf{value: "k"},
         right: %Huffman.Leaf{value: "s"}
       },
       right: %Huffman.Node{
         left: %Huffman.Leaf{value: "a"},
         right: %Huffman.Leaf{value: "h"}
       }
     }
   }
 }, <<188, 213, 216>>}
```

Where the second element of the tuple (`<<188, 213, 216>>`) is our compressed data. 

### Quick size comparison
```elixir
iex(1)> <<188, 213, 216>> |> bit_size()
24 # variable bit length per char, but max 4 bits in this scenario

iex(2)> "cheesecake" |> bit_size()
80 # 10 chars * 8 bits per char = 80 bits
```
Using our Huffman module, encoding the string "cheesecake" results in a binary blob of _only_ 24 bits. Each character in our binary tree is reachable in max. four steps, so each character is encoded in 4 bits or less. Using ASCII encoding each character takes 8 bits.

However, in order to decompress the text, we need access to the same tree we used to compress the text. Meaning that if we want to send the compressed data over the wire or store it to disk, we need need to account for additional space for the tree too.

## Decoding
Now that we have coded ourselves the ability to encode text using Huffman coding, we also should have a way to decode the data back to its original form.

Decoding the data is quite straight-forward: all we need is our original Huffman tree and the encoded binary blob from the previous steps.

We use the binary blob as some sort of turn-by-turn navigation through our binary tree. From the top of the tree, traverse down the left-child when encountering a `0` in the data and traverse down the right-child when finding a `1`. 

Repeat this process until we hit a `Leaf` node. Write down the value of the `Leaf` and repeat with the remainder of the bits.

### Code
First things first, we need a function that can walk the tree following the instructions in the compressed data, until we hit a `Leaf` node.

```elixir
defp walk(binary, %Leaf{value: value}), do: {binary, value}

defp walk(<<0::size(1), rest::bitstring>>, %Node{left: left}) do
  walk(rest, left)
end

defp walk(<<1::size(1), rest::bitstring>>, %Node{right: right}) do
  walk(rest, right)
end
```

In the code above we define a `walk/2` function that takes the encoded binary and the tree and walks the tree. For every `Node` it encounters it looks at the next _bit_ of the data to determine whether it should traverse down the first-child (found a `0`) or traverse down the right-child (found a `1`).

It keeps doing that until it finds a `Leaf` node, then it returns the remainder of the data and the character that belongs to that code.

Now that we have a function that can walk to the first available `Leaf` node following the instructions of the data, we want to call this function recursively as long as there's more binary data available.

Let's define another function:

```elixir
def decode(tree, data, result \\ [])

def decode(_tree, <<>>, result), 
  do: List.to_string(result)

def decode(tree, data, result) do
  {rest, value} = walk(data, tree)
  decode(tree, rest, result ++ [value])
end
```

The `decode/3` function above has two clauses. The last one basically walks the tree until it finds the first `Leaf` node, stores its character value in a list (`result`) and recurses with the remainder of the binary data.

The first clause matches once we have no binary data left to decode. It passes the result to `List.to_string/1` concatenating the items in the list together forming a string.

## The end result

That's all there is to it! We built ourselves a Huffman Coder and Decoder using ~90 lines of Elixir:

```elixir
defmodule Huffman do
  defmodule Node do
    defstruct [:left, :right]
  end

  defmodule Leaf do
    defstruct [:value]
  end

  def encode(text \\ "cheesecake") do
    frequencies =
      text
      |> String.graphemes()
      |> Enum.reduce(%{}, fn char, map ->
        Map.update(map, char, 1, fn val -> val + 1 end)
      end)

    queue =
      frequencies
      |> Enum.sort_by(fn {_node, frequency} -> frequency end)
      |> Enum.map(fn {value, frequency} -> {%Leaf{value: value}, frequency} end)

    tree = build(queue)
    {tree, convert(text, tree)}
  end

  def decode(tree, data, result \\ [])

  def decode(_tree, <<>>, result),
    do: List.to_string(result)

  def decode(tree, data, result) do
    {rest, value} = walk(data, tree)
    decode(tree, rest, result ++ [value])
  end

  defp walk(binary, %Leaf{value: value}), do: {binary, value}

  defp walk(<<0::size(1), rest::bitstring>>, %Node{left: left}) do
    walk(rest, left)
  end

  defp walk(<<1::size(1), rest::bitstring>>, %Node{right: right}) do
    walk(rest, right)
  end

  defp build([{root, _freq}]), do: root

  defp build(queue) do
    [{node_a, freq_a} | queue] = queue
    [{node_b, freq_b} | queue] = queue

    new_node = %Node{
      left: node_a,
      right: node_b
    }

    total = freq_a + freq_b

    queue = [{new_node, total}] ++ queue

    queue
    |> Enum.sort_by(fn {_node, frequency} -> frequency end)
    |> build()
  end

  defp find(tree, character, path \\ <<>>)

  defp find(%Leaf{value: value}, character, path) do
    case value do
      ^character -> path
      _ -> nil
    end
  end

  defp find(%Node{left: left, right: right}, character, path) do
    find(left, character, <<path::bitstring, 0::size(1)>>) ||
      find(right, character, <<path::bitstring, 1::size(1)>>)
  end

  defp convert(text, tree) do
    text
    |> String.graphemes()
    |> Enum.reduce(<<>>, fn character, binary ->
      code = find(tree, character)

      <<binary::bitstring, code::bitstring>>
    end)
  end
end
```

## Next steps
There's several improvements we can make to this implementation. For example, when encoding the text and looking up the Huffman code in the tree, we don't have to walk the tree for every character. We can do a full traversal once and keep track of each character and its Huffman code in a map.


Also building up the queue can be improved. We don't have to keep sorting the queue after every insert, rather have a look at a proper priority queue.

For an implementation that also serializes the tree to be written to disk or network, head over to [the GitHub repository](https://github.com/Tmw/huffman)

Thanks for reading! 🤘
